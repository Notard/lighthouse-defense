import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';

/// 게임 좌표(720 x 1280) -> 화면(테스트 화면) 좌표.
///
/// 고정 해상도 카메라는 화면에 맞춰 배율 min(w/720, h/1280)로 줄이고 가운데 정렬한다.
/// (800 x 600 화면이면 배율 600/1280, 왼쪽 여백 231.25)
Offset gameToScreen(FlameGame game, Vector2 p) {
  final screen = game.canvasSize;
  final scale = gameScale(game);
  final left = (screen.x - GameConfig.width * scale) / 2;
  final top = (screen.y - GameConfig.height * scale) / 2;
  return Offset(left + p.x * scale, top + p.y * scale);
}

/// 게임 좌표 1이 화면에서 차지하는 길이 (배율).
double gameScale(FlameGame game) {
  final screen = game.canvasSize;
  return _min(screen.x / GameConfig.width, screen.y / GameConfig.height);
}

double _min(double a, double b) => a < b ? a : b;

/// 게임 좌표 (x, y)를 눌렀다 뗀다 (떼는 순간 판정이므로 시간을 조금 흘린다).
Future<void> tapGame(WidgetTester tester, FlameGame game, double x, double y) async {
  await tester.tapAt(gameToScreen(game, Vector2(x, y)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

/// 누르고 있는 손가락 하나 (게임 좌표로 움직인다).
class Finger {
  Finger._(this._tester, this._game, this._gesture, this.position);

  final WidgetTester _tester;
  final FlameGame _game;
  final TestGesture _gesture;

  /// 지금 손가락 위치 (게임 좌표).
  Vector2 position;

  /// (x, y)에 손가락을 댄다.
  static Future<Finger> down(WidgetTester tester, FlameGame game, double x, double y) async {
    final g = await tester.startGesture(gameToScreen(game, Vector2(x, y)));
    await tester.pump();
    return Finger._(tester, game, g, Vector2(x, y));
  }

  /// 누른 채 (x, y)까지 [steps]번에 나눠 움직인다 (게임 좌표).
  Future<void> moveTo(double x, double y, {int steps = 8}) async {
    final from = position.clone();
    final to = Vector2(x, y);
    for (var i = 1; i <= steps; i++) {
      final p = from + (to - from) * (i / steps);
      await _gesture.moveTo(gameToScreen(_game, p));
      await _tester.pump(const Duration(milliseconds: 16));
    }
    position = to;
  }

  /// 누른 채 화면(논리) 좌표로 (dx, dy)만큼 한 번에 움직인다.
  Future<void> moveByScreen(double dx, double dy) async {
    final scale = gameScale(_game);
    final target = gameToScreen(_game, position) + Offset(dx, dy);
    await _gesture.moveTo(target);
    await _tester.pump(const Duration(milliseconds: 16));
    position = position + Vector2(dx / scale, dy / scale);
  }

  /// 손을 뗀다.
  Future<void> up() async {
    await _gesture.up();
    await _tester.pump(const Duration(milliseconds: 100));
    await _tester.pump(const Duration(milliseconds: 400));
  }
}

/// (fromX, fromY)에서 (toX, toY)로 끌고 뗀다.
Future<void> dragGame(
  WidgetTester tester,
  FlameGame game,
  double fromX,
  double fromY,
  double toX,
  double toY, {
  int steps = 8,
}) async {
  final f = await Finger.down(tester, game, fromX, fromY);
  await f.moveTo(toX, toY, steps: steps);
  await f.up();
}

/// [done]이 참이 될 때까지 실제 시간으로 기다린다 (그림 읽기·디코딩은 가짜 시계로는 안 끝난다).
Future<void> waitUntil(WidgetTester tester, bool Function() done, {Duration timeout = const Duration(seconds: 10)}) async {
  final end = DateTime.now().add(timeout);
  while (!done() && DateTime.now().isBefore(end)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// `data/tables/<file>`을 읽어 줄마다 {열 이름: 값} 으로 (git이 줄바꿈을 CRLF로 바꿔도 \r 은 버린다).
List<Map<String, String>> readCsv(String file) {
  final lines = File('data/tables/$file')
      .readAsStringSync()
      .replaceAll('\r', '')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final header = lines.first.split(',').map((s) => s.trim()).toList();
  return [
    for (final line in lines.skip(1))
      {
        for (final (i, cell) in line.split(',').indexed) header[i]: cell.trim(),
      },
  ];
}

/// 판 시간을 [seconds]초 흘린다: `update(0.05)`를 되풀이 (0.05초 단위로 반올림).
void tickGame(FlameGame game, double seconds) {
  final n = (seconds / 0.05).round();
  for (var i = 0; i < n; i++) {
    game.update(0.05);
  }
}
