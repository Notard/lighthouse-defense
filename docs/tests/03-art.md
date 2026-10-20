# 3단계 그림 테스트 표 (카드 004)

> 설계: `docs/design.md` §3-2. 그림 자체가 예쁜지는 테스트가 아니라 사용자 확인.

| 번호 | 주어진 것 | 행동 | 기대값 |
|---|---|---|---|
| T3-10 | 저장소 | 그림 파일과 등록을 본다 | `assets/images/night_sea.webp`, `assets/images/lighthouse.webp`가 있다. `pubspec.yaml` flutter assets에 `assets/images/`가 있다 |
| T3-11 | 새 판 | 바다 바탕(`SeaBackdrop`)을 본다 | 위치 (0, 0), 크기 720 × 1280, 그릴 그림(sprite)이 읽혀 있다 |
| T3-12 | 새 판 | 등대(`LighthouseSpot`)를 본다 | 가운데가 (360, 660) (±0.5), 크기 200 × 200 (`GameConfig.lighthouseSize` = 200), 그릴 그림이 읽혀 있다. world 자식 순서에서 모든 `Slot`보다 뒤(위에 그려짐) |
| T3-13 | 없음 | `SheetAction.fromJson({'frames': 8, 'fps': 10, 'loop': true, 'event': 3})` | frames 8, fps 10, loop true, event 3 |
| T3-14 | 없음 | `SheetAction.fromJson({'frames': 6})` | frames 6, fps 12, loop false, event null |
| T3-15 | 없음 | `SheetAction.fromJson({'fps': 12})` (frames 없음), `SheetAction.fromJson({'frames': 'six'})` | 둘 다 `FormatException` |
| T3-16 | 새 판 | 없는 캐릭터 `CharacterArt.load(game, 'no_such_art')` | 실패(예외)하고, 그 뒤 `CharacterArt.isCached('no_such_art')` = false |
