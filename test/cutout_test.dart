import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/art.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';

/// 3단계 캐릭터 컷아웃 (docs/tests/03-cutout.md, T3-17~24).
void main() {
  const friends = ['seahorse', 'crab', 'pufferfish'];
  const enemies = ['shadow_blob', 'ink_squid', 'shadow_jelly'];
  const all = [...friends, ...enemies];

  /// 동작 기대값: frames, fps, loop, event (없으면 null). 설계 §3-3 표.
  const friendActions = <String, (int, num, bool, int?)>{
    'idle': (12, 12, true, null),
    'attack': (8, 12, false, 5),
    'hit': (4, 12, false, null),
    'death': (8, 10, false, null),
  };
  const enemyActions = <String, (int, num, bool, int?)>{
    'move': (12, 12, true, null),
    'attack': (6, 10, true, 3),
    'hit': (4, 12, false, null),
    'death': (8, 10, false, null),
  };
  Map<String, (int, num, bool, int?)> expectedActions(String id) => friends.contains(id) ? friendActions : enemyActions;

  Map<String, dynamic> sheet(String id) {
    final f = File('assets/images/$id/$id.json');
    expect(f.existsSync(), isTrue, reason: '${f.path}가 없다');
    return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  }

  List<num> nums(dynamic v) => (v as List).map((e) => e as num).toList();

  test('T3-17 여섯 캐릭터의 시트 JSON이 있고 pubspec assets에 폴더가 캐릭터마다 등록되어 있다', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync().where((l) => !l.trimLeft().startsWith('#')).join('\n');
    for (final id in all) {
      expect(File('assets/images/$id/$id.json').existsSync(), isTrue, reason: 'assets/images/$id/$id.json');
      expect(RegExp(r'^\s*-\s*assets/images/' + id + r'/\s*$', multiLine: true).hasMatch(pubspec), isTrue,
          reason: 'pubspec.yaml assets에 - assets/images/$id/');
    }
  });

  test('T3-18 동작 목록: 친구 idle·attack·hit·death, 적 move·attack·hit·death (더도 덜도 없음)', () {
    for (final id in all) {
      final actions = (sheet(id)['actions'] as Map<String, dynamic>).keys.toSet();
      expect(actions, expectedActions(id).keys.toSet(), reason: id);
    }
  });

  test('T3-19 동작마다 frames·fps·loop·event가 설계 표와 같다', () {
    for (final id in all) {
      final actions = sheet(id)['actions'] as Map<String, dynamic>;
      for (final e in expectedActions(id).entries) {
        final a = actions[e.key] as Map<String, dynamic>?;
        expect(a, isNotNull, reason: '$id ${e.key}');
        final (frames, fps, loop, event) = e.value;
        expect(a!['frames'], frames, reason: '$id ${e.key} frames');
        expect(a['fps'], fps, reason: '$id ${e.key} fps');
        expect(a['loop'], loop, reason: '$id ${e.key} loop');
        if (event == null) {
          expect(a['event'], isNull, reason: '$id ${e.key} event 없음');
          expect(a.containsKey('event'), isFalse, reason: '$id ${e.key} event 키 없음');
        } else {
          expect(a['event'], event, reason: '$id ${e.key} event');
        }
      }
    }
  });

  test('T3-20 동작 그림 크기: 너비 = frames x 프레임 너비, 높이 = 프레임 높이, 한 변 256 이하', () {
    for (final id in all) {
      final json = sheet(id);
      final frame = nums(json['frame']);
      expect(frame, hasLength(2), reason: '$id frame');
      expect(frame[0], lessThanOrEqualTo(256), reason: '$id 프레임 너비');
      expect(frame[1], lessThanOrEqualTo(256), reason: '$id 프레임 높이');
      final actions = json['actions'] as Map<String, dynamic>;
      for (final entry in actions.entries) {
        final file = File('assets/images/$id/${entry.key}.webp');
        expect(file.existsSync(), isTrue, reason: '${file.path}가 없다');
        final (w, h) = _webpSize(file.readAsBytesSync());
        final frames = (entry.value as Map<String, dynamic>)['frames'] as int;
        expect(w, frame[0] * frames, reason: '$id ${entry.key} 너비');
        expect(h, frame[1], reason: '$id ${entry.key} 높이');
      }
    }
  });

  GameTester(LighthouseGame.new).testGameWidget(
    'T3-21 CharacterArt.load 여섯 개가 모두 성공하고 동작마다 animation 프레임 수가 frames와 같다',
    verify: (game, tester) async {
      CharacterArt.clearCache();
      final failures = <String>[];
      await tester.runAsync(() async {
        for (final id in all) {
          try {
            final art = await CharacterArt.load(game, id);
            for (final e in expectedActions(id).entries) {
              final n = art.animation(e.key).frames.length;
              if (n != e.value.$1) failures.add('$id ${e.key}: 프레임 $n장 (기대 ${e.value.$1})');
            }
          } catch (e) {
            failures.add('$id: 읽기 실패 $e');
          }
        }
      });
      expect(failures, isEmpty);
    },
  );

  test('T3-22 발 기준점 anchor는 프레임 안, bbox 넓이 > 0, anchor.y는 bbox 위 끝보다 아래', () {
    for (final id in all) {
      final json = sheet(id);
      final frame = nums(json['frame']);
      final anchor = nums(json['anchor']);
      final bbox = nums(json['bbox']);
      expect(anchor, hasLength(2), reason: '$id anchor');
      expect(bbox, hasLength(4), reason: '$id bbox');
      expect(anchor[0], inInclusiveRange(0, frame[0]), reason: '$id anchor.x');
      expect(anchor[1], inInclusiveRange(0, frame[1]), reason: '$id anchor.y');
      expect((bbox[2] - bbox[0]) * (bbox[3] - bbox[1]), greaterThan(0), reason: '$id bbox 넓이');
      expect(anchor[1], greaterThan(bbox[1]), reason: '$id anchor.y가 bbox 위 끝보다 아래');
    }
  });

  test('T3-23 해마 시트에 muzzle이 있고 프레임 안', () {
    final json = sheet('seahorse');
    expect(json['muzzle'], isNotNull);
    final frame = nums(json['frame']);
    final muzzle = nums(json['muzzle']);
    expect(muzzle, hasLength(2));
    expect(muzzle[0], inInclusiveRange(0, frame[0]));
    expect(muzzle[1], inInclusiveRange(0, frame[1]));
  });

  test('T3-24 characters.csv: 여섯 id 한 줄씩, 칸 id,kind,name_ko,name_en,display_height', () {
    final lines = File('data/tables/characters.csv')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    expect(lines.first, 'id,kind,name_ko,name_en,display_height');
    final rows = lines.skip(1).map((l) => l.split(',')).toList();
    expect(rows, hasLength(6));
    expect(rows.map((r) => r[0]).toList()..sort(), ([...all]..sort()));
    for (final r in rows) {
      expect(r, hasLength(5), reason: r.join(','));
      final id = r[0];
      expect(r[1], friends.contains(id) ? 'friend' : 'enemy', reason: '$id kind');
      final h = double.parse(r[4]);
      expect(h, greaterThan(0), reason: '$id display_height');
      if (friends.contains(id)) expect(h, lessThan(88), reason: '$id display_height (친구는 88 미만)');
    }
    expect(rows.where((r) => r[1] == 'friend'), hasLength(3));
    expect(rows.where((r) => r[1] == 'enemy'), hasLength(3));
  });
}

/// WebP 파일의 (너비, 높이)를 RIFF 헤더(VP8 / VP8L / VP8X)에서 읽는다.
(int, int) _webpSize(Uint8List b) {
  String tag(int at) => String.fromCharCodes(b.sublist(at, at + 4));
  if (b.length < 30 || tag(0) != 'RIFF' || tag(8) != 'WEBP') throw StateError('WebP 파일이 아닙니다');
  switch (tag(12)) {
    case 'VP8 ':
      return ((b[26] | b[27] << 8) & 0x3FFF, (b[28] | b[29] << 8) & 0x3FFF);
    case 'VP8L':
      final bits = b[21] | b[22] << 8 | b[23] << 16 | b[24] << 24;
      return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    case 'VP8X':
      return ((b[24] | b[25] << 8 | b[26] << 16) + 1, (b[27] | b[28] << 8 | b[29] << 16) + 1);
  }
  throw StateError('알 수 없는 WebP 형식 ${tag(12)}');
}
