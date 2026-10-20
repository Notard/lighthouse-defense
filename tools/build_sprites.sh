#!/usr/bin/env bash
# 캐릭터 하나의 스프라이트 시트를 처음부터 다시 만든다 (2D 컷아웃, design.md §3).
#   bash tools/build_sprites.sh <캐릭터>
#   bash tools/build_sprites.sh --help
# 순서: 기준 그림 자르기(cut_parts) → Blender 렌더(blender_cutout) → 시트 묶기(pack_sheets) → art_preview.html
# 필요: art/ref/<캐릭터>.png (gen_art.py ref), tools/rigs/<캐릭터>.json
# Blender 경로는 환경 변수 BLENDER로 바꿀 수 있다. 로그: logs/03_cutout_<캐릭터>.log
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; }
if [ $# -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  if [ $# -eq 1 ]; then exit 0; else exit 2; fi
fi
NAME="$1"
BLENDER="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
mkdir -p logs

python tools/cut_parts.py "$NAME"
"$BLENDER" --background --python tools/blender_cutout.py -- "$NAME" > "logs/03_cutout_${NAME}.log" 2>&1 \
  || { echo "Blender 실패: logs/03_cutout_${NAME}.log"; exit 1; }
grep "\[cutout\]" "logs/03_cutout_${NAME}.log"
python tools/pack_sheets.py "$NAME"
python tools/make_art_preview.py
