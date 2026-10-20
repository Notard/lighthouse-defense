# 4단계 적·등대 불빛·빛줄기 테스트 표 (카드 006)

> 설계: `docs/design.md` §4. 숫자는 테스트에 박지 말고 **CSV를 직접 읽어** 쓴다 (표를 바꿔도 테스트가 맞게). 아래 괄호 안 숫자는 지금 표의 값으로 든 예.
> 시간은 `game.update(0.05)`를 되풀이해 흘린다 (따로 적지 않으면). 좌표 허용 오차 ±0.5, 시간 경계는 ±0.05초 바깥에서 본다. 판은 연습 스폰을 끈 `LighthouseGame()` (따로 적지 않으면). 그림을 읽기 전이어도 규칙은 같아야 한다 (그림을 기다리지 않는다).

| 번호 | 주어진 것 | 행동 | 기대값 |
|---|---|---|---|
| T4-01 | `data/tables/*.csv` | `Tables`와 비교 | `enemies.csv` 모든 줄의 값이 `Tables.enemies[id]`와 같고 그 수도 같다. `beam.csv`·`lighthouse.csv`·`practice.csv`의 한 줄이 `Tables.beam`·`lighthouse`·`practice`와 같다. `characters.csv` 모든 줄이 `Tables.characters[id]`와 같다 |
| T4-02 | `enemies.csv`, `characters.csv` | 표끼리 | enemies에서 boss 0인 id 모음 = characters에서 kind가 enemy인 id 모음 (카드 010에서 보스 줄이 생겨 고침). hp·speed·bite·bite_interval·radius 모두 0보다 큼. beam의 slow는 0보다 크고 1 이하, vulnerable은 1 이상. lighthouse의 spawn_distance는 등대 가운데(360, 660)에서 판 네 귀퉁이까지 거리 중 가장 먼 것보다 큼 |
| T4-03 | 새 판 | `spawnEnemy('shadow_blob', 0)`, `spawnEnemy('ink_squid', 90)` 뒤 한 번 update(0) | 판의 `enemies`에 둘. 첫째 위치 = (360 + spawn_distance, 660), 둘째 = (360, 660 + spawn_distance). 둘 다 상태 moving, hp = 표의 hp, `distance` = spawn_distance |
| T4-04 | 새 판 (빛 270°) | 그림자 방울을 0°에 (빛 밖), 1초 흘림 | distance = spawn_distance − speed × 1, 위치의 y는 660 그대로, 각도 그대로 |
| T4-05 | 새 판 | 오징어를 0°에, 거리 = 닿는 거리 + 10에서. 1초 흘림 | distance = 닿는 거리(100 + radius) 정확히(넘어가지 않음), 상태 biting. `contactDistance` = 100 + radius |
| T4-06 | 새 판 | 그림자 방울을 0°, 닿는 거리에서 나타나게 하고 시간을 흘림 | bite_interval − 0.05초에는 불빛 = 처음 그대로. bite_interval + 0.05초에 처음 − bite. 3 × bite_interval + 0.05초에 처음 − 3 × bite. 위치는 움직이지 않음 |
| T4-07 | 새 판 | 그림자 해파리 다섯을 72° 간격, 닿는 거리에서. 불빛이 꺼질 때까지 흘리고(길어도 120초) 그 뒤 5초 더 | 불빛은 0 아래로 안 내려가고 끝에 정확히 0. 0이 된 그때 `isOver` 참, 판에 `LightOutText` 하나. 그 뒤 5초 동안 불빛·적 위치·상태 그대로. 꺼진 뒤 `aimBeamAt`·`tapAt`을 불러도 빛 방향·고른 자리 그대로. 꺼지기 전 `isOver` 거짓, `LightOutText` 없음 |
| T4-08 | 새 판 | `beam.contains` | `beam.widthDeg`·`length` = 표 값. 빛 270°: 등대에서 270° 거리 300 속, 290°(경계) 거리 300 속, 290.5° 밖, 270° 거리 length 속, length + 1 밖, 90° 거리 100 밖. 빛 350°: 5° 거리 300 속, 15° 밖. 빛 10°: 355° 속, 335° 밖 |
| T4-09 | 새 판 (빛 270°) | 그림자 방울 둘을 거리 600에서, 하나는 270°(빛 속), 하나는 90°. 1초 흘림. 다시 새 판에서 270°에 하나, 0.5초 흘린 뒤 `aimBeamAt`로 빛을 90° 쪽으로 돌리고 0.5초 더 | 빛 속 하나는 `inBeam` 참, 움직인 거리 = speed × slow, 다른 하나는 거짓, speed. 돌린 경우 움직인 거리 = speed × slow × 0.5 + speed × 0.5, 돌린 뒤 `inBeam` 거짓 |
| T4-10 | 새 판 (빛 270°) | 해파리를 270° 거리 300(빛 속), 다른 해파리를 90° 거리 300에. 각각 `takeDamage(10)` | 빛 속: 10 × vulnerable 을 돌려주고 hp가 그만큼 줄어듦. 밖: 10을 돌려주고 10 줄어듦 |
| T4-11 | 새 판 | 오징어를 0° 거리 300에. `takeDamage(hp)`, 그 뒤 시간 흘림 | 바로 상태 dying. 그 뒤 위치 그대로, 다시 `takeDamage(5)`는 0을 돌려주고 hp 그대로. deathSeconds − 0.05초에는 `enemies`에 있음, deathSeconds + 0.05초에는 `enemies`와 판에서 빠짐. 닿는 거리에서 쓰러진 적은 더 갉지 않는다 (bite_interval × 3 흘려도 불빛 그대로) |
| T4-12 | 새 판 | 불빛 막대 | 처음 `ratio` 1. 그림자 방울을 닿는 거리에서 bite_interval + 0.05초 흘린 뒤 `ratio` = (maxLight − bite) ÷ maxLight. 막대 `position`·`size`가 판 위쪽 0~100 px 안, 가로 0~720 안, 너비가 판 너비의 절반 넘음 |
| T4-13 | `LighthouseGame(practice: true, seed: 7)` 두 판 | 각각 3 × interval + 0.05초 흘림 | 두 판의 `spawner.spawned`가 같고 3개. id는 모두 enemies 표의 id, 각도는 0 이상 360 미만. 씨앗 8인 판과는 다르다 |
| T4-14 | `LighthouseGame(practice: true, seed: 1)` | 꺼질 때까지(길어도 300초) 흘리며 매번 본다 | 쓰러지는 중이 아닌 적 수가 max_alive를 넘은 적이 없다. 꺼진 뒤 interval × 3 흘려도 `spawned` 수 그대로 |
| T4-15 | 새 판 `LighthouseGame()` | 30초 흘림 | `spawner`는 null, `enemies` 비어 있음 |
