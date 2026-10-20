"""리그(부위 다각형·기준점)를 정할 때 보는 좌표 격자 그림을 만든다 (design.md §3).

    python tools/rig_helper.py <캐릭터>                      → 전체 격자 (100px 굵은 선, 50px 가는 선)
    python tools/rig_helper.py <캐릭터> 380 540 1010 720     → 그 영역 확대 (25px 선)

읽는 것  art/ref/<캐릭터>.png (크로마 초록 배경은 투명으로 바꿔 읽는다)
결과     art/parts/<캐릭터>/_grid*.jpg. 투명 배경은 밤바다 남색으로 칠해 경계가 잘 보이게 한다.
"""
import sys

from art_common import ROOT, load_rgba, setup_console, usage, wants_help

BACKDROP = (30, 50, 90, 255)  # 밤바다 남색 (게임 배경에 가까운 색에서 경계를 본다)


def load(name: str):
    from PIL import Image

    path = ROOT / "art" / "ref" / f"{name}.png"
    if not path.exists():
        sys.exit(f"기준 그림이 없습니다: {path.relative_to(ROOT).as_posix()} (python tools/gen_art.py ref {name})")
    im = load_rgba(path)
    bg = Image.new("RGBA", im.size, BACKDROP)
    bg.alpha_composite(im)
    return bg


def font(size: int):
    from PIL import ImageFont

    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def grid(img, box: tuple[int, int, int, int], scale: int, step: int, label: int):
    from PIL import Image, ImageDraw

    x0, y0, x1, y1 = box
    out = img.crop(box).resize(((x1 - x0) * scale, (y1 - y0) * scale), Image.NEAREST)
    d = ImageDraw.Draw(out)
    f = font(14 if scale > 1 else 22)
    for v in range((x0 // step + 1) * step, x1, step):
        x = (v - x0) * scale
        major = v % (step * 2 if step < 100 else 100) == 0
        d.line([(x, 0), (x, out.height)], fill=(255, 0, 0) if major else (255, 150, 150), width=2 if major else 1)
        if v % label == 0:
            d.text((x + 3, 3), str(v), fill=(255, 255, 0), font=f)
    for v in range((y0 // step + 1) * step, y1, step):
        y = (v - y0) * scale
        major = v % (step * 2 if step < 100 else 100) == 0
        d.line([(0, y), (out.width, y)], fill=(255, 0, 0) if major else (255, 150, 150), width=2 if major else 1)
        if v % label == 0:
            d.text((3, y + 3), str(v), fill=(255, 255, 0), font=f)
    return out


def main() -> None:
    setup_console()
    if wants_help(sys.argv):
        usage(__doc__)
    if len(sys.argv) not in (2, 6):
        usage(__doc__, 2)
    name = sys.argv[1]
    img = load(name)
    out_dir = ROOT / "art" / "parts" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) == 2:
        out = grid(img, (0, 0, *img.size), 1, 50, 100)
        path = out_dir / "_grid.jpg"
    else:
        box = tuple(int(v) for v in sys.argv[2:6])
        scale = max(1, min(4, 900 // max(box[2] - box[0], box[3] - box[1])))
        out = grid(img, box, scale, 25, 50)
        path = out_dir / f"_grid_{'_'.join(sys.argv[2:6])}.jpg"
    out.convert("RGB").save(path, quality=90)
    print(path.relative_to(ROOT).as_posix(), out.size)


if __name__ == "__main__":
    main()
