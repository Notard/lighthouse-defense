# 005-cutout

- **목표 (한 문장)**: 친구 셋·적 셋의 기준 그림을 부위로 잘라 Blender 컷아웃 애니메이션 시트로 만들고, 사용자가 볼 GIF를 만든다.
- **하지 않을 것**: 판에 캐릭터 놓기·적 이동(4·5단계), 효과(거품·먹물 등 발사체), 소리
- **관련 문서**: `docs/design.md` §3-3, `docs/tests/03-cutout.md` (T3-17~24), `docs/acceptance/03-cutout.md` (A3-13~18), 숫자 표 `data/tables/characters.csv` (리드 소유, 읽기만)
- **맡는 순서**: tester → implementer(도구 다지기 → 리그 여섯 → 시트 → GIF) → 사용자 움직임 확인 → reviewer
- **끝내는 조건**:
  - [ ] T3-17~24 테스트 있고 통과
  - [ ] `bash tools/loop/check.sh implementer` 통과
  - [ ] 사용자 움직임 승인 (A3-13·14)
  - [ ] reviewer 승인
- **바퀴**: 1 / 3

## implementer 참고
- 흐름: `tools/rigs/<id>.json`(부위 다각형·기준점·동작 키) → `bash tools/build_sprites.sh <id>` (cut_parts → Blender → pack_sheets → 미리보기)
- 숲 지키기 리그 예: `C:/forest_defense/tools/rigs/*.json` (예: `slime.json` 한 덩어리, `fox.json`·`squirrel.json` 여러 부위). 읽기만
- `tools/rig_helper.py`로 부위 경계를 그림 위에 그려 보며 다각형을 잡는다
- Codex는 이번 카드에서 쓰지 않는다 (그림은 카드 004에서 끝). 안전 관문 다지기는 Codex 없이 시연으로 확인 (예: 가짜 Codex 명령으로 art/ 밖 파일을 만드는 경우가 잡히는지)
- 캐릭터 하나 끝날 때마다 리드가 GIF를 볼 수 있게 `preview/05_<id>.gif`

## 바퀴 기록
