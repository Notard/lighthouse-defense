"""숫자 표(data/tables/*.csv)를 읽어 lib/game/tables.g.dart를 만든다 (design.md §4 "숫자 표와 변환기").

    python tools/gen_tables.py            → lib/game/tables.g.dart 쓰기
    python tools/gen_tables.py --check    → 파일이 표와 같은지만 본다 (다르면 종료 코드 1)
    python tools/gen_tables.py --help

표 (리드 소유, 읽기만. 뜻은 data/tables/README.md)
  enemies.csv     id, hp, speed, bite, bite_interval, radius, xp, art, scale, boss
                                                                   → Tables.enemies (Map<String, EnemyStats>)
  beam.csv        width_deg, length, slow, vulnerable, friend_haste (한 줄) → Tables.beam (BeamStats)
  lighthouse.csv  hp, spawn_distance (한 줄)                       → Tables.lighthouse (LighthouseStats)
  practice.csv    interval, max_alive (한 줄)                      → Tables.practice (PracticeStats)
  characters.csv  id, kind, name_ko, name_en, display_height       → Tables.characters (Map<String, CharacterStats>)
  friends.csv     id, attack, range, damage, interval, projectile_speed → Tables.friends (Map<String, FriendStats>)
  progression.csv xp_base, xp_step, shard_delay, shard_speed, absorb_distance (한 줄) → Tables.progression (ProgressionStats)
  cards.csv       id, kind, target, value, max_picks, weight, name_ko, name_en, desc_ko, desc_en
                                                                   → Tables.cards (Map<String, CardStats>)
  waves.csv       wave, enemy, count, interval, delay (여러 줄)    → Tables.waves (List<WaveRow>, 표 순서)
  wave_rules.csv  first_delay, rest, banner_seconds (한 줄)        → Tables.waveRules (WaveRules)
  start.csv       free_friend (한 줄, 빈 칸이면 null)              → Tables.start (StartRules)

- 숫자 열은 double, max_alive·max_picks·wave·count는 int, enemies의 boss는 bool (0 / 1), start의 free_friend는
  String? (빈 칸이면 null).
  표에 열이 빠졌거나 숫자가 아니거나 비었거나 inf·nan이면 어느 표·줄·열인지 알리고 멈춘다 (종료 코드 1)
- 값 검사도 같이 (어기면 표·줄·칸을 짚어 종료 1): 정해진 값만 받는 칸(CHOICES: friends의 attack,
  cards의 kind), 수의 범위(RANGES: progression의 xp_base·shard_speed·absorb_distance > 0, xp_step ≥ 0,
  waves의 count ≥ 1·interval > 0·delay ≥ 0, enemies의 scale > 0), 다른 표를 가리키는 칸(REFERENCES:
  waves의 enemy는 enemies의 id, enemies의 art는 characters의 id, start의 free_friend는 (있으면) friends의 id)
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

# (Dart 이름, CSV 열, 형) — 형: str · str?(빈 칸이면 null) · double · int · bool(0 / 1)
ENEMY = [("id", "id", "str"), ("hp", "hp", "double"), ("speed", "speed", "double"), ("bite", "bite", "double"),
         ("biteInterval", "bite_interval", "double"), ("radius", "radius", "double"), ("xp", "xp", "double"),
         ("art", "art", "str"), ("scale", "scale", "double"), ("boss", "boss", "bool")]
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
WAVE = [("wave", "wave", "int"), ("enemy", "enemy", "str"), ("count", "count", "int"), ("interval", "interval", "double"),
        ("delay", "delay", "double")]
WAVE_RULES = [("firstDelay", "first_delay", "double"), ("rest", "rest", "double"),
              ("bannerSeconds", "banner_seconds", "double")]
START = [("freeFriend", "free_friend", "str?")]
FRIEND = [("id", "id", "str"), ("attack", "attack", "str"), ("range", "range", "double"), ("damage", "damage", "double"),
          ("interval", "interval", "double"), ("projectileSpeed", "projectile_speed", "double")]

# (클래스, 필드, 설명)
CLASSES = [
    ("EnemyStats", ENEMY, "적 하나 (enemies.csv 한 줄). speed는 게임 px/초, bite_interval은 초, xp는 떨어뜨리는 빛 조각 값, "
                          "art는 그림(characters의 id), scale은 그 그림 키에 곱하는 배율, boss는 보스인지"),
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
    ("WaveRow", WAVE, "웨이브 표 한 줄 (waves.csv). 웨이브 wave가 시작되고 delay + k × interval초에 k번째(0부터) enemy가 나온다 (count개)"),
    ("StartRules", START, "판 시작 (start.csv). free_friend는 카드 판이 첫 친구 창보다 먼저 공짜로 놓는 친구 (없으면 null)"),
    ("WaveRules", WAVE_RULES, "웨이브 규칙 (wave_rules.csv). first_delay는 첫 웨이브까지, rest는 깬 뒤 쉬는 시간, "
                              "banner_seconds는 알림이 떠 있는 시간 (모두 초)"),
]

DART_TYPE = {"str": "String", "str?": "String?", "double": "double", "int": "int", "bool": "bool"}


def read(name: str) -> list[dict[str, str]]:
    path = TABLES / name
    if not path.exists():
        sys.exit(f"표가 없습니다: data/tables/{name}")
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = [{(k or "").strip(): (v or "").strip() for k, v in r.items()} for r in reader]
        header = [(k or "").strip() for k in reader.fieldnames or []]
    rows = [r for r in rows if any(r.values())]
    if not rows and name in BLANK_ROW_OK and header:
        # 칸이 모두 빈 한 줄 표 (예: start.csv의 free_friend 빈 칸). CSV는 빈 줄을 건너뛰므로 머리줄만 있어도 받는다
        return [dict.fromkeys(header, "")]
    if not rows:
        sys.exit(f"data/tables/{name}에 줄이 없습니다")
    return rows


# 칸이 모두 비어도 되는 한 줄 표 (빈 칸 = 없음)
BLANK_ROW_OK = {"start.csv"}


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
    if kind == "str?":
        return dart_string(raw) if raw else "null"
    if kind == "str":
        if not raw:
            sys.exit(f"data/tables/{table} {line}번째 줄: '{column}'이 비었습니다")
        return dart_string(raw)
    where = f"data/tables/{table} {line}번째 줄: '{column}'"
    if not raw:
        sys.exit(f"{where}이 비었습니다")
    if kind == "bool":
        if raw not in ("0", "1"):
            sys.exit(f"{where} 값 {raw!r}은 0 또는 1이어야 합니다")
        return "true" if raw == "1" else "false"
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
    check(table, line, row)
    return f"{cls}({args})"


# 수의 범위: (표, 열) → (비교, 기준). gt는 기준보다 커야, ge는 기준 이상
RANGES = {
    ("progression.csv", "xp_base"): ("gt", 0),
    ("progression.csv", "xp_step"): ("ge", 0),
    ("progression.csv", "shard_speed"): ("gt", 0),
    ("progression.csv", "absorb_distance"): ("gt", 0),
    ("waves.csv", "count"): ("ge", 1),
    ("waves.csv", "interval"): ("gt", 0),
    ("waves.csv", "delay"): ("ge", 0),
    ("enemies.csv", "scale"): ("gt", 0),
}

# 다른 표를 가리키는 칸: (표, 열) → 가리키는 표 (그 표의 id 열에 있어야 한다)
REFERENCES = {
    ("waves.csv", "enemy"): "enemies.csv",
    ("enemies.csv", "art"): "characters.csv",
    ("start.csv", "free_friend"): "friends.csv",
}


def check(table: str, line: int, row: dict) -> None:
    """줄 하나의 값 검사 (CHOICES·RANGES·REFERENCES). 어기면 표·줄·칸을 짚어 종료 1."""
    where = lambda column: f"data/tables/{table} {line}번째 줄: '{column}' 값 {row[column]!r}"  # noqa: E731
    for (t, column), allowed in CHOICES.items():
        if t == table and column in row and row[column] not in allowed:
            sys.exit(f"{where(column)}은 {'·'.join(allowed)} 중 하나여야 합니다")
    for (t, column), (op, limit) in RANGES.items():
        if t == table and column in row:
            number = float(row[column])
            if op == "gt" and not number > limit:
                sys.exit(f"{where(column)}은 {limit}보다 커야 합니다")
            if op == "ge" and not number >= limit:
                sys.exit(f"{where(column)}은 {limit} 이상이어야 합니다")
    for (t, column), target in REFERENCES.items():
        # 빈 칸(없음을 뜻하는 String? 칸)은 가리키지 않는다
        if t == table and row.get(column) and row[column] not in {r.get("id") for r in read(target)}:
            sys.exit(f"{where(column)}이 data/tables/{target}의 id에 없습니다")


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
    lines.append("")
    lines.append("  /// waves.csv (표 순서).")
    lines.append("  static const List<WaveRow> waves = [")
    lines += [f"    {construct('WaveRow', WAVE, 'waves.csv', i, row)}," for i, row in enumerate(read("waves.csv"), start=2)]
    lines.append("  ];")
    lines.append("")
    lines.append("  /// wave_rules.csv")
    lines.append(f"  static const WaveRules waveRules = {single('WaveRules', WAVE_RULES, 'wave_rules.csv')};")
    lines.append("")
    lines.append("  /// start.csv")
    lines.append(f"  static const StartRules start = {single('StartRules', START, 'start.csv')};")
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
