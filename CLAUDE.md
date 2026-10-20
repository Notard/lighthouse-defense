# 등대 지키기 프로젝트 규칙

- 사용자에게는 **한국어로** 답한다. 문서·주석도 한국어
- 계획 `plan.md`, 설계 정답 `docs/design.md`, 여러 에이전트 루프 구조 `docs/loop.md`
- 역할(implementer · tester · balancer · reviewer)은 `.claude/agents/`, 고칠 수 있는 범위는 `loop/roles.json`. **자기 범위 밖 파일은 고치지 않는다.** 범위 밖 문제는 보고서에 적어 리드에게
- 관문: `bash tools/loop/check.sh <역할>` (분석 · 테스트 · 범위 · 웹 빌드)
- 숫자는 `data/tables/*.csv`에서 읽는다. 코드에 숫자를 박아 넣지 않는다 (화면 배치 같은 고정 값은 `lib/game/config.dart`)
- 화면은 세로 720 × 1280 고정 해상도. Flame의 `add`는 다음 프레임에 처리된다. 효과 곡선(`Curve.transform`) 입력은 0~1로 묶는다 (릴리스 웹에서 1을 넘으면 멈춤)
- Windows 러너(`windows/runner/*`) 소스는 ASCII만 (한글은 `\uXXXX`)
- 커밋·푸시는 리드(메인 대화)만 한다
