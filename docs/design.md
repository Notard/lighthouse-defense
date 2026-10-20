# 등대 지키기 설계 (정답)

> 게임 규칙의 정답. 리드가 쓰고, implementer·tester·reviewer가 읽는다. 큰 그림은 `plan.md`, 숫자는 `data/tables/`.
> 기능마다 절 하나를 단계가 시작될 때 채운다.

## 1. 화면 (1단계, 완료)
- 세로 720 × 1280 고정 해상도, 바깥은 깊은 바다색 여백
- 등대 가운데 (360, 660)

## 2. 등대 둘레 자리와 입력 (2단계, 카드 002)

### 각도
- 화면 좌표(오른쪽 +x, **아래 +y**)에서 `atan2(dy, dx)`를 도(°)로 바꿔 **0 이상 360 미만**으로 쓴다
- 그래서 **0° = 오른쪽, 90° = 아래, 180° = 왼쪽, 270° = 위** (화면에서 시계 방향으로 커진다)

### 자리 (친구를 놓을 곳, 18개)
| 고리 | 수 | 등대 가운데에서 거리 | 각도 (번호 순서대로) | id |
|---|---|---|---|---|
| 안쪽 | 6 | 150 | 270, 330, 30, 90, 150, 210 (= 270 + 60k) | `I0` … `I5` |
| 바깥 | 12 | 270 | 285, 315, 345, 15, … (= 285 + 30k, 360으로 나눈 나머지) | `O0` … `O11` |

- 자리 가운데 = 등대 가운데 + 거리 × (cos 각도, sin 각도)
- 그리는 원 반지름 44, **누르는 범위 반지름 48** (손가락 여유)
- 바깥 자리는 안쪽 자리 사이사이에 오도록 15° 엇갈림

### 누르기와 끌기
- 손가락(마우스)을 누른 곳에서 **화면(논리) px로 12 넘게 움직였으면 끌기**, 아니면 **누르기**로 친다 (떼는 순간 판정, 한 번 12를 넘으면 끌기로 남는다). 게임 좌표가 아니라 화면 기준인 까닭: 폰에서는 게임이 약 0.54배로 작게 그려져 게임 좌표 12면 손가락 약 6.5 px 흔들림에도 끌기가 된다 (카드 002 리뷰)
- **누르기**
  - 자리 가운데에서 **48 이하**(게임 좌표)면 그 자리를 **고른다** (여럿이면 가장 가까운 자리). 이미 고른 자리를 다시 누르면 고르기를 **푼다**
  - 다른 자리를 누르면 그 자리로 바뀐다
  - 자리가 아닌 곳(바다)을 누르면 고르기를 푼다
  - 누르기는 빛 방향을 바꾸지 않는다
- **끌기**: 등대 빛이 손가락 쪽을 가리킨다
  - 끄는 **도중에도** 손가락이 움직일 때마다 빛 방향 = 등대 가운데에서 손가락 쪽 각도
  - 손가락이 등대 가운데에서 **40 미만**(게임 좌표, 가운데 빈 곳)일 때는 빛 방향을 바꾸지 않는다 (마지막 방향 그대로). 정확히 40이면 바꾼다
  - 끌기는 자리 고르기를 바꾸지 않는다 (자리 위에서 시작해도)
  - 끌기는 **판(720 × 1280) 안에서 시작**한 것만 받는다. 넓은 PC 창의 좌우 여백에서 시작한 끌기는 무시 (판 안에서 시작해 여백으로 나가는 것은 계속 따라간다)
- 처음 빛 방향은 **270° (위)**, 처음에는 고른 자리 없음

### 빛 (2단계는 모양만)
- 등대 가운데에서 빛 방향으로 뻗는 부채꼴, 폭 40°, 길이 640. 반투명 노란빛. 적에게 주는 효과는 4단계 (그때 폭·길이는 `data/tables`로 옮긴다)

### 코드 이름 (tester·implementer가 같이 쓰는 약속)
| 이름 | 뜻 |
|---|---|
| `GameConfig.innerRingRadius` = 150, `outerRingRadius` = 270, `slotRadius` = 44, `slotTouchRadius` = 48, `dragThreshold` = 12 (**화면 논리 px**), `beamDeadZone` = 40, `startBeamAngle` = 270 | `lib/game/config.dart` |
| `Slot` (`lib/game/slots.dart`): `id`(String, `I0`…), `ring`(`SlotRing.inner` / `SlotRing.outer`), `index`(int), `angleDeg`(double), `center`(Vector2) | 자리 하나 (Flame 컴포넌트) |
| `LighthouseGame.slots` | 자리 18개, 안쪽 `I0`…`I5` 다음 바깥 `O0`…`O11` 순서 |
| `LighthouseGame.selectedSlot` | 고른 자리 (`Slot?`) |
| `LighthouseGame.beam` | 빛 컴포넌트 (`Beam`, `lib/game/beam.dart`), `beam.angleDeg`(double, 0 이상 360 미만) |
| `angleFromLighthouse(Vector2 p)` (`lib/game/geometry.dart`) | 등대 가운데에서 p 쪽 각도 (위 규칙) |

## 3. 글꼴·문구·그림 도구 (3단계, 카드 003)

### 글꼴
- **주아(Jua)**, SIL OFL 1.1 (사용자 선택). 원본(약 2 MB)은 저장소에 넣지 않고, 쓰는 글자만 남긴 파일을 `assets/fonts/Jua.ttf`에 둔다. 라이선스 `assets/fonts/OFL.txt`
- 남기는 글자: `lib/` 아래 `.dart` 문자열에 쓰인 글자 전부 + 영문·숫자·기본 기호(U+0020~U+007E) + 몇몇 기호(원본에 있는 것만)
- 만드는 도구: `python tools/subset_font.py <원본 Jua-Regular.ttf 경로>` (숲 지키기 도구를 고쳐서). 문구를 바꾸면 다시 돌린다
- 글꼴 이름(family) `Jua`, 코드에서는 `GameConfig.fontFamily`

### 문구
- 화면 글은 모두 `lib/game/strings.dart`의 `Strings`에서 (코드에 한글 글을 바로 쓰지 않는다)
- 처음부터 두 언어: `enum Lang { ko, en }`, `Strings.lang`(기본 `Lang.ko`). 기기 언어 따르기와 설정 창은 10단계
- 지금 쓰는 글

| 이름 | 한국어 | 영어 |
|---|---|---|
| `Strings.title` | 등대 지키기 | Lighthouse Keepers |
| `Strings.subtitle` | 밤바다 등대를 지켜요 | Keep the lighthouse shining |

- 1단계의 제목(`TitleText`)은 `Strings.title`을 `GameConfig.fontFamily` 글꼴로 그린다 (지금 네모로 나오는 것을 고침)

### 그림 도구 (숲 지키기에서 가져와 고침)
| 도구 | 하는 일 |
|---|---|
| `tools/gen_art.py` | Codex CLI로 기준 그림(`art/ref/<이름>.png`)과 배경·소품 그림. 프롬프트는 **`data/art/prompts.json`** (리드 소유, 그림체·캐릭터 설명) |
| `tools/cut_parts.py`, `tools/blender_cutout.py`, `tools/pack_sheets.py`, `tools/build_sprites.sh` | 부위 자르기(`tools/rigs/<이름>.json`) → Blender 컷아웃 렌더 → 시트(`assets/images/<이름>/<이름>.json` + 동작별 `.webp`) |
| `tools/prep_props.py`, `tools/make_art_preview.py`, `tools/rig_helper.py` | 소품 다듬기, 그림 미리보기 페이지, 리그 도우미 |
| `lib/game/art.dart` | `CharacterArt`: 시트 JSON + 동작별 그림을 Flame 애니메이션으로 (숲 지키기와 같은 형식) |

- 숲 지키기 전용 내용(숲·도토리·레인, 가로 화면, 파일 경로·캐릭터 이름)은 지운다. 세로 판, 밤바다에 맞는 기본값으로
- 카드 003에서는 도구만 가져온다. 실제 그림 만들기는 카드 004

## 난이도 목표 (balancer가 대조, 6·7단계에서 채움)
