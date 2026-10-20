# 005-cutout

- **목표 (한 문장)**: 친구 셋·적 셋의 기준 그림을 부위로 잘라 Blender 컷아웃 애니메이션 시트로 만들고, 사용자가 볼 GIF를 만든다.
- **하지 않을 것**: 판에 캐릭터 놓기·적 이동(4·5단계), 효과(거품·먹물 등 발사체), 소리
- **관련 문서**: `docs/design.md` §3-3, `docs/tests/03-cutout.md` (T3-17~24), `docs/acceptance/03-cutout.md` (A3-13~18), 숫자 표 `data/tables/characters.csv` (리드 소유, 읽기만)
- **맡는 순서**: tester → implementer(도구 다지기 → 리그 여섯 → 시트 → GIF) → 사용자 움직임 확인 → reviewer
- **끝내는 조건**:
  - [ ] T3-17~24 테스트 있고 통과
  - [ ] `bash tools/loop/check.sh implementer --max-files 70` 통과 (시트·리그·GIF가 많아 이 카드만 상한 70)
  - [ ] 사용자 움직임 승인 (A3-13·14)
  - [ ] reviewer 승인
- **바퀴**: 2 / 3

## implementer 참고
- 흐름: `tools/rigs/<id>.json`(부위 다각형·기준점·동작 키) → `bash tools/build_sprites.sh <id>` (cut_parts → Blender → pack_sheets → 미리보기)
- 숲 지키기 리그 예: `C:/forest_defense/tools/rigs/*.json` (예: `slime.json` 한 덩어리, `fox.json`·`squirrel.json` 여러 부위). 읽기만
- `tools/rig_helper.py`로 부위 경계를 그림 위에 그려 보며 다각형을 잡는다
- Codex는 이번 카드에서 쓰지 않는다 (그림은 카드 004에서 끝). 안전 관문 다지기는 Codex 없이 시연으로 확인 (예: 가짜 Codex 명령으로 art/ 밖 파일을 만드는 경우가 잡히는지)
- 캐릭터 하나 끝날 때마다 리드가 GIF를 볼 수 있게 `preview/05_<id>.gif`

## 바퀴 기록
- **1바퀴** (2026-10-20): tester T3-17~24 → implementer 도구 다지기(안전 관문 시연 5가지 모두 잡음)·리그 6·시트 1.93 MB·GIF (관문 통과 48/48, 49개) → **사용자**: "적의 오징어와 문어가 비슷하게 생겨서 게임에선 구분이 잘 안 갈 것 같다. 적은 테두리에 오라가 다르게" → 시안(preview/05_aura_mock.jpg) → "응 적과 아군은 오라로 구분하고, 적도 컬러풀하게"
- **2바퀴** 리드: `data/art/aura.json`(금빛·분홍, 얇게, 그림에 굽기), 적 셋 프롬프트 알록달록하게 + 테두리 빛 없이, 설계 §3-3 "편 오라", T3-25·26, A3-19·20. implementer: 적 셋 다시 그리기(Codex, 안전 관문) → 적 리그 다시 → 오라 굽기(청록 빛 걷기) → 해마 꼬리 이음매·오징어 파란 띠 → 시트·GIF

