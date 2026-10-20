import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/enemy.dart';
import 'package:lighthouse_defense/game/friend.dart';
import 'package:lighthouse_defense/game/hud.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/slots.dart';
import 'package:lighthouse_defense/game/strings.dart';
import 'package:lighthouse_defense/game/tables.g.dart';

import 'support.dart';

/// 7단계: 웨이브·보스·이김과 짐 (docs/tests/07-waves.md, T7-01~19).
/// 숫자는 박지 않고 표(CSV)를 직접 읽어 기대값을 계산한다.
void main() {
  const halfSide = GameConfig.lighthouseSize / 2;
  const windup = Friend.windupSeconds;

  double cell(Map<String, String> row, String key) => double.parse(row[key]!);

  final waveRows = readCsv('waves.csv');
  final rules = readCsv('wave_rules.csv').single;
  final firstDelay = cell(rules, 'first_delay');
  final rest = cell(rules, 'rest');
  final prog = readCsv('progression.csv').single;
  final shardDelay = cell(prog, 'shard_delay');
  final enemyRows = readCsv('enemies.csv');
  final waveCount = waveRows.map((r) => int.parse(r['wave']!)).reduce((a, b) => a > b ? a : b);
  List<Map<String, String>> rowsOf(int wave) => [for (final r in waveRows) if (int.parse(r['wave']!) == wave) r];
  int totalOf(int wave) => rowsOf(wave).fold(0, (a, r) => a + int.parse(r['count']!));

  Slot slotOf(LighthouseGame game, String id) => game.slots.firstWhere((s) => s.id == id);

  double contactOf(String id) => halfSide + Tables.enemies[id]!.radius;

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

  /// 쓰러지는 중이 아닌 적을 모두 쓰러뜨린다.
  void killAll(LighthouseGame game) {
    for (final e in game.enemies) {
      if (e.state != EnemyState.dying) e.takeDamage(e.hp);
    }
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

  /// 첫 친구 창에서 [index]번째를 골라 [slotId]에 놓는다.
  void firstFriend(LighthouseGame game, int index, String slotId) {
    placeFree(game);
    game.pickCard(index);
    expect(game.placing, isNotNull);
    game.tapAt(slotOf(game, slotId).center.clone());
    expect(game.placing, isNull);
    game.update(0);
  }

  /// 해파리 다섯이 닿게 두고 불빛이 꺼질 때까지 (길어도 120초) 흘린다. 걸린 시간을 돌려준다.
  double lightOut(LighthouseGame game) {
    for (final a in const [18.0, 90.0, 162.0, 234.0, 306.0]) {
      spawn(game, 'shadow_jelly', a);
    }
    var t = 0.0;
    while (game.light > 0 && t < 120) {
      game.update(0.05);
      t += 0.05;
    }
    expect(game.isOver, isTrue);
    return t;
  }

  testWithGame<LighthouseGame>(
    'T7-01 표(CSV)의 값이 Tables와 같다 (waves, wave_rules, enemies의 art·scale·boss)',
    () => LighthouseGame(),
    (game) async {
      expect(Tables.waves.length, waveRows.length);
      for (var i = 0; i < waveRows.length; i++) {
        final r = waveRows[i];
        final w = Tables.waves[i];
        expect(w.wave, int.parse(r['wave']!), reason: 'row $i');
        expect(w.enemy, r['enemy'], reason: 'row $i');
        expect(w.count, int.parse(r['count']!), reason: 'row $i');
        expect(w.interval, cell(r, 'interval'), reason: 'row $i');
        expect(w.delay, cell(r, 'delay'), reason: 'row $i');
      }
      expect(Tables.waveRules.firstDelay, firstDelay);
      expect(Tables.waveRules.rest, rest);
      expect(Tables.waveRules.bannerSeconds, cell(rules, 'banner_seconds'));
      for (final r in enemyRows) {
        final s = Tables.enemies[r['id']]!;
        expect(s.art, r['art'], reason: r['id']);
        expect(s.scale, cell(r, 'scale'), reason: r['id']);
        expect(s.boss, r['boss'] == '1', reason: r['id']);
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T7-02 표끼리 맞는다 (웨이브 번호, 보스는 5·10만, boss 0인 id = characters의 enemy id, art, 양수)',
    () => LighthouseGame(),
    (game) async {
      final waves = waveRows.map((r) => int.parse(r['wave']!)).toSet();
      expect(waves, {for (var i = 1; i <= waveCount; i++) i});
      final ids = enemyRows.map((r) => r['id']!).toSet();
      final bossIds = enemyRows.where((r) => r['boss'] == '1').map((r) => r['id']!).toSet();
      for (final r in waveRows) {
        expect(ids, contains(r['enemy']));
        expect(int.parse(r['count']!), greaterThanOrEqualTo(1));
        expect(cell(r, 'interval'), greaterThan(0));
        expect(cell(r, 'delay'), greaterThanOrEqualTo(0));
        if (bossIds.contains(r['enemy'])) {
          expect([5, 10], contains(int.parse(r['wave']!)), reason: 'boss ${r['enemy']}');
        }
      }
      for (final w in [5, 10]) {
        expect(rowsOf(w).where((r) => bossIds.contains(r['enemy'])), isNotEmpty, reason: 'wave $w boss');
      }
      final enemyKinds = readCsv('characters.csv').where((r) => r['kind'] == 'enemy').map((r) => r['id']!).toSet();
      expect(enemyRows.where((r) => r['boss'] == '0').map((r) => r['id']!).toSet(), enemyKinds);
      for (final r in enemyRows) {
        expect(enemyKinds, contains(r['art']), reason: '${r['id']} art');
        expect(cell(r, 'scale'), greaterThan(0), reason: '${r['id']} scale');
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T7-03 first_delay 뒤 웨이브 1이 시작되고 알림이 뜬다',
    () => LighthouseGame(waves: true),
    (game) async {
      final at = clockOf(game);
      at(firstDelay - 0.05);
      expect(game.wave, 0);
      expect(game.isResting, isTrue);
      expect(game.enemies, isEmpty);
      at(firstDelay + 0.05);
      expect(game.wave, 1);
      expect(game.isResting, isFalse);
      expect(game.banner, contains('1'));
    },
  );

  testWithGame<LighthouseGame>(
    'T7-04 줄의 적은 delay + k × interval초에 나온다',
    () => LighthouseGame(waves: true),
    (game) async {
      final row = rowsOf(1).first;
      final delay = cell(row, 'delay');
      final interval = cell(row, 'interval');
      final count = int.parse(row['count']!);
      game.startWave(1);
      final at = clockOf(game);

      // k = 0 은 시작과 같은 시각이라 "앞"을 볼 수 없다: 시작 직후 한 걸음 뒤에 하나
      at(delay + 0.05);
      expect(game.waveSpawned, 1);
      for (final k in [1, 2]) {
        at(delay + k * interval - 0.05);
        expect(game.waveSpawned, k, reason: 'k=$k before');
        at(delay + k * interval + 0.05);
        expect(game.waveSpawned, k + 1, reason: 'k=$k after');
      }
      at(delay + (count - 1) * interval + 2);
      expect(game.waveSpawned, totalOf(1));
      at(delay + (count - 1) * interval + 4);
      expect(game.waveSpawned, totalOf(1));
    },
  );

  testWithGame<LighthouseGame>(
    'T7-05 다 나오기 전에는 나온 적을 모두 쓰러뜨려도 웨이브가 끝나지 않는다',
    () => LighthouseGame(waves: true),
    (game) async {
      game.startWave(1);
      final at = clockOf(game);
      at(cell(rowsOf(1).first, 'interval') + 0.05);
      expect(game.waveSpawned, lessThan(totalOf(1)));
      killAll(game);
      at(cell(rowsOf(1).first, 'interval') + 0.05 + Enemy.deathSeconds + 0.1);
      expect(game.isResting, isFalse);
      expect(game.wave, 1);
    },
  );

  testWithGame<LighthouseGame>(
    'T7-06 웨이브를 깨면 rest초 쉬고 다음 웨이브',
    () => LighthouseGame(waves: true),
    (game) async {
      game.startWave(1);
      var t = 0.0;
      while (game.waveSpawned < totalOf(1) && t < 120) {
        game.update(0.05);
        killAll(game);
        t += 0.05;
      }
      expect(game.waveSpawned, totalOf(1));
      game.update(0.05); // 마지막 적이 쓰러진 뒤의 update
      expect(game.isResting, isTrue);

      final at = clockOf(game);
      at(rest - 0.05);
      expect(game.wave, 1);
      at(rest + 0.05);
      expect(game.wave, 2);
      // 웨이브 2의 첫 줄은 delay 0이라 시작과 함께 하나가 나올 수 있다
      expect(game.waveSpawned, lessThanOrEqualTo(1));
    },
  );

  testWithGame<LighthouseGame>(
    'T7-07 같은 씨앗이면 같은 각도, 모두 0 이상 360 미만, 웨이브 2의 적',
    () => LighthouseGame(waves: true, seed: 4),
    (game) async {
      final other = await initializeGame<LighthouseGame>(() => LighthouseGame(waves: true, seed: 4));
      for (final g in [game, other]) {
        g.startWave(2);
        tickGame(g, 6);
      }
      final angles = [for (final e in game.enemies) e.angleDeg];
      expect(angles, isNotEmpty);
      expect([for (final e in other.enemies) e.angleDeg], angles);
      final allowed = rowsOf(2).map((r) => r['enemy']!).toSet();
      for (final e in game.enemies) {
        expect(e.angleDeg, greaterThanOrEqualTo(0));
        expect(e.angleDeg, lessThan(360));
        expect(allowed, contains(e.id));
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T7-08 보스 웨이브: 알림 "보스가 와요!", 보스는 표 그대로, 닿는 거리 100 + radius',
    () => LighthouseGame(waves: true),
    (game) async {
      game.startWave(5);
      game.update(0.05);
      expect(game.banner, Strings.bossComing);
      final boss = game.enemies.firstWhere((e) => e.id == 'boss_squid');
      expect(boss.stats, Tables.enemies['boss_squid']);
      expect(boss.contactDistance, closeTo(halfSide + cell(enemyRows.firstWhere((r) => r['id'] == 'boss_squid'), 'radius'), 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T7-09 마지막 웨이브(보스 포함)를 깨면 이김: 판이 멈추고 결과 창',
    () => LighthouseGame(waves: true),
    (game) async {
      game.startWave(game.waveCount);
      var t = 0.0;
      while (game.result == null && t < 200) {
        game.update(0.05);
        killAll(game);
        t += 0.05;
      }
      expect(game.result, GameResult.won);
      expect(game.isOver, isTrue);
      game.update(0);
      expect(game.resultPanel, isNotNull);

      final elapsed = game.elapsed;
      final count = game.enemies.length;
      tickGame(game, 3);
      expect(game.elapsed, elapsed);
      expect(game.enemies, hasLength(count));
    },
  );

  testWithGame<LighthouseGame>(
    'T7-10 불빛이 꺼지면 짐: 웨이브 판은 결과 창, 연습 판은 꺼짐 문구',
    () => LighthouseGame(waves: true),
    (game) async {
      lightOut(game);
      expect(game.result, GameResult.lost);
      expect(game.isOver, isTrue);
      game.update(0);
      expect(game.resultPanel, isNotNull);
      expect(game.descendants().whereType<LightOutText>(), isEmpty);

      final practice = await initializeGame<LighthouseGame>(() => LighthouseGame());
      lightOut(practice);
      expect(practice.result, GameResult.lost);
      practice.update(0);
      expect(practice.descendants().whereType<LightOutText>(), hasLength(1));
    },
  );

  testWithGame<LighthouseGame>(
    'T7-11 쓰러뜨린 수는 쓰러지는 순간 한 번씩',
    () => LighthouseGame(waves: true),
    (game) async {
      final squids = [for (var i = 0; i < 3; i++) spawn(game, 'ink_squid', i * 120.0, distance: 300)];
      for (final s in squids) {
        s.takeDamage(s.hp);
      }
      squids.first.takeDamage(5);
      game.update(0);
      expect(game.defeated, 3);
    },
  );

  testWithGame<LighthouseGame>(
    'T7-12 놀이 시간은 꺼질 때까지 흐르고 결과 창에 줄이 있다',
    () => LighthouseGame(waves: true),
    (game) async {
      tickGame(game, 10);
      final took = lightOut(game);
      expect(game.elapsed, closeTo(10 + took, 0.1));
      final elapsed = game.elapsed;
      tickGame(game, 3);
      expect(game.elapsed, elapsed);

      game.update(0);
      final lines = game.resultPanel!.lines;
      expect(lines, contains(Strings.resultWave(game.wave, game.waveCount)));
      expect(lines, contains(Strings.resultDefeated(game.defeated)));
      expect(lines, contains(Strings.resultLevel(game.level)));
      expect(lines, contains(Strings.resultTime(game.elapsed)));
    },
  );

  var restarts = 0;
  GameTester<LighthouseGame>(() => LighthouseGame(waves: true, onRestart: () => restarts++)).testGameWidget(
    'T7-13 다시 하기 단추를 누르면 onRestart가 한 번 불린다',
    verify: (game, tester) async {
      lightOut(game);
      game.update(0);
      await tester.pump();
      final b = game.resultPanel!.restartButton;
      expect(b.position.x, greaterThanOrEqualTo(0));
      expect(b.position.y, greaterThanOrEqualTo(0));
      expect(b.position.x + b.size.x, lessThanOrEqualTo(GameConfig.width));
      expect(b.position.y + b.size.y, lessThanOrEqualTo(GameConfig.height));
      expect(Rect.fromLTWH(b.position.x, b.position.y, b.size.x, b.size.y).isEmpty, isFalse);
      expect(restarts, 0);
      final c = b.position + b.size / 2;
      await tapGame(tester, game, c.x, c.y);
      expect(restarts, 1);
    },
  );

  testWithGame<LighthouseGame>(
    'T7-14 웨이브 글은 웨이브 판에만, 연습 판에는 제목',
    () => LighthouseGame(waves: true),
    (game) async {
      game.update(0);
      expect(game.descendants().whereType<TitleText>(), isEmpty);
      expect(game.descendants().whereType<WaveLabel>().single.text, Strings.wave(1, game.waveCount));
      game.startWave(3);
      game.update(0);
      expect(game.descendants().whereType<WaveLabel>().single.text, Strings.wave(3, game.waveCount));

      final practice = await initializeGame<LighthouseGame>(() => LighthouseGame());
      practice.update(0);
      expect(practice.descendants().whereType<TitleText>(), hasLength(1));
      expect(practice.descendants().whereType<WaveLabel>(), isEmpty);
    },
  );

  testWithGame<LighthouseGame>(
    'T7-15 연습 스폰은 보스를 뽑지 않는다',
    () => LighthouseGame(practice: true, seed: 1),
    (game) async {
      final bossIds = enemyRows.where((r) => r['boss'] == '1').map((r) => r['id']!).toSet();
      var t = 0.0;
      while (!game.isOver && t < 60) {
        game.update(0.05);
        t += 0.05;
      }
      expect(game.spawner!.spawned, isNotEmpty);
      for (final r in game.spawner!.spawned) {
        expect(bossIds, isNot(contains(r.id)));
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T7-16 카드 판은 첫 친구를 놓기 전에는 웨이브 시간이 흐르지 않는다',
    () => LighthouseGame(cards: true, waves: true),
    (game) async {
      game.update(0);
      placeFree(game);
      game.pickCard(0);
      expect(game.placing, isNotNull);
      tickGame(game, 10);
      expect(game.wave, 0);
      expect(game.isResting, isTrue);

      game.tapAt(slotOf(game, 'I3').center.clone());
      expect(game.placing, isNull);
      clockOf(game)(firstDelay + 0.05);
      expect(game.wave, 1);
    },
  );

  testWithGame<LighthouseGame>(
    'T7-17 카드 창이 열린 동안 날아가던 거품이 멈춘다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      firstFriend(game, 0, 'I3');
      spawn(game, 'shadow_blob', 90, distance: 300);
      var guard = 0;
      while (game.bubbles.isEmpty && guard++ < 100) {
        game.update(0.05);
      }
      expect(game.bubbles, isNotEmpty);
      game.addXp(game.xpNeeded);
      expect(game.choice, isNotNull);

      final pos = [for (final b in game.bubbles) b.position.clone()];
      tickGame(game, 2);
      expect(game.bubbles, hasLength(pos.length));
      for (var i = 0; i < pos.length; i++) {
        expect(game.bubbles[i].position.x, closeTo(pos[i].x, 1e-6));
        expect(game.bubbles[i].position.y, closeTo(pos[i].y, 1e-6));
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T7-18 카드 창이 열린 동안 조각과 불빛 차기가 멈춘다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      firstFriend(game, 1, 'O1');
      final squid = spawn(game, 'ink_squid', 0, distance: 300);
      squid.takeDamage(squid.hp);
      game.update(0);
      tickGame(game, shardDelay + 0.1);
      final shard = game.shards.single;
      game.addXp(game.xpNeeded);
      expect(game.choice, isNotNull);
      final pos = shard.position.clone();
      tickGame(game, 2);
      expect(shard.position.x, closeTo(pos.x, 1e-6));
      expect(shard.position.y, closeTo(pos.y, 1e-6));

      // regen: 불빛이 깎인 판에서 창이 열린 동안 그대로
      final g2 = await initializeGame<LighthouseGame>(() => LighthouseGame(cards: true));
      g2.update(0);
      firstFriend(g2, 1, 'O1');
      spawn(g2, 'shadow_blob', 180);
      tickGame(g2, Tables.enemies['shadow_blob']!.biteInterval + 0.05);
      expect(g2.light, lessThan(g2.maxLight));
      g2.applyCard('light_regen');
      g2.addXp(g2.xpNeeded);
      expect(g2.choice, isNotNull);
      final light = g2.light;
      tickGame(g2, 2);
      expect(g2.light, light);
    },
  );

  testWithGame<LighthouseGame>(
    'T7-19 놓기 상태에서는 시간이 안 흐르고, 나중에 놓은 친구에게도 upgrade 배율이 붙는다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      placeFree(game);
      game.pickCard(1);
      expect(game.placing, 'crab');
      final blob = spawn(game, 'shadow_blob', 0, distance: Tables.lighthouse.spawnDistance);
      tickGame(game, 2);
      expect(blob.distance, closeTo(Tables.lighthouse.spawnDistance, 1e-6));

      final practice = await initializeGame<LighthouseGame>(() => LighthouseGame());
      final value = cell(readCsv('cards.csv').firstWhere((r) => r['id'] == 'upgrade_crab'), 'value');
      practice.applyCard('upgrade_crab');
      place(practice, 'crab', 'I3');
      final b = spawn(practice, 'shadow_blob', 90);
      final hp = b.hp;
      clockOf(practice)(windup + 0.05);
      expect(b.hp, closeTo(hp - Tables.friends['crab']!.damage * value, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T7-20 카드 판은 공짜 친구 놓기 상태로 시작하고, 놓으면 첫 친구 창이 열린다',
    () => LighthouseGame(cards: true),
    (game) async {
      game.update(0);
      final free = Tables.start.freeFriend;
      if (free == null) {
        expect(game.choice, isNotNull);
        return;
      }
      expect(game.placing, free);
      expect(game.choice, isNull);
      expect(game.isPaused, isTrue);
      expect(game.picks.values.every((v) => v == 0), isTrue);

      game.tapAt(Vector2(100, 1200));
      expect(game.placing, free);
      expect(game.choice, isNull);

      game.tapAt(slotOf(game, 'O6').center.clone());
      expect(slotOf(game, 'O6').friend?.id, free);
      expect(game.placing, isNull);
      expect(game.choice, [for (final r in readCsv('cards.csv')) if (r['kind'] == 'friend') r['id']!]);
    },
  );
}
