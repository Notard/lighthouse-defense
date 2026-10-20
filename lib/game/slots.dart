import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'config.dart';
import 'friend.dart';
import 'geometry.dart';

/// 자리가 놓인 고리.
enum SlotRing { inner, outer }

/// 등대 둘레의 자리 하나 (친구를 놓을 곳). 위치는 자리 가운데, 고르면 밝게 강조한다.
class Slot extends PositionComponent {
  Slot({required this.ring, required this.index, required this.angleDeg})
      : super(
          position: pointFromLighthouse(angleDeg, ring == SlotRing.inner ? GameConfig.innerRingRadius : GameConfig.outerRingRadius),
          size: Vector2.all(GameConfig.slotRadius * 2),
          anchor: Anchor.center,
        );

  final SlotRing ring;
  final int index;
  final double angleDeg;

  /// `I0`…`I5`, `O0`…`O11`.
  String get id => '${ring == SlotRing.inner ? 'I' : 'O'}$index';

  /// 지금 고른 자리인지 (LighthouseGame이 바꾼다).
  bool selected = false;

  /// 이 자리의 친구 (없으면 null, LighthouseGame.placeFriend가 놓는다).
  Friend? friend;

  /// 게임 좌표 [p]가 이 자리의 누르는 범위 안인지.
  bool touches(Vector2 p) => p.distanceTo(center) <= GameConfig.slotTouchRadius;

  // 안쪽은 따뜻한 빛, 바깥은 차가운 물빛으로 구분한다.
  static final _innerFill = Paint()..color = const Color(0x40FFD58A);
  static final _innerEdge = Paint()
    ..color = const Color(0xB0FFD58A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _outerFill = Paint()..color = const Color(0x307FC8E8);
  static final _outerEdge = Paint()
    ..color = const Color(0x907FC8E8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _selectedFill = Paint()..color = const Color(0x90FFF4C2);
  static final _selectedEdge = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final r = size.x / 2;
    if (selected) {
      canvas.drawCircle(c, r, _selectedFill);
      canvas.drawCircle(c, r, _selectedEdge);
    } else if (ring == SlotRing.inner) {
      canvas.drawCircle(c, r, _innerFill);
      canvas.drawCircle(c, r, _innerEdge);
    } else {
      canvas.drawCircle(c, r, _outerFill);
      canvas.drawCircle(c, r, _outerEdge);
    }
  }
}

/// 자리 18개: 안쪽 `I0`…`I5` 다음 바깥 `O0`…`O11` (design.md §2).
List<Slot> buildSlots() {
  const innerStep = 360 / GameConfig.innerSlotCount;
  const outerStep = 360 / GameConfig.outerSlotCount;
  const outerStart = GameConfig.innerRingStartAngle + GameConfig.outerRingOffsetDeg;
  return [
    for (var i = 0; i < GameConfig.innerSlotCount; i++)
      Slot(ring: SlotRing.inner, index: i, angleDeg: normalizeDeg(GameConfig.innerRingStartAngle + innerStep * i)),
    for (var i = 0; i < GameConfig.outerSlotCount; i++)
      Slot(ring: SlotRing.outer, index: i, angleDeg: normalizeDeg(outerStart + outerStep * i)),
  ];
}
