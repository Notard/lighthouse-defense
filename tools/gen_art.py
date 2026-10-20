"""Codex CLI의 그림 생성 도구로 기준 그림과 배경·소품 그림을 만든다 (design.md §3, 실제로 쓰는 것은 카드 004).

    python tools/gen_art.py ref <캐릭터>            → art/ref/<캐릭터>.png        (기준 그림, 컷아웃의 원본)
    python tools/gen_art.py prop <이름>             → art/ref/props/<이름>.png    (배경·소품·효과 정지 그림)
    python tools/gen_art.py prompt ref <캐릭터>     → Codex에 넘길 프롬프트만 보여 준다 (Codex를 부르지 않음)
    python tools/gen_art.py prompt prop <이름>
    python tools/gen_art.py list                    → 프롬프트 파일에 있는 캐릭터·소품 이름
    python tools/gen_art.py check <캐릭터>          → art/ref/_check/<캐릭터>.png (배경을 투명하게 뺀 확인용, ref 뒤에 자동)

- 프롬프트는 data/art/prompts.json (리드 소유)에서 읽는다
    style        그림체 (모든 그림에 붙음)
    background   배경 지시 (크로마 초록. 투명으로 바꾸기는 tools/art_common.py load_rgba)
    frame_size   기준 그림 캔버스 한 변 (px)
    style_ref    (있으면) 그림체 참고로 함께 넣을 캐릭터 이름 → art/ref/<style_ref>.png
    characters.<이름>  description, based_on (있으면 그 캐릭터 그림을 넣고 고쳐 그리게 함)
    props.<이름>       prompt, size [w, h], opaque (배경처럼 꽉 찬 그림), square, ref (참고 그림 경로)
- Codex 출력은 logs/03_gen_<이름>.log에 남긴다
- 안전 관문: Codex를 부르기 전과 후의 `git status --porcelain`(+ 바뀐 파일의 내용 해시)을 비교해
  art/ 밖에 새로 생기거나 바뀐 파일이 있으면 그 목록을 보여 주고 종료 코드 3으로 멈춘다 (design.md §3-2).
  .gitignore로 빠진 파일(logs/*.log 등)은 git이 보지 않으므로 비교하지 않는다
- 필요: Codex CLI (`npm install -g @openai/codex`), ChatGPT 계정 로그인
- 모델: 기본 `gpt-5.6-sol`. 바꾸려면 환경 변수 CODEX_MODEL
"""
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

from art_common import ROOT, load_prompts, load_rgba, setup_console, usage, wants_help

LOGS = ROOT / "logs"
MODEL = os.environ.get("CODEX_MODEL", "gpt-5.6-sol")


def style_images(prompts: dict, name: str | None) -> list[Path]:
    """그림체 참고로 함께 넣을 그림 (style_ref 캐릭터의 기준 그림. 자기 자신이거나 아직 없으면 없음)."""
    ref = prompts.get("style_ref")
    if not ref or ref == name:
        return []
    path = ROOT / "art" / "ref" / f"{ref}.png"
    return [path] if path.exists() else []


def ref_images(prompts: dict, name: str, strict: bool = True) -> list[Path]:
    """기준 그림에 함께 넣을 그림: based_on 캐릭터 그림, 아니면 그림체 참고 그림.

    based_on 그림이 아직 없으면 strict일 때(그리기) 멈추고, 아니면(프롬프트 보기) 알리기만 한다.
    """
    based = prompts["characters"][name].get("based_on")
    if based:
        path = ROOT / "art" / "ref" / f"{based}.png"
        if not path.exists():
            message = f"{based} 기준 그림이 먼저 있어야 합니다 (gen_art.py ref {based})"
            if strict:
                sys.exit(message)
            print(f"알림: {message}", file=sys.stderr)
            return []
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


def git_snapshot() -> dict[str, str]:
    """git이 보는 바뀐 파일마다 (상태 + 내용 해시). 무시하지 않는 새 파일은 폴더가 아니라 파일 하나하나로."""
    result = subprocess.run(["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
                            cwd=ROOT, capture_output=True, check=True)
    entries = result.stdout.decode("utf-8").split("\0")
    snap: dict[str, str] = {}
    i = 0
    while i < len(entries):
        entry = entries[i]
        i += 1
        if len(entry) < 4:
            continue
        status, path = entry[:2], entry[3:]
        if "R" in status or "C" in status:
            i += 1  # 이름 바꾸기·복사는 원래 이름이 뒤따른다
        file = ROOT / path
        digest = hashlib.sha1(file.read_bytes()).hexdigest() if file.is_file() else "-"
        snap[path] = f"{status} {digest}"
    return snap


def changed_outside_art(before: dict[str, str], after: dict[str, str]) -> list[str]:
    """Codex 실행 중에 art/ 밖에서 새로 생기거나 바뀌거나 되돌려진 파일."""
    paths = set(before) | set(after)
    return sorted(p for p in paths if not p.startswith("art/") and before.get(p) != after.get(p))


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
    before = git_snapshot()
    with log.open("w", encoding="utf-8") as f:
        f.write(task + "\n\n=== CODEX OUTPUT ===\n")
        f.flush()
        result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, input=task.encode("utf-8"))
    # 안전 관문: Codex가 art/ 밖을 건드렸으면 사람이 보기 전에 멈춘다
    outside = changed_outside_art(before, git_snapshot())
    if outside:
        print("안전 관문: Codex 실행 중에 art/ 밖 파일이 바뀌었습니다 (git diff로 확인하세요):", file=sys.stderr)
        for path in outside:
            print(f"  {path}", file=sys.stderr)
        sys.exit(3)
    print("안전 관문: art/ 밖 변경 없음")
    if result.returncode != 0 or not out.exists():
        sys.exit(f"생성 실패 (종료 코드 {result.returncode}). 로그: {log.relative_to(ROOT).as_posix()}")
    print(f"{rel} 저장 ({out.stat().st_size / 1024:,.0f} KB), 로그: {log.relative_to(ROOT).as_posix()}")


def write_check(name: str) -> None:
    """기준 그림의 크로마 초록 배경을 빼서 art/ref/_check/<이름>.png로 저장한다 (투명 처리 확인용)."""
    src = ROOT / "art" / "ref" / f"{name}.png"
    if not src.exists():
        sys.exit(f"기준 그림이 없습니다: {src.relative_to(ROOT).as_posix()} (gen_art.py ref {name})")
    out = ROOT / "art" / "ref" / "_check" / f"{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    im = load_rgba(src)
    im.save(out)
    alpha = im.getchannel("A")
    clear = sum(alpha.histogram()[:1]) / (im.width * im.height)
    print(f"{out.relative_to(ROOT).as_posix()} 저장 (투명 {clear:.0%}, 그림 영역 {alpha.getbbox()})")


def need(prompts: dict, group: str, name: str) -> None:
    if name not in prompts.get(group, {}):
        names = ", ".join(prompts.get(group, {})) or "(없음)"
        sys.exit(f"data/art/prompts.json의 {group}에 '{name}'이 없습니다. 있는 것: {names}")


def main() -> None:
    setup_console()
    args = sys.argv[1:]
    if wants_help(args):
        usage(__doc__)
    if len(args) == 2 and args[0] == "check":
        write_check(args[1])
        return
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
        prompt, images = ref_prompt(prompts, name), ref_images(prompts, name, strict=not show_only)
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
    if args[0] == "ref":
        write_check(args[1])


if __name__ == "__main__":
    main()
