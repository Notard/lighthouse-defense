# 등대 지키기 작업 기록

## 0. 기획 (2026-10-20)

> 사용자: "이 게임은 여기까지 하고 다음엔 어떤 디펜스 게임을 만들면 좋을까? 지금과는 완전 다른 종류의 디펜스 게임이 좋겠는데"
> → 네 가지 중 "A로 하고 밤바다 등대를 지키는 바다 생물들 로 해서 새 폴더를 만들고 새 프로젝트로 하자."

### 결과 요약
| 질문 | 고른 것 |
|---|---|
| 종류 | A. 사방 로그라이크 디펜스 (가운데를 360도로 지키고, 웨이브마다 카드 3장 중 하나) |
| 테마 | 밤바다 등대를 지키는 바다 생물들 |
| 폴더·이름 | `C:\lighthouse_defense` · 등대 지키기 (Lighthouse Keepers) |
| 화면 | 웹(PWA) 세로 먼저 |
| 그림 | 숲 지키기처럼 Codex 카툰 + 컷아웃 |
| 공개 | 새 공개 저장소 + Pages 자동 배포 |

계획서 [plan.md](plan.md): 숲 지키기와 확실히 다르게 **등대 빛을 손가락으로 끌어 돌리는 조작**을 핵심으로 (빛 속의 어둠 생물은 느려지고 약해짐), 고리 자리(안쪽 6 · 바깥 12)에 친구, 빛 조각(경험치)으로 카드, 진주로 판 밖 성장, 밤 셋.

### 진행 방식
숲 지키기 마무리 뒤 같은 대화에서 질문 넷으로 방향을 정하고 계획서를 썼다.

### 검증
사용자 확인 대기.

### 발생한 문제와 해결
없음.

## 1. 프로젝트·저장소·자동 배포 (2026-10-20)

### 결과 요약
- `flutter create` (웹·Windows), Flame 추가. 세로 720 × 1280 고정 해상도 판에 밤바다 그러데이션, 가운데 등대 자리(임시 원), 제목
- 웹: `<title>`·PWA 이름 "등대 지키기", 세로(`portrait`), 바다색 / Windows: 창 540 × 960, 제목 "등대 지키기"
- 숲 지키기에서 `make_todo_html.py`, `serve_web.py`, `dart_test.yaml`, Pages 배포 설정을 가져와 이름·경로(`/lighthouse-defense/`)를 바꿈

### 진행 방식
| 파일 | 내용 |
|---|---|
| `lib/game/config.dart` | 720 × 1280, 등대 자리 (360, 660), 바다색 |
| `lib/game/lighthouse_game.dart` | `LighthouseGame`(고정 해상도 카메라), 바다 바탕, 등대 자리, 제목 |
| `lib/main.dart` | 판 하나 |
| `windows/runner/main.cpp` | 세로 창, 한글 제목을 `\uXXXX`로 (소스는 ASCII여야 한다: /WX가 C4819를 오류로) |
| `.github/workflows/pages.yml` | main 푸시마다 테스트 → 웹 빌드(`--base-href /lighthouse-defense/`) → Pages |

### 검증
- `flutter analyze` 문제 없음, `flutter test` 1/1, `flutter build windows` 성공
- 공개 저장소 https://github.com/Notard/lighthouse-defense 생성·푸시, Pages(GitHub Actions 방식) 켬 → 첫 배포 build·deploy 성공, https://notard.github.io/lighthouse-defense/ 200, 제목 "등대 지키기"
- 실제 사이트 화면: 세로 판·밤바다·등대 자리 확인. **한글 제목이 네모로** 보임 (글꼴 없음, `--no-web-resources-cdn`이라 대체 글꼴도 안 받음) → 3단계 글꼴에서

![1단계 실제 사이트](preview/01_blank.jpg)

### 발생한 문제와 해결
1. 창 제목을 한글 이스케이프로 넣으려 했는데 셸(heredoc)과 편집 도구가 `\uB4F1`을 실제 한글로 풀어 넣었다 (C++ 소스에 한글 → 빌드 실패) → 파이썬 스크립트 파일에서 바이트로 바꿔 넣음. 처음에는 주석이 조건문 괄호 안에 들어가기도 했다

## 1-1. 여러 에이전트 + 루프 엔지니어링 구조 (2026-10-20)

> 사용자 (역할 표와 함께): "본격적인 개발은 이렇게 나눠서 하고 루프 엔지니어링 개념을 네가 조사해와서 여러 에이전트가 일하고 루프 엔지니어링으로 하는 구조로 가자."

### 결과 요약
- 조사: 루프 엔지니어링 = 에이전트가 계획 → 변경 → 관찰 → 고침을 반복하도록 **반복 구조(상태, 검증 관문, 끝내는 조건, 역할 분리, 상한, 사람 개입 지점)를 설계**하는 일. 정리는 [docs/loop.md](docs/loop.md)
- 사용자 표를 Flutter 프로젝트에 맞게 옮김: implementer(`lib/`·`tools/`) · tester(`test/`만) · balancer(`tools/balance/`·`balance/`, 표 숫자는 제안만) · reviewer(읽기만, 기본 거절) · 리드(문서·표·판단·커밋)
- 한 바퀴: 리드 표 → tester(빨간 불) → implementer(최대 3번) → 관문 → (balancer) → reviewer → 리드 판단·커밋. 카드 하나 최대 3바퀴, 넘으면 사용자에게

### 진행 방식
| 파일 | 내용 |
|---|---|
| `docs/loop.md` | 조사 요약(출처), 역할 표, 사람이 쓰는 것, 한 바퀴 그림, 상한·정지·자율성, 숲 지키기 교훈 → 관문 |
| `.claude/agents/{implementer,tester,balancer,reviewer}.md` | 역할별 지시·범위·순서·보고 형식, 모델(Opus·Sonnet), reviewer는 Read·Grep·Glob만 |
| `loop/roles.json` + `tools/loop/gate.py` | 역할별 고칠 수 있는 곳(allow)·금지(deny)·한 번에 30개 상한. git 변경 목록과 대조 |
| `tools/loop/check.sh` | 관문 1 분석·테스트, 2 범위, 3 웹 빌드 |
| `loop/STATE.md`, `loop/run-log.md`, `loop/tasks/_template.md` | 상태(정지 스위치 포함), 덧붙이기만 하는 기록, 작업 카드 틀 |
| `docs/design.md`, `docs/tests/README.md`, `data/tables/README.md`, `CLAUDE.md` | 설계 정답 뼈대, 테스트 표 쓰는 법, 숫자 표 소유, 프로젝트 규칙 |

### 검증
- `gate.py` 지금 변경(리드 문서 15개): lead 통과, implementer·tester·reviewer 거절
- 가짜 변경 10가지(역할마다 범위 안·밖): 모두 기대대로 통과/거절

### 발생한 문제와 해결
1. 조사 자료 중 wikidocs 글은 403으로 읽지 못함 → 나머지 넷으로 정리. "backpressure"·`PROGRESS.md` 같은 말은 읽은 자료에 없어 쓰지 않음

## 2. 등대 둘레 자리와 입력: 루프 첫 카드 002 (2026-10-20)

> 사용자: "응 고고" (루프 구조 확인 → 첫 바퀴 시작)

### 결과 요약
- 등대 둘레에 자리 18개 (안쪽 6 · 150, 바깥 12 · 270, 15° 엇갈림). 누르면 고르고(흰 테두리), 다시 누르거나 바다를 누르면 풀림
- 판 안 어디서든 끌면 등대 빛(폭 40°, 길이 640 부채꼴)이 손가락 쪽을 가리키고 끄는 동안 따라옴. 가운데 40 미만에서는 그대로
- 누르기/끌기 경계: **화면(논리) px 12** (1차 리뷰 뒤 바꿈)
- **루프가 실제로 돌았다**: tester(빨간 불) → implementer(첫 시도 통과) → 관문에서 테스트 파일 분석 경고 → implementer는 범위 밖이라 **보고만**, tester가 정리 → reviewer **거절**(6가지) → 리드가 설계·표 고침 → 2바퀴 → reviewer **승인**

![PC 마우스: O2를 골라 흰 테두리, 끌어서 빛이 오른쪽 위로](preview/02_ring.jpg)

### 진행 방식
| 바퀴 | 누가 | 무엇 |
|---|---|---|
| 준비 | 리드 | `docs/design.md` §2 (각도 0° 오른쪽·90° 아래, 자리 표, 입력 규칙, **코드 이름 표**로 tester·implementer 이름 맞춤), `docs/tests/02-ring.md` T2-01~22, `docs/acceptance/02-ring.md`, 카드 `loop/tasks/002-ring-input.md`, 브랜치 `loop/002-ring` |
| 1 | tester (Sonnet) | `test/ring_test.dart` 22개 + `test/support.dart`(게임 → 화면 좌표, 손가락 도우미). 구현 전이라 컴파일 안 됨 |
| 1 | implementer (Opus) | `lib/game/slots.dart`, `beam.dart`, `geometry.dart`, `board_input.dart`(판 전체를 덮는 입력 층 하나에서 누르기·끌기 판정), `config.dart`, `lighthouse_game.dart`. 첫 시도 23/23 |
| 1 | 관문 | 분석 실패: `test/support.dart` 불필요한 import 2개. implementer는 고치지 않고 "테스트 의문"으로 보고 → 리드가 tester에게 되돌림 → 정리 → 모두 통과 |
| 1 | reviewer (Opus, 읽기만) | **거절**: ① T2-21 허용 오차가 표보다 느슨 ② T2-19가 빈 곳 규칙을 검증 못 함(빼도 통과) ③ 12/13 px 경계 없음 ④ 12가 게임 좌표라 폰에서 약 6.5 px로 너무 민감 ⑤ 미만/이하 문구 ⑥ 여백에서 시작한 끌기 |
| 2 | 리드 | ④ 화면 px 기준으로 설계 변경, ⑤ 40 미만·48 이하, ⑥ 판 안에서 시작한 끌기만. 표: T2-19 보강, T2-21 화면 8 px·±0.01°, T2-23(화면 13 px → 끌기) |
| 2 | tester → implementer | T2-21 빨간 불 → 문턱을 캔버스 거리로 (첫 시도) |
| 2 | reviewer | **승인**: 1~6 해결, 새 문제 없음 |

### 검증
- 관문(`bash tools/loop/check.sh implementer`): 분석 문제 없음, 테스트 24/24, 범위 통과, 웹 빌드 통과 (리드가 직접 다시 돌림)
- 화면(리드, PC 마우스): 자리 18개 두 고리 색, O2 클릭 강조, 끌기로 빛이 끝점 쪽(약 320°), 끌기가 고르기를 바꾸지 않음
- 남음: 폰 세로 터치 (사용자)

### 발생한 문제와 해결
1. 미리보기 도구가 새 폴더의 `.claude/launch.json`이 아니라 이전 프로젝트 설정을 읽어 숲 지키기 서버를 띄움 → 멈추고 서버를 직접 띄움. 그때 Git Bash가 `--base /lighthouse-defense/`를 Windows 경로로 바꿔 404 → `MSYS_NO_PATHCONV=1` (숲 지키기에서도 겪은 것)
2. 폰 크기 흉내에서 화면 찍기가 이상하게 나옴 (숲 지키기 때와 같은 미리보기 문제) → PC 크기로 확인, 폰은 사용자에게
3. `gate.py` 출력이 Windows 콘솔에서 깨짐 → UTF-8로 출력

## 3. 카드 003: 글꼴·문구·그림 도구 (2026-10-20)

> 사용자: "계속" / 글꼴: "주아 Jua (추천)"

### 결과 요약
- **주아(Jua)** 글꼴 (Google Fonts, OFL 1.1): 원본 2,070 KB에서 쓰는 글자만 남겨 **42 KB** (111자). 웹 제목 "등대 지키기"가 네모 대신 주아로 보인다
- 문구 틀 `Strings` (한국어·영어 두 벌, `Lang`), 화면 글은 여기서만
- 숲 지키기 그림 도구 8개(`gen_art`, `cut_parts`, `blender_cutout`, `pack_sheets`, `build_sprites.sh`, `prep_props`, `make_art_preview`, `rig_helper`) + 공통 `art_common.py` + `lib/game/art.dart`를 세로·밤바다에 맞게 가져옴. 프롬프트는 리드 소유 `data/art/prompts.json`에서 읽기만
- 루프 **한 바퀴 만에 승인**

![제목이 주아로](preview/03_font.jpg)

### 진행 방식
| 누가 | 무엇 |
|---|---|
| 리드 | 설계 §3, 테스트 표 T3-01~09, 인수 조건 A3-1~6, 카드, `data/art/prompts.json` 뼈대(밤바다 그림체), 주아 원본 받기 |
| tester | `test/font_test.dart`: 글꼴 파일·등록, 영문 숫자, 두 언어 문구, `lib/` 문자열 글자가 모두 글꼴에 (TrueType cmap 직접 읽기), 제목이 Strings·Jua, `strings.dart` 밖 문자열에 한글 없음 |
| implementer | `subset_font.py`(테스트와 같은 글자 고르기 규칙, cmap (3,1) 확인), 글꼴·라이선스, `strings.dart`, 제목, 도구 8개 + `art_common.py`(크로마 초록 배경 지우기 포함), `art.dart`. 범위 밖 `.gitignore`는 보고만 |
| 리드 | `.gitignore`(art 중간 산출물·logs), 웹에서 제목 확인 |
| reviewer | **승인**. 막지 않는 문제 6개를 카드 004로 (Codex 쓰기 범위, 시트 JSON 필수 키, 캐시, 빈 bbox, 미리보기 숫자, frame_size 뜻) |

### 검증
- 관문: 분석 문제 없음, 테스트 33/33, 범위 통과(18개), 웹 빌드 통과
- 도구 `--help` 종료 코드 0, 필수 인자 없으면 사용법 + 2 (implementer 확인, reviewer 코드로 확인)

### 발생한 문제와 해결
1. 주아는 굵기가 하나라 `fontWeight: w700`이면 가짜 굵게 그려짐 → 굵기를 뺌
2. reviewer: Codex를 `workspace-write`로 부르면 저장소 어디든 쓸 수 있음 → 카드 004에서 실행 뒤 `git status` 확인을 끝내는 조건에 넣기로

