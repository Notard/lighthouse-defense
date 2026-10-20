import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/enemy.dart';
import 'package:lighthouse_defense/game/geometry.dart';
import 'package:lighthouse_defense/game/hud.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/tables.g.dart';

import 'support.dart';

/// 4단계: 적, 등대 불빛, 빛줄기, 연습 스폰 (docs/tests/04-enemies.md, T4-01~15).
/// 숫자는 박지 않고 표(CSV)를 직접 읽어 기대값을 계산한다.
void main() {
  /// 등대 한 변의 절반 (닿는 거리 = 이것 + 적 반지름).
  const halfSide = GameConfig.lighthouseSize / 2;

  Enemy spawn(LighthouseGame game, String id, double angleDeg, {double? distance}) {
    final e = game.spawnEnemy(id, angleDeg, distance: distance);
    game.update(0); // 다음 프레임에 붙는다
    return e;
  }

  double contactOf(String id) => halfSide + Tables.enemies[id]!.radius;

  Iterable<LightOutText> lightOutTexts(LighthouseGame game) => game.descendants().whereType<LightOutText>();

  double cell(Map<String, String> row, String key) => double.parse(row[key]!);

  testWithGame<LighthouseGame>(
    'T4-01 표(CSV)의 값이 Tables와 같다',
    () => LighthouseGame(),
    (game) async {
      final enemies = readCsv('enemies.csv');
      expect(Tables.enemies.length, enemies.length);
      for (final row in enemies) {
        final s = Tables.enemies[row['id']]!;
        expect(s.id, row['id']);
        expect(s.hp, cell(row, 'hp'));
        expect(s.speed, cell(row, 'speed'));
        expect(s.bite, cell(row, 'bite'));
        expect(s.biteInterval, cell(row, 'bite_interval'));
        expect(s.radius, cell(row, 'radius'));
      }

      final beam = readCsv('beam.csv').single;
      expect(Tables.beam.widthDeg, cell(beam, 'width_deg'));
      expect(Tables.beam.length, cell(beam, 'length'));
      expect(Tables.beam.slow, cell(beam, 'slow'));
      expect(Tables.beam.vulnerable, cell(beam, 'vulnerable'));

      final lh = readCsv('lighthouse.csv').single;
      expect(Tables.lighthouse.hp, cell(lh, 'hp'));
      expect(Tables.lighthouse.spawnDistance, cell(lh, 'spawn_distance'));

      final pr = readCsv('practice.csv').single;
      expect(Tables.practice.interval, cell(pr, 'interval'));
      expect(Tables.practice.maxAlive, int.parse(pr['max_alive']!));

      final chars = readCsv('characters.csv');
      expect(Tables.characters.length, chars.length);
      for (final row in chars) {
        final c = Tables.characters[row['id']]!;
        expect(c.id, row['id']);
        expect(c.kind, row['kind']);
        expect(c.nameKo, row['name_ko']);
        expect(c.nameEn, row['name_en']);
        expect(c.displayHeight, cell(row, 'display_height'));
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T4-02 표끼리 맞는다 (id 모음, 양수, 빛 숫자 범위, 나타나는 거리)',
    () => LighthouseGame(),
    (game) async {
      final enemyIds = readCsv('enemies.csv').map((r) => r['id']!).toSet();
      final enemyKinds = readCsv('characters.csv').where((r) => r['kind'] == 'enemy').map((r) => r['id']!).toSet();
      expect(enemyIds, enemyKinds);

      for (final s in Tables.enemies.values) {
        expect(s.hp, greaterThan(0), reason: '${s.id} hp');
        expect(s.speed, greaterThan(0), reason: '${s.id} speed');
        expect(s.bite, greaterThan(0), reason: '${s.id} bite');
        expect(s.biteInterval, greaterThan(0), reason: '${s.id} bite_interval');
        expect(s.radius, greaterThan(0), reason: '${s.id} radius');
      }

      expect(Tables.beam.slow, greaterThan(0));
      expect(Tables.beam.slow, lessThanOrEqualTo(1));
      expect(Tables.beam.vulnerable, greaterThanOrEqualTo(1));

      final center = lighthouseCenter();
      final corners = [Vector2(0, 0), Vector2(GameConfig.width, 0), Vector2(0, GameConfig.height), Vector2(GameConfig.width, GameConfig.height)];
      final farthest = corners.map((c) => c.distanceTo(center)).reduce(math.max);
      expect(Tables.lighthouse.spawnDistance, greaterThan(farthest));
    },
  );

  testWithGame<LighthouseGame>(
    'T4-03 적은 등대에서 spawn_distance 떨어진 곳, 주어진 각도에 나타난다',
    () => LighthouseGame(),
    (game) async {
      game.spawnEnemy('shadow_blob', 0);
      game.spawnEnemy('ink_squid', 90);
      game.update(0);

      final d = Tables.lighthouse.spawnDistance;
      expect(game.enemies, hasLength(2));
      final a = game.enemies[0];
      final b = game.enemies[1];
      expect(a.id, 'shadow_blob');
      expect(b.id, 'ink_squid');
      expect(a.position.x, closeTo(GameConfig.lighthouseX + d, 0.5));
      expect(a.position.y, closeTo(GameConfig.lighthouseY, 0.5));
      expect(b.position.x, closeTo(GameConfig.lighthouseX, 0.5));
      expect(b.position.y, closeTo(GameConfig.lighthouseY + d, 0.5));
      for (final e in [a, b]) {
        expect(e.state, EnemyState.moving, reason: e.id);
        expect(e.hp, Tables.enemies[e.id]!.hp, reason: e.id);
        expect(e.distance, closeTo(d, 0.5), reason: e.id);
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T4-04 적은 등대 가운데를 향해 곧장 온다 (빛 밖에서는 1초에 speed)',
    () => LighthouseGame(),
    (game) async {
      // 새 판의 빛은 270° (위쪽)
      final e = spawn(game, 'shadow_blob', 0);
      tickGame(game, 1);
      final s = Tables.enemies['shadow_blob']!;
      expect(e.distance, closeTo(Tables.lighthouse.spawnDistance - s.speed * 1, 0.5));
      expect(e.position.y, closeTo(GameConfig.lighthouseY, 0.5));
      expect(e.angleDeg, closeTo(0, 0.5));
    },
  );

  testWithGame<LighthouseGame>(
    'T4-05 닿는 거리에서 멈추고(넘어가지 않음) 갉기 상태가 된다',
    () => LighthouseGame(),
    (game) async {
      final contact = contactOf('ink_squid');
      final e = spawn(game, 'ink_squid', 0, distance: contact + 10);
      tickGame(game, 1);
      expect(e.contactDistance, closeTo(contact, 1e-9));
      expect(e.distance, closeTo(contact, 1e-6));
      expect(e.state, EnemyState.biting);
    },
  );

  testWithGame<LighthouseGame>(
    'T4-06 갉기는 bite_interval초마다 불빛을 bite만큼 깎는다 (첫 갉기는 닿고 bite_interval초 뒤)',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.enemies['shadow_blob']!;
      final e = spawn(game, 'shadow_blob', 0, distance: contactOf('shadow_blob'));
      final start = game.light;
      final pos = e.position.clone();

      tickGame(game, s.biteInterval - 0.05);
      expect(game.light, start);
      tickGame(game, 0.1);
      expect(game.light, closeTo(start - s.bite, 1e-9));
      tickGame(game, 2 * s.biteInterval); // 합계 3 × bite_interval + 0.05초
      expect(game.light, closeTo(start - 3 * s.bite, 1e-9));
      expect(e.position.x, closeTo(pos.x, 1e-6));
      expect(e.position.y, closeTo(pos.y, 1e-6));
    },
  );

  testWithGame<LighthouseGame>(
    'T4-07 불빛이 0이 되면 꺼지고 판이 멈춘다',
    () => LighthouseGame(),
    (game) async {
      final jellies = [for (var i = 0; i < 5; i++) spawn(game, 'shadow_jelly', i * 72.0, distance: contactOf('shadow_jelly'))];

      var t = 0.0;
      while (game.light > 0 && t < 120) {
        expect(game.isOver, isFalse, reason: 'light ${game.light} at $t');
        expect(lightOutTexts(game), isEmpty, reason: 'light ${game.light} at $t');
        game.update(0.05);
        t += 0.05;
        expect(game.light, greaterThanOrEqualTo(0));
      }
      expect(game.light, 0);
      expect(game.isOver, isTrue);
      game.update(0); // 문구는 다음 프레임에 붙는다
      expect(lightOutTexts(game), hasLength(1));

      final positions = [for (final e in jellies) e.position.clone()];
      final states = [for (final e in jellies) e.state];
      tickGame(game, 5);
      expect(game.light, 0);
      for (var i = 0; i < jellies.length; i++) {
        expect(jellies[i].position.x, closeTo(positions[i].x, 1e-6));
        expect(jellies[i].position.y, closeTo(positions[i].y, 1e-6));
        expect(jellies[i].state, states[i]);
      }
      expect(lightOutTexts(game), hasLength(1));

      // 꺼진 뒤 입력은 무시
      final beamAngle = game.beam.angleDeg;
      game.aimBeamAt(pointFromLighthouse(90, 300));
      expect(game.beam.angleDeg, beamAngle);
      final selected = game.selectedSlot;
      game.tapAt(game.slots.first.center);
      expect(game.selectedSlot, selected);
    },
  );

  testWithGame<LighthouseGame>(
    'T4-08 빛 속 판정: 경계는 속, 조금 넘으면 밖',
    () => LighthouseGame(),
    (game) async {
      expect(game.beam.widthDeg, Tables.beam.widthDeg);
      expect(game.beam.length, Tables.beam.length);
      final half = Tables.beam.widthDeg / 2;
      final length = Tables.beam.length;

      bool at(double deg, double dist) => game.beam.contains(pointFromLighthouse(deg, dist));

      game.beam.angleDeg = 270;
      expect(at(270, 300), isTrue, reason: '270° 거리 300');
      expect(at(270 + half, 300), isTrue, reason: '경계');
      expect(at(270 + half + 0.5, 300), isFalse, reason: '경계 밖');
      expect(at(270, length), isTrue, reason: '길이 끝');
      expect(at(270, length + 1), isFalse, reason: '길이 밖');
      expect(at(90, 100), isFalse, reason: '반대쪽');

      game.beam.angleDeg = 350;
      expect(at(5, 300), isTrue, reason: '360 경계를 넘는 속');
      expect(at(15, 300), isFalse, reason: '360 경계를 넘는 밖');

      game.beam.angleDeg = 10;
      expect(at(355, 300), isTrue);
      expect(at(335, 300), isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T4-09 빛 속 적은 slow 배로 느려지고, 빛을 돌리면 바로 바뀐다',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.enemies['shadow_blob']!;
      final inside = spawn(game, 'shadow_blob', 270, distance: 600);
      final outside = spawn(game, 'shadow_blob', 90, distance: 600);
      tickGame(game, 1);
      expect(inside.inBeam, isTrue);
      expect(600 - inside.distance, closeTo(s.speed * Tables.beam.slow, 0.5));
      expect(outside.inBeam, isFalse);
      expect(600 - outside.distance, closeTo(s.speed, 0.5));

      final game2 = await initializeGame<LighthouseGame>(() => LighthouseGame());
      final turned = spawn(game2, 'shadow_blob', 270, distance: 600);
      tickGame(game2, 0.5);
      game2.aimBeamAt(pointFromLighthouse(90, 300));
      tickGame(game2, 0.5);
      expect(600 - turned.distance, closeTo(s.speed * Tables.beam.slow * 0.5 + s.speed * 0.5, 0.5));
      expect(turned.inBeam, isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T4-10 빛 속 적은 피해를 vulnerable 배로 받는다',
    () => LighthouseGame(),
    (game) async {
      final inside = spawn(game, 'shadow_jelly', 270, distance: 300);
      final outside = spawn(game, 'shadow_jelly', 90, distance: 300);
      final hp = Tables.enemies['shadow_jelly']!.hp;

      final dealtIn = inside.takeDamage(10);
      expect(dealtIn, closeTo(10 * Tables.beam.vulnerable, 1e-9));
      expect(inside.hp, closeTo(hp - dealtIn, 1e-9));

      final dealtOut = outside.takeDamage(10);
      expect(dealtOut, closeTo(10, 1e-9));
      expect(outside.hp, closeTo(hp - 10, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T4-11 쓰러진 적은 멈추고 deathSeconds 뒤 사라지며, 더 갉지 않는다',
    () => LighthouseGame(),
    (game) async {
      final e = spawn(game, 'ink_squid', 0, distance: 300);
      e.takeDamage(e.hp);
      expect(e.state, EnemyState.dying);

      final pos = e.position.clone();
      final hpAfter = e.hp;
      tickGame(game, Enemy.deathSeconds - 0.05);
      expect(game.enemies, contains(e));
      expect(e.position.x, closeTo(pos.x, 1e-6));
      expect(e.position.y, closeTo(pos.y, 1e-6));
      expect(e.takeDamage(5), 0);
      expect(e.hp, hpAfter);

      tickGame(game, 0.1);
      expect(game.enemies, isNot(contains(e)));
      game.update(0);
      expect(game.descendants().contains(e), isFalse);

      // 닿는 거리에서 쓰러진 적은 갉지 않는다
      final game2 = await initializeGame<LighthouseGame>(() => LighthouseGame());
      final s = Tables.enemies['shadow_blob']!;
      final b = spawn(game2, 'shadow_blob', 0, distance: contactOf('shadow_blob'));
      final start = game2.light;
      b.takeDamage(b.hp);
      tickGame(game2, s.biteInterval * 3);
      expect(game2.light, start);
    },
  );

  testWithGame<LighthouseGame>(
    'T4-12 불빛 막대: 채운 비율과 자리',
    () => LighthouseGame(),
    (game) async {
      final bar = game.lightBar;
      expect(bar.ratio, 1);
      expect(bar.position.x, greaterThanOrEqualTo(0));
      expect(bar.position.y, greaterThanOrEqualTo(0));
      expect(bar.position.x + bar.size.x, lessThanOrEqualTo(GameConfig.width));
      expect(bar.position.y + bar.size.y, lessThanOrEqualTo(100));
      expect(bar.size.x, greaterThan(GameConfig.width / 2));

      final s = Tables.enemies['shadow_blob']!;
      spawn(game, 'shadow_blob', 0, distance: contactOf('shadow_blob'));
      tickGame(game, s.biteInterval + 0.05);
      expect(game.lightBar.ratio, closeTo((game.maxLight - s.bite) / game.maxLight, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T4-13 연습 스폰은 같은 씨앗이면 같은 순서, 다른 씨앗이면 다르다',
    () => LighthouseGame(practice: true, seed: 7),
    (game) async {
      final interval = Tables.practice.interval;
      final other = await initializeGame<LighthouseGame>(() => LighthouseGame(practice: true, seed: 7));
      final different = await initializeGame<LighthouseGame>(() => LighthouseGame(practice: true, seed: 8));
      for (final g in [game, other, different]) {
        tickGame(g, 3 * interval + 0.05);
      }

      expect(game.spawner!.spawned, hasLength(3));
      expect(other.spawner!.spawned, game.spawner!.spawned);
      for (final r in game.spawner!.spawned) {
        expect(Tables.enemies.containsKey(r.id), isTrue, reason: r.id);
        expect(r.angleDeg, greaterThanOrEqualTo(0));
        expect(r.angleDeg, lessThan(360));
      }
      expect(different.spawner!.spawned, isNot(game.spawner!.spawned));
    },
  );

  testWithGame<LighthouseGame>(
    'T4-14 연습 스폰은 max_alive를 넘지 않고, 꺼지면 멈춘다',
    () => LighthouseGame(practice: true, seed: 1),
    (game) async {
      var t = 0.0;
      while (!game.isOver && t < 300) {
        game.update(0.05);
        t += 0.05;
        final alive = game.enemies.where((e) => e.state != EnemyState.dying).length;
        expect(alive, lessThanOrEqualTo(Tables.practice.maxAlive), reason: 't=$t');
      }
      expect(game.isOver, isTrue, reason: '300초 안에 꺼져야 한다');

      final count = game.spawner!.spawned.length;
      tickGame(game, Tables.practice.interval * 3);
      expect(game.spawner!.spawned, hasLength(count));
    },
  );

  testWithGame<LighthouseGame>(
    'T4-15 기본 판은 연습 스폰이 꺼져 있다',
    () => LighthouseGame(),
    (game) async {
      tickGame(game, 30);
      expect(game.spawner, isNull);
      expect(game.enemies, isEmpty);
    },
  );
}
