import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/foundation.dart';

import 'art.dart';
import 'config.dart';
import 'geometry.dart';
import 'lighthouse_game.dart';
import 'tables.g.dart';

/// 적 상태: 다가옴 → 갉기, 또는 쓰러짐 (design.md §4).
enum EnemyState { moving, biting, dying }

/// 시트 그림이 원래 보는 쪽.
enum ArtFacing { front, left, right }

/// 사방에서 등대로 곧장 다가와 불빛을 갉는 적 (design.md §4).
///
/// 위치([position], 게임 좌표)는 몸 가운데. 규칙 숫자는 모두 숫자 표(`Tables.enemies`, `Tables.beam`)에서.
/// 판이 멈추면(불빛 꺼짐) 움직이지도 갉지도 않는다.
///
/// `PositionComponent`가 아닌 까닭: 설계의 `distance`(등대까지 거리) 이름이 `PositionComponent.distance(other)`와 겹친다.
/// 부모(판의 적 층)가 게임 좌표 그대로라 [position]을 직접 들고 그 자리에 그린다.
class Enemy extends Component with HasGameReference<LighthouseGame> {
  Enemy(this.id, double angleDeg, double distance)
      : stats = Tables.enemies[id]!,
        angleDeg = normalizeDeg(angleDeg),
        _distance = distance {
    hp = stats.hp;
    _place();
  }

  /// 쓰러진 뒤 판에서 사라지기까지 (death 8프레임 ÷ 10fps).
  static const double deathSeconds = 0.8;

  /// 시트 그림이 원래 보는 쪽 (`assets/images/<id>/move.webp`를 보고 정함).
  /// 적 셋은 모두 앞(보는 사람 쪽)을 본다: 실루엣 무게중심의 좌우 치우침이 256 px 프레임에서 1 px 안팎.
  /// 옆을 보는 그림으로 바꾸면 여기만 고친다 (등대 쪽을 보게 좌우를 뒤집는다).
  static const Map<String, ArtFacing> artFacing = {
    'shadow_blob': ArtFacing.front,
    'ink_squid': ArtFacing.front,
    'shadow_jelly': ArtFacing.front,
  };

  final String id;
  final EnemyStats stats;

  /// 몸 가운데 (게임 좌표).
  final Vector2 position = Vector2.zero();

  /// 나타난 각도 (등대 가운데에서, 그대로 유지).
  final double angleDeg;

  /// 지금 체력.
  late double hp;

  double _distance;

  /// 등대 가운데까지 거리.
  double get distance => _distance;

  /// 닿는 거리 = 등대 한 변의 절반 + 몸 반지름.
  double get contactDistance => GameConfig.lighthouseSize / 2 + stats.radius;

  EnemyState _state = EnemyState.moving;
  EnemyState get state => _state;

  /// 지금 빛 속인지 (몸 가운데로 매 순간 본다).
  bool get inBeam => game.beam.contains(position);

  double _biteTimer = 0;
  double _deathTimer = 0;
  double _flash = 0;

  CharacterArt? _art;
  final Map<String, SpriteAnimationTicker> _tickers = {};
  String? _action;

  /// 피해를 받는다. 빛 속이면 × vulnerable. 실제로 깎은 양을 돌려준다 (쓰러지는 중이면 0).
  double takeDamage(double amount) {
    if (_state == EnemyState.dying || amount <= 0) return 0;
    final dealt = math.min(amount * (inBeam ? Tables.beam.vulnerable : 1), hp);
    hp -= dealt;
    if (hp <= 0) {
      _state = EnemyState.dying;
      _deathTimer = 0;
      _flash = 0;
      // 쓰러지는 순간 그 자리에 빛 조각 하나 (쓰러진 적은 피해를 더 받지 않으니 한 번만, design.md §6)
      game.dropShard(position, stats.xp);
      game.countDefeat();
    } else {
      _flash = GameConfig.enemyHitFlashSeconds;
      // 그림을 읽기 전에 받은 피해의 hit는 그림이 온 뒤 재생하지 않는다 (번쩍만)
      if (_art != null) _play('hit', restart: true);
    }
    return dealt;
  }

  void _place() {
    position.setFrom(pointFromLighthouse(angleDeg, _distance));
  }

  @override
  void onLoad() {
    // 판이 그림을 기다리지 않게 읽기만 시작한다 (읽기 전에는 보라 원)
    // 그림은 표의 art (보스는 보통 적의 그림을 크게 쓴다, design.md §7)
    CharacterArt.load(game, stats.art)
        .then(_useArt, onError: (Object e) => debugPrint('enemy art load failed: ${stats.art} ($e)'));
  }

  void _useArt(CharacterArt art) {
    for (final action in art.actions) {
      _tickers[action] = art.animation(action).createTicker();
    }
    _art = art;
  }

  @override
  void update(double dt) {
    if (game.isStopped) return; // 판이 멈춤(꺼짐·카드 창·놓기): 움직임·갉기·그림 모두 그대로
    // 시간이 흐르지 않은 프레임(판에 붙는 update(0) 등)에는 아무 일도 없다.
    // 닿는 거리 안쪽에서 나타난 적도 시간이 흐르는 첫 update에 밖으로 옮겨진다 (design.md §5)
    if (dt <= 0) return;
    switch (_state) {
      case EnemyState.moving:
        _move(dt);
      case EnemyState.biting:
        _bite(dt);
      case EnemyState.dying:
        _deathTimer += dt;
        if (_deathTimer >= deathSeconds) {
          game.forgetEnemy(this);
          removeFromParent();
        }
    }
    if (_flash > 0) _flash = math.max(0, _flash - dt);
    _animate(dt);
  }

  void _move(double dt) {
    final speed = stats.speed * (inBeam ? Tables.beam.slow : 1);
    final step = speed * dt;
    final left = _distance - contactDistance;
    if (step < left) {
      _distance -= step;
      _place();
      return;
    }
    // 닿는 거리에서 멈추고(넘어가지 않음) 갉기. 걸어와 닿았으면 닿은 뒤 남은 시간(0 ~ dt)을 갉기 시간으로.
    // 닿는 거리 안쪽에서 나타났으면(left < 0) 밖으로 옮기고 이월은 0 (그 프레임에 갉지 않는다, design.md §5)
    _distance = contactDistance;
    _place();
    _state = EnemyState.biting;
    _biteTimer = 0;
    final carry = left < 0 || speed <= 0 ? 0.0 : (dt - left / speed).clamp(0.0, dt);
    _bite(carry);
  }

  void _bite(double dt) {
    _biteTimer += dt;
    while (_biteTimer >= stats.biteInterval && !game.isStopped) {
      _biteTimer -= stats.biteInterval;
      game.biteLight(stats.bite);
    }
  }

  // ---- 그림 ----

  /// 지금 상태의 기본 동작 (hit는 한 번 보인 뒤 이것으로 돌아온다).
  String get _baseAction => switch (_state) {
        EnemyState.moving => 'move',
        EnemyState.biting => 'attack',
        EnemyState.dying => 'death',
      };

  void _play(String action, {bool restart = false}) {
    if (_action == action && !restart) return;
    _action = action;
    _tickers[action]?.reset();
  }

  void _animate(double dt) {
    final art = _art;
    if (art == null) return;
    final current = _action;
    final hitting = current == 'hit' && _state != EnemyState.dying && !(_tickers['hit']?.done() ?? true);
    if (!hitting) _play(_baseAction);
    if (_action == 'attack') {
      _syncBite(art);
    } else {
      _tickers[_action]?.update(dt);
    }
  }

  /// 갉는 그림을 피해와 맞춘다 (design.md §5): attack 한 바퀴 = bite_interval, 이벤트 프레임이 갉는 순간에 시작.
  /// 그림만 맞추고 규칙(갉기 타이머)은 그대로다. 프레임은 갉기 타이머에서 바로 계산한다.
  void _syncBite(CharacterArt art) {
    final ticker = _tickers['attack'];
    if (ticker == null) return;
    final frames = art.frameCount('attack');
    final event = (art.eventFrame('attack') ?? 1) - 1;
    final step = stats.biteInterval / frames;
    final passed = step > 0 ? (_biteTimer / step).floor() : 0;
    ticker.currentIndex = (event + passed) % frames;
  }

  /// 화면 키 = 그림(art)의 display_height × scale (design.md §7, 보통 적은 art = 자기 id, scale 1).
  double get displayHeight => Tables.characters[stats.art]!.displayHeight * stats.scale;

  @override
  void render(Canvas canvas) {
    final art = _art;
    final ticker = _tickers[_action ?? _baseAction];
    if (art == null || ticker == null) {
      canvas.drawCircle(position.toOffset(), stats.radius, _placeholderPaint());
    } else {
      // 몸 가운데(첫 프레임 그림 영역의 가운데)가 위치에 오게, 키 displayHeight로
      final s = art.scaleForHeight(displayHeight);
      final body = Vector2((art.bbox.left + art.bbox.right) / 2, (art.bbox.top + art.bbox.bottom) / 2);
      canvas.save();
      canvas.translate(position.x, position.y);
      if (_flipped) canvas.scale(-1, 1);
      ticker.getSprite().render(canvas, position: -body * s, size: art.frameSize * s, overridePaint: _flashPaint());
      canvas.restore();
    }
    if (stats.boss && _state != EnemyState.dying) _renderBossBar(canvas);
  }

  /// 보스 머리 위 작은 체력 막대 (그리기만). 머리 끝은 몸 가운데에서 키의 절반 위.
  void _renderBossBar(Canvas canvas) {
    const w = GameConfig.bossBarWidth;
    const h = GameConfig.bossBarHeight;
    final top = position.y - displayHeight / 2 - GameConfig.bossBarGap - h;
    final rect = Rect.fromLTWH(position.x - w / 2, top, w, h);
    final ratio = (hp / stats.hp).clamp(0.0, 1.0);
    canvas.drawRect(rect, _bossEmpty);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, w * ratio, h), _bossFill);
    canvas.drawRect(rect, _bossBorder);
  }

  static final _bossEmpty = Paint()..color = GameConfig.bossBarEmpty;
  static final _bossFill = Paint()..color = GameConfig.bossBarFill;
  static final _bossBorder = Paint()
    ..color = GameConfig.bossBarBorder
    ..style = PaintingStyle.stroke
    ..strokeWidth = GameConfig.bossBarBorderWidth;

  /// 등대 쪽을 보게 좌우를 뒤집는지 (앞을 보는 그림은 뒤집지 않는다).
  bool get _flipped {
    final lighthouseOnRight = math.cos(degToRad(angleDeg)) < 0;
    return switch (artFacing[stats.art] ?? ArtFacing.front) {
      ArtFacing.front => false,
      ArtFacing.left => lighthouseOnRight,
      ArtFacing.right => !lighthouseOnRight,
    };
  }

  /// 번쩍 세기 (0~1).
  double get _flashT => (_flash / GameConfig.enemyHitFlashSeconds).clamp(0.0, 1.0);

  Paint _placeholderPaint() =>
      Paint()..color = Color.lerp(GameConfig.enemyPlaceholder, GameConfig.enemyHitFlash, _flashT)!;

  Paint? _flashPaint() {
    final t = _flashT;
    if (t <= 0) return null;
    final c = GameConfig.enemyHitFlash;
    return Paint()..colorFilter = ColorFilter.mode(c.withValues(alpha: c.a * t), BlendMode.srcATop);
  }
}
