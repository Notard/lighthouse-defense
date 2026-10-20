# 7단계 웨이브·보스·이김과 짐 테스트 표 (카드 010)

> 설계: `docs/design.md` §7. 숫자는 CSV를 직접 읽는다. 시간은 `game.update(0.05)` 되풀이, 경계는 ±0.05초 바깥. "웨이브 판" = `LighthouseGame(waves: true)` (카드 없음, 연습 없음). "모두 쓰러뜨림" = 그때 `enemies` 중 쓰러지는 중이 아닌 것마다 `takeDamage(hp)`.
> 마지막 줄들(T7-15~19)은 카드 009 리뷰에서 미룬 멈춤 테스트 보강.

| 번호 | 주어진 것 | 행동 | 기대값 |
|---|---|---|---|
| T7-01 | 표 | `Tables`와 비교 | `waves.csv` 모든 줄이 `Tables.waves`와 같고 수·순서 같음. `wave_rules.csv`가 `Tables.waveRules`와 같음. `enemies.csv`의 art·scale·boss가 같음 (boss는 1 → 참) |
| T7-02 | 표 | 표끼리 | 웨이브 번호는 1부터 빈틈없이 이어지고 번호마다 줄이 하나 이상. 모든 enemy가 enemies에 있음. 보스(boss 1)는 웨이브 5와 10에만, 그리고 5와 10에는 보스가 하나 이상. enemies에서 boss 0인 id 모음 = characters의 enemy id 모음. 모든 art가 characters의 enemy id. scale > 0. count ≥ 1, interval > 0, delay ≥ 0 |
| T7-03 | 웨이브 판 | 시간 흘림 | first_delay − 0.05초: `wave` 0, `isResting` 참, `enemies` 비어 있음. first_delay + 0.05초: `wave` 1, `isResting` 거짓, `banner`에 "1"이 들어 있음 |
| T7-04 | 웨이브 판 | `startWave(1)` 뒤 시간 흘림 (적은 쓰러뜨리지 않음) | 웨이브 1 첫 줄 기준 delay + k × interval − 0.05초에는 `waveSpawned` = k, + 0.05초에는 k + 1 (k = 0, 1, 2). 결국 `waveSpawned` = 웨이브 1 count 합계, 그 뒤로 늘지 않음 |
| T7-05 | 웨이브 판 | `startWave(1)`. 다 나오기 전에 나온 적을 모두 쓰러뜨림 (deathSeconds + 0.1초 흘림) | 아직 다 안 나왔으므로 `isResting` 거짓, `wave` 1 |
| T7-06 | 웨이브 판 | `startWave(1)`, 다 나올 때까지 흘리며 나오는 대로 모두 쓰러뜨림 | 마지막 적이 쓰러진 뒤(그 update) `isResting` 참. rest − 0.05초 뒤 `wave` 1, rest + 0.05초 뒤 `wave` 2, `waveSpawned` 0에서 다시 셈 |
| T7-07 | 웨이브 판, 씨앗 4 두 판 | 각각 `startWave(2)`, 6초 흘림 | 두 판의 적 각도 목록이 같다. 모두 0 이상 360 미만, id는 웨이브 2 줄의 적 |
| T7-08 | 웨이브 판 | `startWave(5)`, update(0.05) | `banner` = `Strings.bossComing`. 나온 적 중 boss_squid가 있고 그 `stats`가 표, `contactDistance` = 100 + 보스 radius |
| T7-09 | 웨이브 판 | `startWave(waveCount)`, 다 나올 때까지 흘리며 나오는 대로 모두 쓰러뜨림 (보스 포함) | 마지막 적이 쓰러진 뒤 `result` = won, `isOver` 참, `resultPanel` 있음(다음 프레임에 붙어도 됨). 그 뒤 3초: `elapsed` 그대로, `enemies` 수 그대로 |
| T7-10 | 웨이브 판 | 해파리 다섯을 닿게 두어 불빛을 끔 (T4-07처럼) | `result` = lost, `isOver` 참, `resultPanel` 있음, `LightOutText` 없음. (연습 판 `LighthouseGame()`에서는 지금처럼 `LightOutText`이고 `result` = lost) |
| T7-11 | 웨이브 판 | 오징어 셋을 거리 300에 두고 차례로 `takeDamage(hp)`, 하나는 두 번 | `defeated` 3 |
| T7-12 | 웨이브 판 | 10초 흘림, 그 뒤 카드 판처럼 멈춤은 없으니 `result`를 만들어(불빛 끄기) 3초 더 | `elapsed` ≈ 10 + 불빛이 꺼질 때까지 걸린 시간 (±0.1), 꺼진 뒤 그대로. `resultPanel.lines`에 웨이브 글(`Strings.resultWave(wave, waveCount)`), 쓰러뜨린 수, 레벨, 시간 글이 있다 |
| T7-13 | 웨이브 판 `onRestart`에 셈하는 콜백 (위젯) | 불빛을 끈 뒤 `restartButton` 가운데를 누름 | 콜백이 한 번 불림. 단추가 판 안 |
| T7-14 | 웨이브 판 | 웨이브 글 | 처음 `WaveLabel.text` = `Strings.wave(1, waveCount)`, `TitleText` 없음. `startWave(3)` 뒤 `Strings.wave(3, waveCount)`. 연습 판에는 `TitleText` 있고 `WaveLabel` 없음 |
| T7-15 | `LighthouseGame(practice: true, seed: 1)` | 60초 흘림 (꺼지면 멈춤) | `spawner.spawned`에 보스 id 없음 |
| T7-16 | 카드 판(`cards: true, waves: true`) | 첫 친구를 고르기만 하고(놓기 상태) 10초 | `wave` 0, `isResting` 참, 웨이브 시간이 흐르지 않음: 그 뒤 놓고 first_delay + 0.05초에 `wave` 1 |
| T7-17 | 카드 판 (`cards: true`), 첫 친구 해마를 I3에 놓은 뒤 | 방울을 I3 쪽(90°) 거리 300에 두고 해마가 거품을 쏘게 흘림 (거품이 생길 때까지). 거품이 날 때 `addXp(xpNeeded)`로 창을 열고, 거품 위치를 적은 뒤 2초 | 거품 위치 그대로, `bubbles` 수 그대로 |
| T7-18 | 카드 판, 첫 친구를 놓은 뒤 | 오징어를 0° 거리 300에서 쓰러뜨려 조각이 날기 시작한 뒤(shard_delay + 0.1초) `addXp(xpNeeded)`로 창을 열고 2초 | 조각 위치 그대로. `applyCard('light_regen')`로 regen을 준 판에서 창을 연 동안 light 그대로 |
| T7-19 | 카드 판 | 첫 친구 게를 I0에 놓기 전(놓기 상태) 방울을 0°에 두고 2초 / 연습 판에서 `applyCard('upgrade_crab')` 뒤 게를 I3에 놓고 방울을 90°에 닿게 windup + 0.05초 | 놓기 상태에서 방울 distance 그대로 / 방울 hp = 처음 − damage × value (나중에 놓은 친구에도 배율) |
