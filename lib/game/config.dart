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

  // ---- 프레임 시간 (design.md §5) ----

  /// 한 번 update가 흘리는 최대 시간 (초). 더 큰 dt(탭을 숨겼다 돌아옴 등)는 여기로 자르고 남는 시간은 버린다.
  static const double maxFrameDt = 0.1;

  // ---- 친구 (규칙 숫자는 data/tables/friends.csv → Tables.friends, design.md §5) ----

  /// 그림을 읽기 전 친구를 그리는 임시 원 색 (금빛).
  static const Color friendPlaceholder = Color(0xFFFFC85A);

  /// 거품 (해마의 탄): 반지름과 색 (작은 반투명 물방울).
  static const double bubbleRadius = 9;
  static const Color bubbleFill = Color(0x6699E6FF);
  static const Color bubbleEdge = Color(0xCCE8FBFF);

  /// 거품 테두리 굵기, 반짝이 점의 자리(가운데에서 왼쪽 위로, 반지름에 곱함)와 크기(반지름에 곱함).
  static const double bubbleEdgeWidth = 2;
  static const double bubbleShineOffset = 0.35;
  static const double bubbleShineSize = 0.25;

  /// 빛 속 친구의 금빛 (design.md §5-2, 그리기만). 빛줄기의 옅은 노란빛 위에서도 보이게, 진한 주황 금빛과 흰 금빛을 쓴다.
  /// 모두 숨쉬듯 밝아졌다 어두워진다: 한 바퀴(초)와 가장 어두울 때 세기(0~1).
  static const double beamGlowPeriod = 1.6;
  static const double beamGlowMinStrength = 0.7;

  /// 발밑 타원: 너비·높이, 색(가운데 → 가장자리).
  static const double beamGlowWidth = 92;
  static const double beamGlowHeight = 32;
  static const Color beamGlowInner = Color(0xD0FFB020);
  static const Color beamGlowOuter = Color(0x00FFB020);

  /// 몸 뒤 후광: 반지름, 색(가운데 → 가장자리).
  static const double beamHaloRadius = 60;
  static const Color beamHaloInner = Color(0xA0FFC640);
  static const Color beamHaloOuter = Color(0x00FFA020);

  /// 자리 원 둘레 고리: 반지름(자리 원과 같음), 선 굵기, 바깥 번짐 굵기·흐림, 색(선·번짐).
  static const double beamRingRadius = slotRadius;
  static const double beamRingWidth = 5;
  static const double beamRingGlowWidth = 10;
  static const double beamRingGlowBlur = 6;
  static const Color beamRingColor = Color(0xFFFFF0B0);
  static const Color beamRingGlowColor = Color(0xE0FFA818);

  /// 떠오르는 반짝이 (네 갈래 별): 개수, 한 번 떠오르는 높이(발에서 위로), 좌우로 퍼지는 폭,
  /// 별 끝까지 반지름, 허리 반지름(끝 반지름에 곱함), 테두리 굵기, 색(속·테두리).
  /// 한 바퀴(beamGlowPeriod) 동안 아래에서 위로 오르며 나타났다 사라지고, 개수만큼 시차를 두고 나온다.
  static const int beamSparkleCount = 4;
  static const double beamSparkleRise = 70;
  static const double beamSparkleSpread = 56;
  static const double beamSparkleSize = 7;
  static const double beamSparkleWaist = 0.25;
  static const double beamSparkleEdgeWidth = 1.5;
  static const Color beamSparkleColor = Color(0xFFFFFBE6);
  static const Color beamSparkleEdge = Color(0xFFFFA818);

  // ---- 친구 쟁반 (design.md §5, 판 아래쪽 y 1100~1260) ----

  /// 단추 셋을 가로로: 위쪽 y, 단추 크기, 단추 사이 간격 (가로 가운데 맞춤: x 104~616).
  /// 양옆은 비워 둔다: 왼쪽 아래 바다(예: (100, 1200), 테스트 T2-12)를 누르면 고르기를 푸는 2단계 규칙이 그대로 먹게.
  static const double trayY = 1100;
  static const double trayButtonWidth = 160;
  static const double trayButtonHeight = 160;
  static const double trayButtonGap = 16;

  /// 단추 모서리 반지름과 테두리 굵기 (보통·든 단추).
  static const double trayButtonCorner = 24;
  static const double trayButtonEdgeWidth = 2;
  static const double trayHeldEdgeWidth = 5;

  /// 단추 안 여백: 위에서 그림 머리까지, 아래에서 이름 글자 바닥까지.
  static const double trayArtTop = 16;
  static const double trayNameBottom = 12;

  /// 단추 안 친구 그림 키와 이름 글자 크기.
  static const double trayArtHeight = 80;
  static const double trayNameFontSize = 28;

  /// 단추 색: 바탕·테두리, 든 단추의 바탕·테두리, 이름 글자.
  static const Color trayButtonFill = Color(0x80142A52);
  static const Color trayButtonEdge = Color(0x907FC8E8);
  static const Color trayHeldFill = Color(0xB0FFE9A8);
  static const Color trayHeldEdge = Color(0xFFFFFFFF);
  static const Color trayNameColor = Color(0xFFFFF4DC);
  static const Color trayHeldNameColor = Color(0xFF142A52);

  // ---- 빛 조각 (design.md §6, 규칙 숫자는 data/tables/progression.csv → Tables.progression) ----

  /// 작은 노란 별빛: 별 끝 반지름, 허리 반지름(끝에 곱함), 둘레 번짐 반지름, 색(별·번짐), 반짝이는 한 바퀴(초).
  static const double shardSize = 9;
  static const double shardWaist = 0.35;
  static const double shardGlowRadius = 14;
  static const Color shardColor = Color(0xFFFFF2A8);
  static const Color shardGlow = Color(0x80FFD24A);
  static const double shardTwinklePeriod = 0.5;

  /// 반짝일 때 별이 작아지는 정도 (0~1, 가장 작을 때 크기 = 1 − 이 값).
  static const double shardTwinkleDepth = 0.3;

  // ---- 카드 창 (design.md §6) ----

  /// 창에 보이는 카드 수 (고를 수 있는 카드가 적으면 그만큼).
  static const int cardChoiceCount = 3;

  /// 판을 어둡게 덮는 색.
  static const Color cardDim = Color(0xB0050D1F);

  /// 창 제목: 가운데 y, 글자 크기, 색.
  static const double cardTitleY = 260;
  static const double cardTitleFontSize = 56;
  static const Color cardTitleColor = Color(0xFFFFE9A8);

  /// 카드 (세로로 쌓음): 첫 카드 위쪽 y, 카드 크기, 카드 사이 간격 (가로 가운데 맞춤).
  static const double cardTop = 340;
  static const double cardWidth = 600;
  static const double cardHeight = 190;
  static const double cardGap = 28;

  /// 카드 모양: 모서리 반지름, 테두리 굵기, 바탕 색.
  static const double cardCorner = 26;
  static const double cardEdgeWidth = 5;
  static const Color cardFill = Color(0xF0142A52);

  /// 카드 안: 여백, 왼쪽 그림 칸 너비, 그림 키, 이름·설명 글자 크기, 이름과 설명 사이, 글 색.
  static const double cardPadding = 22;
  static const double cardArtBox = 140;
  static const double cardArtHeight = 120;
  static const double cardNameFontSize = 38;
  static const double cardDescFontSize = 26;
  static const double cardLineGap = 10;
  static const Color cardNameColor = Color(0xFFFFF4DC);
  static const Color cardDescColor = Color(0xFFD8E6F5);

  /// 종류별 테두리·그림 색: friend 금빛, upgrade 주황, beam 연노랑, lighthouse 따뜻한 빨강.
  static const Color cardFriendColor = Color(0xFFFFC85A);
  static const Color cardUpgradeColor = Color(0xFFFF8A3D);
  static const Color cardBeamColor = Color(0xFFFFF0A0);
  static const Color cardLighthouseColor = Color(0xFFFF6B6B);

  /// 그림 없는 카드(빛·등대)의 그림 칸 표시: 부채꼴 반지름·폭(도), 등대 불빛 원 반지름.
  static const double cardIconRadius = 56;
  static const double cardIconFanDeg = 50;
  static const double cardIconGlowRadius = 40;

  /// 업그레이드 카드 그림 위 "+" 표시 크기와 굵기.
  static const double cardPlusSize = 22;
  static const double cardPlusWidth = 7;

  // ---- 놓기 안내 (design.md §6) ----

  /// 판 가운데 위 안내 글: 가운데 y, 글자 크기, 색.
  static const double placeHintY = 230;
  static const double placeHintFontSize = 40;
  static const Color placeHintColor = Color(0xFFFFE9A8);

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

  /// 불빛 막대·조각 막대 테두리 굵기.
  static const double barBorderWidth = 2;

  /// 조각 막대 (불빛 막대 아래, 판 위쪽 130 px 안): 막대 전체(왼쪽 위 기준), 옆 레벨 글자 크기.
  static const double xpBarX = 60;
  static const double xpBarY = 76;
  static const double xpBarWidth = 500;
  static const double xpBarHeight = 18;
  static const double xpLevelFontSize = 30;

  /// 조각 막대 색: 채운 쪽(맑은 하늘빛), 빈 쪽, 테두리, 레벨 글자.
  static const Color xpBarFill = Color(0xFF8FE3FF);
  static const Color xpBarEmpty = Color(0x66101C38);
  static const Color xpBarBorder = Color(0xCCFFF4DC);
  static const Color xpLevelColor = Color(0xFFFFF4DC);

  /// 꺼짐 문구 글자 크기와 색.
  static const double lightOutFontSize = 56;
  static const Color lightOutColor = Color(0xFFFFF4DC);
}
