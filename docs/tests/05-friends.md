# 5단계 친구 놓기·자동 공격 테스트 표 (카드 007)

> 설계: `docs/design.md` §5 (와 §4). 숫자는 테스트에 박지 말고 **CSV를 직접 읽어** 쓴다 (괄호 안은 지금 값의 예). 시간은 `game.update(0.05)` 되풀이, 시간 경계는 ±0.05초 바깥에서 본다. 판은 `LighthouseGame()` (연습 스폰 꺼짐, 빛 270°). 좌표 허용 오차 ±0.5.
> "닿게 둔 적" = `spawnEnemy(id, 각도, distance: 그 적의 닿는 거리)` (움직이지 않고 갉는 적이라 과녁 시험에 쓴다). `I3` = 아래 안쪽 자리 (360, 810).

| 번호 | 주어진 것 | 행동 | 기대값 |
|---|---|---|---|
| T5-01 | `friends.csv`, `characters.csv` | `Tables.friends`와 비교 | 모든 줄 값이 같고 수도 같다. id 모음 = characters에서 kind가 friend인 id 모음. attack은 shot·melee·burst 중 하나, range·damage·interval은 0보다 큼, shot이면 projectile_speed > 0 |
| T5-02 | 새 판 | `placeFriend('crab', I0)`, 다시 `placeFriend('seahorse', I0)`, `placeFriend('seahorse', O5)` | 첫째는 Friend를 돌려주고 `I0.friend`가 그것, 위치 = I0 가운데. 둘째는 null, I0은 여전히 게. 셋째 성공. `friends` = [게, 해마] (놓은 순서) |
| T5-03 | 새 판 (위젯) | 쟁반 | 단추 셋, `friendId` 순서 seahorse·crab·pufferfish. 단추마다 판 안, y가 1000 넘고 1280 이하, 서로 겹치지 않음. 처음 `held` null |
| T5-04 | 새 판 (위젯) | 해마 단추 누름 → `O3` 누름 → `O4` 누름 → 해마 단추 다시 누름 → `O6` 누름 | 단추 누른 뒤 `held` = seahorse, 고른 자리 그대로(없음). O3·O4에 해마, `held`는 계속 seahorse, 고른 자리 없음. 다시 누르면 `held` null. 그 뒤 O6 누르기는 친구를 놓지 않고 O6을 **고른다** (2단계 규칙) |
| T5-05 | 새 판 (위젯) | 게 단추 → I0 누름 → 복어 단추 → I0 누름 | 두 번째 I0 누르기는 아무 일 없음: I0은 게, `friends` 하나, `held` = pufferfish |
| T5-06 | 새 판 | 게를 I3에, 그림자 방울을 0°에 닿게 (사거리 밖). 5초 | 방울 hp 그대로, 게 `isAttacking` 한 번도 참 아님, `target` null |
| T5-07 | 새 판 | 게를 I3에, 그림자 방울을 90°에 닿게. 시간 흘림 | windupSeconds − 0.05초: hp 그대로, `isAttacking` 참, `target` = 방울. windup + 0.05초: hp − damage. interval + windup − 0.05초: 그대로. interval + windup + 0.05초: hp − 2 × damage |
| T5-08 | 새 판 | 복어를 I3에, 해파리 셋을 80°·90°·100°에 닿게, 해파리 하나를 270°에 닿게. windup + 0.05초 | 아래 셋은 hp − damage, 위 하나는 그대로 |
| T5-09 | 새 판 | 해마를 I3에, 오징어를 80°에, 해파리를 100°에 닿게 (둘 다 사거리 안, 오징어가 등대에 더 가까움). windup − 0.05초, windup + 0.5초 | 처음 `target` = 오징어. windup + 0.05초 때 `bubbles` 하나, 그 위치가 I3 가운데에서 60 안. windup + 0.5초: 오징어 hp − damage, 해파리 그대로, `bubbles` 비어 있음 |
| T5-10 | 새 판 | 게를 I3에, 방울을 90°에 닿게. 빛을 90° 쪽으로 (`aimBeamAt(360, 1000)`). windup + 0.05초 | 방울 hp − damage × vulnerable |
| T5-11 | 새 판 | 해마를 I3에, 오징어를 90° 거리 400에서 (사거리 안, 움직임). windup + 0.05초에 거품이 있는지 보고 바로 `오징어.takeDamage(오징어.hp)`. 1초 더 | windup + 0.05초에 `bubbles` 하나. 1초 뒤 `bubbles` 비어 있고, 오징어 hp는 쓰러뜨린 직후 값 그대로 (터진 거품이 피해를 주지 않음) |
| T5-12 | 새 판 | 게를 I3에, 방울을 90°에, 해파리를 100°에 닿게 (방울이 과녁). windup − 0.1초에 방울 `takeDamage(방울.hp)`. windup + 0.05초 | 해파리 hp 그대로 (헛침, 다른 적으로 바꾸지 않음) |
| T5-13 | 새 판 | 게를 I3에, 방울을 90°에 닿게. 방울이 쓰러질 때까지(길어도 10초) 흘림. 그 뒤 deathSeconds + 0.1초 | 쓰러지는 데 든 공격 횟수 = ceil(방울 hp ÷ damage). 쓰러진 뒤 게 `target`은 쓰러진 방울이 아님(null), `isAttacking` 거짓으로 남음. deathSeconds 뒤 방울은 `enemies`에 없음 |
| T5-14 | 새 판 | 방울을 0°에 (빛 밖, 움직임). `game.update(5.0)` 한 번 | distance = spawn_distance − speed × maxFrameDt (5초가 아니라 0.1초만) |
| T5-15 | 새 판 | 방울을 0°, 거리 = 닿는 거리 − 20에서. update(0.05) 한 번, 그 뒤 흘림 | 첫 update 뒤 distance = 닿는 거리, 상태 biting, 불빛 그대로. 첫 update 뒤부터 센 시간으로 bite_interval − 0.05초에 불빛 그대로, bite_interval + 0.05초에 처음 − bite |
| T5-16 | 새 판 | 해파리 다섯을 18°·90°·162°·234°·306°에 닿게, 불빛이 꺼질 때까지(길어도 120초). 꺼진 뒤 `placeFriend('crab', I3)` 하고 3초 | 90° 해파리 hp 그대로, 게 `isAttacking` 거짓, `bubbles` 비어 있음 |
| T5-17 | 새 판 (위젯) | 꺼진 뒤(T5-16처럼) 게 단추 누름 | `held` 그대로 (null) |
