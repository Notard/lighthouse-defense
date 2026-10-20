#!/usr/bin/env bash
# 리드가 매 바퀴 돌리는 자동 관문 (docs/loop.md "관문 1·2·3"). 하나라도 실패하면 1.
#   bash tools/loop/check.sh implementer          # 범위 검사할 역할
#   bash tools/loop/check.sh tester --base main   # worktree 브랜치 결과
#   SKIP_WEB=1 bash tools/loop/check.sh lead      # 웹 빌드 건너뛰기 (빠르게)
set -uo pipefail
cd "$(dirname "$0")/../.."
role="${1:-lead}"; shift || true
fail=0
step() { printf '\n== %s ==\n' "$1"; }

step "관문 1: 정적 분석"
flutter analyze || fail=1

step "관문 1: 테스트 (봇·그림 테스트 제외)"
flutter test --exclude-tags shots,balance || fail=1

step "관문 2: 범위 ($role)"
python tools/loop/gate.py "$role" "$@" || fail=1

if [ "${SKIP_WEB:-0}" != "1" ]; then
  step "관문 3: 웹 빌드"
  MSYS_NO_PATHCONV=1 flutter build web --release --base-href /lighthouse-defense/ --no-web-resources-cdn >/dev/null || fail=1
fi

step "결과"
if [ $fail -eq 0 ]; then echo "모든 관문 통과"; else echo "관문 실패"; fi
exit $fail
