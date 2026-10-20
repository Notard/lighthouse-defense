"""implementer 역할을 Codex CLI(ChatGPT OAuth 로그인)로 돌린다 (사용자: "implementer만 Codex").

사용:
    python tools/loop/codex_implementer.py <지시 파일.md>

- 역할 설명(`.claude/agents/implementer.md` 본문)과 프로젝트 규칙(`CLAUDE.md`)에 리드의 지시를 붙여
  `codex exec -s workspace-write`로 넘긴다. 프롬프트는 표준 입력으로 (Windows codex.cmd는 여러 줄 인자를 자른다)
- 안전 관문: 실행 앞뒤의 HEAD·stash 목록·스테이징을 비교한다. Codex가 커밋·stash·`git add`를 했으면 종료 코드 3
- 끝나면 `tools/loop/gate.py implementer`로 범위를 보고, Codex의 마지막 메시지(보고서)를 출력한다
- 기록: `logs/codex/<시각>-implementer.jsonl`(이벤트), `...-report.md`(마지막 메시지)
- 모델은 `~/.codex/config.toml` 기본. 바꾸려면 환경 변수 CODEX_MODEL
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TIMEOUT = 60 * 60  # 한 번 실행 최대 1시간


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8").stdout


def snapshot() -> tuple[str, str, str]:
    return git("rev-parse", "HEAD").strip(), git("stash", "list"), git("diff", "--cached", "--name-only")


def role_text() -> str:
    text = (ROOT / ".claude" / "agents" / "implementer.md").read_text(encoding="utf-8")
    if text.startswith("---"):
        text = text.split("---", 2)[2]  # 앞머리(frontmatter) 빼고 본문만
    return text.strip()


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    task = Path(sys.argv[1]).read_text(encoding="utf-8")
    codex = shutil.which("codex") or shutil.which("codex.cmd")
    if codex is None:
        sys.exit("codex CLI를 찾을 수 없습니다 (npm install -g @openai/codex)")

    prompt = "\n\n".join([
        role_text(),
        "## 프로젝트 규칙 (CLAUDE.md)\n" + (ROOT / "CLAUDE.md").read_text(encoding="utf-8"),
        "## 이번 지시 (리드)\n" + task,
        "## 꼭 지킬 것\n- git commit·push·stash·add·reset·checkout을 하지 않는다 (리드만 한다)\n"
        "- 마지막 메시지는 위 '보고' 형식 그대로, 한국어로",
    ])

    logs = ROOT / "logs" / "codex"
    logs.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    events = logs / f"{stamp}-implementer.jsonl"
    report = logs / f"{stamp}-report.md"

    cmd = [codex, "exec", "-C", str(ROOT), "-s", "workspace-write", "--json", "-o", str(report)]
    if os.environ.get("CODEX_MODEL"):
        cmd += ["-m", os.environ["CODEX_MODEL"]]
    cmd.append("-")

    before = snapshot()
    with events.open("w", encoding="utf-8") as out:
        proc = subprocess.run(cmd, cwd=ROOT, input=prompt, stdout=out, stderr=subprocess.STDOUT,
                              text=True, encoding="utf-8", timeout=TIMEOUT)
    after = snapshot()

    print(f"[codex] 종료 코드 {proc.returncode}, 기록 {events.relative_to(ROOT)}")
    if before != after:
        names = ["HEAD", "stash 목록", "스테이징"]
        changed = [n for n, a, b in zip(names, before, after) if a != b]
        print(f"[codex] 안전 관문 실패: {', '.join(changed)}이(가) 바뀜 (Codex는 git 상태를 바꾸면 안 된다)")
        return 3

    gate = subprocess.run([sys.executable, "tools/loop/gate.py", "implementer", "--max-files", "60"], cwd=ROOT)
    print("\n===== Codex 보고 =====")
    print(report.read_text(encoding="utf-8") if report.exists() else "(보고 없음)")
    return proc.returncode or gate.returncode


if __name__ == "__main__":
    sys.exit(main())
