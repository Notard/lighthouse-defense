"""캐릭터 시트의 동작을 이어 붙여 밤바다 바탕 GIF 한 장으로 만든다 (사용자 움직임 확인용, design.md §3-3).

    python tools/make_gifs.py <캐릭터> [<캐릭터> ...]   → preview/05_<캐릭터>.gif
    python tools/make_gifs.py --help

- 읽는 것: assets/images/<캐릭터>/<캐릭터>.json + <동작>.webp (tools/pack_sheets.py)
- 동작을 시트 JSON 순서대로 이어 붙인다. 반복 동작은 2바퀴, 한 번 동작은 끝 모습을 0.5초 더 보여 준다
- 칸 크기 SIZE px, 아래에 동작 이름. 프레임 시간은 동작의 fps대로 (GIF는 1/100초 단위라 반올림)
- 발 기준점(anchor)에 작은 표시를 그려 발이 흔들리지 않는지 볼 수 있게 한다
"""
import json
import sys

from art_common import ROOT, setup_console, usage, wants_help

SIZE = 256  # GIF 한 칸 (px)
LABEL = 28  # 아래 글씨 줄 높이 (px)
NIGHT_SEA = (11, 26, 51)  # 게임 바탕색 (GameConfig.nightSea 0xFF0B1A33)
LOOP_REPEAT = 2


def frames_of(name: str, action: str, meta: dict) -> list:
    from PIL import Image, ImageDraw

    sheet = Image.open(ROOT / "assets" / "images" / name / f"{action}.webp").convert("RGBA")
    w, h = meta["frame"]
    s = SIZE / max(w, h)
    ax, ay = meta["anchor"]
    out = []
    for i in range(meta["actions"][action]["frames"]):
        cell = Image.new("RGBA", (SIZE, SIZE + LABEL), NIGHT_SEA + (255,))
        frame = sheet.crop((i * w, 0, (i + 1) * w, h)).resize((round(w * s), round(h * s)), Image.LANCZOS)
        cell.alpha_composite(frame)
        d = ImageDraw.Draw(cell)
        x, y = ax * s, ay * s
        d.line([(x - 6, y), (x + 6, y)], fill=(255, 213, 138, 255), width=2)  # 발 기준점
        d.text((8, SIZE + 6), f"{action} {i + 1}/{meta['actions'][action]['frames']}", fill=(238, 243, 255, 255))
        out.append(cell.convert("RGB"))
    return out


def make(name: str) -> None:
    meta_path = ROOT / "assets" / "images" / name / f"{name}.json"
    if not meta_path.exists():
        sys.exit(f"시트가 없습니다: {meta_path.relative_to(ROOT).as_posix()} (bash tools/build_sprites.sh {name})")
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    images, durations = [], []
    for action, spec in meta["actions"].items():
        frames = frames_of(name, action, meta)
        ms = round(1000 / spec["fps"])
        if spec["loop"]:
            clip = frames * LOOP_REPEAT
        else:
            clip = frames + [frames[-1]] * round(spec["fps"] / 2)  # 끝 모습 0.5초
        images += clip
        durations += [ms] * len(clip)
    out = ROOT / "preview" / f"05_{name}.gif"
    out.parent.mkdir(exist_ok=True)
    images[0].save(out, save_all=True, append_images=images[1:], duration=durations, loop=0, optimize=True)
    print(f"{out.relative_to(ROOT).as_posix()}  프레임 {len(images)}장  {out.stat().st_size / 1024:,.0f} KB")


def main() -> None:
    setup_console()
    if wants_help(sys.argv):
        usage(__doc__)
    if len(sys.argv) < 2:
        usage(__doc__, 2)
    for name in sys.argv[1:]:
        make(name)


if __name__ == "__main__":
    main()
