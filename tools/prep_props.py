"""배경·소품·효과 정지 그림을 게임용으로 정리해 assets/images/<이름>.webp로 저장한다 (design.md §3·§3-2).

    python tools/prep_props.py
    python tools/prep_props.py --help

data/art/prompts.json의 props를 하나씩 본다 (이름이 _로 시작하거나 app_icon이면 건너뜀).
- 보통: art/ref/props/<이름>.png (gen_art.py prop) → 크로마 초록 배경 지우기·알파 정리, 여백 자르기,
  size [w, h] 안에 맞춰 가운데 정렬. WebP 품질 90 (투명도는 무손실)
- opaque (배경처럼 꽉 찬 그림): 세로 9:16으로 가운데를 잘라 size [w, h]로 줄인다. WebP 품질 85
- from_part [캐릭터, 부위]: 원본 대신 컷아웃 조각 art/parts/<캐릭터>/<부위>.png를 쓴다 (build_sprites.sh를 먼저)
원본이 없는 것은 알려 주고 건너뛴다. 결과가 MAX_KB를 넘으면 품질을 낮춰 다시 저장하고, 그래도 넘으면 알린다.
"""
import sys

from art_common import ROOT, load_prompts, load_rgba, setup_console, usage, wants_help

OUT = ROOT / "assets" / "images"
PORTRAIT = 9 / 16  # 세로 판 (720 × 1280)
MAX_KB = {"night_sea": 500, "lighthouse": 150}  # 파일 크기 한도 (docs/acceptance/03-art.md A3-12)
MIN_QUALITY = 60


def save_webp(im, path, name: str, quality: int) -> int:
    """WebP로 저장한다. 한도(MAX_KB)를 넘으면 품질을 5씩 낮춰 다시. 마지막 품질을 돌려준다."""
    limit = MAX_KB.get(name)
    while True:
        im.save(path, "WEBP", quality=quality, method=6)
        if limit is None or path.stat().st_size <= limit * 1024 or quality <= MIN_QUALITY:
            break
        quality -= 5
    if limit is not None and path.stat().st_size > limit * 1024:
        print(f"알림: {path.name}이 {limit} KB를 넘습니다 (품질 {quality})")
    return quality


def fit(im, size: tuple[int, int]):
    from PIL import Image

    im = im.crop(im.getchannel("A").getbbox())
    w, h = size
    s = min(w / im.width, h / im.height)
    small = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(small, ((w - small.width) // 2, (h - small.height) // 2))
    return canvas


def crop_portrait(im):
    """세로 9:16이 되게 가운데를 자른다."""
    ratio = im.width / im.height
    if ratio > PORTRAIT:
        w = round(im.height * PORTRAIT)
        return im.crop(((im.width - w) // 2, 0, (im.width + w) // 2, im.height))
    h = round(im.width / PORTRAIT)
    return im.crop((0, (im.height - h) // 2, im.width, (im.height + h) // 2))


def main() -> None:
    setup_console()
    if wants_help(sys.argv):
        usage(__doc__)
    if len(sys.argv) != 1:
        usage(__doc__, 2)

    from PIL import Image

    props = load_prompts().get("props", {})
    todo = {k: v for k, v in props.items() if not k.startswith("_") and not v.get("app_icon")}
    if not todo:
        print("data/art/prompts.json에 정리할 props가 없습니다")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in todo.items():
        if "from_part" in spec:
            character, part = spec["from_part"]
            src = ROOT / "art" / "parts" / character / f"{part}.png"
            hint = f"bash tools/build_sprites.sh {character}"
        else:
            src = ROOT / "art" / "ref" / "props" / f"{name}.png"
            hint = f"python tools/gen_art.py prop {name}"
        if not src.exists():
            print(f"{name}: 원본 없음 ({hint})")
            continue
        path = OUT / f"{name}.webp"
        size = tuple(spec["size"])
        if spec.get("opaque"):
            im = crop_portrait(Image.open(src).convert("RGB")).resize(size, Image.LANCZOS)
            quality = save_webp(im, path, name, 85)
        else:
            quality = save_webp(fit(load_rgba(src), size), path, name, 90)
        print(f"{path.relative_to(ROOT).as_posix()}  {Image.open(path).size}  {path.stat().st_size / 1024:,.0f} KB (품질 {quality})")


if __name__ == "__main__":
    main()
