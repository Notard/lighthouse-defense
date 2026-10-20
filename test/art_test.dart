import 'dart:io';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/art.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/slots.dart';

import 'support.dart';

/// 3단계 그림 (docs/tests/03-art.md, T3-10~16).
void main() {
  test('T3-10 그림 파일 night_sea.webp·lighthouse.webp가 있고 pubspec assets에 assets/images/가 있다', () {
    expect(File('assets/images/night_sea.webp').existsSync(), isTrue, reason: 'assets/images/night_sea.webp');
    expect(File('assets/images/lighthouse.webp').existsSync(), isTrue, reason: 'assets/images/lighthouse.webp');
    final pubspec = File('pubspec.yaml').readAsLinesSync().where((l) => !l.trimLeft().startsWith('#')).join('\n');
    expect(RegExp(r'^\s*-\s*assets/images/\s*$', multiLine: true).hasMatch(pubspec), isTrue,
        reason: 'flutter assets에 - assets/images/');
  });

  GameTester(LighthouseGame.new).testGameWidget(
    'T3-11 바다 바탕은 (0, 0)에서 720 x 1280 크기이고 그림이 읽혀 있다',
    verify: (game, tester) async {
      final sea = game.world.children.whereType<SeaBackdrop>().single;
      await waitUntil(tester, () => sea.sprite != null);
      expect(sea.absoluteTopLeftPosition.x, closeTo(0, 0.5));
      expect(sea.absoluteTopLeftPosition.y, closeTo(0, 0.5));
      expect(sea.size.x, closeTo(720, 0.01));
      expect(sea.size.y, closeTo(1280, 0.01));
      expect(sea.sprite, isNotNull);
    },
  );

  GameTester(LighthouseGame.new).testGameWidget(
    'T3-12 등대는 가운데 (360, 660), 크기 200 x 200, 그림이 읽혀 있고 모든 자리보다 뒤에 그려진다',
    verify: (game, tester) async {
      final spot = game.world.children.whereType<LighthouseSpot>().single;
      await waitUntil(tester, () => spot.sprite != null);
      expect(GameConfig.lighthouseSize, 200);
      expect(spot.absoluteCenter.x, closeTo(360, 0.5));
      expect(spot.absoluteCenter.y, closeTo(660, 0.5));
      expect(spot.size.x, closeTo(200, 0.01));
      expect(spot.size.y, closeTo(200, 0.01));
      expect(spot.sprite, isNotNull);
      final order = game.world.children.toList();
      final spotAt = order.indexOf(spot);
      final slotAts = [for (final s in order.whereType<Slot>()) order.indexOf(s)];
      expect(slotAts, hasLength(18));
      for (final at in slotAts) {
        expect(spotAt, greaterThan(at), reason: '등대는 모든 자리보다 뒤(위)');
      }
    },
  );

  test('T3-13 SheetAction.fromJson은 frames·fps·loop·event를 그대로 읽는다', () {
    final a = SheetAction.fromJson({'frames': 8, 'fps': 10, 'loop': true, 'event': 3});
    expect(a.frames, 8);
    expect(a.fps, 10);
    expect(a.loop, isTrue);
    expect(a.event, 3);
  });

  test('T3-14 SheetAction.fromJson은 빠진 값을 fps 12, loop false, event null로 채운다', () {
    final a = SheetAction.fromJson({'frames': 6});
    expect(a.frames, 6);
    expect(a.fps, 12);
    expect(a.loop, isFalse);
    expect(a.event, isNull);
  });

  test('T3-15 frames가 없거나 정수가 아니면 FormatException', () {
    expect(() => SheetAction.fromJson({'fps': 12}), throwsFormatException);
    expect(() => SheetAction.fromJson({'frames': 'six'}), throwsFormatException);
  });

  GameTester(LighthouseGame.new).testGameWidget(
    'T3-16 없는 캐릭터 그림을 읽으면 실패하고 캐시에 남지 않는다',
    verify: (game, tester) async {
      CharacterArt.clearCache();
      Object? error;
      await tester.runAsync(() async {
        try {
          await CharacterArt.load(game, 'no_such_art');
        } catch (e) {
          error = e;
        }
      });
      expect(error, isNotNull, reason: '없는 그림을 읽으면 예외');
      expect(CharacterArt.isCached('no_such_art'), isFalse);
    },
  );
}
