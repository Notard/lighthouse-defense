# 숫자 표 (리드 소유)

게임의 숫자(친구·적·카드·웨이브·밤)는 여기 CSV에 둔다. 코드는 implementer가 만든 변환기로 표를 읽는다.
balancer는 이 숫자를 바꾸지 않고 `balance/proposals.md`에 제안한다. 리드가 보고 고친다.

| 표 | 뜻 | 단계 |
|---|---|---|
| `characters.csv` | 캐릭터 이름·편·화면 키 | 3 |
| `enemies.csv` | 적 체력·속도(게임 px/초)·한 번 갉는 양·갉는 간격(초)·몸 반지름 | 4 |
| `beam.csv` | 빛 폭(도)·길이·느려짐 배율·받는 피해 배율 | 4 |
| `lighthouse.csv` | 등대 불빛(체력)·적이 나타나는 거리 | 4 |
| `practice.csv` | 연습 스폰 간격(초)·한꺼번에 있을 수 있는 적 수 (7단계 웨이브가 오면 없앤다) | 4 |

표를 바꾸면 `python tools/gen_tables.py`로 `lib/game/tables.g.dart`를 다시 만든다 (손으로 고치지 않는다).
