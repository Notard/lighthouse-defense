import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/enemy.dart';
import 'package:lighthouse_defense/game/friend.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/slots.dart';
import 'package:lighthouse_defense/game/tables.g.dart';

import 'support.dart';

/// 5단계: 친구 놓기·자동 공격 (docs/tests/05-friends.md, T5-01~17).
/// 숫자는 박지 않고 표(CSV)를 직접 읽어 기대값을 계산한다.
void main() {
  const halfSide = GameConfig.lighthouseSize / 2;
  const windup = Friend.windupSeconds;

  Slot slotOf(LighthouseGame game, String id) => game.slots.firstWhere((s) => s.id == id);

  double contactOf(String id) => halfSide + Tables.enemies[id]!.radius;

  /// 닿게 둔 적 (distance 없으면 닿는 거리).
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

  double cell(Map<String, String> row, String key) => double.parse(row[key]!);

  /// 시작부터 센 시간을 0.05초 단위 걸음 수로 맞춰 흘린다 (반올림 오차가 쌓이지 않게).
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

  Vector2 buttonCenter(LighthouseGame game, String friendId) {
    final b = game.tray!.buttons.firstWhere((b) => b.friendId == friendId);
    return b.position + b.size / 2;
  }

  Future<void> tapButton(WidgetTester tester, LighthouseGame game, String friendId) {
    final c = buttonCenter(game, friendId);
    return tapGame(tester, game, c.x, c.y);
  }

  Future<void> tapSlot(WidgetTester tester, LighthouseGame game, String id) {
    final c = slotOf(game, id).center;
    return tapGame(tester, game, c.x, c.y);
  }

  /// 해파리 다섯이 닿게 두고 불빛이 꺼질 때까지 (길어도 120초) 흘린다.
  void lightOut(LighthouseGame game) {
    for (final a in const [18.0, 90.0, 162.0, 234.0, 306.0]) {
      spawn(game, 'shadow_jelly', a);
    }
    var t = 0.0;
    while (game.light > 0 && t < 120) {
      game.update(0.05);
      t += 0.05;
    }
    expect(game.isOver, isTrue);
  }

  testWithGame<LighthouseGame>(
    'T5-01 표(CSV)의 값이 Tables와 같고, 친구 id는 characters의 friend와 같다',
    () => LighthouseGame(),
    (game) async {
      final rows = readCsv('friends.csv');
      expect(Tables.friends.length, rows.length);
      for (final row in rows) {
        final s = Tables.friends[row['id']]!;
        expect(s.id, row['id']);
        expect(s.attack, row['attack']);
        expect(s.range, cell(row, 'range'));
        expect(s.damage, cell(row, 'damage'));
        expect(s.interval, cell(row, 'interval'));
        expect(s.projectileSpeed, cell(row, 'projectile_speed'));
      }
      final friendIds = readCsv('characters.csv').where((r) => r['kind'] == 'friend').map((r) => r['id']!).toSet();
      expect(Tables.friends.keys.toSet(), friendIds);
      for (final s in Tables.friends.values) {
        expect(['shot', 'melee', 'burst'], contains(s.attack), reason: s.id);
        expect(s.range, greaterThan(0), reason: '${s.id} range');
        expect(s.damage, greaterThan(0), reason: '${s.id} damage');
        expect(s.interval, greaterThan(0), reason: '${s.id} interval');
        if (s.attack == 'shot') expect(s.projectileSpeed, greaterThan(0), reason: '${s.id} projectile_speed');
      }
    },
  );

  testWithGame<LighthouseGame>(
    'T5-02 빈 자리에만 놓인다 (차 있으면 null), friends는 놓은 순서',
    () => LighthouseGame(),
    (game) async {
      final i0 = slotOf(game, 'I0');
      final crab = game.placeFriend('crab', i0);
      expect(crab, isA<Friend>());
      expect(i0.friend, same(crab));
      expect(crab!.position.x, closeTo(i0.center.x, 0.5));
      expect(crab.position.y, closeTo(i0.center.y, 0.5));

      expect(game.placeFriend('seahorse', i0), isNull);
      expect(i0.friend, same(crab));
      expect(i0.friend!.id, 'crab');

      final horse = game.placeFriend('seahorse', slotOf(game, 'O5'));
      expect(horse, isNotNull);
      game.update(0);
      expect(game.friends, [crab, horse]);
      expect([for (final f in game.friends) f.id], ['crab', 'seahorse']);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T5-03 쟁반: 단추 셋 (해마·게·복어), 판 안 아래쪽, 겹치지 않음, 처음 held null',
    verify: (game, tester) async {
      final buttons = game.tray!.buttons;
      expect([for (final b in buttons) b.friendId], ['seahorse', 'crab', 'pufferfish']);
      for (final b in buttons) {
        expect(b.position.x, greaterThanOrEqualTo(0), reason: b.friendId);
        expect(b.position.x + b.size.x, lessThanOrEqualTo(GameConfig.width), reason: b.friendId);
        expect(b.position.y, greaterThan(1000), reason: b.friendId);
        expect(b.position.y + b.size.y, lessThanOrEqualTo(GameConfig.height), reason: b.friendId);
      }
      for (var i = 0; i < buttons.length; i++) {
        for (var j = i + 1; j < buttons.length; j++) {
          final a = Rect.fromLTWH(buttons[i].position.x, buttons[i].position.y, buttons[i].size.x, buttons[i].size.y);
          final b = Rect.fromLTWH(buttons[j].position.x, buttons[j].position.y, buttons[j].size.x, buttons[j].size.y);
          expect(a.overlaps(b), isFalse, reason: '${buttons[i].friendId} / ${buttons[j].friendId}');
        }
      }
      expect(game.tray!.held, isNull);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T5-04 단추로 들고, 빈 자리에 이어 놓고, 다시 누르면 내려놓는다 (그 뒤 자리 누르기는 고르기)',
    verify: (game, tester) async {
      await tapButton(tester, game, 'seahorse');
      expect(game.tray!.held, 'seahorse');
      expect(game.selectedSlot, isNull);

      await tapSlot(tester, game, 'O3');
      await tapSlot(tester, game, 'O4');
      expect(slotOf(game, 'O3').friend?.id, 'seahorse');
      expect(slotOf(game, 'O4').friend?.id, 'seahorse');
      expect(game.tray!.held, 'seahorse');
      expect(game.selectedSlot, isNull);

      await tapButton(tester, game, 'seahorse');
      expect(game.tray!.held, isNull);

      await tapSlot(tester, game, 'O6');
      expect(slotOf(game, 'O6').friend, isNull);
      expect(game.selectedSlot, same(slotOf(game, 'O6')));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T5-05 친구를 든 채 친구 있는 자리를 누르면 아무 일 없다',
    verify: (game, tester) async {
      await tapButton(tester, game, 'crab');
      await tapSlot(tester, game, 'I0');
      expect(slotOf(game, 'I0').friend?.id, 'crab');
      await tapButton(tester, game, 'pufferfish');
      await tapSlot(tester, game, 'I0');
      expect(slotOf(game, 'I0').friend?.id, 'crab');
      expect(game.friends, hasLength(1));
      expect(game.tray!.held, 'pufferfish');
    },
  );

  testWithGame<LighthouseGame>(
    'T5-06 사거리 밖 적은 공격하지 않는다',
    () => LighthouseGame(),
    (game) async {
      final crab = place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_blob', 0);
      final hp = blob.hp;
      for (var i = 0; i < 100; i++) {
        game.update(0.05);
        expect(crab.isAttacking, isFalse, reason: 'step $i');
      }
      expect(blob.hp, hp);
      expect(crab.target, isNull);
    },
  );

  testWithGame<LighthouseGame>(
    'T5-07 사거리 안 적: windup 뒤 damage, interval마다 되풀이',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.friends['crab']!;
      final crab = place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_blob', 90);
      final hp = blob.hp;
      final at = clockOf(game);

      at(windup - 0.05);
      expect(blob.hp, hp);
      expect(crab.isAttacking, isTrue);
      expect(crab.target, same(blob));
      at(windup + 0.05);
      expect(blob.hp, closeTo(hp - s.damage, 1e-9));
      at(s.interval + windup - 0.05);
      expect(blob.hp, closeTo(hp - s.damage, 1e-9));
      at(s.interval + windup + 0.05);
      expect(blob.hp, closeTo(hp - 2 * s.damage, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T5-08 복어는 사거리 안 모든 적에게 damage, 밖은 그대로',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.friends['pufferfish']!;
      place(game, 'pufferfish', 'I3');
      final near = [for (final a in [80.0, 90.0, 100.0]) spawn(game, 'shadow_jelly', a)];
      final far = spawn(game, 'shadow_jelly', 270);
      final hp = Tables.enemies['shadow_jelly']!.hp;

      clockOf(game)(windup + 0.05);
      for (final e in near) {
        expect(e.hp, closeTo(hp - s.damage, 1e-9), reason: '${e.angleDeg}');
      }
      expect(far.hp, hp);
    },
  );

  testWithGame<LighthouseGame>(
    'T5-09 해마는 등대에 가까운 적에게 거품을 쏜다',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.friends['seahorse']!;
      final horse = place(game, 'seahorse', 'I3');
      final squid = spawn(game, 'ink_squid', 80);
      final jelly = spawn(game, 'shadow_jelly', 100);
      final squidHp = squid.hp;
      final jellyHp = jelly.hp;
      final at = clockOf(game);

      at(windup - 0.05);
      expect(horse.target, same(squid));
      at(windup + 0.05);
      expect(game.bubbles, hasLength(1));
      expect(game.bubbles.single.position.distanceTo(slotOf(game, 'I3').center), lessThan(60));
      at(windup + 0.5);
      expect(squid.hp, closeTo(squidHp - s.damage, 1e-9));
      expect(jelly.hp, jellyHp);
      expect(game.bubbles, isEmpty);
    },
  );

  testWithGame<LighthouseGame>(
    'T5-10 빛 속 적은 vulnerable 배로 맞는다',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.friends['crab']!;
      place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_blob', 90);
      final hp = blob.hp;
      game.aimBeamAt(Vector2(360, 1000));
      clockOf(game)(windup + 0.05);
      expect(blob.hp, closeTo(hp - s.damage * Tables.beam.vulnerable, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T5-11 날아가던 거품은 과녁이 쓰러지면 피해 없이 터진다',
    () => LighthouseGame(),
    (game) async {
      place(game, 'seahorse', 'I3');
      final squid = spawn(game, 'ink_squid', 90, distance: 400);
      final at = clockOf(game);

      at(windup + 0.05);
      expect(game.bubbles, hasLength(1));
      squid.takeDamage(squid.hp);
      final hpAfter = squid.hp;
      for (var i = 0; i < 20; i++) {
        game.update(0.05);
      }
      expect(game.bubbles, isEmpty);
      expect(squid.hp, hpAfter);
    },
  );

  testWithGame<LighthouseGame>(
    'T5-12 게는 과녁이 쓰러지면 헛친다 (다른 적으로 바꾸지 않음)',
    () => LighthouseGame(),
    (game) async {
      place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_blob', 90);
      final jelly = spawn(game, 'shadow_jelly', 100);
      final jellyHp = jelly.hp;
      final at = clockOf(game);

      at(windup - 0.1);
      blob.takeDamage(blob.hp);
      at(windup + 0.05);
      expect(jelly.hp, jellyHp);
    },
  );

  testWithGame<LighthouseGame>(
    'T5-13 쓰러뜨리는 공격 횟수는 ceil(hp / damage), 쓰러지면 과녁을 놓고 사라진다',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.friends['crab']!;
      final crab = place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_blob', 90);
      final maxHp = blob.hp;

      var hits = 0;
      var t = 0.0;
      while (blob.state != EnemyState.dying && t < 10) {
        final before = blob.hp;
        game.update(0.05);
        t += 0.05;
        if (blob.hp < before) hits++;
      }
      expect(blob.state, EnemyState.dying);
      expect(hits, (maxHp / s.damage).ceil());
      expect(crab.target, isNull);
      expect(crab.isAttacking, isFalse);

      tickGame(game, Enemy.deathSeconds + 0.1);
      expect(game.enemies, isNot(contains(blob)));
      expect(crab.target, isNull);
      expect(crab.isAttacking, isFalse);
    },
  );

  testWithGame<LighthouseGame>(
    'T5-14 큰 dt는 maxFrameDt로 자른다',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.enemies['shadow_blob']!;
      final blob = spawn(game, 'shadow_blob', 0, distance: Tables.lighthouse.spawnDistance);
      game.update(5.0);
      expect(blob.distance, closeTo(Tables.lighthouse.spawnDistance - s.speed * GameConfig.maxFrameDt, 0.5));
    },
  );

  testWithGame<LighthouseGame>(
    'T5-15 닿는 거리 안쪽에서 나타난 적은 첫 update에 밖으로 옮겨지고 그 프레임에 갉지 않는다',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.enemies['shadow_blob']!;
      final contact = contactOf('shadow_blob');
      final blob = spawn(game, 'shadow_blob', 0, distance: contact - 20);
      final start = game.light;

      game.update(0.05);
      expect(blob.distance, closeTo(contact, 0.5));
      expect(blob.state, EnemyState.biting);
      expect(game.light, start);

      final at = clockOf(game);
      at(s.biteInterval - 0.05);
      expect(game.light, start);
      at(s.biteInterval + 0.05);
      expect(game.light, closeTo(start - s.bite, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T5-16 꺼진 판에서는 친구를 놓을 수 없고 친구가 공격하지 않는다',
    () => LighthouseGame(),
    (game) async {
      lightOut(game);
      final jelly90 = game.enemies.firstWhere((e) => (e.angleDeg - 90).abs() < 1);
      final hp = jelly90.hp;
      final crab = game.placeFriend('crab', slotOf(game, 'I3'));
      expect(crab, isNull);
      game.update(0);
      tickGame(game, 3);
      expect(slotOf(game, 'I3').friend, isNull);
      expect(game.friends, isEmpty);
      expect(jelly90.hp, hp);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T5-17 꺼진 뒤에는 쟁반 단추가 먹히지 않는다',
    verify: (game, tester) async {
      lightOut(game);
      await tapButton(tester, game, 'crab');
      expect(game.tray!.held, isNull);
    },
  );

  testWithGame<LighthouseGame>(
    'T5-18 시간이 흐르지 않는 update(0)에서는 공격이 시작되지 않는다',
    () => LighthouseGame(),
    (game) async {
      final crab = place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_blob', 90);
      final hp = blob.hp;
      for (var i = 0; i < 5; i++) {
        game.update(0);
      }
      expect(crab.target, isNull);
      expect(crab.isAttacking, isFalse);
      expect(crab.cooldown, 0);
      expect(blob.hp, hp);
      game.update(0.05);
      expect(crab.isAttacking, isTrue);
      expect(crab.target, same(blob));
    },
  );

  testWithGame<LighthouseGame>(
    'T5-19 꺼지면 모든 것이 멈춘다 (적 체력, 친구, 거품, 쓰러지는 적의 사라짐)',
    () => LighthouseGame(),
    (game) async {
      place(game, 'crab', 'I3');
      place(game, 'seahorse', 'I0');
      for (final a in const [18.0, 90.0, 162.0, 234.0, 306.0]) {
        spawn(game, 'shadow_jelly', a);
      }
      var shot = false;
      var t = 0.0;
      while (game.light > 0 && t < 120) {
        game.update(0.05);
        t += 0.05;
        if (game.bubbles.isNotEmpty) shot = true;
      }
      expect(game.isOver, isTrue);
      expect(shot, isTrue, reason: '꺼지기 전 해마가 거품을 쏘았어야 한다');

      final hps = [for (final e in game.enemies) e.hp];
      final count = game.enemies.length;
      final friendState = [for (final f in game.friends) (f.cooldown, f.isAttacking)];
      final bubblePos = [for (final b in game.bubbles) b.position.clone()];

      tickGame(game, 3);

      expect([for (final e in game.enemies) e.hp], hps);
      expect(game.enemies, hasLength(count));
      expect([for (final f in game.friends) (f.cooldown, f.isAttacking)], friendState);
      expect(game.bubbles, hasLength(bubblePos.length));
      for (var i = 0; i < bubblePos.length; i++) {
        expect(game.bubbles[i].position.x, closeTo(bubblePos[i].x, 1e-6));
        expect(game.bubbles[i].position.y, closeTo(bubblePos[i].y, 1e-6));
      }
    },
  );
}
