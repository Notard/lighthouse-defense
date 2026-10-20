import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/foundation.dart';

import 'art.dart';
import 'config.dart';
import 'enemy.dart';
import 'lighthouse_game.dart';
import 'slots.dart';
import 'tables.g.dart';

/// 자리에 놓여 사거리 안 적을 저절로 공격하는 친구 (design.md §5).
///
/// 위치([position], 게임 좌표)는 자리 가운데 = 몸 가운데. 규칙 숫자는 모두 숫자 표(`Tables.friends`)에서.
/// 판이 멈추면(불빛 꺼짐) 공격도 그림도 멈춘다.
class Friend extends PositionComponent with HasGameReference<LighthouseGame> {
  Friend(this.id, this.slot)
      : stats = Tables.friends[id]!,
        super(position: slot.center.clone());

  /// 공격 시작에서 효과까지 (attack 이벤트 프레임 5: (5 − 1) ÷ 12fps).
  static const double windupSeconds = 1 / 3;

  final String id;
  final FriendStats stats;

  /// 놓인 자리.
  final Slot slot;

  /// 남은 쉬는 시간 (0이면 바로 공격할 수 있다).
  double cooldown = 0;

  bool _attacking = false;
  double _windup = 0;
  Enemy? _target;

  /// 빛 속인지: 자리 가운데가 빛 속 (design.md §5-2, 매 순간 본다).
  bool get inBeam => game.beam.contains(slot.center);

  /// 공격 시작 ~ 효과 사이인지.
  bool get isAttacking => _attacking;

  /// 지금 과녁 (공격 시작에 정하고 효과가 나면 놓는다).
  Enemy? get target => _target;

  CharacterArt? _art;
  final Map<String, SpriteAnimationTicker> _tickers = {};
  String _action = 'idle';

  /// 발밑 금빛이 숨쉬는 시계 (초, 한 바퀴마다 0으로).
  double _glowClock = 0;

  /// 사거리 안 적: 자리 가운데에서 몸 가운데까지 거리 ≤ range이고 쓰러지는 중이 아닌 적.
  List<Enemy> enemiesInRange() => [
        for (final e in game.enemies)
          if (e.state != EnemyState.dying && e.position.distanceTo(position) <= stats.range) e,
      ];

  /// 과녁 고르기: 사거리 안에서 등대에 가장 가까운 적, 같으면 친구에게 더 가까운 적 (없으면 null).
  Enemy? _pickTarget() {
    Enemy? best;
    for (final e in enemiesInRange()) {
      if (best == null ||
          e.distance < best.distance ||
          (e.distance == best.distance && e.position.distanceTo(position) < best.position.distanceTo(position))) {
        best = e;
      }
    }
    return best;
  }

  /// 과녁이 아직 맞을 수 있는지 (쓰러지지 않았고 판에서 사라지지 않음).
  bool _alive(Enemy? e) => e != null && e.state != EnemyState.dying && game.enemies.contains(e);

  @override
  void onLoad() {
    // 판이 그림을 기다리지 않게 읽기만 시작한다 (읽기 전에는 금빛 원)
    CharacterArt.load(game, id).then(_useArt, onError: (Object e) => debugPrint('friend art load failed: $id ($e)'));
  }

  void _useArt(CharacterArt art) {
    for (final action in art.actions) {
      _tickers[action] = art.animation(action).createTicker();
    }
    _art = art;
  }

  @override
  void update(double dt) {
    if (game.isOver) return; // 판이 멈춤: 공격·그림 모두 그대로
    if (dt <= 0) return; // 시간이 흐르지 않은 프레임에는 공격을 시작하지도 진행하지도 않는다 (design.md §5 프레임 시간)
    // 빛 속이면 쉬는 시간이 friend_haste배 빨리 준다 (windup은 그대로, design.md §5-2)
    cooldown = math.max(0, cooldown - dt * (inBeam ? Tables.beam.friendHaste : 1));
    _glowClock = (_glowClock + dt) % GameConfig.beamGlowPeriod;
    if (_attacking) {
      _windup += dt;
      if (_windup >= windupSeconds) _strike();
    }
    if (!_attacking && cooldown <= 0) {
      final t = _pickTarget();
      if (t != null) _startAttack(t);
    }
    _animate(dt);
  }

  void _startAttack(Enemy t) {
    _target = t;
    _attacking = true;
    _windup = 0;
    cooldown = stats.interval;
    // 그림을 읽기 전 공격은 그림이 온 뒤 재생하지 않는다
    if (_art != null) _play('attack');
  }

  /// 효과: shot은 거품, melee는 과녁에 damage(쓰러졌으면 헛침), burst는 사거리 안 모두에게 damage.
  void _strike() {
    final t = _target;
    _attacking = false;
    _target = null;
    switch (stats.attack) {
      case 'shot':
        final aim = _alive(t) ? t : _pickTarget();
        if (aim != null) game.shootBubble(muzzle, aim, stats.damage, stats.projectileSpeed);
      case 'melee':
        if (_alive(t)) t!.takeDamage(stats.damage);
      case 'burst':
        for (final e in enemiesInRange()) {
          e.takeDamage(stats.damage);
        }
    }
  }

  // ---- 그림 ----

  /// 몸 가운데(첫 프레임 그림 영역의 가운데, 프레임 px).
  static Vector2 _bodyOf(CharacterArt art) =>
      Vector2((art.bbox.left + art.bbox.right) / 2, (art.bbox.top + art.bbox.bottom) / 2);

  /// 거품이 나가는 점 (게임 좌표): 시트의 `muzzle`을 화면 배율로. 그림이나 muzzle이 없으면 자리 가운데.
  Vector2 get muzzle {
    final art = _art;
    final m = art?.muzzle;
    if (art == null || m == null) return position.clone();
    final s = art.scaleForHeight(Tables.characters[id]!.displayHeight);
    return position + (m - _bodyOf(art)) * s;
  }

  void _play(String action) {
    _action = action;
    _tickers[action]?.reset();
  }

  /// idle 반복, 공격 시작에 attack 한 번 → 끝나면 idle.
  void _animate(double dt) {
    if (_art == null) return;
    if (_action == 'attack' && (_tickers['attack']?.done() ?? true)) _play('idle');
    _tickers[_action]?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final lit = inBeam;
    if (lit) _renderGlowBehind(canvas);
    final art = _art;
    final ticker = _tickers[_action];
    if (art == null || ticker == null) {
      canvas.drawCircle(Offset.zero, Tables.characters[id]!.displayHeight / 2, _placeholder);
    } else {
      // 몸 가운데가 위치(자리 가운데)에 오게, 키 display_height로. 앞을 본다 (뒤집지 않음)
      final s = art.scaleForHeight(Tables.characters[id]!.displayHeight);
      ticker.getSprite().render(canvas, position: -_bodyOf(art) * s, size: art.frameSize * s);
    }
    if (lit) _renderSparkles(canvas);
  }

  // ---- 빛 속 금빛 (design.md §5-2, 그리기만. 숫자는 GameConfig.beam*) ----

  /// 숨쉬는 세기 (beamGlowMinStrength ~ 1).
  double get _glowStrength {
    final phase = (_glowClock / GameConfig.beamGlowPeriod).clamp(0.0, 1.0);
    final wave = (1 - math.cos(phase * 2 * math.pi)) / 2;
    return GameConfig.beamGlowMinStrength + (1 - GameConfig.beamGlowMinStrength) * wave;
  }

  /// 발 높이 (몸 가운데 기준 아래로). 발은 그림의 기준점, 그림 전에는 임시 원의 아래 끝.
  double get _footY {
    final art = _art;
    final height = Tables.characters[id]!.displayHeight;
    return art == null ? height / 2 : (art.anchor.y - _bodyOf(art).y) * art.scaleForHeight(height);
  }

  static Color _fade(Color c, double t) => c.withValues(alpha: c.a * t);

  /// 몸 뒤: 자리 둘레 고리(번짐 + 밝은 선), 후광, 발밑 타원.
  void _renderGlowBehind(Canvas canvas) {
    final k = _glowStrength;
    // 자리 원 둘레 고리: 바깥으로 번지는 주황 금빛 위에 밝은 선
    final ringGlow = Paint()
      ..color = _fade(GameConfig.beamRingGlowColor, k)
      ..style = PaintingStyle.stroke
      ..strokeWidth = GameConfig.beamRingGlowWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, GameConfig.beamRingGlowBlur);
    canvas.drawCircle(Offset.zero, GameConfig.beamRingRadius, ringGlow);
    final ring = Paint()
      ..color = _fade(GameConfig.beamRingColor, k)
      ..style = PaintingStyle.stroke
      ..strokeWidth = GameConfig.beamRingWidth;
    canvas.drawCircle(Offset.zero, GameConfig.beamRingRadius, ring);

    // 몸 뒤 후광
    final halo = Paint()
      ..shader = Gradient.radial(
        Offset.zero,
        GameConfig.beamHaloRadius,
        [_fade(GameConfig.beamHaloInner, k), GameConfig.beamHaloOuter],
      );
    canvas.drawCircle(Offset.zero, GameConfig.beamHaloRadius, halo);

    // 발밑 타원: 둥근 빛을 납작하게 눌러서
    final footY = _footY;
    const r = GameConfig.beamGlowWidth / 2;
    final foot = Paint()
      ..shader = Gradient.radial(Offset(0, footY), r, [_fade(GameConfig.beamGlowInner, k), GameConfig.beamGlowOuter]);
    canvas.save();
    canvas.translate(0, footY);
    canvas.scale(1, GameConfig.beamGlowHeight / GameConfig.beamGlowWidth);
    canvas.translate(0, -footY);
    canvas.drawCircle(Offset(0, footY), r, foot);
    canvas.restore();
  }

  /// 몸 앞: 발에서 위로 떠오르며 사라지는 작은 반짝이 (네 갈래 별).
  void _renderSparkles(Canvas canvas) {
    const n = GameConfig.beamSparkleCount;
    final footY = _footY;
    final base = (_glowClock / GameConfig.beamGlowPeriod).clamp(0.0, 1.0);
    for (var i = 0; i < n; i++) {
      final t = (base + i / n) % 1; // 이 반짝이가 떠오른 정도 0~1
      // 좌우 자리는 폭 안에 고르게 두되, 바깥 왼쪽·바깥 오른쪽·안 왼쪽… 차례로 번갈아 나오게
      final slot = i.isEven ? i ~/ 2 : n - 1 - i ~/ 2;
      final x = ((slot + 0.5) / n - 0.5) * GameConfig.beamSparkleSpread;
      final y = footY - t * GameConfig.beamSparkleRise;
      final alpha = math.sin(t * math.pi); // 나타났다 사라짐
      _drawStar(canvas, Offset(x, y), alpha);
    }
  }

  /// 네 갈래 별: 끝까지 반지름 beamSparkleSize, 허리는 그 beamSparkleWaist배.
  static void _drawStar(Canvas canvas, Offset c, double alpha) {
    const r = GameConfig.beamSparkleSize;
    const w = r * GameConfig.beamSparkleWaist;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + w, c.dy - w)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + w, c.dy + w)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - w, c.dy + w)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - w, c.dy - w)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _fade(GameConfig.beamSparkleEdge, alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = GameConfig.beamSparkleEdgeWidth,
    );
    canvas.drawPath(path, Paint()..color = _fade(GameConfig.beamSparkleColor, alpha));
  }

  static final _placeholder = Paint()..color = GameConfig.friendPlaceholder;
}
