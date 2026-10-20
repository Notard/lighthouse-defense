# 009-cards

- **목표 (한 문장)**: 적이 떨어뜨린 빛 조각으로 레벨이 오르면 카드 3장 중 하나를 고르고(판이 멈춤), 첫 친구도 카드로 고른다.
- **하지 않을 것**: 웨이브·보스·결과 창(7단계), 친구 Lv3 갈래·카드 다시 뽑기·빛 조각 끌어오기(나중), 소리
- **관련 문서**: `docs/design.md` §6, `docs/tests/06-cards.md` (T6-01~20), `docs/acceptance/06-cards.md`, 표 `enemies.csv`(xp 칸), `progression.csv`, `cards.csv` (리드 소유)
- **맡는 순서**: tester → implementer(표 → 조각·레벨 → 카드 규칙·멈춤 → 카드 판 시작·놓기 → 창 그리기 → 글꼴) → 리드 웹 확인 → reviewer → 사용자
- **끝내는 조건**:
  - [x] T6-01~20 테스트 있고 통과 (전체 통과)
  - [x] `bash tools/loop/check.sh implementer` 통과, `gen_tables.py --check` 통과
  - [x] reviewer 승인
  - [ ] 사용자 확인 (A6-3~5)
- **바퀴**: 1 / 3

## 참고
- 기존 T2·T4·T5·T8 테스트는 연습 판이라 그대로 통과해야 한다
- 글꼴: `tools/subset_font.py`가 `cards.csv` 글자도 넣게 고치고 다시 만들기 (원본 경로는 `loop/tasks/006-enemies.md`)

## 바퀴 기록
- **1바퀴** (2026-10-20): tester T6-01~20 (T6-12 "2장뿐인 판" 불가능을 짚음 → 표 고침) → implementer (관문이 friends_test 하나로 막힘: tray가 nullable이 됨 — 범위 밖이라 우회 않고 보고) → 리드: 카드 표 ° → 도(글꼴에 없음), 표·글꼴 다시 → tester friends_test `tray!` → 108/108 → reviewer 승인 (미룸 넷: 멈춤 테스트 보강, progression 양수 검사, T6-19 우연, 그리기 숫자)
