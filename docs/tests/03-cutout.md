# 3단계 캐릭터 컷아웃 테스트 표 (카드 005)

> 설계: `docs/design.md` §3-3. 캐릭터 id: 친구 `seahorse`, `crab`, `pufferfish` / 적 `shadow_blob`, `ink_squid`, `shadow_jelly`. 움직임이 예쁜지는 사용자 확인.

| 번호 | 주어진 것 | 행동 | 기대값 |
|---|---|---|---|
| T3-17 | 저장소 | 여섯 캐릭터의 시트 JSON과 등록 | `assets/images/<id>/<id>.json`이 있고, `pubspec.yaml` flutter assets에 `assets/images/<id>/`가 캐릭터마다 있다 |
| T3-18 | 여섯 시트 JSON | 동작 목록 | 친구: `idle`, `attack`, `hit`, `death` / 적: `move`, `attack`, `hit`, `death` (더도 덜도 없음) |
| T3-19 | 여섯 시트 JSON | 동작마다 frames·fps·loop·event | 설계 §3-3 표와 같다 (친구 idle 12·12·true, attack 8·12·false·5, hit 4·12·false, death 8·10·false / 적 move 12·12·true, attack 6·10·true·3, hit 4·12·false, death 8·10·false). event가 없는 동작은 event 없음 |
| T3-20 | 여섯 시트 | 동작마다 그림 `assets/images/<id>/<동작>.webp`의 크기 | 너비 = frames × 프레임 너비, 높이 = 프레임 높이 (프레임 크기는 시트 JSON의 `frame`), 프레임 한 변 256 이하 |
| T3-21 | 새 판 | `CharacterArt.load(game, <id>)` 여섯 개 | 모두 성공. 동작마다 `animation(동작)`의 프레임 수가 frames와 같다 |
| T3-22 | 여섯 시트 JSON | 발 기준점 `anchor`와 `bbox` | anchor가 프레임 안, bbox 넓이 0보다 큼, anchor의 y가 bbox 위 끝보다 아래 |
| T3-23 | 해마 시트 JSON | `muzzle` | 있고 프레임 안 |
| T3-24 | `data/tables/characters.csv` | 줄과 칸 | 여섯 id가 한 줄씩, 칸 `id,kind,name_ko,name_en,display_height`, kind는 friend 셋·enemy 셋, display_height는 0보다 크고 친구는 88 미만 |
