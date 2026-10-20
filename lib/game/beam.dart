import 'dart:ui';

import 'package:flame/components.dart';

import 'config.dart';
import 'geometry.dart';
import 'tables.g.dart';

/// 등대 빛: 등대 가운데에서 [angleDeg] 쪽으로 뻗는 반투명 부채꼴. 폭·길이는 숫자 표(beam.csv) + 카드로 더한 값 (design.md §4·§6).
class Beam extends PositionComponent {
  Beam() : super(position: lighthouseCenter());

  /// 계산 오차 여유 (거리 px·각도 도 모두, design.md §4 "빛 속").
  ///
  /// 설계는 1e-6이지만 `Vector2`가 32비트 실수라 좌표 자체의 오차(판 안에서 1e-5 px 안팎)가
  /// 각도로 1e-6°를 넘는다 (등대에서 290° 거리 300인 점의 각도가 290 + 1.7e-6). 그래서 32비트 오차보다 넉넉한 1e-3.
  static const double _epsilon = 1e-3;

  double _angleDeg = GameConfig.startBeamAngle;

  /// 빛 방향 (0 이상 360 미만, 0° 오른쪽·90° 아래).
  double get angleDeg => _angleDeg;
  set angleDeg(double value) => _angleDeg = normalizeDeg(value);

  /// 카드(beam)로 더한 폭(도)과 길이 (처음 0).
  double widthBonus = 0;
  double lengthBonus = 0;

  /// 부채꼴 폭(도) = 표의 `width_deg` + 카드로 더한 값.
  double get widthDeg => Tables.beam.widthDeg + widthBonus;

  /// 부채꼴 길이 (게임 px) = 표의 `length` + 카드로 더한 값.
  double get length => Tables.beam.length + lengthBonus;

  /// 점 [p](`Vector2`, 게임 좌표)가 빛 속인지: 등대 가운데에서 거리 ≤ 길이이고,
  /// 각도 차이(360 둘레에서 짧은 쪽) ≤ 폭의 절반. 경계는 속.
  ///
  /// 설계의 이름 `beam.contains(p)`가 `Component.contains(Component)`(자식인지)와 겹쳐서 인자를 [Object]로 넓혔다.
  /// 컴포넌트를 주면 원래 뜻(자식인지)대로 답한다.
  @override
  bool contains(Object p) {
    if (p is Component) return super.contains(p);
    if (p is! Vector2) throw ArgumentError.value(p, 'p', 'Vector2 or Component');
    return _inBeam(p);
  }

  bool _inBeam(Vector2 p) {
    if (p.distanceTo(lighthouseCenter()) > length + _epsilon) return false;
    final diff = (angleFromLighthouse(p) - _angleDeg).abs() % 360;
    final shortest = diff > 180 ? 360 - diff : diff;
    return shortest <= widthDeg / 2 + _epsilon;
  }

  // 등대 쪽이 밝고 끝으로 갈수록 옅어지는 노란빛. 길이가 바뀔 때만 다시 만든다.
  double? _paintLength;
  Paint _paint = Paint();

  Paint _paintFor(double len) {
    if (_paintLength != len) {
      _paintLength = len;
      _paint = Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          len,
          const [Color(0x99FFE9A0), Color(0x55FFE9A0), Color(0x00FFE9A0)],
          const [0, 0.6, 1],
        );
    }
    return _paint;
  }

  @override
  void render(Canvas canvas) {
    final len = length;
    final half = widthDeg / 2;
    final path = Path()
      ..moveTo(0, 0)
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: len), degToRad(_angleDeg - half), degToRad(widthDeg), false)
      ..close();
    canvas.drawPath(path, _paintFor(len));
  }
}
