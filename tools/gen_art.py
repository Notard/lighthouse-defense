"""Codex CLI의 그림 생성 도구로 기준 그림과 배경·소품 그림을 만든다 (design.md §3, 실제로 쓰는 것은 카드 004).

    python tools/gen_art.py ref <캐릭터>            → art/ref/<캐릭터>.png        (기준 그림, 컷아웃의 원본)
    python tools/gen_art.py prop <이름>             → art/ref/props/<이름>.png    (배경·소품·효과 정지 그림)
    python tools/gen_art.py prompt ref <캐릭터>     → Codex에 넘길 프롬프트만 보여 준다 (Codex를 부르지 않음)
    python tools/gen_art.py prompt prop <이름>
    python tools/gen_art.py list                    → 프롬프트 파일에 있는 캐릭터·소품 이름

- 프롬프트는 data/art/prompts.json (리드 소유)에서 읽는다
    style        그림체 (모든 그림에 붙음)
    background   배경 지시 (크로마 초록. 투명으로 바꾸기는 tools/art_common.py load_rgba)
    frame_size   기준 그림 캔버스 한 변 (px)
    style_ref    (있으면) 그림체 참고로 함께 넣을 캐릭터 이름 → art/ref/<style_ref>.png
    characters.<이름>  description, based_on (있으면 그 캐릭터 그림을 넣고 고쳐 그리게 함)
    props.<이름>       prompt, size [w, h], opaque (배경처럼 꽉 찬 그림), square, ref (참고 그림 경로)
- Codex 출력은 logs/03_gen_<이름>.log에 남긴다
- 필요: Codex CLI (`npm install -g @openai/codex`), ChatGPT 계정 로그인
- 모델: 기본 `gpt-5.6-sol`. 바꾸려면 환경 변수 CODEX_MODEL
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

from art_common import ROOT, setup_console, load_prompts, usage, wants_help

LOGS = ROOT / "logs"
MODEL = os.environ.get("CODEX_MODEL", "gpt-5.6-sol")


def style_images(prompts: dict, name: str | None) -> list[Path]:
    """그림체 참고로 함께 넣을 그림 (style_ref 캐릭터의 기준 그림. 자기 자신이거나 아직 없으면 없음)."""
    ref = prompts.get("style_ref")
    if not ref or ref == name:
        return []
    path = ROOT / "art" / "ref" / f"{ref}.png"
    return [path] if path.exists() else []


def ref_images(prompts: dict, name: str) -> list[Path]:
    """기준 그림에 함께 넣을 그림: based_on 캐릭터 그림, 아니면 그림체 참고 그림."""
    based = prompts["characters"][name].get("based_on")
    if based:
        path = ROOT / "art" / "ref" / f"{based}.png"
        if not path.exists():
            sys.exit(f"{based} 기준 그림이 먼저 있어야 합니다 (gen_art.py ref {based})")
        return [path]
    return style_images(prompts, name)


def ref_prompt(prompts: dict, name: str) -> str:
    c = prompts["characters"][name]
    if c.get("based_on"):
        guide = "The attached image is the existing character to edit. Keep everything identical except what the description asks to add."
    elif ref_images(prompts, name):
        guide = ("The attached image is ANOTHER character from the same game, given only as the art-style reference. "
                 "Match its art style exactly (outline color and thickness, cel shading, palette brightness, cuteness), "
                 "but draw the NEW character described below.")
    else:
        guide = ""
    n = prompts.get("frame_size", 1024)
    return "\n".join(line for line in [
        prompts["style"],
        prompts["background"],
        guide,
        f"Character: {c['description']}",
        f"Draw exactly ONE character, full body, centered, filling about 80% of a square {n}x{n} canvas.",
        "This image is the master reference that the cutout animation is built from, so keep the design simple and readable "
        "at small size, and keep limbs, tail and head clearly readable as separate shapes.",
    ] if line)


def prop_prompt(prompts: dict, name: str) -> tuple[str, list[Path]]:
    prop = prompts["props"][name]
    images = [ROOT / prop["ref"]] if "ref" in prop else style_images(prompts, None)
    lines = [prompts["style"]]
    if not prop.get("opaque"):
        lines.append(prompts["background"])
    if "ref" in prop:
        lines.append("The attached image is a reference from the same game; use it as the prompt below says.")
    elif images:
        lines.append("The attached image is a character from the same game, given only as the art-style reference. "
                     "Match its style, do not draw that character.")
    lines.append(prop["prompt"])
    w, h = prop["size"]
    # 최종 크기를 알려 주면 Codex가 그 크기로 줄여 저장해 원본 해상도를 잃는다. 줄이기는 prep_props.py가 한다.
    if prop.get("square"):
        lines.append("Use a square 1:1 canvas (for example 1024x1024). Save at full generated resolution; do not resize it.")
    elif prop.get("opaque"):
        lines.append("Use a tall 9:16 portrait canvas (for example 864x1536) for a vertical phone screen. "
                     "Save at full generated resolution; do not resize it.")
    elif max(w, h) < 512:
        lines.append("It will be shown small in the game, so keep shapes bold and readable. "
                     "Save the image at full generated resolution; do not resize it.")
    else:
        lines.append("Save the image at full generated resolution; do not resize it.")
    return "\n".join(lines), images


def run_codex(prompt: str, out: Path, images: list[Path], log_name: str) -> None:
    codex = shutil.which("codex") or shutil.which("codex.cmd")
    if codex is None:
        sys.exit("codex CLI를 찾을 수 없습니다 (npm install -g @openai/codex)")
    out.parent.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(exist_ok=True)
    rel = out.relative_to(ROOT).as_posix()
    task = (
        "Use your built-in image generation tool to create exactly one image from the art brief below. "
        "Use the highest quality setting and follow the background instruction of the brief exactly. "
        f"Then save the generated image as a PNG file at `{rel}` inside this workspace (overwrite if it exists). "
        "Do not create or modify any other file. When done, reply with only the saved path.\n\n"
        "=== ART BRIEF ===\n" + prompt
    )
    cmd = [codex, "exec", "-m", MODEL, "-C", str(ROOT), "-s", "workspace-write"]
    for img in images:
        cmd += ["-i", str(img)]
    # 프롬프트는 표준 입력으로 넘긴다. Windows의 codex.cmd는 여러 줄 인자를 첫 줄에서 잘라 버린다.
    cmd.append("-")
    log = LOGS / f"03_gen_{log_name}.log"
    with log.open("w", encoding="utf-8") as f:
        f.write(task + "\n\n=== CODEX OUTPUT ===\n")
        f.flush()
        result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, input=task.encode("utf-8"))
    if result.returncode != 0 or not out.exists():
        sys.exit(f"생성 실패 (종료 코드 {result.returncode}). 로그: {log.relative_to(ROOT).as_posix()}")
    print(f"{rel} 저장 ({out.stat().st_size / 1024:,.0f} KB), 로그: {log.relative_to(ROOT).as_posix()}")


def need(prompts: dict, group: str, name: str) -> None:
    if name not in prompts.get(group, {}):
        names = ", ".join(prompts.get(group, {})) or "(없음)"
        sys.exit(f"data/art/prompts.json의 {group}에 '{name}'이 없습니다. 있는 것: {names}")


def main() -> None:
    setup_console()
    args = sys.argv[1:]
    if wants_help(args):
        usage(__doc__)
    if args == ["list"]:
        prompts = load_prompts()
        print("characters:", ", ".join(prompts.get("characters", {})) or "(없음)")
        print("props:", ", ".join(prompts.get("props", {})) or "(없음)")
        return
    show_only = len(args) == 3 and args[0] == "prompt"
    if show_only:
        args = args[1:]
    if len(args) == 2 and args[0] == "ref":
        prompts = load_prompts()
        name = args[1]
        need(prompts, "characters", name)
        prompt, images = ref_prompt(prompts, name), ref_images(prompts, name)
        out, log = ROOT / "art" / "ref" / f"{name}.png", f"ref_{name}"
    elif len(args) == 2 and args[0] == "prop":
        prompts = load_prompts()
        name = args[1]
        need(prompts, "props", name)
        prompt, images = prop_prompt(prompts, name)
        out, log = ROOT / "art" / "ref" / "props" / f"{name}.png", f"prop_{name}"
    else:
        usage(__doc__, 2)
        return
    if show_only:
        print(prompt)
        print("\n함께 넣을 그림:", ", ".join(p.relative_to(ROOT).as_posix() for p in images) or "(없음)")
        return
    run_codex(prompt, out, images, log)


if __name__ == "__main__":
    main()
