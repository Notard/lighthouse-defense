# 008-beam-boost

- **목표 (한 문장)**: 빛 속 친구는 쉬는 시간이 빨리 줄어 더 자주 공격하고, 발밑에 금빛이 돈다.
- **하지 않을 것**: 빛 조각·카드(6단계), 피해 배율 바꾸기
- **관련 문서**: `docs/design.md` §5-2, `docs/tests/08-beam-boost.md` (T8-01~05), `docs/acceptance/08-beam-boost.md`, `data/tables/beam.csv` (friend_haste 칸 새로)
- **맡는 순서**: tester → implementer → reviewer → 사용자
- **끝내는 조건**:
  - [x] T8-01~05 테스트 있고 통과 (전체 통과)
  - [x] `bash tools/loop/check.sh implementer` 통과, `python tools/gen_tables.py --check` 통과
  - [x] reviewer 승인
  - [x] 사용자 확인 (A8-3, "응")
- **바퀴**: 1 / 3

## 바퀴 기록
- **1바퀴** (2026-10-20): tester T8-01~05 (표의 시간 계산 실수 둘을 짚음 → 리드가 표 고침) → implementer 89/89 → 리드 웹 확인: 발밑 금빛이 빛줄기에 묻힘 → implementer 고리·후광·반짝이로 다듬음 → reviewer 승인 (미룸: T8-04 전제 단언, 변수 이름 blob, 표 숫자를 바꾸면 빠듯한 시간 여유)
