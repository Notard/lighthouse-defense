# 6단계 빛 조각·레벨업 카드 테스트 표 (카드 009)

> 설계: `docs/design.md` §6. 숫자는 CSV를 직접 읽어 쓴다 (괄호 안은 지금 값의 예). 시간은 `game.update(0.05)` 되풀이, 경계는 ±0.05초 바깥(나는 시간은 ±0.1초). "연습 판" = `LighthouseGame()`, "카드 판" = `LighthouseGame(cards: true)` (판이 붙은 뒤, 곧 첫 친구 고르기 창이 열려 있음). 좌표 허용 오차 ±0.5.
> "필요1" = xp_base, "필요2" = xp_base + xp_step.

| 번호 | 주어진 것 | 행동 | 기대값 |
|---|---|---|---|
| T6-01 | 표 | `Tables`와 비교 | `cards.csv` 모든 줄이 `Tables.cards[id]`와 같고 수·순서 같음. `progression.csv` 한 줄이 `Tables.progression`과 같음. `enemies.csv`의 xp가 `Tables.enemies[id].xp`와 같음 |
| T6-02 | 표 | 표끼리 | kind는 friend·upgrade·beam·lighthouse 중 하나. friend·upgrade의 target은 characters의 friend id, 친구마다 friend 카드 하나·upgrade 카드 하나. beam의 target은 width_deg·length, lighthouse의 target은 max_hp·regen. weight > 0, max_picks ≥ 0, value > 0, 이름·설명 네 칸 비어 있지 않음. 적 xp > 0 |
| T6-03 | 연습 판 | `xpNeeded`, `addXp` | 처음 level 1, xp 0, xpNeeded = 필요1. `addXp(필요1 − 1)`: level 1. `addXp(1)`: level 2, xp 0, xpNeeded = 필요2. 연습 판이라 `choice` null, `isPaused` 거짓 |
| T6-04 | 카드 판, 첫 창에서 `pickCard(0)` 하고 빈 자리 I0 눌러(`tapAt`) 놓은 뒤 | `addXp(필요1 + 필요2 + 1)` | level 3, xp 1, 창 열림(`choice` 길이 1~3), `pendingPicks` 1. `pickCard(0)` (놓기 상태가 되면 빈 자리 하나를 `tapAt`으로 눌러 놓음) 뒤 다시 창 열림, `pendingPicks` 0. 한 번 더 고르고(놓기면 놓고) 나면 `choice` null, `isPaused` 거짓 |
| T6-05 | 연습 판 | 오징어를 0° 거리 300에, `takeDamage(오징어.hp)`, 다시 `takeDamage(5)`, update(0) | `shards` 하나, 위치 = 오징어가 쓰러진 자리, value = 오징어 xp |
| T6-06 | 연습 판 | 방울을 0° 거리 300에서 쓰러뜨림 (조각은 (660, 660)). 시간 흘림 | shard_delay − 0.05초: 조각 위치 그대로. 그 뒤 날아가고, shard_delay + (300 − absorb_distance) ÷ shard_speed + 0.1초에 `shards` 비어 있고 xp = 방울 xp. 그 0.2초 전에는 아직 `shards`에 있고 xp 0 |
| T6-07 | 카드 판 | 판이 붙은 뒤 | `choice` = [friend_seahorse, friend_crab, friend_pufferfish], `isPaused` 참, `tray` null, `pendingPicks` 0, level 1, xp 0 |
| T6-08 | 카드 판 | `pickCard(1)` → `tapAt` 바다 (100, 1200) → `tapAt` I0 가운데 | pick 뒤 `choice` null, `placing` = crab, `isPaused` 참. 바다 누르기: 그대로. I0 누르기: I0에 게, `placing` null, `isPaused` 거짓 |
| T6-09 | 카드 판, 창 열림 | 멈춤: 연습 판처럼 방울을 0°에 (`spawnEnemy`), 1초 흘림. `aimBeamAt(360, 1000)` | 방울 distance 그대로(spawn_distance), 빛 방향 그대로 270. 첫 친구 고른 뒤(놓기 끝난 뒤) 1초: 방울이 움직였음 |
| T6-10 | 카드 판, 첫 창에서 해마를 골라 I3에 놓은 뒤 | 방울을 90°에 닿게 두고, `addXp(필요1)`로 창을 연 다음 3초 | 창이 열린 동안 방울 hp 그대로, 불빛 그대로, `bubbles` 위치 그대로 (멈춤). 해마 `cooldown` 그대로 |
| T6-11 | 연습 판 | `availableCards()` | 처음: friend 셋 + beam 둘 + lighthouse 둘 (upgrade 없음, 표 순서). `placeFriend('crab', I0)` 뒤 upgrade_crab 들어옴. `applyCard('upgrade_crab')`를 max_picks번 하면 빠짐. 18자리 모두 채우면 friend 셋 빠짐. `applyCard('beam_wide')` max_picks번 뒤 beam_wide 빠짐 |
| T6-12 | 연습 판, 씨앗 3 두 판 | 각각 `drawCards()` 다섯 번 | 두 판의 결과가 같다. 매번 서로 다른 id 3개, 모두 그때의 `availableCards()` 안. 고를 수 있는 카드가 2개뿐인 판(해마 1 + 게 17로 빈 자리 없음, beam·lighthouse 카드 모두 max까지 골라 upgrade 둘만 남김)에서는 2개 |
| T6-13 | 연습 판 | 게를 I3에, 방울을 90°에 닿게, `applyCard('upgrade_crab')` 두 번. windup + 0.05초 | `damageMultiplier('crab')` = value². 방울 hp = 처음 − damage × value² (빛 밖). 다른 종류 `damageMultiplier('seahorse')` = 1 |
| T6-14 | 연습 판 | `applyCard('beam_wide')`, `applyCard('beam_long')` | `beam.widthDeg` = width_deg + 10(값), `beam.length` = length + 80(값). 빛 270°에서 270 + (새 폭 ÷ 2 − 0.5)° 거리 300은 속, 거리 새 길이 − 1은 속 |
| T6-15 | 연습 판 | 방울을 0°에 닿게 두고 불빛을 bite만큼 깎이게 (bite_interval + 0.05초). `applyCard('light_up')` | maxLight = hp + value, light = 깎인 값 + value (최대를 넘지 않음) |
| T6-16 | 연습 판 | 방울 둘을 닿게 두어 불빛을 깎은 뒤 방울을 `takeDamage`로 모두 쓰러뜨림. `applyCard('light_regen')` 두 번, 2초 | `lightRegen` = 2 × value. 2초 뒤 light = 그때 + 2 × value × 2 (±0.05, 최대 넘지 않음) |
| T6-17 | 연습 판 | 조각 막대 | 처음 `ratio` 0, `levelText`에 "1". `addXp(필요1 ÷ 2)` 뒤 ratio 0.5. 막대가 판 위쪽 0~130 px 안, 불빛 막대보다 아래 |
| T6-18 | 카드 판 (위젯) | 창의 둘째 `CardView` 가운데를 누름 → I3 가운데를 누름 | 카드 셋이 판 안에서 서로 겹치지 않음. 누른 뒤 `placing` = crab. I3에 게, `isPaused` 거짓 |
| T6-19 | 카드 판 | 꺼진 뒤 | (해파리 다섯으로 불빛을 끈 것과 같은 판에서, 첫 친구를 놓은 뒤 끔) 꺼진 뒤 `addXp(필요1)`: level 2지만 창은 열리지 않음 (`choice` null) |
| T6-20 | (카드 008 리뷰) | `beam_boost_test.dart` | T8-04에 "c0 − 0.5 × friend_haste − 0.3 > 0" 단언, T8-03 변수 이름이 해파리 |
