"""범위 관문: 한 역할이 바꾼 파일이 그 역할이 고칠 수 있는 곳인지 검사한다 (docs/loop.md "관문 2").

    python tools/loop/gate.py implementer            # 작업 트리의 변경(스테이징·미스테이징·새 파일)
    python tools/loop/gate.py tester --base main     # main과 비교한 이 브랜치의 변경 (worktree 결과 검사)

통과하면 0, 범위를 벗어난 파일이 있거나 너무 많이 바꿨으면 1을 돌려주고 이유를 적는다.
역할 표는 loop/roles.json.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def changed_files(base: str | None) -> list[str]:
    def git(*args: str) -> list[str]:
        out = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout
        return [line.strip() for line in out.splitlines() if line.strip()]

    files: set[str] = set()
    if base:
        files.update(git("diff", "--name-only", f"{base}...HEAD"))
    files.update(git("diff", "--name-only"))
    files.update(git("diff", "--name-only", "--cached"))
    files.update(git("ls-files", "--others", "--exclude-standard"))
    return sorted(f.replace("\\", "/") for f in files)


def matches(path: str, patterns: list[str]) -> bool:
    for p in patterns:
        if fnmatch.fnmatch(path, p):
            return True
        # "dir/**"는 dir 안의 모든 깊이
        if p.endswith("/**") and (path == p[:-3] or path.startswith(p[:-2])):
            return True
    return False


def check(role: str, files: list[str], table: dict) -> list[str]:
    spec = table["roles"][role]
    problems = []
    for f in files:
        if matches(f, spec["deny"]):
            problems.append(f"손대면 안 되는 곳: {f}")
        elif not matches(f, spec["allow"]):
            problems.append(f"고칠 수 있는 곳이 아님: {f}")
    if len(files) > table["maxFiles"]:
        problems.append(f"한 번에 너무 많이 바꿈: {len(files)}개 (최대 {table['maxFiles']})")
    return problems


def main() -> int:
    # Windows 콘솔(cp949)에서도 한글이 깨지지 않게
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    table = json.loads((ROOT / "loop" / "roles.json").read_text(encoding="utf-8"))
    ap = argparse.ArgumentParser()
    ap.add_argument("role", choices=sorted(table["roles"]))
    ap.add_argument("--base", help="이 브랜치와 비교 (예: main)")
    ap.add_argument("--max-files", type=int, help="이번 카드만 파일 수 상한을 바꾼다 (리드가 카드에 적은 값, 예: 그림 시트가 많은 카드)")
    args = ap.parse_args()
    files = changed_files(args.base)
    if args.max_files:
        table["maxFiles"] = args.max_files
    problems = check(args.role, files, table)
    print(f"[gate] {args.role}: 바꾼 파일 {len(files)}개")
    for f in files:
        print(f"  - {f}")
    if problems:
        print("[gate] 거절")
        for p in problems:
            print(f"  ! {p}")
        return 1
    print("[gate] 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
