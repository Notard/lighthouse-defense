"""렌더한 프레임을 동작별 가로 한 줄 스프라이트 시트로 묶고 메타데이터 JSON을 쓴다 (design.md §3).

    python tools/pack_sheets.py <캐릭터>

읽는 것  art/render/<캐릭터>/<동작>/0001.png … (tools/blender_cutout.py), tools/rigs/<캐릭터>.json
만드는 것 assets/images/<캐릭터>/<동작>.webp, assets/images/<캐릭터>/<캐릭터>.json

시트는 WebP(품질 88, 투명도는 무손실)로 저장한다. PNG보다 훨씬 작고 화질 차이는 거의 없다.

JSON (게임이 읽음, lib/game/art.dart CharacterArt)
  frame   [너비, 높이]         한 프레임 크기 (px)
  anchor  [x, y]              프레임 안의 발 위치 → 자리 가운데에 맞춘다
                              리그의 anchor_point 좌표, 또는 anchor_part 부위 기준점 (없으면 body)
  bbox    [x0, y0, x1, y1]    첫 동작 첫 프레임에서 그림이 있는 영역 (오라 빼고) → 게임 표시 크기·카드 그림에 쓴다
  aura, aura_color            편 오라 (characters.csv kind, data/art/aura.json 색). 오라는 시트 그림에 구워 넣는다
  muzzle  [x, y]              (있으면) 이벤트가 일어나는 위치 (쏘는 곳, 빛이 나오는 곳 …)
                              리그의 muzzle_point 좌표, 또는 muzzle_part 부위 기준점
  actions.<동작>              frames, fps, loop, event(이 프레임에서 발사·생산·피해)

리그 동작마다 frames·fps·loop가 꼭 있어야 하고 형식도 맞아야 한다: frames 1 이상 정수, fps 0보다 큰 수,
loop 참/거짓, event(있으면) 1~frames 정수 (어기면 어느 동작의 무엇이 틀렸는지 알리고 멈춘다).
첫 동작 첫 프레임이 완전히 투명하면 알리고, 그림이 있는 첫 프레임으로 bbox를 정한다.
"""
import json
import sys

from art_common import ROOT, add_aura, load_aura, load_characters, setup_console, usage, wants_help

WEBP_QUALITY = 88
REQUIRED = ("frames", "fps", "loop")  # 리그 동작에 꼭 있어야 하는 키


def is_int(v) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


def action_problems(action: str, spec: dict) -> list[str]:
    """동작 하나의 키와 형식 문제 (없으면 빈 목록).

    frames 1 이상 정수 · fps 0보다 큰 수 · loop 참/거짓 · event(있으면) 1~frames 정수
    """
    missing = [k for k in REQUIRED if k not in spec]
    if missing:
        return [f"{action}: {', '.join(missing)} 없음"]
    problems = []
    frames, fps, loop = spec["frames"], spec["fps"], spec["loop"]
    if not is_int(frames) or frames < 1:
        problems.append(f"{action}: frames는 1 이상 정수여야 함 ({frames!r})")
    if not isinstance(fps, (int, float)) or isinstance(fps, bool) or fps <= 0:
        problems.append(f"{action}: fps는 0보다 큰 수여야 함 ({fps!r})")
    if not isinstance(loop, bool):
        problems.append(f"{action}: loop는 true/false여야 함 ({loop!r})")
    if "event" in spec:
        event = spec["event"]
        top = frames if is_int(frames) else None
        if not is_int(event) or event < 1 or (top is not None and event > top):
            problems.append(f"{action}: event는 1~{top if top is not None else 'frames'} 정수여야 함 ({event!r})")
    return problems


def check_actions(name: str, actions: dict) -> None:
    """리그 동작의 필수 키와 형식을 확인한다. 어기면 알아보기 쉬운 오류로 멈춘다."""
    if not actions:
        sys.exit(f"tools/rigs/{name}.json에 actions가 없습니다")
    problems = [p for action, spec in actions.items() for p in action_problems(action, spec)]
    if problems:
        sys.exit(f"tools/rigs/{name}.json 동작 오류 (필수: {', '.join(REQUIRED)})" + "".join(f"\n  {p}" for p in problems))


def first_bbox(name: str, action: str, imgs: list) -> list[int] | None:
    """그림이 있는 첫 프레임의 영역. 첫 프레임이 완전히 투명하면 알린다."""
    for i, im in enumerate(imgs):
        box = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()
        if box is None:
            print(f"알림: {name}/{action} {i + 1}번 프레임이 완전히 투명합니다 (리그·렌더 확인)")
            continue
        if i > 0:
            print(f"알림: bbox는 {action} {i + 1}번 프레임으로 정했습니다")
        return list(box)
    return None


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
    check_actions(name, rig.get("actions", {}))
    left, top, right, bottom = rig["canvas"]["box"]
    scale = rig["canvas"]["frame_px"] / max(right - left, bottom - top)

    def to_frame(p: list[float]) -> list[float]:
        return [round((p[0] - left) * scale, 1), round((p[1] - top) * scale, 1)]

    parts = {p["name"]: p for p in rig["parts"]}
    anchor_part = rig.get("anchor_part", "body")
    if "anchor_point" in rig:
        anchor = rig["anchor_point"]
    elif anchor_part in parts:
        anchor = parts[anchor_part]["pivot"]
    else:
        sys.exit(f"발 기준 부위 '{anchor_part}'이 리그에 없습니다 (anchor_point나 anchor_part를 정하세요)")
    out_dir = ROOT / "assets" / "images" / name
    out_dir.mkdir(parents=True, exist_ok=True)
    meta = {"character": name, "anchor": to_frame(anchor), "actions": {}}
    # 편 오라: 편은 data/tables/characters.csv의 kind, 색·넓이는 data/art/aura.json (design.md §3-3)
    kind = load_characters().get(name, {}).get("kind")
    aura = load_aura()
    if kind in ("friend", "enemy"):
        meta["aura"] = kind
        meta["aura_color"] = aura[kind]
    else:
        print(f"알림: data/tables/characters.csv에 {name}이 없어 오라를 입히지 않습니다")
    if "muzzle_point" in rig:
        meta["muzzle"] = to_frame(rig["muzzle_point"])
    elif rig.get("muzzle_part") in parts:
        meta["muzzle"] = to_frame(parts[rig["muzzle_part"]]["pivot"])

    for action, spec in rig["actions"].items():
        frames = sorted((ROOT / "art" / "render" / name / action).glob("*.png"))
        if len(frames) != spec["frames"]:
            sys.exit(f"{action}: 프레임 {len(frames)}장, 리그에는 {spec['frames']}장 (Blender 렌더를 먼저)")
        imgs = raw = [Image.open(f).convert("RGBA") for f in frames]
        if "aura" in meta:  # bbox는 오라를 입히기 전 그림으로 (키에 오라를 넣지 않게)
            imgs = [add_aura(im, meta["aura_color"], aura["width"], aura["blur"], aura["strength"]) for im in imgs]
        w, h = imgs[0].size
        sheet = Image.new("RGBA", (w * len(imgs), h))
        for i, im in enumerate(imgs):
            sheet.paste(im, (i * w, 0))
        sheet.save(out_dir / f"{action}.webp", "WEBP", quality=WEBP_QUALITY, method=6)
        meta["frame"] = [w, h]
        if "bbox" not in meta:
            box = first_bbox(name, action, raw)
            if box is not None:
                meta["bbox"] = box
        meta["actions"][action] = {k: spec[k] for k in ("frames", "fps", "loop", "event") if k in spec}
        print(f"{name}/{action}.webp  {sheet.width}×{sheet.height}  {(out_dir / f'{action}.webp').stat().st_size / 1024:,.0f} KB")

    if "bbox" not in meta:
        sys.exit(f"{name}: 모든 프레임이 완전히 투명합니다 (리그·렌더 확인). JSON을 쓰지 않았습니다")
    (out_dir / f"{name}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{name}/{name}.json  anchor {meta['anchor']}  muzzle {meta.get('muzzle')}")


if __name__ == "__main__":
    main()
