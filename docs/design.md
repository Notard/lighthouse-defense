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
- 등대 가운데에서 빛 방향으로 뻗는 부채꼴, 폭 40°, 길이 640. 반투명 노란빛. 적에게 주는 효과와 표로 옮긴 폭·길이는 §4

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
- `data/art/prompts.json`의 `frame_size`는 **Codex 기준 그림 캔버스 한 변(px)**. 렌더 프레임 크기는 리그의 `canvas.frame_px`

## 3-2. 그림 (카드 004)

### 그림 목록 (프롬프트 `data/art/prompts.json`)
| 이름 | 종류 | 무엇 | 쓰는 곳 |
|---|---|---|---|
| `seahorse` 해마 · `crab` 게 · `pufferfish` 복어 | 캐릭터 기준 그림 (`art/ref/<이름>.png`) | 친구 셋 | 컷아웃 애니메이션은 카드 005 |
| `shadow_blob` 그림자 방울 · `ink_squid` 먹물 오징어 · `shadow_jelly` 그림자 해파리 | 캐릭터 기준 그림 | 적 셋 | 카드 005 |
| `night_sea` | 배경 (꽉 찬 세로 9:16) | 밤바다 | `assets/images/night_sea.webp` 1080 × 1920 |
| `lighthouse` | 소품 (정사각) | 작은 바위섬 위 등대 | `assets/images/lighthouse.webp` 400 × 400 |

- 캐릭터는 사방에서 오가므로 모두 **앞(보는 사람 쪽)**을 본다. `seahorse`를 먼저 그려 그림체 기준(`style_ref`)으로 삼는다
- 그림이 마음에 드는지는 **사용자가 정한다** (다시 그리기는 프롬프트를 리드가 고쳐서)

### 게임에 보이기
- 바다 바탕(`SeaBackdrop`)은 `night_sea` 그림을 판 전체(0, 0, 720 × 1280)에 그린다 (임시 그러데이션 대신)
- 등대(`LighthouseSpot`)는 `lighthouse` 그림을 가운데 (360, 660)에 **한 변 `GameConfig.lighthouseSize` = 200**으로 그린다 (안쪽 자리 원과 겹치지 않음: 150 − 44 = 106 > 100)
- 그리는 순서: 바다 → 빛 → 자리 → 등대 → 제목 (2단계와 같음)
- 그림을 읽지 못하면(파일 없음 등) 바다는 임시 그러데이션, 등대는 임시 원으로 그리고 로그를 남긴다 (게임은 멈추지 않음)
- 배경 `night_sea`는 Codex 원본(941 × 1672)을 1080 × 1920으로 키워 쓴다 (사용자 승인, 다시 그릴 때는 원본 크기를 크게 받기)
- 코드 이름: `SeaBackdrop`과 `LighthouseSpot`은 읽은 그림을 `Sprite? get sprite`로 보인다 (읽기 전에는 null). `GameConfig.lighthouseSize` (double, 200)
- `pubspec.yaml` assets에 `assets/images/`

### 시트 읽기 다지기 (카드 003 리뷰)
- `SheetAction.fromJson(Map)` (`lib/game/art.dart`): 시트 JSON의 동작 하나. `frames`는 꼭 있어야 한다(없거나 정수가 아니면 `FormatException`). `fps` 없으면 12, `loop` 없으면 false, `event` 없으면 null
- `CharacterArt.load`가 실패하면 캐시에 남기지 않는다 (다음에 다시 읽는다). 확인용 `CharacterArt.isCached(name)`
- `tools/pack_sheets.py`: 리그 동작에 `frames`·`fps`·`loop`가 없으면 알아보기 쉬운 오류로 멈춘다. 첫 프레임이 완전히 투명하면 트레이스백 대신 알림
- `tools/gen_art.py prompt ref <이름>`은 `based_on` 그림이 없어도 끝나지 않고 프롬프트를 보여 준다

### Codex 안전 관문 (카드 003 리뷰 ①)
- `tools/gen_art.py`는 Codex를 부르기 전과 후의 `git status --porcelain`을 비교해, **`art/` 밖에 새로 생기거나 바뀐 파일이 있으면** 그 목록을 보여 주고 종료 코드 3으로 멈춘다 (Codex가 저장소의 다른 곳을 고쳤는지 사람이 보기 전에 기계가 잡는다)

## 3-3. 캐릭터 컷아웃 애니메이션 (카드 005)

### 동작 (시트 `assets/images/<id>/<id>.json` + `<동작>.webp`)
| 누구 | 동작 | 프레임 | fps | 반복 | 이벤트 프레임 | 모습 |
|---|---|---|---|---|---|---|
| 친구 셋 | `idle` | 12 | 12 | 예 | — | 숨쉬듯 살짝 오르내림 (해마는 꼬리 흔들기, 게는 집게 까딱, 복어는 둥실) |
| 친구 셋 | `attack` | 8 | 12 | 아니오 | 5 | 해마: 거품을 뿜음(주둥이 끝) · 게: 집게로 집기 · 복어: 크게 부풀며 가시 |
| 친구 셋 | `hit` | 4 | 12 | 아니오 | — | 움찔 |
| 친구 셋 | `death` | 8 | 10 | 아니오 | — | 쓰러지며 작아짐 |
| 적 셋 | `move` | 12 | 12 | 예 | — | 방울: 출렁출렁 · 오징어: 다리 오므렸다 펴며 쭉 · 해파리: 종 오므렸다 펴며 둥실 |
| 적 셋 | `attack` | 6 | 10 | 예 | 3 | 등대에 붙어 빛을 갉아먹음 (이벤트마다 피해) |
| 적 셋 | `hit` | 4 | 12 | 아니오 | — | 움찔 (밝게 번쩍은 게임이 그림) |
| 적 셋 | `death` | 8 | 10 | 아니오 | — | 흩어지며 사라짐 |

- 캐릭터는 제자리에서 움직인다 (이동은 게임이). **발(기준점) 위치는 모든 동작에서 같다**
- 프레임 크기(정사각, `canvas.frame_px`)는 캐릭터마다 리그에서 정하되 **256 이하**
- 시트 한 장은 프레임을 **가로 한 줄**로 (너비 = 프레임 수 × 프레임 크기)
- 해마는 거품이 나가는 점(`muzzle`)을 시트 JSON에 둔다

### 편 오라 (사용자: "적과 아군은 오라로 구분하고, 적도 컬러풀하게")
- 친구는 **금빛**, 적은 **분홍빛** 오라를 실루엣 바깥에 얇고 은은하게 (`data/art/aura.json`: 색, 넓이 5, 흐림 4, 세기 1.3 — 256 px 프레임 기준). 시트를 만들 때 **그림에 구워** 넣는다 (게임이 그리지 않음)
- 편은 `data/tables/characters.csv`의 `kind`(friend / enemy)로
- 그림체 기준(해마)에서 옮겨 온 청록 테두리 빛은 걷어낸 뒤 오라를 입힌다. 새로 그리는 그림은 테두리 빛 없이 (프롬프트)
- 시트 JSON에 `"aura": "friend"` 또는 `"enemy"`와 `"aura_color": "#RRGGBB"`
- 적도 알록달록하게: 그림자 방울 **연두**, 먹물 오징어 **남청 + 주황 점** (오징어 모양: 화살촉 머리·옆 지느러미, 문어와 다르게), 그림자 해파리 **보라 → 하늘색 투명 종** — 적 셋은 다시 그린다

### 화면에 그릴 키
- 숫자 표 `data/tables/characters.csv`의 `display_height` (게임 px, 발에서 머리 끝까지). 친구는 자리 원(지름 88) 안에 들어가게 88 미만
- 미리보기 도구(`make_art_preview.py`)도 이 표를 읽는다 (도구에 숫자를 박지 않음, 카드 004 리뷰)

### 도구 다지기 (카드 004 리뷰)
- 안전 관문: Codex 실행 앞뒤의 `git rev-parse HEAD`와 `git stash list`도 비교하고, `art/` 안에서 바뀐 파일이 **이번 출력 파일**(과 그 `_check` 그림)뿐인지 본다. 어기면 종료 코드 3
- `pack_sheets.py`: `frames`(1 이상 정수)·`fps`(0보다 큰 수)·`loop`(참/거짓)·`event`(있으면 1~frames 정수)의 **형식**까지 검사
- 시트 폴더는 `pubspec.yaml`에 캐릭터마다 등록 (`assets/images/` 아래 폴더는 따로 등록해야 한다)
- 사용자에게 보여 줄 움직이는 그림: 캐릭터마다 동작을 이어 붙인 GIF `preview/05_<id>.gif` (숲 지키기 `make_gifs.py`를 가져와 고쳐도 됨)

## 4. 사방에서 오는 적·등대 불빛·빛줄기 (4단계, 카드 006)

### 숫자 표와 변환기
- 숫자는 `data/tables/`의 `enemies.csv`, `beam.csv`, `lighthouse.csv`, `practice.csv` (와 `characters.csv`). 뜻은 `data/tables/README.md`
- `python tools/gen_tables.py`가 표를 읽어 `lib/game/tables.g.dart`를 만든다 (맨 위에 "만든 파일, 고치지 말 것"). 저장소에 넣는다. `--check`를 주면 파일이 표와 같은지만 보고 다르면 종료 코드 1
- 빛 폭·길이는 `GameConfig`에서 빼고 표로 옮긴다 (`GameConfig.beamWidthDeg`·`beamLength` 없앰)

### 적
- 나타나기: 등대 가운데에서 `spawn_distance`(780, 화면 네 귀퉁이보다 멂) 떨어진 곳, 주어진 각도 (§2 각도 규칙). 체력은 표의 `hp`
- 움직이기: 등대 가운데를 향해 **곧장** (각도는 그대로, 거리만 줄어듦). 1초에 `speed` (빛 속이면 × `slow`)
- **닿는 거리** = 등대 한 변의 절반(100) + 적 `radius`. 거리가 닿는 거리까지 줄면 거기서 멈추고(넘어가지 않음) **갉기** 상태
- 갉기: 닿은 때부터 `bite_interval`초마다 등대 불빛을 `bite`만큼 깎는다 (첫 갉기는 닿고 `bite_interval`초 뒤). 빛은 갉기 빠르기를 바꾸지 않는다
- 위치(`position`)는 몸 가운데. 그림은 몸 가운데가 위치에 오게, 키 `display_height`로 그린다. 등대 쪽을 보게 좌우만 뒤집는다 (그림이 원래 어느 쪽을 보는지는 시트를 보고). 그림을 읽기 전에는 반지름 `radius`의 보라 원
- 동작: 움직일 때 `move`, 갉을 때 `attack`, 피해를 받으면 `hit` 한 번(움찔 + 밝게 번쩍) 뒤 원래 동작, 쓰러지면 `death`
- 피해 받기 `takeDamage(양)`: 빛 속이면 양 × `vulnerable`. 실제로 깎은 양을 돌려준다. 체력이 0 이하가 되면 **쓰러짐**: 더 움직이거나 갉지 않고, 피해도 더 받지 않으며(0을 돌려줌), **0.8초**(death 8프레임 ÷ 10fps) 뒤 판에서 사라진다. 4단계에는 적을 공격하는 것이 없다 (친구는 5단계) — 피해는 테스트와 다음 단계를 위한 것

### 빛 속
- 점 p가 빛 속 = 등대 가운데에서 거리 ≤ `length` **이고** p 쪽 각도와 빛 방향의 차이(360 둘레에서 짧은 쪽) ≤ `width_deg / 2`. 경계는 속 (같거나 작으면 속, 계산 오차를 생각해 거리(px)·각도(도) 모두 1e-3 여유 — Vector2가 32비트라 1e-6은 모자람 (카드 006 implementer))
- 적이 빛 속인지는 매 순간 몸 가운데(`position`)로 본다. 빛을 돌리면 바로 바뀐다

### 등대 불빛 (체력)
- 처음 `hp`(100). 0 아래로 내려가지 않는다
- 화면 위 **불빛 막대**: 판 위쪽 100 px 안, 가로로 길게. 채운 비율 = 지금 불빛 ÷ 처음 불빛. 따뜻한 노란빛
- 불빛이 0이 되면 **꺼짐**: 판이 멈춘다 (적이 움직이지도 갉지도 않음, 연습 스폰도 멈춤, 끌기·누르기 무시). 가운데에 문구(다음 프레임에 붙어도 됨) "불빛이 꺼졌어요" / "The light went out". 결과 창과 다시 하기는 7단계 (지금은 새로 고침)

### 연습 스폰 (7단계 웨이브 전까지, 확인용)
- 앱에서는 켜고, 테스트의 기본 판(`LighthouseGame()`)에서는 끈다
- `interval`초마다 (첫 스폰은 `interval`초 뒤) 적 셋 중 하나를 고르게, 각도 0 이상 360 미만 고르게 뽑아 나타나게 한다. 판에 (쓰러지는 중 빼고) 적이 `max_alive` 이상이면 그번은 건너뛴다
- 무작위는 씨앗(seed)을 받는다: 같은 씨앗이면 같은 순서

### 그리는 순서
바다 → 빛 → 자리 → 등대 → 적 → 제목 → 불빛 막대 → 꺼짐 문구

### 코드 이름 (tester·implementer가 같이 쓰는 약속)
| 이름 | 뜻 |
|---|---|
| `Tables` (`lib/game/tables.g.dart`) | `Tables.enemies`: `Map<String, EnemyStats>` (`id`, `hp`, `speed`, `bite`, `biteInterval`, `radius`, 모두 double 빼고 id), `Tables.beam`: `BeamStats` (`widthDeg`, `length`, `slow`, `vulnerable`), `Tables.lighthouse`: `LighthouseStats` (`hp`, `spawnDistance`), `Tables.practice`: `PracticeStats` (`interval` double, `maxAlive` int), `Tables.characters`: `Map<String, CharacterStats>` (`id`, `kind`, `nameKo`, `nameEn`, `displayHeight`) |
| `LighthouseGame({bool practice = false, int seed = 0})` | 연습 스폰 켜기, 씨앗. `main.dart`는 `practice: true` |
| `game.spawnEnemy(String id, double angleDeg, {double? distance})` → `Enemy` | 적 하나를 바로 판에 넣는다 (거리 없으면 `spawn_distance`). 테스트도 이것으로 |
| `game.enemies` | 판에 있는 적 (쓰러지는 중 포함, 사라지면 빠짐) `List<Enemy>` |
| `game.light`, `game.maxLight` | 지금 불빛, 처음 불빛 (double) |
| `game.isOver` | 불빛이 꺼졌는지 |
| `game.lightBar` | `LightBar` (`lib/game/hud.dart`): `ratio`(0~1), `position`·`size`(Vector2, 게임 좌표, 왼쪽 위 기준, **막대 전체** 크기) |
| `game.spawner` | `PracticeSpawner?` (연습이 꺼져 있으면 null): `spawned` = 지금까지 나타난 것 `List<({String id, double angleDeg})>` |
| `Enemy` (`lib/game/enemy.dart`) | `id`, `stats`(`EnemyStats`), `hp`, `angleDeg`, `distance`(등대 가운데까지), `contactDistance`, `state`(`EnemyState.moving` / `biting` / `dying`), `inBeam`, `takeDamage(double)` → double, `position` |
| `Enemy.deathSeconds` = 0.8 | 쓰러진 뒤 사라지기까지 |
| `game.beam.widthDeg`, `game.beam.length`, `game.beam.contains(Vector2 p)` | 표의 값, 빛 속인지 |
| `LightOutText` (`lib/game/hud.dart`) | 꺼짐 문구 컴포넌트 (꺼졌을 때만 판에 있음) |
| `Strings.lightOut` | "불빛이 꺼졌어요" / "The light went out" |

### 카드 005 리뷰에서 온 작은 일 (도구)
- `pack_sheets.py`: 오라 넓이·흐림을 `frame_px / 256` 배로 (aura.json 값은 256 기준). 지금 시트는 모두 256이라 결과가 같아야 한다
- 청록 테두리 빛 걷기(`strip_rim`)는 리그 JSON의 옵션 (`"strip_rim": true`)일 때만. 지금 시트가 그것으로 만들어졌으므로 여섯 리그 모두 켜 둔다 (적 셋도 조금 걷혀 있었음, 끄면 시트가 바뀜). 새 캐릭터는 끈 채로. 시트를 다시 만들면 지금과 같아야 한다
- `gen_art.py`의 `CODEX_BIN` 환경 변수는 **시험 전용**(가짜 Codex로 안전 관문 시연)이라고 도움말·주석에 적는다

## 5. 친구 놓기와 자동 공격 (5단계, 카드 007)

### 친구 놓기 (연습용 쟁반, 6단계 카드가 오면 바뀐다)
- 판 아래쪽(y 1100~1260, 바깥 고리 아래)에 **친구 쟁반**: 친구 셋(해마·게·복어)의 단추가 가로로. 단추에는 친구 그림과 이름(`characters.csv`의 이름, 지금 언어)
- 단추를 누르면 그 친구를 **들고** 있게 된다 (단추 강조). 같은 단추를 다시 누르면 내려놓음(안 듦), 다른 단추를 누르면 그 친구로 바뀜
- 친구를 든 채 **빈 자리**를 누르면 거기에 그 친구를 놓는다. 든 것은 그대로 (여러 자리에 이어 놓을 수 있음). 놓은 뒤 고른 자리는 없음
- 친구를 든 채 **친구가 있는 자리**를 누르면 아무 일도 없다 (바꾸기·팔기는 나중)
- 친구를 들지 않았을 때 자리 누르기는 2단계 그대로 (고르기·풀기). 쟁반 단추를 누르는 것은 자리 고르기를 바꾸지 않는다
- 놓을 수 있는 수는 연습이라 제한 없음. 적은 친구를 공격하지 않는다 (친구 맞음·쓰러짐은 나중)
- 친구는 자리 가운데에 몸 가운데가 오게, 키 `display_height`로. 앞을 본다 (뒤집지 않음)

### 자동 공격 (`data/tables/friends.csv`)
- **사거리 안 적**: 자리 가운데에서 적 몸 가운데까지 거리 ≤ `range` 이고 쓰러지는 중이 아닌 적
- **과녁 고르기**: 사거리 안 적 중 **등대에 가장 가까운**(`distance`가 가장 작은) 적. 같으면 친구에게 더 가까운 적
- 친구마다 **쉬는 시간**이 있고 처음엔 0 (바로 쏠 수 있음). 쉬는 시간이 0이고 사거리 안 적이 있으면 **공격 시작**: 과녁을 정하고, 쉬는 시간 = `interval`, `attack` 동작
- 공격 시작에서 **`windupSeconds` = 1/3초 뒤**(attack 이벤트 프레임 5: (5 − 1) ÷ 12fps)에 효과가 난다. 그 사이 쉬는 시간도 흐른다 (다음 공격은 시작에서 `interval` 뒤)
  - `shot`(해마): 거품 하나를 주둥이(`muzzle`, 그림이 없으면 자리 가운데)에서 과녁으로 쏜다. 효과가 날 때 과녁이 쓰러졌거나 사라졌으면 그때 사거리 안의 새 과녁(위 규칙)으로, 없으면 쏘지 않는다
  - `melee`(게): 과녁이 쓰러지지 않았고 사라지지 않았으면 `damage`. 아니면 헛침
  - `burst`(복어): 그때 사거리 안의 모든 적에게 `damage`
- 피해는 언제나 `enemy.takeDamage(damage)` (빛 속이면 커짐, §4)
- 판이 멈추면(꺼짐) 친구도 멈춘다

### 거품 (해마의 탄)
- 1초에 `projectile_speed`로 과녁의 **지금** 몸 가운데를 향해 날아간다 (따라감)
- 과녁 몸 가운데에서 과녁 `radius` 안에 들면 맞음: `damage`를 주고 사라짐
- 날아가는 중에 과녁이 쓰러지거나 사라지면 과녁의 마지막 자리까지 가서 **피해 없이** 터져 사라진다 (다른 적을 맞히지 않음)
- 작은 반투명 물방울 (그림 대신 그리기). 판이 멈추면 멈춘다

### 프레임 시간 (카드 006 리뷰)
- 판의 한 번 `update`는 **최대 0.1초**(`GameConfig.maxFrameDt`)만 흘린다. 더 큰 dt(탭을 숨겼다 돌아옴 등)는 0.1로 자른다 (남는 시간은 버림)

### 카드 006 리뷰에서 온 작은 일
- 닿는 거리 안쪽에서 나타난 적(`spawnEnemy`의 `distance` < 닿는 거리): 첫 `update`에 닿는 거리로 옮겨지고(밖으로) 갉기 상태가 되며, **그 프레임에 갉지 않는다**. 첫 갉기는 그 update가 끝난 때부터 `bite_interval` 뒤 (이때 이월하는 남은 시간은 0. 밖에서 걸어와 닿는 보통 경우의 이월은 0 ~ dt로 묶는다)
- 갉는 그림과 피해를 맞춘다: 갉기 중 attack 동작 한 바퀴가 `bite_interval`이 되게 늘리고, 이벤트 프레임(3)이 피해 순간에 오게 (그림만, 규칙은 §4 타이머 그대로)
- 그림을 읽기 전에 받은 피해의 `hit` 동작은 그림이 온 뒤 재생하지 않는다
- `cut_parts.py` 도움말의 "(친구 셋)"을 지금 사실(여섯 리그 모두)로
- `gen_tables.py`: 숫자 칸에 inf·nan·빈 값이 있으면 표 이름·줄·칸을 짚어 실패(종료 1)

### 그리는 순서
바다 → 빛 → 자리 → 등대 → 친구 → 적 → 거품 → 제목 → 불빛 막대 → 쟁반 → 꺼짐 문구

### 코드 이름 (tester·implementer가 같이 쓰는 약속)
| 이름 | 뜻 |
|---|---|
| `Tables.friends`: `Map<String, FriendStats>` | `id`, `attack`(String `shot`/`melee`/`burst`), `range`, `damage`, `interval`, `projectileSpeed` (double) |
| `Friend` (`lib/game/friend.dart`) | `id`, `stats`, `slot`(`Slot`), `position`(Vector2, 자리 가운데), `cooldown`(double, 남은 쉬는 시간), `isAttacking`(공격 시작~효과 사이), `target`(`Enemy?`, 지금 과녁), `enemiesInRange()` → `List<Enemy>` |
| `Friend.windupSeconds` = 1/3 | 공격 시작에서 효과까지 |
| `game.placeFriend(String id, Slot slot)` → `Friend?` | 빈 자리면 놓고 돌려줌, 차 있거나 판이 멈췄으면(꺼짐) null (아무 일 없음) |
| `game.friends` | 놓인 친구 `List<Friend>` (놓은 순서) |
| `slot.friend` | 그 자리의 친구 (`Friend?`) |
| `game.tray` | `FriendTray` (`lib/game/tray.dart`): `buttons`(`List<TrayButton>`, 해마·게·복어 순서), `held`(`String?`, 든 친구 id) |
| `TrayButton` | `friendId`, `position`·`size`(Vector2, 게임 좌표, 왼쪽 위 기준) |
| `game.bubbles` | 날아가는 거품 `List<Bubble>` (`lib/game/bubble.dart`): `position`, `target`(`Enemy`), 사라지면 빠짐 |
| `GameConfig.maxFrameDt` = 0.1 | 한 번 update의 최대 시간 |

## 난이도 목표 (balancer가 대조, 6·7단계에서 채움)
