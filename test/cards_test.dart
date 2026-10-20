import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/enemy.dart';
import 'package:lighthouse_defense/game/friend.dart';
import 'package:lighthouse_defense/game/geometry.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/slots.dart';
import 'package:lighthouse_defense/game/tables.g.dart';

import 'support.dart';

/// 6단계: 빛 조각·레벨업 카드 (docs/tests/06-cards.md, T6-01~19. T6-20은 beam_boost_test.dart).
/// 숫자는 박지 않고 표(CSV)를 직접 읽어 기대값을 계산한다.
void main() {
  const halfSide = GameConfig.lighthouseSize / 2;
  const windup = Friend.windupSeconds;

  double cell(Map<String, String> row, String key) => double.parse(row[key]!);

  final prog = readCsv('progression.csv').single;
  final xpBase = cell(prog, 'xp_base');
  final xpStep = cell(prog, 'xp_step');
  final shardDelay = cell(prog, 'shard_delay');
  final shardSpeed = cell(prog, 'shard_speed');
  final absorb = cell(prog, 'absorb_distance');
  final cardRows = readCsv('cards.csv');
  Map<String, String> cardRow(String id) => cardRows.firstWhere((r) => r['id'] == id);

  Slot slotOf(LighthouseGame game, String id) => game.slots.firstWhere((s) => s.id == id);

  double contactOf(String id) => halfSide + Tables.enemies[id]!.radius;

  double xpOf(String id) => cell(readCsv('enemies.csv').firstWhere((r) => r['id'] == id), 'xp');

  Enemy spawn(LighthouseGame game, String id, double angleDeg, {double? distance}) {
    final e = game.spawnEnemy(id, angleDeg, distance: distance ?? contactOf(id));
    game.update(0);
    return e;
  }

  Friend place(LighthouseGame game, String id, String slotId) {
    final f = game.placeFriend(id, slotOf(game, slotId));
    expect(f, isNotNull, reason: 'placeFriend($id, $slotId)');
    game.update(0);
    return f!;
  }

  /// 시작부터 센 시간을 0.05초 단위 걸음 수로 맞춰 흘린다.
  void Function(double) clockOf(LighthouseGame game) {
    var steps = 0;
    return (double seconds) {
      final target = (seconds / 0.05).round();
      while (steps < target) {
        game.update(0.05);
        steps++;
      }
    };
  }

  /// 카드 판 시작: 공짜 친구 놓기 상태(`start.csv`)면 O6에 놓는다 (그 뒤 첫 친구 창이 열린다).
  void placeFree(LighthouseGame game) {
    final free = Tables.start.freeFriend;
    if (free == null) return;
    expect(game.placing, free);
    game.tapAt(slotOf(game, 'O6').center.clone());
    expect(game.placing, isNull);
    game.update(0);
  }

  /// 창의 [index]번째 카드를 고르고, 놓기 상태면 빈 자리 하나를 눌러 놓는다.
  void pickAndPlace(LighthouseGame game, int index) {
    game.pickCard(index);
    if (game.placing != null) {
      final empty = game.slots.firstWhere((s) => s.friend == null);
      game.tapAt(empty.center.clone());
    }
  }

  /// 첫 친구 창에서 [index]번째 친구를 골라 [slotId]에 놓는다.
  void firstFriend(LighthouseGame game, int index, String slotId) {
    placeFree(game);
    game.pickCard(index);
    expect(game.placing, isNotNull);
    game.tapAt(slotOf(game, slotId).center.clone());
    expect(game.placing, isNull);
    game.update(0);
  }

  /// 해파리 다섯이 닿게 두고 불빛이 꺼질 때까지 (길어도 120초) 흘린다.
  void lightOut(LighthouseGame game, {String enemy = 'shadow_jelly'}) {
    for (final a in const [18.0, 90.0, 162.0, 234.0, 306.0]) {
      spawn(game, enemy, a);
    }
    var t = 0.0;
    while (game.light > 0 && !game.isPaused && t < 120) {
      game.update(0.05);
      t += 0.05;
    }
    expect(game.isOver, isTrue);
  }

  testWithGame<LighthouseGame>(
    'T6-01 표(CSV)의 값이 Tables와 같다 (cards, progression, enemies의 xp)',
    () => LighthouseGame(),
    (game) async {
      expect(Tables.cards.length, cardRows.length);
      expect(Tables.cards.keys.toList(), [for (final r in cardRows) r['id']!]);
      for (final r in cardRows) {
        final c = Tables.cards[r['id']]!;
        expect(c.id, r['id']);
        expect(c.kind, r['kind']);
        expect(c.target, r['target']);
        expect(c.value, cell(r, 'value'));
        expect(c.maxPicks, int.parse(r['max_picks']!));
        expect(c.weight, cell(r, 'weight'));
        expect(c.nameKo, r['name_ko']);
        expect(c.nameEn, r['name_en']);
        expect(c.descKo, r['desc_ko']);
        expect(c.descEn, r['desc_en']);
      }
      expect(Tables.progression.xpBase, xpBase);
      expect(Tables.progression.xpStep, xpStep);
      expect(Tables.progression.shardDelay, shardDelay);
      expect(Tables.progression.shardSpeed, shardSpeed);
      expect(Tables.progression.absorbDistance, absorb);
      for (final r in readCsv('enemies.csv')) {
        expect(Tables.enemies[r['id']]!.xp, cell(r, 'xp'), reason: r['id']);
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T6-02 표끼리 맞는다 (kind, target, 친구마다 friend·upgrade 카드, 양수, 이름·설명, 적 xp)',
    () => LighthouseGame(),
    (game) async {
      final friendIds = readCsv('characters.csv').where((r) => r['kind'] == 'friend').map((r) => r['id']!).toSet();
      for (final r in cardRows) {
        final id = r['id'];
        expect(['friend', 'upgrade', 'beam', 'lighthouse'], contains(r['kind']), reason: '$id kind');
        switch (r['kind']) {
          case 'friend' || 'upgrade':
            expect(friendIds, contains(r['target']), reason: '$id target');
          case 'beam':
            expect(['width_deg', 'length'], contains(r['target']), reason: '$id target');
          case 'lighthouse':
            expect(['max_hp', 'regen'], contains(r['target']), reason: '$id target');
        }
        expect(cell(r, 'weight'), greaterThan(0), reason: '$id weight');
        expect(int.parse(r['max_picks']!), greaterThanOrEqualTo(0), reason: '$id max_picks');
        expect(cell(r, 'value'), greaterThan(0), reason: '$id value');
        for (final k in ['name_ko', 'name_en', 'desc_ko', 'desc_en']) {
          expect(r[k], isNotEmpty, reason: '$id $k');
        }
      }
      for (final f in friendIds) {
        expect(cardRows.where((r) => r['kind'] == 'friend' && r['target'] == f), hasLength(1), reason: 'friend $f');
        expect(cardRows.where((r) => r['kind'] == 'upgrade' && r['target'] == f), hasLength(1), reason: 'upgrade $f');
      }
      for (final r in readCsv('enemies.csv')) {
        expect(cell(r, 'xp'), greaterThan(0), reason: '${r['id']} xp');
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T6-03 레벨: xpNeeded = xp_base, 채우면 레벨 오르고 쌓인 양 0, 연습 판은 창이 없다',
    () => LighthouseGame(),
    (game) async {
      expect(game.level, 1);
      expect(game.xp, 0);
      expect(game.xpNeeded, xpBase);
      game.addXp(xpBase - 1);
      expect(game.level, 1);
      game.addXp(1);
      expect(game.level, 2);
      expect(game.xp, 0);
      expect(game.xpNeeded, xpBase + xpStep);
      expect(game.choice, isNull);
      expect(game.isPaused, isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T6-04 여러 레벨이 한꺼번에 오르면 고르기가 밀리고 하나씩 창이 열린다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      placeFree(game);
      game.pickCard(0);
      game.tapAt(slotOf(game, 'I0').center.clone());
      expect(game.isPaused, isFalse);

      game.addXp(xpBase + (xpBase + xpStep) + 1);
      expect(game.level, 3);
      expect(game.xp, 1);
      expect(game.choice, isNotNull);
      expect(game.choice!.length, inInclusiveRange(1, 3));
      expect(game.pendingPicks, 1);

      pickAndPlace(game, 0);
      expect(game.choice, isNotNull);
      expect(game.pendingPicks, 0);

      pickAndPlace(game, 0);
      expect(game.choice, isNull);
      expect(game.isPaused, isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T6-05 적이 쓰러지는 순간 그 자리에 빛 조각 하나 (한 번만)',
    () => LighthouseGame(),
    (game) async {
      final squid = spawn(game, 'ink_squid', 0, distance: 300);
      final pos = squid.position.clone();
      squid.takeDamage(squid.hp);
      squid.takeDamage(5);
      game.update(0);
      expect(game.shards, hasLength(1));
      expect(game.shards.single.position.x, closeTo(pos.x, 0.5));
      expect(game.shards.single.position.y, closeTo(pos.y, 0.5));
      expect(game.shards.single.value, xpOf('ink_squid'));
    },
  );

  testWithGame<LighthouseGame>(
    'T6-06 조각은 shard_delay 제자리, 날아가 빨려 들어 xp가 쌓인다',
    () => LighthouseGame(),
    (game) async {
      final blob = spawn(game, 'shadow_blob', 0, distance: 300);
      blob.takeDamage(blob.hp);
      game.update(0);
      final shard = game.shards.single;
      final pos = shard.position.clone();
      final at = clockOf(game);

      at(shardDelay - 0.05);
      expect(shard.position.x, closeTo(pos.x, 0.5));
      expect(shard.position.y, closeTo(pos.y, 0.5));

      final total = shardDelay + (300 - absorb) / shardSpeed;
      at(total - 0.2);
      expect(game.shards, contains(shard));
      expect(game.xp, 0);
      at(total + 0.1);
      expect(game.shards, isEmpty);
      expect(game.xp, xpOf('shadow_blob'));
    },
  );

  testWithGame<LighthouseGame>(
    'T6-07 카드 판은 처음에 첫 친구 고르기 창이 열려 있다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      placeFree(game); // 공짜 친구를 놓은 뒤의 창을 본다
      expect(game.choice, ['friend_seahorse', 'friend_crab', 'friend_pufferfish']);
      expect(game.isPaused, isTrue);
      expect(game.tray, isNull);
      expect(game.pendingPicks, 0);
      expect(game.level, 1);
      expect(game.xp, 0);
    },
  );

  testWithGame<LighthouseGame>(
    'T6-08 친구 카드를 고르면 놓기 상태, 바다는 무시, 빈 자리를 누르면 놓는다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      placeFree(game);
      game.pickCard(1);
      expect(game.choice, isNull);
      expect(game.placing, 'crab');
      expect(game.isPaused, isTrue);

      game.tapAt(Vector2(100, 1200));
      expect(game.placing, 'crab');
      expect(game.isPaused, isTrue);

      game.tapAt(slotOf(game, 'I0').center.clone());
      expect(slotOf(game, 'I0').friend?.id, 'crab');
      expect(game.placing, isNull);
      expect(game.isPaused, isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T6-09 창이 열린 동안은 멈추고 빛 끌기도 무시, 첫 친구를 놓으면 다시 흐른다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      final spawnDist = Tables.lighthouse.spawnDistance;
      final blob = spawn(game, 'shadow_blob', 0, distance: spawnDist);
      tickGame(game, 1);
      expect(blob.distance, closeTo(spawnDist, 1e-6));
      game.aimBeamAt(Vector2(360, 1000));
      expect(game.beam.angleDeg, closeTo(270, 1e-6));

      placeFree(game); // 창이 열려 있어도 멈춤
      tickGame(game, 1);
      expect(blob.distance, closeTo(spawnDist, 1e-6));
      pickAndPlace(game, 0);
      expect(game.isPaused, isFalse);
      tickGame(game, 1);
      expect(blob.distance, lessThan(spawnDist - 1));
    },
  );

  testWithGame<LighthouseGame>(
    'T6-10 레벨업 창이 열린 동안 적·불빛·거품·친구 쉬는 시간이 멈춘다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      firstFriend(game, 0, 'I3');
      final horse = game.friends.last; // 공짜 해마(O6) 다음에 놓은 해마
      final blob = spawn(game, 'shadow_blob', 90);
      game.addXp(xpBase);
      expect(game.choice, isNotNull);

      final hp = blob.hp;
      final light = game.light;
      final bubbles = [for (final b in game.bubbles) b.position.clone()];
      final cooldown = horse.cooldown;
      tickGame(game, 3);
      expect(blob.hp, hp);
      expect(game.light, light);
      expect(game.bubbles, hasLength(bubbles.length));
      for (var i = 0; i < bubbles.length; i++) {
        expect(game.bubbles[i].position.x, closeTo(bubbles[i].x, 1e-6));
        expect(game.bubbles[i].position.y, closeTo(bubbles[i].y, 1e-6));
      }
      expect(horse.cooldown, cooldown);
    },
  );

  testWithGame<LighthouseGame>(
    'T6-11 고를 수 있는 카드: 친구는 빈 자리, upgrade는 그 친구가 있고 max_picks 전, 나머지는 max_picks 전',
    () => LighthouseGame(),
    (game) async {
      List<String> ids(bool Function(Map<String, String>) test) => [for (final r in cardRows) if (test(r)) r['id']!];
      bool notUpgrade(Map<String, String> r) => r['kind'] != 'upgrade';

      expect(game.availableCards(), ids(notUpgrade));
      expect(game.availableCards(), isNot(contains('upgrade_crab')));

      place(game, 'crab', 'I0');
      expect(game.availableCards(), ids((r) => notUpgrade(r) || r['id'] == 'upgrade_crab'));

      final crabUp = Tables.cards['upgrade_crab']!;
      for (var i = 0; i < crabUp.maxPicks; i++) {
        game.applyCard('upgrade_crab');
      }
      expect(game.availableCards(), isNot(contains('upgrade_crab')));

      final wide = Tables.cards['beam_wide']!;
      for (var i = 0; i < wide.maxPicks; i++) {
        game.applyCard('beam_wide');
      }
      expect(game.availableCards(), isNot(contains('beam_wide')));
      expect(game.availableCards(), contains('beam_long'));

      for (final s in game.slots) {
        if (s.friend == null) game.placeFriend('crab', s);
      }
      game.update(0);
      expect(game.availableCards().where((id) => Tables.cards[id]!.kind == 'friend'), isEmpty);
      expect(game.availableCards(), contains('light_up'));
    },
  );

  testWithGame<LighthouseGame>(
    'T6-12 뽑기: 씨앗이 같으면 같은 결과, 서로 다른 3장 (고를 것이 2개면 2장)',
    () => LighthouseGame(seed: 3),
    (game) async {
      final other = await initializeGame<LighthouseGame>(() => LighthouseGame(seed: 3));

      List<List<String>> draws(LighthouseGame g) {
        final out = <List<String>>[];
        for (var i = 0; i < 5; i++) {
          final avail = g.availableCards();
          final d = g.drawCards();
          expect(d, hasLength(3));
          expect(d.toSet(), hasLength(3));
          for (final id in d) {
            expect(avail, contains(id));
          }
          out.add(d);
        }
        return out;
      }

      expect(draws(game), draws(other));

      // 고를 수 있는 카드가 2개뿐인 판: 빈 자리 없음, beam·lighthouse는 max까지, upgrade는 두 종류 남김
      final small = await initializeGame<LighthouseGame>(() => LighthouseGame(seed: 3));
      var n = 0;
      for (final s in small.slots) {
        expect(small.placeFriend(n++ == 0 ? 'seahorse' : 'crab', s), isNotNull);
      }
      small.update(0);
      for (final c in Tables.cards.values) {
        if (c.kind == 'beam' || c.kind == 'lighthouse') {
          for (var i = 0; i < c.maxPicks; i++) {
            small.applyCard(c.id);
          }
        }
      }
      expect(small.availableCards(), ['upgrade_seahorse', 'upgrade_crab']);
      for (var i = 0; i < 5; i++) {
        final d = small.drawCards();
        expect(d, hasLength(2));
        expect(d.toSet(), {'upgrade_seahorse', 'upgrade_crab'});
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T6-13 upgrade는 그 친구 종류 피해에 value를 곱한다 (고를 때마다)',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.friends['crab']!;
      final value = cell(cardRow('upgrade_crab'), 'value');
      place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_blob', 90);
      final hp = blob.hp;
      game.applyCard('upgrade_crab');
      game.applyCard('upgrade_crab');
      expect(game.damageMultiplier('crab'), closeTo(value * value, 1e-9));
      expect(game.damageMultiplier('seahorse'), 1);

      clockOf(game)(windup + 0.05);
      expect(blob.hp, closeTo(hp - s.damage * value * value, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T6-14 beam 카드: 빛 폭·길이가 value만큼 늘고 빛 속 판정도 따른다',
    () => LighthouseGame(),
    (game) async {
      final wide = cell(cardRow('beam_wide'), 'value');
      final long = cell(cardRow('beam_long'), 'value');
      final w0 = Tables.beam.widthDeg;
      final l0 = Tables.beam.length;
      game.applyCard('beam_wide');
      game.applyCard('beam_long');
      expect(game.beam.widthDeg, w0 + wide);
      expect(game.beam.length, l0 + long);
      expect(game.beam.contains(pointFromLighthouse(270 + (game.beam.widthDeg / 2 - 0.5), 300)), isTrue);
      expect(game.beam.contains(pointFromLighthouse(270, game.beam.length - 1)), isTrue);
      expect(game.beam.contains(pointFromLighthouse(270, l0 + long + 5)), isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T6-15 light_up: 최대와 지금 불빛이 value만큼 (최대를 넘지 않음)',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.enemies['shadow_blob']!;
      final value = cell(cardRow('light_up'), 'value');
      spawn(game, 'shadow_blob', 0);
      tickGame(game, s.biteInterval + 0.05);
      final hurt = game.light;
      expect(hurt, lessThan(Tables.lighthouse.hp));
      game.applyCard('light_up');
      expect(game.maxLight, Tables.lighthouse.hp + value);
      expect(game.light, closeTo(hurt + value, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T6-16 light_regen: 겹치면 더하고 1초에 그만큼 차며 최대를 넘지 않는다',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.enemies['shadow_blob']!;
      final value = cell(cardRow('light_regen'), 'value');
      final a = spawn(game, 'shadow_blob', 0);
      final b = spawn(game, 'shadow_blob', 180);
      tickGame(game, s.biteInterval + 0.05);
      expect(game.light, lessThan(game.maxLight));
      a.takeDamage(a.hp);
      b.takeDamage(b.hp);
      game.applyCard('light_regen');
      game.applyCard('light_regen');
      expect(game.lightRegen, closeTo(2 * value, 1e-9));

      final before = game.light;
      tickGame(game, 2);
      expect(game.light, closeTo(before + 2 * value * 2, 0.05));
      expect(game.light, lessThanOrEqualTo(game.maxLight));
    },
  );

  testWithGame<LighthouseGame>(
    'T6-17 조각 막대: 채운 비율, Lv 글자, 불빛 막대 아래 판 위쪽 130 px 안',
    () => LighthouseGame(),
    (game) async {
      final bar = game.xpBar;
      expect(bar.ratio, 0);
      expect(bar.levelText, contains('1'));
      game.addXp(xpBase / 2);
      expect(bar.ratio, closeTo(0.5, 1e-9));
      expect(bar.position.y, greaterThanOrEqualTo(0));
      expect(bar.position.y + bar.size.y, lessThanOrEqualTo(130));
      expect(bar.position.y, greaterThanOrEqualTo(game.lightBar.position.y + game.lightBar.size.y));
    },
  );

  GameTester<LighthouseGame>(() => LighthouseGame(cards: true)).testGameWidget(
    'T6-18 카드 셋은 판 안에서 겹치지 않고, 카드를 누르고 자리를 누르면 놓인다',
    verify: (game, tester) async {
      await tester.pump();
      if (Tables.start.freeFriend != null) {
        final o6 = slotOf(game, 'O6').center;
        await tapGame(tester, game, o6.x, o6.y);
      }
      final views = game.cardPanel!.views;
      expect(views, hasLength(3));
      final rects = [for (final v in views) Rect.fromLTWH(v.position.x, v.position.y, v.size.x, v.size.y)];
      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].left, greaterThanOrEqualTo(0));
        expect(rects[i].right, lessThanOrEqualTo(GameConfig.width));
        expect(rects[i].top, greaterThanOrEqualTo(0));
        expect(rects[i].bottom, lessThanOrEqualTo(GameConfig.height));
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse, reason: '$i / $j');
        }
      }
      final c = views[1].position + views[1].size / 2;
      await tapGame(tester, game, c.x, c.y);
      expect(game.placing, 'crab');

      final i3 = slotOf(game, 'I3').center;
      await tapGame(tester, game, i3.x, i3.y);
      expect(slotOf(game, 'I3').friend?.id, 'crab');
      expect(game.isPaused, isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T6-19 꺼진 뒤에는 레벨이 올라도 카드 창이 열리지 않는다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      firstFriend(game, 1, 'O1');
      lightOut(game, enemy: 'boss_jelly'); // hp가 커서 해마가 못 쓰러뜨림 (레벨이 먼저 오르지 않게)
      final level = game.level;
      game.addXp(game.xpNeeded);
      expect(game.level, level + 1);
      expect(game.choice, isNull);
    },
  );
}
