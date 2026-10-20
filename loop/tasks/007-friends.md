# 007-friends

- **목표 (한 문장)**: 쟁반에서 친구(해마·게·복어)를 골라 자리에 놓으면 사거리 안 적을 저절로 공격한다.
- **하지 않을 것**: 카드·빛 조각(6단계), 친구 강화·팔기·옮기기, 적이 친구를 공격, 웨이브(7단계), 소리
- **관련 문서**: `docs/design.md` §5 (와 §4), `docs/tests/05-friends.md` (T5-01~17), `docs/acceptance/05-friends.md` (A5-1~6), 표 `data/tables/friends.csv` (리드 소유, 읽기만)
- **맡는 순서**: tester → implementer(표 → 놓기·쟁반 → 공격·거품 → 프레임 시간·006 작은 일 → 그림) → 리드 웹 확인 → reviewer → 사용자
- **끝내는 조건**:
  - [ ] T5-01~19 테스트 있고 통과 (전체 통과)
  - [ ] `bash tools/loop/check.sh implementer` 통과
  - [ ] `python tools/gen_tables.py --check` 통과
  - [ ] reviewer 승인
  - [ ] 사용자 확인 (A5-3~5)
- **바퀴**: 2 / 3

## implementer 참고
- 쟁반 이름 글자는 `Tables.characters`의 이름 (글꼴은 이미 들어 있음, 새 글을 더하면 다시 만들기)
- 친구 그림은 `CharacterArt` (idle 반복, 공격 시작에 attack 한 번 → idle). 해마 `muzzle`은 시트 JSON (프레임 px) → 화면 배율로
- 거품은 그림 없이 그리기 (작은 반투명 물방울)

## 바퀴 기록
- **1바퀴** (2026-10-20): tester T5-01~17 → implementer 82/82 (판단 셋 → 설계에) → 리드 웹 확인(친구가 적을 막음) → **reviewer 거절**: ① Friend가 dt ≤ 0 update에서도 공격 시작(설계 어김) ② T5-16이 느슨함(꺼진 뒤 놓기 null을 안 봄, 멈춤을 확인하는 테스트 없음). 미룸 셋(T5-11 강화, 그리기 숫자, attack 값 검사) 중 둘은 2바퀴에 같이
- **2바퀴** 리드: T5-16 고침, T5-18(dt 0)·T5-19(꺼짐 멈춤) 더함, A5-7. tester → implementer(friend dt ≤ 0, 그리기 숫자 config로, gen_tables attack 검사)
