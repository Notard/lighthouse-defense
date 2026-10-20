# 003-font-tools

- **목표 (한 문장)**: 주아 글꼴(쓰는 글자만)과 한국어·영어 문구 틀을 넣어 제목이 제대로 보이게 하고, 숲 지키기의 그림 도구를 이 프로젝트에 맞게 가져온다.
- **하지 않을 것**: 실제 그림 만들기·Codex 호출·Blender 렌더(카드 004), 메뉴·설정·기기 언어 따르기(10단계), 다른 화면 글
- **관련 문서**: `docs/design.md` §3, `docs/tests/03-font.md` (T3-01~09), `docs/acceptance/03-font.md` (A3-1~6)
- **맡는 순서**: tester → implementer → reviewer
- **끝내는 조건**:
  - [ ] T3-01~09가 모두 같은 번호 이름의 테스트로 있고 통과
  - [ ] `bash tools/loop/check.sh implementer` 통과
  - [ ] reviewer 승인
  - [ ] 웹에서 제목 글꼴 (리드)
- **바퀴**: 1 / 3

## 참고
- 주아 원본: `C:/Users/elbre/AppData/Local/Temp/claude/C--forest-defense/259dfae4-2eb0-4b9b-9b79-e0a74836419c/scratchpad/jua_dl/Jua-Regular.ttf` (와 `OFL.txt`). 저장소에 넣지 말 것
- 숲 지키기 원본 도구: `C:/forest_defense/tools/` (`subset_font.py`, `gen_art.py`, `cut_parts.py`, `blender_cutout.py`, `pack_sheets.py`, `build_sprites.sh`, `prep_props.py`, `make_art_preview.py`, `rig_helper.py`), `C:/forest_defense/lib/game/art.dart`, 글꼴 테스트 예 `C:/forest_defense/test/font_coverage_test.dart`. 읽기만 하고 고치지 말 것
- 그림 프롬프트 `data/art/prompts.json`은 리드가 카드 004에서 채운다. 이번에는 리드가 넣어 둔 뼈대를 읽기만
- Blender: `C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`, Codex CLI 0.158 있음

## 바퀴 기록
