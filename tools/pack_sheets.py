"""렌더한 프레임을 동작별 가로 한 줄 스프라이트 시트로 묶고 메타데이터 JSON을 쓴다 (design.md §3).

    python tools/pack_sheets.py <캐릭터>

읽는 것  art/render/<캐릭터>/<동작>/0001.png … (tools/blender_cutout.py), tools/rigs/<캐릭터>.json
만드는 것 assets/images/<캐릭터>/<동작>.webp, assets/images/<캐릭터>/<캐릭터>.json

시트는 WebP(품질 88, 투명도는 무손실)로 저장한다. PNG보다 훨씬 작고 화질 차이는 거의 없다.

JSON (게임이 읽음, lib/game/art.dart CharacterArt)
  frame   [너비, 높이]         한 프레임 크기 (px)
  anchor  [x, y]              프레임 안의 발 위치 → 자리 가운데에 맞춘다
                              리그의 anchor_part 부위 기준점 (없으면 body)
  bbox    [x0, y0, x1, y1]    첫 동작 첫 프레임에서 그림이 있는 영역 → 게임 표시 크기·카드 그림에 쓴다
  muzzle  [x, y]              (있으면) 이벤트가 일어나는 위치 (쏘는 곳, 빛이 나오는 곳 …)
                              리그의 muzzle_point 좌표, 또는 muzzle_part 부위 기준점
  actions.<동작>              frames, fps, loop, event(이 프레임에서 발사·생산·피해)
"""
import json
import sys

from art_common import ROOT, setup_console, usage, wants_help

WEBP_QUALITY = 88


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

    from PIL import Image

    rig = json.loads(rig_path.read_text(encoding="utf-8"))
    left, top, right, bottom = rig["canvas"]["box"]
    scale = rig["canvas"]["frame_px"] / max(right - left, bottom - top)

    def to_frame(p: list[float]) -> list[float]:
        return [round((p[0] - left) * scale, 1), round((p[1] - top) * scale, 1)]

    parts = {p["name"]: p for p in rig["parts"]}
    anchor_part = rig.get("anchor_part", "body")
    if anchor_part not in parts:
        sys.exit(f"발 기준 부위 '{anchor_part}'이 리그에 없습니다 (anchor_part를 정하세요)")
    out_dir = ROOT / "assets" / "images" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    meta = {"character": name, "anchor": to_frame(parts[anchor_part]["pivot"]), "actions": {}}
    if "muzzle_point" in rig:
        meta["muzzle"] = to_frame(rig["muzzle_point"])
    elif rig.get("muzzle_part") in parts:
        meta["muzzle"] = to_frame(parts[rig["muzzle_part"]]["pivot"])

    for action, spec in rig["actions"].items():
        frames = sorted((ROOT / "art" / "render" / name / action).glob("*.png"))
        if len(frames) != spec["frames"]:
            sys.exit(f"{action}: 프레임 {len(frames)}장, 리그에는 {spec['frames']}장 (Blender 렌더를 먼저)")
        imgs = [Image.open(f).convert("RGBA") for f in frames]
        w, h = imgs[0].size
        sheet = Image.new("RGBA", (w * len(imgs), h))
        for i, im in enumerate(imgs):
            sheet.paste(im, (i * w, 0))
        sheet.save(out_dir / f"{action}.webp", "WEBP", quality=WEBP_QUALITY, method=6)
        meta["frame"] = [w, h]
        if "bbox" not in meta:
            meta["bbox"] = list(imgs[0].getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox())
        meta["actions"][action] = {k: spec[k] for k in ("frames", "fps", "loop", "event") if k in spec}
        print(f"{name}/{action}.webp  {sheet.width}×{sheet.height}  {(out_dir / f'{action}.webp').stat().st_size / 1024:,.0f} KB")

    (out_dir / f"{name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{name}/{name}.json  anchor {meta['anchor']}  muzzle {meta.get('muzzle')}")


if __name__ == "__main__":
    main()
