import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/geometry.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/slots.dart';

import 'support.dart';

/// 2단계: 등대 둘레 자리 18개, 누르기·끌기 (docs/tests/02-ring.md, T2-01~22).
void main() {
  final lighthouse = Vector2(GameConfig.lighthouseX, GameConfig.lighthouseY);

  Slot slotOf(LighthouseGame game, String id) => game.slots.firstWhere((s) => s.id == id);

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-01 자리는 18개: 안쪽 I0~I5, 바깥 O0~O11 순서',
    verify: (game, tester) async {
      expect(game.slots, hasLength(18));
      for (var i = 0; i < 6; i++) {
        final s = game.slots[i];
        expect(s.id, 'I$i');
        expect(s.ring, SlotRing.inner);
        expect(s.index, i);
      }
      for (var i = 0; i < 12; i++) {
        final s = game.slots[6 + i];
        expect(s.id, 'O$i');
        expect(s.ring, SlotRing.outer);
        expect(s.index, i);
      }
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-02 안쪽 자리 각도는 270, 330, 30, 90, 150, 210',
    verify: (game, tester) async {
      const expected = [270, 330, 30, 90, 150, 210];
      for (var i = 0; i < 6; i++) {
        expect(slotOf(game, 'I$i').angleDeg, closeTo(expected[i].toDouble(), 0.01), reason: 'I$i');
      }
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-03 바깥 자리 각도는 285, 315, 345, 15, 45, 75, 105, 135, 165, 195, 225, 255',
    verify: (game, tester) async {
      const expected = [285, 315, 345, 15, 45, 75, 105, 135, 165, 195, 225, 255];
      for (var i = 0; i < 12; i++) {
        expect(slotOf(game, 'O$i').angleDeg, closeTo(expected[i].toDouble(), 0.01), reason: 'O$i');
      }
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-04 자리 가운데: I0 (360, 510), I3 (360, 810), O0 (429.88, 399.20), O8 (99.20, 729.88)',
    verify: (game, tester) async {
      void check(String id, double x, double y) {
        final c = slotOf(game, id).center;
        expect(c.x, closeTo(x, 0.5), reason: '$id x');
        expect(c.y, closeTo(y, 0.5), reason: '$id y');
      }

      check('I0', 360, 510);
      check('I3', 360, 810);
      check('O0', 429.88, 399.20);
      check('O8', 99.20, 729.88);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-05 등대 가운데까지 거리: 안쪽 150, 바깥 270',
    verify: (game, tester) async {
      for (final s in game.slots) {
        final want = s.ring == SlotRing.inner ? 150.0 : 270.0;
        expect(s.center.distanceTo(lighthouse), closeTo(want, 0.5), reason: s.id);
      }
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-06 모든 자리의 원(반지름 44)이 화면 안',
    verify: (game, tester) async {
      for (final s in game.slots) {
        expect(s.center.x - 44, greaterThanOrEqualTo(0), reason: '${s.id} 왼쪽');
        expect(s.center.x + 44, lessThanOrEqualTo(720), reason: '${s.id} 오른쪽');
        expect(s.center.y - 44, greaterThanOrEqualTo(0), reason: '${s.id} 위');
        expect(s.center.y + 44, lessThanOrEqualTo(1280), reason: '${s.id} 아래');
      }
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-07 두 자리 사이 거리는 모두 88 이상',
    verify: (game, tester) async {
      final slots = game.slots;
      for (var i = 0; i < slots.length; i++) {
        for (var j = i + 1; j < slots.length; j++) {
          expect(
            slots[i].center.distanceTo(slots[j].center),
            greaterThanOrEqualTo(88),
            reason: '${slots[i].id} - ${slots[j].id}',
          );
        }
      }
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-08 새 판은 고른 자리가 없고 빛 방향은 270',
    verify: (game, tester) async {
      expect(game.selectedSlot, isNull);
      expect(game.beam.angleDeg, closeTo(270, 0.01));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-09 I0 가운데를 누르면 I0을 고른다',
    verify: (game, tester) async {
      await tapGame(tester, game, 360, 510);
      expect(game.selectedSlot?.id, 'I0');
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-10 고른 I0을 다시 누르면 고르기가 풀린다',
    verify: (game, tester) async {
      await tapGame(tester, game, 360, 510);
      expect(game.selectedSlot?.id, 'I0');
      await tapGame(tester, game, 360, 510);
      expect(game.selectedSlot, isNull);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-11 I2를 누르고 O5를 누르면 O5로 바뀐다',
    verify: (game, tester) async {
      final i2 = slotOf(game, 'I2').center;
      await tapGame(tester, game, i2.x, i2.y);
      expect(game.selectedSlot?.id, 'I2');
      await tapGame(tester, game, 429.88, 920.80);
      expect(game.selectedSlot?.id, 'O5');
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-12 I0을 고른 뒤 바다 (100, 1200)를 누르면 고르기가 풀린다',
    verify: (game, tester) async {
      await tapGame(tester, game, 360, 510);
      expect(game.selectedSlot?.id, 'I0');
      await tapGame(tester, game, 100, 1200);
      expect(game.selectedSlot, isNull);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-13 I0 가운데에서 오른쪽 30 px을 눌러도 I0을 고른다 (누르는 범위 48)',
    verify: (game, tester) async {
      await tapGame(tester, game, 390, 510);
      expect(game.selectedSlot?.id, 'I0');
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-14 어느 자리에서도 48 넘게 떨어진 (360, 450)을 누르면 고른 자리 없음',
    verify: (game, tester) async {
      await tapGame(tester, game, 360, 450);
      expect(game.selectedSlot, isNull);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-15 (360, 900)에서 (660, 660)으로 끌면 빛 방향 0',
    verify: (game, tester) async {
      await dragGame(tester, game, 360, 900, 660, 660);
      expect(game.beam.angleDeg, closeTo(0, 1));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-16 (360, 900)에서 (60, 660)으로 끌면 빛 방향 180',
    verify: (game, tester) async {
      await dragGame(tester, game, 360, 900, 60, 660);
      expect(game.beam.angleDeg, closeTo(180, 1));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-17 (60, 660)에서 (360, 1100)으로 끌면 빛 방향 90',
    verify: (game, tester) async {
      await dragGame(tester, game, 60, 660, 360, 1100);
      expect(game.beam.angleDeg, closeTo(90, 1));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-18 끄는 도중에도 빛이 따라가고, 더 끌어 떼면 마지막 방향 270',
    verify: (game, tester) async {
      final finger = await Finger.down(tester, game, 360, 900);
      await finger.moveTo(660, 660);
      // 아직 누른 채
      expect(game.beam.angleDeg, closeTo(0, 1));
      await finger.moveTo(360, 300);
      await finger.up();
      expect(game.beam.angleDeg, closeTo(270, 1));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-19 끝이 가운데 40 px 안인 (365, 660)이면 빛은 바뀌지 않고 0 그대로',
    verify: (game, tester) async {
      final finger = await Finger.down(tester, game, 660, 660);
      await finger.moveTo(500, 660);
      expect(game.beam.angleDeg, closeTo(0, 1));
      await finger.moveTo(365, 660);
      // 가운데 빈 곳에서는 바뀌지 않는다
      expect(game.beam.angleDeg, closeTo(0, 1));
      await finger.up();
      expect(game.beam.angleDeg, closeTo(0, 1));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-20 I0에서 시작해 (660, 660)으로 끌면 고르지 않고 빛 방향 0',
    verify: (game, tester) async {
      await dragGame(tester, game, 360, 510, 660, 660);
      expect(game.selectedSlot, isNull);
      expect(game.beam.angleDeg, closeTo(0, 1));
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T2-21 I3 가운데를 누르고 8 px 움직인 뒤 떼면 I3을 고르고 빛은 270 그대로',
    verify: (game, tester) async {
      final finger = await Finger.down(tester, game, 360, 810);
      await finger.moveTo(368, 810, steps: 1);
      await finger.up();
      expect(game.selectedSlot?.id, 'I3');
      expect(game.beam.angleDeg, closeTo(270, 1));
    },
  );

  test('T2-22 angleFromLighthouse는 (460,660)->0, (360,760)->90, (260,660)->180, (360,560)->270', () {
    expect(angleFromLighthouse(Vector2(460, 660)), closeTo(0, 0.01));
    expect(angleFromLighthouse(Vector2(360, 760)), closeTo(90, 0.01));
    expect(angleFromLighthouse(Vector2(260, 660)), closeTo(180, 0.01));
    expect(angleFromLighthouse(Vector2(360, 560)), closeTo(270, 0.01));
  });
}
