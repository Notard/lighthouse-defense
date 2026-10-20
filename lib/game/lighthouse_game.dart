import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'art.dart';
import 'beam.dart';
import 'board_input.dart';
import 'bubble.dart';
import 'config.dart';
import 'enemy.dart';
import 'friend.dart';
import 'geometry.dart';
import 'hud.dart';
import 'slots.dart';
import 'strings.dart';
import 'tables.g.dart';
import 'tray.dart';

/// 한 판 (밤바다, 등대, 둘레 자리 18개, 빛 방향 끌기, 사방에서 오는 적과 등대 불빛, 친구 놓기와 자동 공격).
///
/// [practice]면 연습 스폰을 켠다 (앱은 켜고 테스트 기본 판은 끈다). [seed]는 연습 스폰 무작위 씨앗.
class LighthouseGame extends FlameGame {
  LighthouseGame({bool practice = false, int seed = 0})
      : spawner = practice ? PracticeSpawner(seed) : null,
        super(camera: CameraComponent.withFixedResolution(width: GameConfig.width, height: GameConfig.height));

  /// 자리 18개: 안쪽 `I0`…`I5` 다음 바깥 `O0`…`O11`.
  final List<Slot> slots = buildSlots();

  /// 등대 빛.
  final Beam beam = Beam();

  Slot? _selectedSlot;

  /// 연습 스폰 (꺼져 있으면 null).
  final PracticeSpawner? spawner;

  /// 적이 들어가는 층 (등대 위, 제목 아래에 그린다).
  final Component _enemyLayer = Component();
  final List<Enemy> _enemies = [];

  /// 판에 있는 적 (쓰러지는 중 포함, 사라지면 빠짐).
  List<Enemy> get enemies => List.unmodifiable(_enemies);

  /// 친구가 들어가는 층 (등대 위, 적 아래).
  final Component _friendLayer = Component();
  final List<Friend> _friends = [];

  /// 놓인 친구 (놓은 순서).
  List<Friend> get friends => List.unmodifiable(_friends);

  /// 거품이 들어가는 층 (적 위, 제목 아래).
  final Component _bubbleLayer = Component();
  final List<Bubble> _bubbles = [];

  /// 날아가는 거품 (사라지면 빠짐).
  List<Bubble> get bubbles => List.unmodifiable(_bubbles);

  /// 아래쪽 친구 쟁반.
  late final FriendTray tray = FriendTray();

  /// 처음 불빛 (표의 등대 hp).
  final double maxLight = Tables.lighthouse.hp;
  late double _light = maxLight;

  /// 지금 불빛 (0 아래로 내려가지 않는다).
  double get light => _light;

  bool _over = false;

  /// 불빛이 꺼졌는지 (꺼지면 판이 멈춘다).
  bool get isOver => _over;

  /// 위쪽 불빛 막대.
  late final LightBar lightBar = LightBar(() => _light / maxLight);

  /// 고른 자리 (없으면 null).
  Slot? get selectedSlot => _selectedSlot;

  @override
  Color backgroundColor() => GameConfig.deepSea;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    // 그리는 순서: 바다 → 빛 → 자리 → 등대 → 친구 → 적 → 거품 → 제목 → 불빛 막대 → 쟁반
    // (→ 꺼짐 문구는 꺼질 때 맨 뒤에). 입력 층은 그리지 않는다.
    // 친구 층이 적 층보다 먼저라 한 프레임 안에서 친구가 먼저 움직인다 (새 거품은 다음 프레임부터 난다)
    await world.addAll([
      SeaBackdrop(),
      beam,
      ...slots,
      LighthouseSpot(),
      _friendLayer,
      _enemyLayer,
      _bubbleLayer,
      TitleText(),
      lightBar,
      tray,
      BoardInput(),
    ]);
  }

  @override
  void update(double dt) {
    // 한 번에 흘리는 시간은 maxFrameDt까지 (남는 시간은 버린다, design.md §5)
    final step = math.min(dt, GameConfig.maxFrameDt);
    super.update(step);
    if (!_over) spawner?.tick(this, step);
  }

  /// 적 [id]를 등대 가운데에서 [angleDeg] 쪽, [distance](없으면 표의 spawn_distance)에 바로 넣는다 (판에는 다음 프레임에 붙는다).
  Enemy spawnEnemy(String id, double angleDeg, {double? distance}) {
    final e = Enemy(id, angleDeg, distance ?? Tables.lighthouse.spawnDistance)..game = this;
    _enemies.add(e);
    _enemyLayer.add(e);
    return e;
  }

  /// 쓰러진 적이 사라질 때 [enemies]에서 뺀다 (Enemy가 부른다).
  void forgetEnemy(Enemy e) => _enemies.remove(e);

  /// 친구 [id]를 [slot]에 놓는다 (판에는 다음 프레임에 붙는다). 차 있거나 판이 멈췄으면 아무 일 없이 null.
  Friend? placeFriend(String id, Slot slot) {
    if (_over || slot.friend != null) return null;
    final f = Friend(id, slot);
    slot.friend = f;
    _friends.add(f);
    _friendLayer.add(f);
    return f;
  }

  /// 거품 하나를 [from]에서 [target]으로 쏜다 (Friend가 부른다).
  void shootBubble(Vector2 from, Enemy target, double damage, double speed) {
    final b = Bubble(from, target, damage, speed);
    _bubbles.add(b);
    _bubbleLayer.add(b);
  }

  /// 거품이 터지거나 맞아 사라질 때 [bubbles]에서 뺀다 (Bubble이 부른다).
  void forgetBubble(Bubble b) => _bubbles.remove(b);

  /// 적이 등대 불빛을 [amount]만큼 갉는다. 0이 되면 꺼짐: 판이 멈추고 가운데 문구.
  void biteLight(double amount) {
    if (_over) return;
    _light = math.max(0, _light - amount);
    if (_light <= 0) {
      _over = true;
      world.add(LightOutText());
    }
  }

  /// 게임 좌표 [p]에 닿는 자리 (누르는 범위 안에서 가장 가까운 것).
  Slot? slotAt(Vector2 p) {
    Slot? best;
    var bestDistance = double.infinity;
    for (final s in slots) {
      final d = s.center.distanceTo(p);
      if (s.touches(p) && d < bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    return best;
  }

  /// 누르기 (design.md §2·§5). 빛은 그대로.
  /// - 쟁반 단추: 친구를 들거나 내려놓는다 (자리 고르기는 그대로)
  /// - 친구를 든 채 자리: 빈 자리면 놓고(든 것은 그대로, 고른 자리는 없음), 친구가 있으면 아무 일 없음
  /// - 그 밖: 자리를 고르고, 고른 자리를 다시 누르거나 바다를 누르면 고르기를 푼다
  void tapAt(Vector2 p) {
    if (_over) return; // 꺼진 뒤 입력은 무시
    final button = tray.buttonAt(p);
    if (button != null) {
      tray.press(button);
      return;
    }
    final s = slotAt(p);
    final held = tray.held;
    if (held != null && s != null) {
      if (placeFriend(held, s) != null) _select(null);
      return;
    }
    _select(s == _selectedSlot ? null : s);
  }

  void _select(Slot? s) {
    _selectedSlot?.selected = false;
    _selectedSlot = s;
    s?.selected = true;
  }

  /// 끌기: 빛이 [p] 쪽을 가리킨다. 등대 가운데 빈 곳 안이면 마지막 방향 그대로.
  void aimBeamAt(Vector2 p) {
    if (_over) return; // 꺼진 뒤 입력은 무시
    if (p.distanceTo(lighthouseCenter()) < GameConfig.beamDeadZone) return;
    beam.angleDeg = angleFromLighthouse(p);
  }
}

/// 밤바다 바탕: `night_sea` 그림을 판 전체에 그린다. 그림을 읽기 전(또는 읽기에 실패하면)에는 그러데이션.
class SeaBackdrop extends PositionComponent with HasGameReference<LighthouseGame> {
  SeaBackdrop() : super(size: Vector2(GameConfig.width, GameConfig.height));

  static const imageFile = 'night_sea.webp';

  /// 읽은 그림 (읽기 전에는 null).
  Sprite? get sprite => _sprite;
  Sprite? _sprite;

  final _paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1B2E57), GameConfig.nightSea, GameConfig.deepSea],
    ).createShader(const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.height));

  @override
  void onLoad() {
    // 판이 그림을 기다리지 않게 읽기만 시작한다 (다 읽으면 그때부터 그림으로 그린다)
    _loadSprite(game, imageFile).then((s) => _sprite = s);
  }

  @override
  void render(Canvas canvas) {
    final s = _sprite;
    if (s == null) {
      canvas.drawRect(size.toRect(), _paint);
    } else {
      s.render(canvas, size: size);
    }
  }
}

/// 등대: `lighthouse` 그림을 등대 가운데에 한 변 [GameConfig.lighthouseSize]로 그린다. 읽기 전에는 임시 원.
class LighthouseSpot extends PositionComponent with HasGameReference<LighthouseGame> {
  LighthouseSpot()
      : super(position: lighthouseCenter(), size: Vector2.all(GameConfig.lighthouseSize), anchor: Anchor.center);

  static const imageFile = 'lighthouse.webp';

  /// 읽은 그림 (읽기 전에는 null).
  Sprite? get sprite => _sprite;
  Sprite? _sprite;

  final _glow = Paint()..color = const Color(0x55FFE9A8);
  final _body = Paint()..color = const Color(0xFFEFE6D2);

  @override
  void onLoad() {
    _loadSprite(game, imageFile).then((s) => _sprite = s);
  }

  @override
  void render(Canvas canvas) {
    final s = _sprite;
    if (s != null) {
      s.render(canvas, size: size);
      return;
    }
    final c = Offset(size.x / 2, size.y / 2);
    final r = size.x * 0.3;
    canvas.drawCircle(c, r * 1.6, _glow);
    canvas.drawCircle(c, r, _body);
  }
}

/// `assets/images/<file>`을 읽어 그림으로. 실패하면 null (임시 모양으로 계속 그린다).
Future<Sprite?> _loadSprite(LighthouseGame game, String file) async {
  try {
    return Sprite(await loadGameImage(game, file));
  } catch (e) {
    debugPrint('image load failed: $file ($e)');
    return null;
  }
}

/// 연습 스폰 (7단계 웨이브 전까지 확인용, design.md §4).
///
/// `interval`초마다(첫 스폰은 `interval`초 뒤) 적 셋 중 하나를 고르게, 각도 0 이상 360 미만 고르게 뽑아 나타나게 한다.
/// 판에 (쓰러지는 중 빼고) 적이 `max_alive` 이상이면 그번은 건너뛴다. 같은 씨앗이면 같은 순서.
class PracticeSpawner {
  PracticeSpawner(int seed) : _random = math.Random(seed);

  final math.Random _random;
  final List<String> _ids = Tables.enemies.keys.toList();
  double _timer = 0;

  /// 지금까지 나타난 것 (차례대로).
  final List<({String id, double angleDeg})> spawned = [];

  /// [dt]초 흘린다 (판이 멈추면 부르지 않는다).
  void tick(LighthouseGame game, double dt) {
    final interval = Tables.practice.interval;
    _timer += dt;
    while (_timer >= interval) {
      _timer -= interval;
      final alive = game.enemies.where((e) => e.state != EnemyState.dying).length;
      if (alive >= Tables.practice.maxAlive) continue;
      final id = _ids[_random.nextInt(_ids.length)];
      final angle = normalizeDeg(_random.nextDouble() * 360);
      spawned.add((id: id, angleDeg: angle));
      game.spawnEnemy(id, angle);
    }
  }
}

class TitleText extends TextComponent {
  TitleText()
      : super(
          text: Strings.title,
          anchor: Anchor.topCenter,
          position: Vector2(GameConfig.width / 2, 120),
          textRenderer: TextPaint(style: const TextStyle(fontFamily: GameConfig.fontFamily, fontSize: 64, color: Color(0xFFFFF4DC))),
        );
}
