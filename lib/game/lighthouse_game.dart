import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'art.dart';
import 'beam.dart';
import 'board_input.dart';
import 'bubble.dart';
import 'card_panel.dart';
import 'config.dart';
import 'enemy.dart';
import 'friend.dart';
import 'geometry.dart';
import 'hud.dart';
import 'result_panel.dart';
import 'shard.dart';
import 'slots.dart';
import 'strings.dart';
import 'tables.g.dart';
import 'tray.dart';
import 'waves.dart';

/// 판의 결과 (design.md §7): 이김(새벽) 또는 짐(불빛 꺼짐).
enum GameResult { won, lost }

/// 한 판 (밤바다, 등대, 둘레 자리 18개, 빛 방향 끌기, 사방에서 오는 적과 등대 불빛, 친구 놓기와 자동 공격,
/// 빛 조각과 레벨업 카드).
///
/// [practice]면 연습 스폰을 켠다 (앱은 켜고 테스트 기본 판은 끈다). [seed]는 연습 스폰·카드 뽑기 무작위 씨앗.
/// [cards]면 카드 판 (앱): 쟁반 없이, 공짜 친구(start.csv)를 놓은 뒤 첫 친구 고르기 창, 레벨이 오르면 카드 창 (design.md §6).
/// 아니면 연습 판 (테스트·개발): 쟁반이 있고 레벨이 올라도 창을 열지 않는다.
/// [waves]면 웨이브 판: 웨이브 10개를 깨면 이김, 끝나면 결과 창과 다시 하기([onRestart]) (design.md §7).
class LighthouseGame extends FlameGame {
  LighthouseGame({bool practice = false, int seed = 0, bool cards = false, bool waves = false, this.onRestart})
      : spawner = practice ? PracticeSpawner(seed) : null,
        _cards = cards,
        _random = math.Random(seed),
        _waves = waves ? WaveRunner(seed) : null,
        tray = cards ? null : FriendTray(),
        super(camera: CameraComponent.withFixedResolution(width: GameConfig.width, height: GameConfig.height)) {
    if (cards) {
      final free = Tables.start.freeFriend;
      if (free != null) {
        // 공짜 친구: 창보다 먼저 그 친구의 놓기 상태 (고른 횟수는 세지 않음). 놓으면 첫 친구 창
        _placing = free;
        _firstPickAfterPlacing = true;
      } else {
        _openFirstPick();
      }
    }
  }

  /// 다시 하기 단추를 누르면 부른다 (앱이 새 판으로 바꿔 끼운다).
  final void Function()? onRestart;

  /// 웨이브 진행 (웨이브 판이 아니면 null).
  final WaveRunner? _waves;

  /// 공짜 친구를 놓으면 첫 친구 창을 연다.
  bool _firstPickAfterPlacing = false;

  /// 첫 친구 고르기: 친구 카드 셋을 표 순서 그대로 (뽑지 않음, 레벨·쌓인 양은 그대로).
  void _openFirstPick() =>
      _openChoice([for (final c in Tables.cards.values) if (c.kind == 'friend') c.id], first: true);

  // ---- 웨이브 (design.md §7) ----

  /// 지금(또는 막 깬) 웨이브 번호 (첫 웨이브 전 0, 웨이브 판이 아니면 0).
  int get wave => _waves?.wave ?? 0;

  /// 마지막 웨이브 번호 (표에서).
  int get waveCount => WaveRunner.waveCount;

  /// 웨이브를 깨고 다음을 기다리는 중 (첫 웨이브 전 기다림도 참).
  bool get isResting => _waves?.resting ?? false;

  /// 이번 웨이브에서 지금까지 나온 적 수.
  int get waveSpawned => _waves?.spawned ?? 0;

  /// 떠 있는 웨이브 알림 글 (없으면 null).
  String? get banner => _waves?.banner;

  /// (테스트·개발) 지금 바로 웨이브 [n]을 시작한다 (쉬는 시간·남은 스폰은 버림). 웨이브 판이 아니면 아무 일 없음.
  void startWave(int n) => _waves?.start(n);

  GameResult? _result;

  /// 판의 결과 (놀이 중 null).
  GameResult? get result => _result;

  /// 결과 창 (웨이브 판이 끝났을 때만, 아니면 null).
  ResultPanel? get resultPanel => _resultPanel;
  ResultPanel? _resultPanel;

  int _defeated = 0;

  /// 쓰러뜨린 적 수 (쓰러지는 순간 +1).
  int get defeated => _defeated;

  /// 적이 쓰러졌다 (Enemy가 쓰러지는 순간 한 번 부른다).
  void countDefeat() => _defeated++;

  double _elapsed = 0;

  /// 놀이 시간 (초, 멈춤·끝난 뒤에는 흐르지 않는다).
  double get elapsed => _elapsed;

  final bool _cards;

  /// 카드 뽑기 무작위 (씨앗).
  final math.Random _random;

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

  /// 빛 조각이 들어가는 층 (거품 위, 제목 아래).
  final Component _shardLayer = Component();
  final List<Shard> _shards = [];

  /// 등대로 날아가는 빛 조각 (빨려 들면 빠짐).
  List<Shard> get shards => List.unmodifiable(_shards);

  /// 아래쪽 친구 쟁반 (연습 판만, 카드 판은 null).
  final FriendTray? tray;

  double _maxLight = Tables.lighthouse.hp;
  late double _light = _maxLight;

  /// 불빛 최대 (처음 표의 등대 hp, 카드로 늘어난다).
  double get maxLight => _maxLight;

  /// 지금 불빛 (0 아래로, 최대 위로 가지 않는다).
  double get light => _light;

  /// 1초에 차는 불빛 (카드 light_regen, 처음 0).
  double lightRegen = 0;

  /// 판이 끝났는지 (= [result]가 있음). 이겨도 져도 판이 멈춘다.
  bool get isOver => _result != null;

  /// 위쪽 불빛 막대.
  late final LightBar lightBar = LightBar(() => _light / _maxLight);

  // ---- 빛 조각·레벨·카드 (design.md §6) ----

  double _xp = 0;
  int _level = 1;
  int _pending = 0;
  List<String>? _choice;
  CardPanel? _panel;
  String? _placing;
  final Map<String, int> _picks = {};
  final Map<String, double> _damageMultipliers = {};

  /// 쌓인 빛 조각.
  double get xp => _xp;

  /// 레벨 (처음 1).
  int get level => _level;

  /// 지금 레벨에서 다음 레벨에 드는 양 = xp_base + xp_step × (레벨 − 1).
  double get xpNeeded => Tables.progression.xpBase + Tables.progression.xpStep * (_level - 1);

  /// 밀린 카드 고르기 수 (열린 창의 것은 뺀다).
  int get pendingPicks => _pending;

  /// 열린 카드 창의 카드 id (닫혔으면 null).
  List<String>? get choice => _choice == null ? null : List.unmodifiable(_choice!);

  /// 열린 카드 창 (닫혔으면 null).
  CardPanel? get cardPanel => _panel;

  /// 놓기 상태의 친구 id (아니면 null).
  String? get placing => _placing;

  /// 카드마다 고른 횟수 (고른 적 없으면 키 없음).
  Map<String, int> get picks => Map.unmodifiable(_picks);

  /// 멈춤: 카드 창이 열렸거나 놓기 상태.
  bool get isPaused => _choice != null || _placing != null;

  /// 판이 멈췄는지 (꺼짐 또는 멈춤): 적·친구·거품·조각·연습 스폰·불빛 차기가 모두 멈춘다.
  bool get isStopped => isOver || isPaused;

  /// 조각 막대 (불빛 막대 아래).
  late final XpBar xpBar = XpBar(() => _xp / xpNeeded, () => _level);

  /// 고른 자리 (없으면 null).
  Slot? get selectedSlot => _selectedSlot;

  @override
  Color backgroundColor() => GameConfig.deepSea;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    // 그리는 순서: 바다 → 빛 → 자리 → 등대 → 친구 → 적 → 거품 → 조각 → 제목 → 불빛 막대·조각 막대 → (연습 판) 쟁반
    // → 놓기 안내 → 카드 창(열릴 때 붙는다) (→ 꺼짐 문구는 꺼질 때 맨 뒤에). 입력 층은 그리지 않는다.
    // 친구 층이 적 층보다 먼저라 한 프레임 안에서 친구가 먼저 움직인다 (새 거품은 다음 프레임부터 난다)
    await world.addAll([
      SeaBackdrop(),
      beam,
      ...slots,
      LighthouseSpot(),
      _friendLayer,
      _enemyLayer,
      _bubbleLayer,
      _shardLayer,
      if (_waves == null) TitleText() else WaveLabel(() => Strings.wave(math.max(wave, 1), waveCount)),
      lightBar,
      xpBar,
      ?tray,
      PlaceHint(() => _placing != null),
      if (_waves != null) WaveBanner(() => banner, () => banner == Strings.bossComing),
      BoardInput(),
    ]);
    // 생성자에서 연 첫 친구 창의 그림
    final panel = _panel;
    if (panel != null && panel.parent == null) await world.add(panel);
  }

  @override
  void update(double dt) {
    // 한 번에 흘리는 시간은 maxFrameDt까지 (남는 시간은 버린다, design.md §5)
    final step = math.min(dt, GameConfig.maxFrameDt);
    super.update(step);
    if (isStopped || step <= 0) return;
    _elapsed += step;
    spawner?.tick(this, step);
    if (lightRegen > 0) _light = math.min(_maxLight, _light + lightRegen * step);
    if (_waves?.tick(this, step) ?? false) _finish(GameResult.won);
  }

  /// 판을 끝낸다: 웨이브 판은 결과 창, 아니면 (짐일 때) 꺼짐 문구.
  void _finish(GameResult r) {
    if (_result != null) return;
    _result = r;
    if (_waves == null) {
      if (r == GameResult.lost) world.add(LightOutText());
      return;
    }
    final panel = ResultPanel(
      title: r == GameResult.won ? Strings.dawn : Strings.lightOut,
      lines: [
        Strings.resultWave(wave, waveCount),
        Strings.resultDefeated(_defeated),
        Strings.resultLevel(_level),
        Strings.resultTime(_elapsed),
      ],
      won: r == GameResult.won,
    );
    _resultPanel = panel;
    world.add(panel);
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

  /// 친구 [id]를 [slot]에 놓는다 (판에는 다음 프레임에 붙는다). 차 있거나 판이 꺼졌으면 아무 일 없이 null.
  Friend? placeFriend(String id, Slot slot) {
    if (isOver || slot.friend != null) return null;
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

  /// 적이 쓰러진 자리 [at]에 값 [value]의 빛 조각 하나 (Enemy가 쓰러지는 순간 부른다).
  void dropShard(Vector2 at, double value) {
    final s = Shard(at, value);
    _shards.add(s);
    _shardLayer.add(s);
  }

  /// 조각이 등대에 빨려 들었다 (Shard가 부른다): 목록에서 빼고 값만큼 쌓는다.
  void absorbShard(Shard s) {
    _shards.remove(s);
    addXp(s.value);
  }

  /// 빛 조각 [v]를 쌓는다. 레벨이 오르면(여러 번이면 그만큼) 카드 고르기가 밀리고,
  /// 카드 판에서 꺼지지 않았고 열린 창·놓기가 없으면 바로 창을 연다.
  void addXp(double v) {
    _xp += v;
    while (_xp >= xpNeeded) {
      _xp -= xpNeeded;
      _level++;
      if (_cards) _pending++;
    }
    _openNext();
  }

  /// 그 친구 종류의 피해 배율 (처음 1, upgrade 카드마다 value를 곱함).
  double damageMultiplier(String friendId) => _damageMultipliers[friendId] ?? 1;

  /// 지금 고를 수 있는 카드 id (표 순서).
  /// friend: 빈 자리가 있을 때. upgrade: 그 친구가 판에 있고 max_picks 전. beam·lighthouse: max_picks 전 (0은 제한 없음).
  List<String> availableCards() {
    final hasEmpty = slots.any((s) => s.friend == null);
    bool underMax(CardStats c) => c.maxPicks == 0 || (_picks[c.id] ?? 0) < c.maxPicks;
    bool available(CardStats c) => switch (c.kind) {
          'friend' => hasEmpty,
          'upgrade' => _friends.any((f) => f.id == c.target) && underMax(c),
          _ => underMax(c),
        };
    return [for (final c in Tables.cards.values) if (available(c)) c.id];
  }

  /// 고를 수 있는 카드 중 서로 다른 최대 3장을 weight에 비례해 뽑는다 (씨앗 무작위, 부를 때마다 무작위가 흐른다).
  List<String> drawCards() {
    final pool = availableCards();
    final out = <String>[];
    while (out.length < GameConfig.cardChoiceCount && pool.isNotEmpty) {
      final total = pool.fold<double>(0, (sum, id) => sum + Tables.cards[id]!.weight);
      var r = _random.nextDouble() * total;
      var pick = pool.length - 1; // 반올림 오차로 끝까지 가면 마지막
      for (var i = 0; i < pool.length; i++) {
        r -= Tables.cards[pool[i]]!.weight;
        if (r < 0) {
          pick = i;
          break;
        }
      }
      out.add(pool.removeAt(pick));
    }
    return out;
  }

  /// 카드 [id]의 효과만 바로 낸다 (창 없이, 고른 횟수 +1). friend면 놓기 상태가 된다.
  void applyCard(String id) {
    final c = Tables.cards[id]!;
    _picks[id] = (_picks[id] ?? 0) + 1;
    switch ((c.kind, c.target)) {
      case ('friend', _):
        _placing = c.target;
      case ('upgrade', _):
        _damageMultipliers[c.target] = damageMultiplier(c.target) * c.value;
      case ('beam', 'width_deg'):
        beam.widthBonus += c.value;
      case ('beam', 'length'):
        beam.lengthBonus += c.value;
      case ('lighthouse', 'max_hp'):
        _maxLight += c.value;
        _light = math.min(_maxLight, _light + c.value);
      case ('lighthouse', 'regen'):
        lightRegen += c.value;
      default:
        debugPrint('unknown card: $id (${c.kind} ${c.target})');
    }
  }

  /// 열린 창의 [index]번째 카드를 고른다: 창을 닫고 효과. 놓기가 아니면 밀린 고르기의 다음 창 (창이 없으면 아무 일 없음).
  void pickCard(int index) {
    final ids = _choice;
    if (ids == null || index < 0 || index >= ids.length) return;
    _closeChoice();
    applyCard(ids[index]);
    _openNext();
  }

  /// 밀린 고르기가 있고 열린 창·놓기가 없으면(꺼지지 않았으면) 다음 창을 연다. 고를 카드가 없으면 그 고르기는 버린다.
  void _openNext() {
    if (!_cards || isOver) return;
    while (_pending > 0 && !isPaused) {
      _pending--;
      final ids = drawCards();
      if (ids.isNotEmpty) _openChoice(ids, first: false);
    }
  }

  void _openChoice(List<String> ids, {required bool first}) {
    _choice = ids;
    final panel = CardPanel(ids, first: first);
    _panel = panel;
    // 판이 붙기 전(생성자)이면 onLoad에서 붙인다
    if (isLoaded) world.add(panel);
  }

  void _closeChoice() {
    _choice = null;
    _panel?.removeFromParent();
    _panel = null;
  }

  /// 적이 등대 불빛을 [amount]만큼 갉는다. 0이 되면 꺼짐: 판이 멈추고 가운데 문구.
  void biteLight(double amount) {
    if (isStopped) return;
    _light = math.max(0, _light - amount);
    if (_light <= 0) _finish(GameResult.lost);
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
    if (isOver) {
      // 끝난 뒤에는 결과 창의 다시 하기 단추만 받는다
      final b = _resultPanel?.restartButton;
      if (b != null && b.toRect().contains(p.toOffset())) onRestart?.call();
      return;
    }
    // 멈춤 (design.md §6): 카드 창은 카드 누르기만, 놓기 상태는 빈 자리 누르기만 받는다
    if (_choice != null) {
      final i = _panel?.indexAt(p);
      if (i != null) pickCard(i);
      return;
    }
    final placing = _placing;
    if (placing != null) {
      final s = slotAt(p);
      if (s != null && placeFriend(placing, s) != null) {
        _placing = null;
        _select(null);
        if (_firstPickAfterPlacing) {
          _firstPickAfterPlacing = false;
          _openFirstPick();
        } else {
          _openNext();
        }
      }
      return;
    }
    final t = tray;
    final button = t?.buttonAt(p);
    if (t != null && button != null) {
      t.press(button);
      return;
    }
    final s = slotAt(p);
    final held = t?.held;
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
    if (isStopped) return; // 꺼진 뒤·멈춤 때 끌기는 무시
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
  /// 뽑을 적 (보스는 뽑지 않는다, design.md §7).
  final List<String> _ids = [for (final e in Tables.enemies.values) if (!e.boss) e.id];
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
