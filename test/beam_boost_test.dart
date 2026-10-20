import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/enemy.dart';
import 'package:lighthouse_defense/game/friend.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/slots.dart';
import 'package:lighthouse_defense/game/tables.g.dart';

import 'support.dart';

/// 빛 속 친구가 힘을 얻음 (docs/tests/08-beam-boost.md, T8-01~05).
void main() {
  const halfSide = GameConfig.lighthouseSize / 2;
  const windup = Friend.windupSeconds;
  final down = Vector2(360, 1000);
  final up = Vector2(360, 300);

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

  testWithGame<LighthouseGame>(
    'T8-01 friendHaste는 표의 friend_haste이고 1 이상이다',
    () => LighthouseGame(),
    (game) async {
      final row = readCsv('beam.csv').single;
      expect(Tables.beam.friendHaste, double.parse(row['friend_haste']!));
      expect(Tables.beam.friendHaste, greaterThanOrEqualTo(1));
    },
  );

  testWithGame<LighthouseGame>(
    'T8-02 빛 속 친구는 inBeam 참, 빛을 돌리면 바로 바뀐다',
    () => LighthouseGame(),
    (game) async {
      final top = place(game, 'crab', 'I0');
      final bottom = place(game, 'crab', 'I3');
      expect(top.inBeam, isTrue);
      expect(bottom.inBeam, isFalse);
      game.aimBeamAt(down);
      expect(top.inBeam, isFalse);
      expect(bottom.inBeam, isTrue);
    },
  );

  testWithGame<LighthouseGame>(
    'T8-03 빛 속 친구의 두 번째 공격은 interval / friend_haste + windup 무렵',
    () => LighthouseGame(),
    (game) async {
      final s = Tables.friends['crab']!;
      final haste = Tables.beam.friendHaste;
      game.aimBeamAt(down);
      place(game, 'crab', 'I3');
      final blob = spawn(game, 'shadow_jelly', 90);
      final hp = blob.hp;
      final dealt = s.damage * Tables.beam.vulnerable;
      final second = s.interval / haste + windup;
      final at = clockOf(game);

      at(second - 0.1);
      expect(blob.hp, closeTo(hp - dealt, 1e-9));
      at(second + 0.1);
      expect(blob.hp, closeTo(hp - 2 * dealt, 1e-9));
    },
  );

  testWithGame<LighthouseGame>(
    'T8-04 쉬는 시간은 빛 속에서 friend_haste 배로 줄고, 빛 밖에서는 1배',
    () => LighthouseGame(),
    (game) async {
      final haste = Tables.beam.friendHaste;
      game.aimBeamAt(down);
      final crab = place(game, 'crab', 'I3');
      spawn(game, 'shadow_blob', 90);

      var guard = 0;
      while (!crab.isAttacking && guard++ < 100) {
        game.update(0.05);
      }
      expect(crab.isAttacking, isTrue);
      final c0 = crab.cooldown;
      final at = clockOf(game);

      at(0.5);
      expect(crab.cooldown, closeTo(c0 - 0.5 * haste, 0.05 * haste));
      game.aimBeamAt(up);
      at(0.8);
      expect(crab.cooldown, closeTo(c0 - 0.5 * haste - 0.3, 0.05 * haste));
    },
  );

  testWithGame<LighthouseGame>(
    'T8-05 터진 거품은 근처 다른 적을 맞히지 않는다',
    () => LighthouseGame(),
    (game) async {
      final horse = place(game, 'seahorse', 'I3');
      final squid = spawn(game, 'ink_squid', 90, distance: 400);
      final blob = spawn(game, 'shadow_blob', 90, distance: 405);
      final blobHp = blob.hp;

      game.update(0.05);
      expect(horse.target, same(squid));
      var guard = 0;
      while (game.bubbles.isEmpty && guard++ < 100) {
        game.update(0.05);
      }
      expect(game.bubbles, hasLength(1));
      squid.takeDamage(squid.hp);
      tickGame(game, 0.6);
      expect(game.bubbles, isEmpty);
      expect(blob.hp, blobHp);
    },
  );
}
