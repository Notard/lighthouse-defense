import 'dart:ui';

/// 화면과 판의 고정 값 (plan.md). 세로 9:16, 논리 해상도 720 × 1280.
abstract final class GameConfig {
  static const double width = 720;
  static const double height = 1280;

  /// 등대 가운데 (판 가운데보다 조금 아래: 위쪽에 웨이브·체력, 아래에 카드 자리를 둘 예정).
  static const double lighthouseX = width / 2;
  static const double lighthouseY = 660;

  /// 등대 그림 한 변 (안쪽 자리 원과 겹치지 않음: 150 - 44 = 106 > 100).
  static const double lighthouseSize = 200;

  /// 밤바다 색 (화면 밖 여백도 이 색).
  static const Color nightSea = Color(0xFF0B1A33);
  static const Color deepSea = Color(0xFF050D1F);

  /// 글꼴 이름 (pubspec.yaml의 family, 주아. tools/subset_font.py로 쓰는 글자만 남긴다).
  static const String fontFamily = 'Jua';

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

  // ---- 빛 (폭·길이·효과는 숫자 표 data/tables/beam.csv → Tables.beam) ----

  /// 처음 빛 방향 (위).
  static const double startBeamAngle = 270;

  // ---- 적 (규칙 숫자는 data/tables/enemies.csv → Tables.enemies) ----

  /// 그림을 읽기 전 적을 그리는 임시 원 색 (보라).
  static const Color enemyPlaceholder = Color(0xFF8A5CD6);

  /// 피해를 받았을 때 밝게 번쩍이는 색과 시간 (초, 그동안 점점 옅어진다).
  static const Color enemyHitFlash = Color(0xCCFFFFFF);
  static const double enemyHitFlashSeconds = 0.3;

  // ---- 위쪽 표시 (design.md §4 등대 불빛) ----

  /// 불빛 막대 전체 (왼쪽 위 기준, 판 위쪽 100 px 안).
  static const double lightBarX = 60;
  static const double lightBarY = 36;
  static const double lightBarWidth = 600;
  static const double lightBarHeight = 28;

  /// 불빛 막대 색: 채운 쪽(따뜻한 노란빛), 빈 쪽, 테두리.
  static const Color lightBarFill = Color(0xFFFFD66B);
  static const Color lightBarEmpty = Color(0x66101C38);
  static const Color lightBarBorder = Color(0xCCFFF4DC);

  /// 꺼짐 문구 글자 크기와 색.
  static const double lightOutFontSize = 56;
  static const Color lightOutColor = Color(0xFFFFF4DC);
}
