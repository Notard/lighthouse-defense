import 'dart:io';
import 'dart:typed_data';

import 'package:flame/text.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';
import 'package:lighthouse_defense/game/strings.dart';

/// 3단계: 주아 글꼴(쓰는 글자만)과 문구 틀 (docs/tests/03-font.md, T3-01~09).
void main() {
  // 글꼴 파일이 없어도 다른 테스트가 돌도록 쓸 때 읽는다.
  Set<int> covered() => _cmapCodePoints(ByteData.sublistView(File('assets/fonts/Jua.ttf').readAsBytesSync()));

  // '작은따옴표' 또는 "큰따옴표" 문자열 (tools/subset_font.py와 같은 규칙).
  final literal = RegExp(r"'([^'\n]*)'" '|' r'"([^"\n]*)"');

  /// lib/ 아래 .dart 파일마다 (경로, 주석을 뺀 코드).
  List<(String, String)> libCode() => [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            (
              f.path.replaceAll(r'\', '/'),
              f.readAsLinesSync().map((l) => l.replaceFirst(RegExp(r'//.*'), '')).join('\n'),
            ),
      ];

  test('T3-01 글꼴 파일·라이선스가 있고 pubspec에 family Jua로 등록되어 있다', () {
    expect(File('assets/fonts/Jua.ttf').existsSync(), isTrue, reason: 'assets/fonts/Jua.ttf');
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue, reason: 'assets/fonts/OFL.txt');
    final pubspec = File('pubspec.yaml').readAsLinesSync().where((l) => !l.trimLeft().startsWith('#')).join('\n');
    expect(RegExp(r'^\s*-\s*family:\s*Jua\s*$', multiLine: true).hasMatch(pubspec), isTrue, reason: 'family: Jua');
    expect(RegExp(r'^\s*-\s*asset:\s*assets/fonts/Jua\.ttf\s*$', multiLine: true).hasMatch(pubspec), isTrue,
        reason: 'asset: assets/fonts/Jua.ttf');
  });

  test('T3-02 글꼴에 영문·숫자·기본 기호(U+0020~U+007E, 백틱 빼고)가 모두 있다', () {
    final c = covered();
    final missing = [
      for (var cp = 0x20; cp <= 0x7E; cp++)
        if (cp != 0x60 && !c.contains(cp)) String.fromCharCode(cp),
    ];
    expect(missing, isEmpty);
  });

  test('T3-03 두 언어의 제목·부제 글자가 모두 글꼴에 있다', () {
    addTearDown(() => Strings.lang = Lang.ko);
    final c = covered();
    final texts = StringBuffer();
    for (final lang in [Lang.ko, Lang.en]) {
      Strings.lang = lang;
      texts
        ..write(Strings.title)
        ..write(Strings.subtitle);
    }
    expect(_missing(texts.toString(), c), isEmpty);
  });

  test('T3-04 lib/ 문자열에 쓰인 U+007E보다 큰 글자가 모두 글꼴에 있다', () {
    final c = covered();
    final problems = <String>[];
    for (final (path, code) in libCode()) {
      for (final m in literal.allMatches(code)) {
        final missing = _missing((m[1] ?? '') + (m[2] ?? ''), c);
        if (missing.isNotEmpty) problems.add('$path: "$missing" (문자열 ${m[0]})');
      }
    }
    expect(problems, isEmpty, reason: 'python tools/subset_font.py <원본 Jua-Regular.ttf>로 글꼴을 다시 만드세요');
  });

  test('T3-05 한국어 제목·부제', () {
    addTearDown(() => Strings.lang = Lang.ko);
    Strings.lang = Lang.ko;
    expect(Strings.title, '등대 지키기');
    expect(Strings.subtitle, '밤바다 등대를 지켜요');
  });

  test('T3-06 영어 제목·부제', () {
    addTearDown(() => Strings.lang = Lang.ko);
    Strings.lang = Lang.en;
    expect(Strings.title, 'Lighthouse Keepers');
    expect(Strings.subtitle, 'Keep the lighthouse shining');
  });

  GameTester(LighthouseGame.new).testGameWidget(
    'T3-07 제목 컴포넌트는 Strings.title을 GameConfig.fontFamily(Jua) 글꼴로 그린다',
    setUp: (game, tester) async {
      Strings.lang = Lang.ko;
    },
    verify: (game, tester) async {
      final title = game.world.children.whereType<TitleText>().single;
      expect(title.text, Strings.title);
      expect(title.text, '등대 지키기');
      final renderer = title.textRenderer;
      expect(renderer, isA<TextPaint>());
      expect((renderer as TextPaint).style.fontFamily, GameConfig.fontFamily);
      expect(renderer.style.fontFamily, 'Jua');
    },
  );

  test('T3-08 GameConfig.fontFamily는 Jua', () {
    expect(GameConfig.fontFamily, 'Jua');
  });

  test('T3-09 strings.dart 말고 lib/ 문자열에는 한글(가~힣)이 없다', () {
    final hangul = RegExp(r'[가-힣]');
    final problems = <String>[];
    for (final (path, code) in libCode()) {
      if (path.endsWith('/strings.dart')) continue;
      for (final m in literal.allMatches(code)) {
        final text = (m[1] ?? '') + (m[2] ?? '');
        if (hangul.hasMatch(text)) problems.add('$path: ${m[0]}');
      }
    }
    expect(problems, isEmpty, reason: '화면 글은 Strings에서만 쓴다');
  });
}

String _missing(String text, Set<int> covered) =>
    String.fromCharCodes(text.runes.where((cp) => cp > 0x7E && !covered.contains(cp)).toSet());

/// TrueType `cmap` 표의 format 4(유니코드 BMP) 부분에서 글자 목록을 읽는다.
Set<int> _cmapCodePoints(ByteData d) {
  final numTables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes([for (var j = 0; j < 4; j++) d.getUint8(rec + j)]);
    if (tag == 'cmap') cmap = d.getUint32(rec + 8);
  }
  if (cmap < 0) throw StateError('cmap 표가 없습니다');

  final subtables = d.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final platform = d.getUint16(cmap + 4 + i * 8);
    final encoding = d.getUint16(cmap + 6 + i * 8);
    final offset = cmap + d.getUint32(cmap + 8 + i * 8);
    if (platform == 3 && encoding == 1 && d.getUint16(offset) == 4) {
      return _format4(d, offset);
    }
  }
  throw StateError('Windows 유니코드 BMP(format 4) 표가 없습니다');
}

Set<int> _format4(ByteData d, int t) {
  final segCount = d.getUint16(t + 6) ~/ 2;
  final ends = t + 14;
  final starts = ends + segCount * 2 + 2;
  final deltas = starts + segCount * 2;
  final rangeOffsets = deltas + segCount * 2;
  final result = <int>{};
  for (var s = 0; s < segCount; s++) {
    final end = d.getUint16(ends + s * 2);
    final start = d.getUint16(starts + s * 2);
    final delta = d.getInt16(deltas + s * 2);
    final ro = d.getUint16(rangeOffsets + s * 2);
    for (var c = start; c <= end && c != 0xFFFF; c++) {
      int glyph;
      if (ro == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final at = rangeOffsets + s * 2 + ro + (c - start) * 2;
        final g = d.getUint16(at);
        glyph = g == 0 ? 0 : (g + delta) & 0xFFFF;
      }
      if (glyph != 0) result.add(c);
    }
  }
  return result;
}
