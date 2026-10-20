# 숫자 표 (리드 소유)

게임의 숫자(친구·적·카드·웨이브·밤)는 여기 CSV에 둔다. 코드는 implementer가 만든 변환기로 표를 읽는다.
balancer는 이 숫자를 바꾸지 않고 `balance/proposals.md`에 제안한다. 리드가 보고 고친다.

| 표 | 뜻 | 단계 |
|---|---|---|
| `characters.csv` | 캐릭터 이름·편·화면 키 | 3 |
| `enemies.csv` | 적 체력·속도(게임 px/초)·한 번 갉는 양·갉는 간격(초)·몸 반지름·떨어뜨리는 빛 조각 값(`xp`, 6단계) | 4 |
| `beam.csv` | 빛 폭(도)·길이·느려짐 배율·받는 피해 배율·빛 속 친구의 쉬는 시간이 흐르는 배율(`friend_haste`, 카드 008) | 4 |
| `lighthouse.csv` | 등대 불빛(체력)·적이 나타나는 거리 | 4 |
| `friends.csv` | 친구 공격 방식(shot 쏘기 / melee 한 마리 / burst 둘레 모두)·사거리·피해·공격 간격(초)·거품 속도(쏘기만, 아니면 0) | 5 |
| `progression.csv` | 레벨에 드는 빛 조각(`xp_base` + `xp_step` × (레벨 − 1))·조각이 머무는 시간·나는 속도·등대가 빨아들이는 거리 | 6 |
| `cards.csv` | 레벨업 카드: 종류(friend·upgrade·beam·lighthouse)·대상·값·최대 고르기(0 = 제한 없음)·뽑힐 무게·이름과 설명(두 언어) | 6 |
| `practice.csv` | 연습 스폰 간격(초)·한꺼번에 있을 수 있는 적 수 (7단계 웨이브가 오면 없앤다) | 4 |

표를 바꾸면 `python tools/gen_tables.py`로 `lib/game/tables.g.dart`를 다시 만든다 (손으로 고치지 않는다).
