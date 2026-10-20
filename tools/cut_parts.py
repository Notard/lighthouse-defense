"""기준 그림을 리그 파일(tools/rigs/<캐릭터>.json)대로 부위 조각으로 자른다 (2D 컷아웃, design.md §3).

    python tools/cut_parts.py <캐릭터>

리그 파일 (tools/rigs/<캐릭터>.json)
  ref      기준 그림 경로 (예: art/ref/<캐릭터>.png). 크로마 초록 배경은 투명으로 바꿔 읽는다
  parts    앞 → 뒤 순서의 부위 목록. 부위마다
           name, parent(없으면 null), pivot [x, y], polygon [[x, y], …], fill_band(선택), color_key(선택)
  variants (선택) 부위 조각 위에 선을 그려 바꿔 끼울 그림 (예: 금 간 몸통)
           {"name": "body_cracked", "base": "body", "lines": [[[x, y], …], …], "width": 10, "color": "#1B2340"}
  canvas, actions …  Blender 렌더·시트 묶기에서 쓴다 (tools/blender_cutout.py, tools/pack_sheets.py)
  좌표는 모두 기준 그림 픽셀 기준

결과
  art/parts/<캐릭터>/<부위>.png   부위 조각 (여백을 잘라낸 크기)
  art/parts/<캐릭터>/rig.json     조각 위치·기준점·부모·그리는 순서 (Blender 스크립트가 읽음)
  art/parts/<캐릭터>/_overlay.png 부위별 색칠 확인 그림
  art/parts/<캐릭터>/_rebuild.png 조각을 다시 합친 그림 — 기준 그림과 같아야 한다

규칙
  - 알파 정리: 16 미만 → 0, 200 이상 → 255
  - 픽셀은 그 위치를 다각형에 포함하는 가장 앞 부위가 가진다
  - color_key "warm": 다각형 안에서 채도 높은 주황·노랑 픽셀(불빛·등불) + 그 테두리 안쪽(밝은 속)만 그 부위로 본다.
    밝은 빛의 속은 흰색·크림색 부위와 색이 거의 같아서 색만으로는 못 나눈다
  - 다각형 경계에서 떨어져 나온 작은 섬(부위 픽셀의 2% 미만)은 가장 많이 맞닿은 부위에 넘긴다
  - 뒤 부위는 앞 부위에 가려진 곳을 fill_band 너비까지, 가려진 곳 바로 옆 그 부위 색(외곽선 뺀 중앙값)으로 채운다.
    단 캐릭터 전체 실루엣의 바깥 테두리에서 INSET px 안쪽만 채운다.
    움직일 때 틈으로 살짝 보이는 곳이라 무늬를 흉내 내는 것보다 깨끗한 단색이 낫다
"""
import json
import sys

from art_common import ROOT, load_rgba, setup_console, strip_rim, usage, wants_help

INSET = 30  # 채움이 전체 실루엣 바깥 테두리에서 떨어져야 하는 거리 (px)
COLORS = [(255, 80, 80), (80, 200, 255), (120, 220, 90), (255, 200, 60), (200, 120, 255), (255, 140, 200)]
OUTLINE = "#1B2340"  # 변형 선의 기본색 = 그림체 외곽선 (진한 남색, data/art/prompts.json style)


def polygon_mask(size, polygon):
    import numpy as np
    from PIL import Image, ImageDraw

    img = Image.new("L", size, 0)
    ImageDraw.Draw(img).polygon([tuple(p) for p in polygon], fill=255)
    return np.array(img) > 0


def warm_key(rgb, region):
    import cv2
    import numpy as np

    hsv = cv2.cvtColor(np.ascontiguousarray(rgb), cv2.COLOR_RGB2HSV)
    ring = region & (hsv[..., 1] > 80) & (hsv[..., 2] > 110) & (hsv[..., 0] <= 35)
    contours, _ = cv2.findContours(ring.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    filled = np.zeros(ring.shape, np.uint8)
    cv2.drawContours(filled, contours, -1, 1, thickness=cv2.FILLED)
    return filled > 0


def reassign_islands(owner, count: int) -> int:
    """부위마다 작은 섬을 떼어 가장 많이 맞닿은 다른 부위에 준다. 옮긴 픽셀 수를 돌려준다."""
    import cv2
    import numpy as np

    moved = 0
    kernel = np.ones((3, 3), np.uint8)
    for i in range(count):
        mask = (owner == i).astype(np.uint8)
        n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
        if n <= 2:
            continue
        limit = 0.02 * mask.sum()
        for k in range(1, n):
            if stats[k, cv2.CC_STAT_AREA] >= limit:
                continue
            island = labels == k
            ring = (cv2.dilate(island.astype(np.uint8), kernel) > 0) & ~island
            neighbours = owner[ring]
            neighbours = neighbours[(neighbours >= 0) & (neighbours != i)]
            if neighbours.size:
                owner[island] = np.bincount(neighbours).argmax()
                moved += int(island.sum())
    return moved


def main() -> None:
    setup_console()
    if wants_help(sys.argv):
        usage(__doc__)
    if len(sys.argv) != 2:
        usage(__doc__, 2)
    name = sys.argv[1]
    rig_path = ROOT / "tools" / "rigs" / f"{name}.json"
    if not rig_path.exists():
        sys.exit(f"리그 파일이 없습니다: {rig_path.relative_to(ROOT).as_posix()}")

    import cv2
    import numpy as np
    from PIL import Image, ImageColor, ImageDraw

    rig = json.loads(rig_path.read_text(encoding="utf-8"))
    src = load_rgba(ROOT / rig["ref"])
    # 그림체 기준(해마)에서 옮겨 온 청록 테두리 빛은 걷는다. 편 오라는 pack_sheets.py가 굽는다 (design.md §3-3)
    src, rim = strip_rim(src)
    if rim:
        print(f"청록 테두리 빛 걷음: {rim:,} 픽셀")
    rgba = np.array(src)
    alpha = rgba[..., 3]
    rgb = rgba[..., :3]
    size = src.size
    solid = alpha > 0

    # 1) 각 픽셀의 주인 부위 정하기 (앞 부위 우선)
    owner = np.full(alpha.shape, -1, dtype=int)
    polys = []
    for i, part in enumerate(rig["parts"]):
        poly = polygon_mask(size, part["polygon"])
        polys.append(poly)
        mine = poly & solid & (owner < 0)
        if part.get("color_key") == "warm":
            mine &= warm_key(rgb, poly)
        owner[mine] = i
    moved = reassign_islands(owner, len(rig["parts"]))
    orphan = solid & (owner < 0)

    out_dir = ROOT / "art" / "parts" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    rebuild = Image.new("RGBA", size, (0, 0, 0, 0))
    overlay = np.zeros_like(rgba)
    meta = {"character": name, "ref_size": list(size), "parts": []}

    # 2) 부위 조각 만들기. 그리는 순서는 뒤 → 앞이므로 거꾸로 돈다.
    inset = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * INSET + 1, 2 * INSET + 1))
    inner = cv2.erode(solid.astype(np.uint8), inset) > 0
    for i in reversed(range(len(rig["parts"]))):
        part = rig["parts"][i]
        own = owner == i
        piece = np.zeros_like(rgba)
        piece[own] = rgba[own]

        band = part.get("fill_band", 0)
        if band:
            # 앞 부위에 가려진 곳 중 내 영역 가장자리에서 band 안쪽만 채운다
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * band + 1, 2 * band + 1))
            grown = cv2.dilate(own.astype(np.uint8), kernel) > 0
            # 바깥 테두리 근처까지 채우면 움직일 때 테두리 없는 띠가 바깥으로 삐져나온다. 실루엣을 INSET px 줄인 안쪽만.
            hidden = grown & inner & polys[i] & solid & (owner >= 0) & (owner < i)
            if hidden.any():
                # 채움 색은 가려진 곳 바로 옆 내 색 (어두운 외곽선 제외)
                near = cv2.dilate(hidden.astype(np.uint8), kernel) > 0
                fill = rgba[own & near & (alpha == 255)][:, :3]
                fill = fill[fill.astype(int).sum(axis=1) > 3 * 110]
                if len(fill) < 50:
                    fill = rgba[own & (alpha == 255)][:, :3]
                piece[hidden, :3] = np.median(fill, axis=0).astype(np.uint8)
                piece[hidden, 3] = 255

        ys, xs = np.nonzero(piece[..., 3])
        if len(xs) == 0:
            sys.exit(f"부위 '{part['name']}'에 픽셀이 없습니다 (다각형 확인: python tools/rig_helper.py {name})")
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        Image.fromarray(piece[y0:y1, x0:x1]).save(out_dir / f"{part['name']}.png")
        meta["parts"].insert(0, {
            "name": part["name"],
            "parent": part["parent"],
            "pivot": part["pivot"],
            "offset": [int(x0), int(y0)],
            "size": [int(x1 - x0), int(y1 - y0)],
            "z": len(rig["parts"]) - 1 - i,
            "pixels": int(own.sum()),
            "filled": int((piece[..., 3] > 0).sum() - own.sum()),
        })
        rebuild.alpha_composite(Image.fromarray(piece))
        overlay[own, :3] = COLORS[i % len(COLORS)]
        overlay[own, 3] = 255

    for var in rig.get("variants", []):
        base = next(p for p in meta["parts"] if p["name"] == var["base"])
        img = Image.open(out_dir / f"{var['base']}.png").convert("RGBA")
        d = ImageDraw.Draw(img)
        ox, oy = base["offset"]
        w = var.get("width", 10)
        color = ImageColor.getrgb(var.get("color", OUTLINE)) + (255,)
        for line in var["lines"]:
            pts = [(x - ox, y - oy) for x, y in line]
            d.line(pts, fill=color, width=w, joint="curve")  # 외곽선과 같은 색
            d.line([(x + w // 3, y + w // 3) for x, y in pts], fill=(255, 255, 255, 70), width=max(2, w // 3), joint="curve")  # 아래쪽 밝은 결
        img.save(out_dir / f"{var['name']}.png")
        meta.setdefault("variants", []).append({"name": var["name"], "base": var["base"]})
        print(f"변형 {var['name']} ← {var['base']} (선 {len(var['lines'])}개)")

    (out_dir / "rig.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    # 3) 확인 그림: 원본 위에 부위 색 + 기준점
    over = Image.alpha_composite(src.copy(), Image.fromarray(overlay).point(lambda v: v * 0.55 if v else 0))
    d = ImageDraw.Draw(over)
    for part in rig["parts"]:
        x, y = part["pivot"]
        d.ellipse([x - 12, y - 12, x + 12, y + 12], outline=(0, 0, 0, 255), width=4)
        d.text((x + 16, y - 8), part["name"], fill=(0, 0, 0, 255))
    over.save(out_dir / "_overlay.png")
    rebuild.save(out_dir / "_rebuild.png")

    diff = np.abs(np.array(rebuild).astype(int) - rgba.astype(int)).max(axis=2)
    for p in meta["parts"]:
        print(f"{p['name']:6} {p['size'][0]:4}×{p['size'][1]:<4} 픽셀 {p['pixels']:7,} 채움 {p['filled']:6,}")
    exact = solid & (alpha == 255)
    print(f"주인 없는 픽셀 {int(orphan.sum()):,} · 섬 정리로 옮긴 픽셀 {moved:,} · "
          f"다시 합친 그림이 원본과 다른 불투명 픽셀 {int((diff[exact] > 2).sum()):,}")


if __name__ == "__main__":
    main()
