import 'tables.g.dart';

/// 화면에 나오는 글 (design.md §3). 코드에 한글 글을 바로 쓰지 않고 여기서만 꺼내 쓴다.
///
/// 처음부터 두 언어. 기기 언어 따르기와 설정 창은 10단계.
/// 글을 바꾸거나 더하면 `python tools/subset_font.py <원본 Jua-Regular.ttf>`로 글꼴을 다시 만든다.
enum Lang { ko, en }

abstract final class Strings {
  /// 지금 언어 (기본 한국어).
  static Lang lang = Lang.ko;

  static String _pick(String ko, String en) => switch (lang) {
        Lang.ko => ko,
        Lang.en => en,
      };

  /// 게임 제목.
  static String get title => _pick('등대 지키기', 'Lighthouse Keepers');

  /// 제목 아래 한 줄.
  static String get subtitle => _pick('밤바다 등대를 지켜요', 'Keep the lighthouse shining');

  /// 등대 불빛이 꺼졌을 때 가운데 문구 (design.md §4).
  static String get lightOut => _pick('불빛이 꺼졌어요', 'The light went out');

  /// 캐릭터 이름 (characters.csv의 name_ko·name_en, 지금 언어).
  static String characterName(CharacterStats c) => _pick(c.nameKo, c.nameEn);

  /// 레벨업 카드 창 제목 (design.md §6).
  static String get levelUp => _pick('레벨 업!', 'Level up!');

  /// 카드 판 시작의 첫 친구 고르기 창 제목.
  static String get firstPick => _pick('첫 친구를 골라요', 'Pick your first friend');

  /// 놓기 상태의 안내 (판 가운데 위).
  static String get placeHint => _pick('친구를 놓을 자리를 눌러요', 'Tap a spot for your friend');

  /// 카드 이름·설명 (cards.csv의 name_ko·name_en, desc_ko·desc_en, 지금 언어).
  static String cardName(CardStats c) => _pick(c.nameKo, c.nameEn);
  static String cardDesc(CardStats c) => _pick(c.descKo, c.descEn);

  /// 조각 막대 옆 레벨 글자.
  static String level(int n) => 'Lv $n';
}
