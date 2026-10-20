import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';

/// 게임 좌표(720 x 1280) -> 화면(테스트 화면) 좌표.
///
/// 고정 해상도 카메라는 화면에 맞춰 배율 min(w/720, h/1280)로 줄이고 가운데 정렬한다.
/// (800 x 600 화면이면 배율 600/1280, 왼쪽 여백 231.25)
Offset gameToScreen(FlameGame game, Vector2 p) {
  final screen = game.canvasSize;
  final scale = _min(screen.x / GameConfig.width, screen.y / GameConfig.height);
  final left = (screen.x - GameConfig.width * scale) / 2;
  final top = (screen.y - GameConfig.height * scale) / 2;
  return Offset(left + p.x * scale, top + p.y * scale);
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
