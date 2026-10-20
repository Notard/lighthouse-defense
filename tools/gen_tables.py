"""숫자 표(data/tables/*.csv)를 읽어 lib/game/tables.g.dart를 만든다 (design.md §4 "숫자 표와 변환기").

    python tools/gen_tables.py            → lib/game/tables.g.dart 쓰기
    python tools/gen_tables.py --check    → 파일이 표와 같은지만 본다 (다르면 종료 코드 1)
    python tools/gen_tables.py --help

표 (리드 소유, 읽기만. 뜻은 data/tables/README.md)
  enemies.csv     id, hp, speed, bite, bite_interval, radius, xp   → Tables.enemies (Map<String, EnemyStats>)
  beam.csv        width_deg, length, slow, vulnerable, friend_haste (한 줄) → Tables.beam (BeamStats)
  lighthouse.csv  hp, spawn_distance (한 줄)                       → Tables.lighthouse (LighthouseStats)
  practice.csv    interval, max_alive (한 줄)                      → Tables.practice (PracticeStats)
  characters.csv  id, kind, name_ko, name_en, display_height       → Tables.characters (Map<String, CharacterStats>)
  friends.csv     id, attack, range, damage, interval, projectile_speed → Tables.friends (Map<String, FriendStats>)
  progression.csv xp_base, xp_step, shard_delay, shard_speed, absorb_distance (한 줄) → Tables.progression (ProgressionStats)
  cards.csv       id, kind, target, value, max_picks, weight, name_ko, name_en, desc_ko, desc_en
                                                                   → Tables.cards (Map<String, CardStats>)

- 숫자 열은 double, max_alive·max_picks만 int. 표에 열이 빠졌거나 숫자가 아니거나 비었거나 inf·nan이면
  어느 표·줄·열인지 알리고 멈춘다 (종료 코드 1). friends.csv의 attack이 shot·melee·burst가 아니거나
  cards.csv의 kind가 friend·upgrade·beam·lighthouse가 아니어도 멈춘다
- 줄 순서는 표 그대로 (Map도 그 순서)
- 글은 ASCII 밖 글자를 \\uXXXX로 적는다 (lib/ 문자열에 한글을 바로 쓰지 않는 규칙, test/font_test.dart T3-09)
- 만든 파일은 줄바꿈 LF. 비교(--check)는 줄바꿈(CRLF/LF)을 무시한다
"""
import csv
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLES = ROOT / "data" / "tables"
OUT = ROOT / "lib" / "game" / "tables.g.dart"

# (Dart 이름, CSV 열, 형) — 형: str · double · int
ENEMY = [("id", "id", "str"), ("hp", "hp", "double"), ("speed", "speed", "double"), ("bite", "bite", "double"),
         ("biteInterval", "bite_interval", "double"), ("radius", "radius", "double"), ("xp", "xp", "double")]
BEAM = [("widthDeg", "width_deg", "double"), ("length", "length", "double"), ("slow", "slow", "double"),
        ("vulnerable", "vulnerable", "double"), ("friendHaste", "friend_haste", "double")]
LIGHTHOUSE = [("hp", "hp", "double"), ("spawnDistance", "spawn_distance", "double")]
PRACTICE = [("interval", "interval", "double"), ("maxAlive", "max_alive", "int")]
CHARACTER = [("id", "id", "str"), ("kind", "kind", "str"), ("nameKo", "name_ko", "str"), ("nameEn", "name_en", "str"),
             ("displayHeight", "display_height", "double")]
PROGRESSION = [("xpBase", "xp_base", "double"), ("xpStep", "xp_step", "double"), ("shardDelay", "shard_delay", "double"),
               ("shardSpeed", "shard_speed", "double"), ("absorbDistance", "absorb_distance", "double")]
CARD = [("id", "id", "str"), ("kind", "kind", "str"), ("target", "target", "str"), ("value", "value", "double"),
        ("maxPicks", "max_picks", "int"), ("weight", "weight", "double"), ("nameKo", "name_ko", "str"),
        ("nameEn", "name_en", "str"), ("descKo", "desc_ko", "str"), ("descEn", "desc_en", "str")]
FRIEND = [("id", "id", "str"), ("attack", "attack", "str"), ("range", "range", "double"), ("damage", "damage", "double"),
          ("interval", "interval", "double"), ("projectileSpeed", "projectile_speed", "double")]

# (클래스, 필드, 설명)
CLASSES = [
    ("EnemyStats", ENEMY, "적 하나 (enemies.csv 한 줄). speed는 게임 px/초, bite_interval은 초, xp는 떨어뜨리는 빛 조각 값"),
    ("BeamStats", BEAM, "등대 빛 (beam.csv). slow는 빛 속 빠르기 배율, vulnerable은 빛 속 받는 피해 배율, "
                         "friend_haste는 빛 속 친구의 쉬는 시간이 흐르는 배율"),
    ("LighthouseStats", LIGHTHOUSE, "등대 (lighthouse.csv). hp는 처음 불빛, spawn_distance는 적이 나타나는 거리"),
    ("PracticeStats", PRACTICE, "연습 스폰 (practice.csv, 7단계 웨이브가 오면 없앤다)"),
    ("CharacterStats", CHARACTER, "캐릭터 (characters.csv 한 줄). display_height는 화면 키 (게임 px)"),
    ("FriendStats", FRIEND, "친구 하나 (friends.csv 한 줄). attack은 shot·melee·burst, range는 게임 px, interval은 초, "
                            "projectile_speed는 거품 빠르기 (게임 px/초, shot만)"),
    ("ProgressionStats", PROGRESSION, "레벨과 빛 조각 (progression.csv). 레벨 n에서 다음 레벨에 드는 양 = xp_base + xp_step × (n − 1), "
                                      "shard_delay는 초, shard_speed는 게임 px/초, absorb_distance는 게임 px"),
    ("CardStats", CARD, "레벨업 카드 하나 (cards.csv 한 줄). kind는 friend·upgrade·beam·lighthouse, max_picks 0은 제한 없음, "
                        "weight는 뽑힐 무게"),
]

DART_TYPE = {"str": "String", "double": "double", "int": "int"}


def read(name: str) -> list[dict[str, str]]:
    path = TABLES / name
    if not path.exists():
        sys.exit(f"표가 없습니다: data/tables/{name}")
    with path.open(encoding="utf-8-sig", newline="") as f:
        rows = [{(k or "").strip(): (v or "").strip() for k, v in r.items()} for r in csv.DictReader(f)]
    rows = [r for r in rows if any(r.values())]
    if not rows:
        sys.exit(f"data/tables/{name}에 줄이 없습니다")
    return rows


def dart_string(s: str) -> str:
    out = []
    for ch in s:
        cp = ord(ch)
        if ch in "'\\$":
            out.append("\\" + ch)
        elif 0x20 <= cp <= 0x7E:
            out.append(ch)
        elif cp <= 0xFFFF:
            out.append(f"\\u{cp:04X}")
        else:
            out.append(f"\\u{{{cp:X}}}")
    return "'" + "".join(out) + "'"


def value(table: str, line: int, row: dict, column: str, kind: str) -> str:
    if column not in row:
        sys.exit(f"data/tables/{table}: '{column}' 열이 없습니다")
    raw = row[column]
    if kind == "str":
        if not raw:
            sys.exit(f"data/tables/{table} {line}번째 줄: '{column}'이 비었습니다")
        return dart_string(raw)
    where = f"data/tables/{table} {line}번째 줄: '{column}'"
    if not raw:
        sys.exit(f"{where}이 비었습니다")
    try:
        if kind == "int":
            return str(int(raw))
        number = float(raw)
    except ValueError:
        sys.exit(f"{where} 값 {raw!r}이 {'정수' if kind == 'int' else '수'}가 아닙니다")
    if not math.isfinite(number):
        sys.exit(f"{where} 값 {raw!r}은 쓸 수 없습니다 (inf·nan)")
    return repr(number)


def construct(cls: str, fields: list, table: str, line: int, row: dict) -> str:
    args = ", ".join(f"{dart}: {value(table, line, row, column, kind)}" for dart, column, kind in fields)
    return f"{cls}({args})"


def single(cls: str, fields: list, table: str) -> str:
    rows = read(table)
    if len(rows) != 1:
        sys.exit(f"data/tables/{table}에는 줄이 하나여야 합니다 (지금 {len(rows)}줄)")
    return construct(cls, fields, table, 2, rows[0])


# 글 칸 중 정해진 값만 받는 칸: (표, 열) → 받는 값
CHOICES = {
    ("friends.csv", "attack"): ("shot", "melee", "burst"),
    ("cards.csv", "kind"): ("friend", "upgrade", "beam", "lighthouse"),
}


def keyed(cls: str, fields: list, table: str) -> list[str]:
    rows = read(table)
    seen = set()
    entries = []
    for i, row in enumerate(rows, start=2):
        for (t, column), allowed in CHOICES.items():
            if t == table and column in row and row[column] not in allowed:
                sys.exit(f"data/tables/{table} {i}번째 줄: '{column}' 값 {row[column]!r}은 {'·'.join(allowed)} 중 하나여야 합니다")
        key = row.get("id", "")
        if key in seen:
            sys.exit(f"data/tables/{table} {i}번째 줄: id '{key}'가 겹칩니다")
        seen.add(key)
        entries.append(f"    {dart_string(key)}: {construct(cls, fields, table, i, row)},")
    return entries


def render() -> str:
    lines = [
        "// 만든 파일, 고치지 말 것. data/tables/*.csv를 바꾸고 `python tools/gen_tables.py`로 다시 만든다.",
        "// (design.md §4 \"숫자 표와 변환기\". 뜻은 data/tables/README.md)",
        "",
    ]
    for cls, fields, doc in CLASSES:
        lines.append(f"/// {doc}.")
        lines.append(f"class {cls} {{")
        params = ", ".join(f"required this.{dart}" for dart, _, _ in fields)
        lines.append(f"  const {cls}({{{params}}});")
        lines.append("")
        for dart, column, kind in fields:
            lines.append(f"  /// `{column}`")
            lines.append(f"  final {DART_TYPE[kind]} {dart};")
        lines.append("}")
        lines.append("")
    lines.append("/// 숫자 표 전체.")
    lines.append("abstract final class Tables {")
    lines.append("  /// enemies.csv (id → 값, 표 순서).")
    lines.append("  static const Map<String, EnemyStats> enemies = {")
    lines += keyed("EnemyStats", ENEMY, "enemies.csv")
    lines.append("  };")
    lines.append("")
    lines.append("  /// beam.csv")
    lines.append(f"  static const BeamStats beam = {single('BeamStats', BEAM, 'beam.csv')};")
    lines.append("")
    lines.append("  /// lighthouse.csv")
    lines.append(f"  static const LighthouseStats lighthouse = {single('LighthouseStats', LIGHTHOUSE, 'lighthouse.csv')};")
    lines.append("")
    lines.append("  /// practice.csv")
    lines.append(f"  static const PracticeStats practice = {single('PracticeStats', PRACTICE, 'practice.csv')};")
    lines.append("")
    lines.append("  /// characters.csv (id → 값, 표 순서).")
    lines.append("  static const Map<String, CharacterStats> characters = {")
    lines += keyed("CharacterStats", CHARACTER, "characters.csv")
    lines.append("  };")
    lines.append("")
    lines.append("  /// friends.csv (id → 값, 표 순서).")
    lines.append("  static const Map<String, FriendStats> friends = {")
    lines += keyed("FriendStats", FRIEND, "friends.csv")
    lines.append("  };")
    lines.append("")
    lines.append("  /// progression.csv")
    lines.append(f"  static const ProgressionStats progression = {single('ProgressionStats', PROGRESSION, 'progression.csv')};")
    lines.append("")
    lines.append("  /// cards.csv (id → 값, 표 순서).")
    lines.append("  static const Map<String, CardStats> cards = {")
    lines += keyed("CardStats", CARD, "cards.csv")
    lines.append("  };")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> None:
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if "-h" in args or "--help" in args:
        print(__doc__.strip())
        return
    if args not in ([], ["--check"]):
        print(__doc__.strip())
        sys.exit(2)
    text = render()
    rel = OUT.relative_to(ROOT).as_posix()
    if args == ["--check"]:
        now = OUT.read_text(encoding="utf-8").replace("\r\n", "\n") if OUT.exists() else None
        if now != text:
            print(f"{rel}이 표와 다릅니다. python tools/gen_tables.py로 다시 만드세요")
            sys.exit(1)
        print(f"{rel}: 표와 같음")
        return
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"{rel} 만듦")


if __name__ == "__main__":
    main()
