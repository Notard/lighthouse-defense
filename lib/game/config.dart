import 'dart:ui';

/// 화면과 판의 고정 값 (plan.md). 세로 9:16, 논리 해상도 720 × 1280.
abstract final class GameConfig {
  static const double width = 720;
  static const double height = 1280;

  /// 등대 가운데 (판 가운데보다 조금 아래: 위쪽에 웨이브·체력, 아래에 카드 자리를 둘 예정).
  static const double lighthouseX = width / 2;
  static const double lighthouseY = 660;

  /// 밤바다 색 (화면 밖 여백도 이 색).
  static const Color nightSea = Color(0xFF0B1A33);
  static const Color deepSea = Color(0xFF050D1F);

  // ---- 등대 둘레 자리 (design.md §2) ----

  /// 안쪽·바깥 고리의 등대 가운데에서 거리.
  static const double innerRingRadius = 150;
  static const double outerRingRadius = 270;

  /// 고리마다 자리 수.
  static const int innerSlotCount = 6;
  static const int outerSlotCount = 12;

  /// 안쪽 고리 첫 자리(I0) 각도 (위). 바깥 고리는 여기서 [outerRingOffsetDeg]만큼 엇갈린다.
  static const double innerRingStartAngle = 270;
  static const double outerRingOffsetDeg = 15;

  /// 자리 원 반지름(그리기)과 누르는 범위 반지름(손가락 여유).
  static const double slotRadius = 44;
  static const double slotTouchRadius = 48;

  // ---- 입력 ----

  /// 누른 곳에서 화면(논리) px로 이만큼 넘게 움직이면 끌기, 아니면 누르기 (게임 좌표가 아님).
  static const double dragThreshold = 12;

  /// 등대 가운데에서 이 거리 안에서 끌 때는 빛 방향을 바꾸지 않는다.
  static const double beamDeadZone = 40;

  // ---- 빛 (2단계는 모양만, 4단계에서 data/tables로 옮긴다) ----

  /// 처음 빛 방향 (위).
  static const double startBeamAngle = 270;

  /// 빛 부채꼴 폭(도)과 길이.
  static const double beamWidthDeg = 40;
  static const double beamLength = 640;
}
