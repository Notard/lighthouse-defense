import 'dart:math' as math;

import 'package:flame/components.dart';

import 'config.dart';

/// 등대 가운데 (게임 좌표).
Vector2 lighthouseCenter() => Vector2(GameConfig.lighthouseX, GameConfig.lighthouseY);

/// 각도(도)를 0 이상 360 미만으로 맞춘다.
double normalizeDeg(double deg) {
  final a = deg % 360;
  // 아주 작은 음수는 % 뒤에 360.0으로 반올림될 수 있다
  return a >= 360 ? 0 : a;
}

double degToRad(double deg) => deg * math.pi / 180;

/// 등대 가운데에서 p 쪽 각도 (design.md §2: 0° 오른쪽, 90° 아래, 180° 왼쪽, 270° 위).
double angleFromLighthouse(Vector2 p) {
  final dx = p.x - GameConfig.lighthouseX;
  final dy = p.y - GameConfig.lighthouseY;
  return normalizeDeg(math.atan2(dy, dx) * 180 / math.pi);
}

/// 등대 가운데에서 [angleDeg] 쪽으로 [distance]만큼 떨어진 점.
Vector2 pointFromLighthouse(double angleDeg, double distance) {
  final r = degToRad(angleDeg);
  return Vector2(
    GameConfig.lighthouseX + distance * math.cos(r),
    GameConfig.lighthouseY + distance * math.sin(r),
  );
}
