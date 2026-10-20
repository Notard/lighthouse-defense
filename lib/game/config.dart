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
}
