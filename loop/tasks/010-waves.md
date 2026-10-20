# 010-waves

- **목표 (한 문장)**: 웨이브 10개(5·10은 보스)를 버티면 새벽이 와서 이기고, 지거나 이기면 결과 창에서 다시 할 수 있다.
- **하지 않을 것**: 진주·판 밖 성장(9단계), 소리(8단계), 난이도 조정(12단계, 지금 숫자는 첫 어림), 보스 전용 그림·기술
- **관련 문서**: `docs/design.md` §7, `docs/tests/07-waves.md` (T7-01~19), `docs/acceptance/07-waves.md`, 표 `enemies.csv`(art·scale·boss 칸, 보스 둘), `waves.csv`, `wave_rules.csv`
- **맡는 순서**: tester → implementer(표·검사 → 웨이브 → 보스 → 결과·다시 하기 → 그리기·글꼴) → 리드 웹 확인 → reviewer → 사용자
- **끝내는 조건**:
  - [x] T7-01~20 테스트 있고 통과 (전체 통과)
  - [x] `bash tools/loop/check.sh implementer` 통과, `gen_tables.py --check` 통과
  - [x] reviewer 승인
  - [ ] 사용자 확인 (A7-3~5)
- **바퀴**: 1 / 3

## 참고
- T4-02 ("enemies id 모음 = characters의 enemy id 모음")는 보스 줄이 생겨 표 뜻이 바뀐다 → tester가 T7-02 규칙(boss 0인 id 모음)으로 고친다 (리드가 04 표도 고침)
- 적 그림 키는 art·scale 규칙으로 (`Tables.characters[id]`로 바로 찾으면 보스에서 깨짐)
- 글꼴: 새 글자 (`Strings`)면 다시 만들기

## 바퀴 기록
- **1바퀴** (2026-10-20): tester T7-01~19 (때 맞춤 질문 → 설계) → 사용자 의견 둘이 중간에 들어옴: 해마 사거리 320, 공짜 해마로 시작(start.csv, T7-20) → tester 도우미·T6-19 보스 해파리(해마 사거리가 어디서든 닿는 것을 tester가 계산) → implementer 128/128 → reviewer 승인 (미룸: T7-06 깸 전 isResting 거짓, art kind 검사, 첫 웨이브 전 짐 "0 / 10" 문구, 다시 하기 메모리)
- 이 카드 뒤부터 implementer는 Codex (사용자: "에이전트를 codex oauth 로 하자" → "implementer만 Codex"), `tools/loop/codex_implementer.py`
