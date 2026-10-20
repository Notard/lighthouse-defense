# 002-ring-input

- **목표 (한 문장)**: 등대 둘레에 자리 18개를 놓고, 누르면 자리를 고르고 끌면 등대 빛이 손가락 쪽을 가리키게 한다.
- **하지 않을 것**: 친구 놓기(5단계), 적, 빛의 효과(4단계), 그림·글꼴(3단계). 빛은 반투명 부채꼴 모양만.
- **관련 문서**: `docs/design.md` §2 (각도 규칙, 자리 표, 입력 규칙, **코드 이름 표**), `docs/tests/02-ring.md` (T2-01~22), `docs/acceptance/02-ring.md` (A2-1~7)
- **맡는 순서**: tester → implementer → reviewer (밸런스 없음)
- **끝내는 조건**:
  - [ ] T2-01~22가 모두 같은 번호 이름의 테스트로 있고 통과
  - [ ] `bash tools/loop/check.sh implementer` 통과 (분석·테스트·범위·웹 빌드)
  - [ ] reviewer 승인
  - [ ] 화면 (A2-1·3·7) 사용자 확인
- **바퀴**: 0 / 3

## 참고 (지금 코드)
- `lib/game/lighthouse_game.dart`: `LighthouseGame`(고정 해상도 720 × 1280 카메라, `viewfinder.anchor = topLeft`), `SeaBackdrop`, `LighthouseSpot`, `TitleText`
- `test/game_test.dart`: 1단계 테스트 (지우지 말 것)
- flame_test의 테스트 화면은 800 × 600 → 게임(720 × 1280)이 높이에 맞춰 줄고(배율 600/1280) 좌우에 여백이 생긴다

## 바퀴 기록
