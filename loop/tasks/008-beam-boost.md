# 008-beam-boost

- **목표 (한 문장)**: 빛 속 친구는 쉬는 시간이 빨리 줄어 더 자주 공격하고, 발밑에 금빛이 돈다.
- **하지 않을 것**: 빛 조각·카드(6단계), 피해 배율 바꾸기
- **관련 문서**: `docs/design.md` §5-2, `docs/tests/08-beam-boost.md` (T8-01~05), `docs/acceptance/08-beam-boost.md`, `data/tables/beam.csv` (friend_haste 칸 새로)
- **맡는 순서**: tester → implementer → reviewer → 사용자
- **끝내는 조건**:
  - [ ] T8-01~05 테스트 있고 통과 (전체 통과)
  - [ ] `bash tools/loop/check.sh implementer` 통과, `python tools/gen_tables.py --check` 통과
  - [ ] reviewer 승인
  - [ ] 사용자 확인 (A8-3)
- **바퀴**: 0 / 3

## 바퀴 기록
