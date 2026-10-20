import 'dart:ui';

import 'package:flame/components.dart';

import 'config.dart';
import 'geometry.dart';

/// 등대 빛: 등대 가운데에서 [angleDeg] 쪽으로 뻗는 반투명 부채꼴 (2단계는 모양만).
class Beam extends PositionComponent {
  Beam() : super(position: lighthouseCenter());

  double _angleDeg = GameConfig.startBeamAngle;

  /// 빛 방향 (0 이상 360 미만, 0° 오른쪽·90° 아래).
  double get angleDeg => _angleDeg;
  set angleDeg(double value) => _angleDeg = normalizeDeg(value);

  static const _rect = Rect.fromLTRB(-GameConfig.beamLength, -GameConfig.beamLength, GameConfig.beamLength, GameConfig.beamLength);

  // 등대 쪽이 밝고 끝으로 갈수록 옅어지는 노란빛.
  static final _paint = Paint()
    ..shader = Gradient.radial(
      Offset.zero,
      GameConfig.beamLength,
      const [Color(0x99FFE9A0), Color(0x55FFE9A0), Color(0x00FFE9A0)],
      const [0, 0.6, 1],
    );

  @override
  void render(Canvas canvas) {
    final half = GameConfig.beamWidthDeg / 2;
    final path = Path()
      ..moveTo(0, 0)
      ..arcTo(_rect, degToRad(_angleDeg - half), degToRad(GameConfig.beamWidthDeg), false)
      ..close();
    canvas.drawPath(path, _paint);
  }
}
