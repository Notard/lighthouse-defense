"""캐릭터 기준 그림에 편 오라를 입혀 한 장에 모은다 (사용자 확인용, design.md §3-3 "편 오라").

    python tools/make_aura_sheet.py            → art/ref/_check/_aura_sheet.png
    python tools/make_aura_sheet.py --help

- 캐릭터·편(kind)·이름은 data/tables/characters.csv, 오라 색·넓이는 data/art/aura.json
- 그림: art/ref/<id>.png → 크로마 초록 빼기(load_rgba) → 청록 테두리 빛 걷기(strip_rim, 리그에 "strip_rim": true일 때만)
  → CELL px로 줄임 → 오라
- 오라 넓이·흐림은 256 px 프레임 기준이라 칸 크기에 맞춰 늘린다
- 밤바다 색 바탕에 친구 줄, 적 줄
"""
import json
import sys

from art_common import ROOT, add_aura, load_aura, load_characters, load_rgba, setup_console, strip_rim, usage, wants_help

CELL = 400  # 칸 한 변 (px)
LABEL = 40  # 이름 줄 높이 (px)
FRAME_PX = 256  # aura.json 넓이의 기준 프레임
NIGHT_SEA = (11, 26, 51)  # 게임 바탕색 (GameConfig.nightSea 0xFF0B1A33)
OUT = ROOT / "art" / "ref" / "_check" / "_aura_sheet.png"


def cell(cid: str, kind: str, name: str, aura: dict):
    from PIL import Image, ImageDraw, ImageFont

    im = load_rgba(ROOT / "art" / "ref" / f"{cid}.png")
    rig = ROOT / "tools" / "rigs" / f"{cid}.json"
    if rig.exists() and json.loads(rig.read_text(encoding="utf-8")).get("strip_rim") is True:
        im, _ = strip_rim(im)  # 시트(cut_parts.py)와 같은 규칙
    inner = round(CELL * 0.86)
    s = inner / max(im.size)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    pad = Image.new("RGBA", (CELL, CELL))
    pad.alpha_composite(im, ((CELL - im.width) // 2, (CELL - im.height) // 2))
    k = CELL / FRAME_PX
    glowing = add_aura(pad, aura[kind], aura["width"] * k, aura["blur"] * k, aura["strength"])
    out = Image.new("RGBA", (CELL, CELL + LABEL), NIGHT_SEA + (255,))
    out.alpha_composite(glowing)
    try:
        font = ImageFont.truetype("malgun.ttf", 24)
    except OSError:
        font = ImageFont.load_default()
    ImageDraw.Draw(out).text((12, CELL + 6), f"{name} ({cid}, {kind})", fill=(238, 243, 255, 255), font=font)
    return out


def main() -> None:
    setup_console()
    if wants_help(sys.argv):
        usage(__doc__)
    if len(sys.argv) != 1:
        usage(__doc__, 2)

    from PIL import Image

    characters = load_characters()
    if not characters:
        sys.exit("data/tables/characters.csv가 없습니다")
    aura = load_aura()
    rows = [[c for c, v in characters.items() if v["kind"] == kind] for kind in ("friend", "enemy")]
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGB", (CELL * cols, (CELL + LABEL) * len(rows)), NIGHT_SEA)
    for y, row in enumerate(rows):
        for x, cid in enumerate(row):
            v = characters[cid]
            sheet.paste(cell(cid, v["kind"], v["name_ko"], aura).convert("RGB"), (x * CELL, y * (CELL + LABEL)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"{OUT.relative_to(ROOT).as_posix()}  {sheet.size}  {OUT.stat().st_size / 1024:,.0f} KB")


if __name__ == "__main__":
    main()
