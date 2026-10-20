import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'config.dart';
import 'lighthouse_game.dart';

/// 판 전체(720 × 1280)를 덮는 보이지 않는 입력 층. 누르기와 끌기를 여기 한 곳에서 판정한다 (design.md §2).
///
/// - 손가락 하나만 따라간다 (누르고 있는 동안 다른 손가락은 무시)
/// - 누른 곳에서 [GameConfig.dragThreshold] 넘게 움직이면 그때부터 끌기: 움직일 때마다 빛을 손가락 쪽으로
/// - 떼는 순간 끌기가 아니었으면 누르기: 누른 곳으로 자리 고르기
class BoardInput extends PositionComponent with DragCallbacks, HasGameReference<LighthouseGame> {
  BoardInput() : super(size: Vector2(GameConfig.width, GameConfig.height));

  int? _pointerId;

  /// 누른 곳 (게임 좌표).
  Vector2 _start = Vector2.zero();

  /// 지금 손가락 위치 (캔버스 좌표). 끌기 이벤트의 이동량을 더해 따라간다.
  Vector2 _canvas = Vector2.zero();

  bool _dragging = false;

  Vector2 _toGame(Vector2 canvasPoint) => game.camera.globalToLocal(canvasPoint);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_pointerId != null) return;
    _pointerId = event.pointerId;
    _canvas = event.canvasPosition.clone();
    _start = _toGame(_canvas);
    _dragging = false;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (event.pointerId != _pointerId) return;
    _canvas += event.canvasDelta;
    final p = _toGame(_canvas);
    if (!_dragging && p.distanceTo(_start) > GameConfig.dragThreshold) {
      _dragging = true;
    }
    if (_dragging) game.aimBeamAt(p);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId != _pointerId) return;
    if (!_dragging) game.tapAt(_start);
    _pointerId = null;
    _dragging = false;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    // 취소는 누르기로 치지 않는다 (super가 onDragEnd를 부르기 전에 손가락을 놓는다)
    if (event.pointerId == _pointerId) {
      _pointerId = null;
      _dragging = false;
    }
    super.onDragCancel(event);
  }
}
