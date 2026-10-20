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

  // ---- 웨이브·결과 (design.md §7) ----

  /// 제목 자리의 웨이브 글: "웨이브 3 / 10".
  static String wave(int n, int total) => _pick('웨이브 $n / $total', 'Wave $n / $total');

  /// 웨이브가 시작될 때 가운데 알림: "웨이브 3" (보스 웨이브는 [bossComing]).
  static String waveBanner(int n) => _pick('웨이브 $n', 'Wave $n');

  /// 보스가 있는 웨이브의 알림.
  static String get bossComing => _pick('보스가 와요!', 'A boss is coming!');

  /// 이겼을 때 결과 창 제목 (졌을 때는 [lightOut]).
  static String get dawn => _pick('새벽이 왔어요!', 'Dawn has come!');

  /// 결과 창의 다시 하기 단추.
  static String get restart => _pick('다시 하기', 'Play again');

  /// 결과 창 줄들: 다다른 웨이브, 쓰러뜨린 적 수, 레벨, 놀이 시간(m:ss).
  static String resultWave(int n, int total) => _pick('다다른 웨이브  $n / $total', 'Wave reached  $n / $total');
  static String resultDefeated(int n) => _pick('쓰러뜨린 적  $n', 'Enemies defeated  $n');
  static String resultLevel(int n) => _pick('레벨  $n', 'Level  $n');
  static String resultTime(double seconds) => _pick('시간  ${clock(seconds)}', 'Time  ${clock(seconds)}');

  /// 초를 m:ss로 (내림).
  static String clock(double seconds) {
    final total = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
