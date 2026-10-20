"""주아(Jua) 원본(약 2 MB)에서 게임에 쓰는 글자만 남겨 assets/fonts/Jua.ttf로 저장한다 (design.md §3).

    pip install fonttools
    python tools/subset_font.py <원본 Jua-Regular.ttf 경로> [--all-hangul]
    python tools/subset_font.py --help

남기는 글자
  1. lib/ 아래 .dart 파일의 '작은따옴표'·"큰따옴표" 문자열에 쓰인 U+007E보다 큰 글자 전부
     (줄마다 `//` 뒤는 주석으로 보고 뺀다. test/font_test.dart T3-04와 같은 규칙)
  2. 영문·숫자·기본 기호 (U+0020~U+007E)
  3. 게임에 쓸 만한 몇몇 기호 (EXTRA_SYMBOLS 중 원본에 있는 것만)
  4. 캐릭터 이름 (data/tables/characters.csv의 name_ko·name_en). lib/game/tables.g.dart는 이름을 유니코드 이스케이프로
     적어 1번 규칙에 잡히지 않으므로 표에서 직접 읽는다
`--all-hangul`을 붙이면 한글 2,350자(KS X 1001 완성형)와 호환 자모(ㄱ~ㅣ)도 모두 남긴다 (파일이 커진다).

문구(lib/game/strings.dart)를 바꾸면 이 스크립트를 다시 돌린다. 빠뜨리면 test/font_test.dart T3-04가 실패한다.
원본 글꼴은 저장소에 넣지 않는다. 라이선스(OFL.txt)는 assets/fonts/OFL.txt에 함께 둔다.
  받는 곳: https://github.com/google/fonts/tree/main/ofl/jua  (Jua-Regular.ttf, OFL.txt)
"""
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts" / "Jua.ttf"

EXTRA_SYMBOLS = "·…—–‘’“”×÷←↑→↓★☆♥♡♪○●◎△▲▽▼□■※～！？"

# '작은따옴표' 또는 "큰따옴표" 문자열 (test/font_test.dart와 같은 규칙)
LITERAL = re.compile(r"'([^'\n]*)'|\"([^\"\n]*)\"")


def ks_x_1001_hangul() -> set[str]:
    chars = set()
    for cp in range(0xAC00, 0xD7A4):
        ch = chr(cp)
        try:
            ch.encode("euc_kr")
        except UnicodeEncodeError:
            continue
        chars.add(ch)
    return chars


def used_in_code() -> set[str]:
    chars = set()
    for path in (ROOT / "lib").rglob("*.dart"):
        # 줄마다 주석(// 뒤)을 빼고 문자열 안의 글자만 모은다.
        lines = path.read_text(encoding="utf-8").splitlines()
        text = "\n".join(re.sub(r"//.*", "", line, count=1) for line in lines)
        for literal in LITERAL.findall(text):
            for ch in "".join(literal):
                if ord(ch) > 0x7E:
                    chars.add(ch)
    return chars


def used_in_tables() -> set[str]:
    """캐릭터 이름 글자 (data/tables/characters.csv, 없으면 빈 모음)."""
    path = ROOT / "data" / "tables" / "characters.csv"
    if not path.exists():
        return set()
    with path.open(encoding="utf-8-sig", newline="") as f:
        names = "".join(r.get("name_ko", "") + r.get("name_en", "") for r in csv.DictReader(f))
    return {ch for ch in names if ord(ch) > 0x7E}


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    if "-h" in sys.argv or "--help" in sys.argv:
        print(__doc__)
        return
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    all_hangul = "--all-hangul" in sys.argv
    if len(args) != 1:
        print(__doc__)
        sys.exit(2)
    src = Path(args[0])
    if not src.exists():
        sys.exit(f"원본 글꼴이 없습니다: {src}")

    from fontTools import subset
    from fontTools.ttLib import TTFont

    hangul = ks_x_1001_hangul() if all_hangul else set()
    jamo = {chr(cp) for cp in range(0x3131, 0x3164)} if all_hangul else set()
    ascii_ = {chr(cp) for cp in range(0x20, 0x7F)}
    code = used_in_code() | used_in_tables()
    wanted = hangul | jamo | ascii_ | set(EXTRA_SYMBOLS) | code

    font = TTFont(src)
    cmap = font.getBestCmap()
    missing = sorted(ch for ch in wanted if ord(ch) not in cmap)
    missing_in_code = sorted(ch for ch in code if ord(ch) not in cmap)
    if missing_in_code:
        sys.exit(f"게임 코드에 쓰인 글자가 원본 글꼴에 없음: {''.join(missing_in_code)}")

    options = subset.Options()
    options.layout_features = ["*"]  # 커닝 등 배치 정보 유지
    options.name_IDs = ["*"]  # 글꼴 이름·저작권 표기 유지
    options.notdef_outline = True
    options.drop_tables += ["DSIG"]  # 고치면 서명이 무효가 되므로 뺀다
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[ord(ch) for ch in wanted if ord(ch) in cmap])
    subsetter.subset(font)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)

    out = TTFont(OUT)
    kept = len(out.getBestCmap())
    # 게임 테스트(test/font_test.dart)는 Windows 유니코드 BMP 표(3,1 format 4)를 읽는다
    if not any(t.platformID == 3 and t.platEncID == 1 and t.format == 4 for t in out["cmap"].tables):
        sys.exit("결과 글꼴에 cmap (3,1) format 4 표가 없습니다")
    print(f"원본 {src.stat().st_size / 1024:,.0f} KB → {OUT.relative_to(ROOT).as_posix()} {OUT.stat().st_size / 1024:,.0f} KB")
    extra = " · 한글 2,350자 전부" if all_hangul else ""
    print(f"글자 {len(cmap):,}개 → {kept:,}개 (코드에서 {len(code)}개{extra} · 원본에 없어 뺀 기호 {len(missing)}개: {''.join(missing)})")


if __name__ == "__main__":
    main()
