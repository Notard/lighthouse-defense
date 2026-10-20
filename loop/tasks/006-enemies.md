# 006-enemies

- **목표 (한 문장)**: 숫자 표와 변환기를 만들고, 적이 사방에서 등대로 다가와 불빛을 갉으며, 빛줄기 속 적은 느려지고 약해지게 한다 (연습 스폰으로 확인).
- **하지 않을 것**: 친구 놓기·공격(5단계), 빛 조각·카드(6단계), 웨이브·결과 창·다시 하기(7단계), 소리, 빛 효과 카드
- **관련 문서**: `docs/design.md` §4, `docs/tests/04-enemies.md` (T4-01~15), `docs/acceptance/04-enemies.md` (A4-1~7), 표 `data/tables/*.csv` (리드 소유, 읽기만)
- **맡는 순서**: tester → implementer(변환기 → 적·빛·불빛 → 연습 스폰 → 그림 → 도구 일) → 사용자 미리보기 → reviewer
- **끝내는 조건**:
  - [x] T4-01~15 테스트 있고 통과
  - [x] `bash tools/loop/check.sh implementer` 통과
  - [x] `python tools/gen_tables.py --check` 통과
  - [x] 사용자 확인 (A4-3~6, "응": 정면 그대로, 갉기 맞추기는 다음으로)
  - [x] reviewer 승인
- **바퀴**: 1 / 3

## implementer 참고
- 글을 더하므로 글꼴을 다시: `python tools/subset_font.py "C:/Users/elbre/AppData/Local/Temp/claude/C--forest-defense/259dfae4-2eb0-4b9b-9b79-e0a74836419c/scratchpad/jua_dl/Jua-Regular.ttf"` (원본은 저장소에 넣지 않음)
- 적 그림은 `CharacterArt` (카드 004·005). 판이 그림을 기다리지 않게 (읽기 전에는 원)
- 그림이 보는 쪽은 `assets/images/<id>/move.webp`를 보고 정한다
- 리드가 미리보기로 볼 수 있게 연습 판 스크린숏 `preview/06_practice.jpg`를 남겨도 됨 (허용 경로 아님 → 만들지 말고 보고만, 리드가 찍는다)

## 바퀴 기록
- **1바퀴** (2026-10-20): tester T4-01~15 (빨간 불, 모호한 점 둘 → 설계 정리) → implementer 65/65 (결정 요청: 적 리그 strip_rim → 여섯 모두 켬, 빛 여유 1e-6 모자람 → 1e-3, Flame 이름 겹침 둘) → 리드 웹 확인·스크린숏 → reviewer 승인 (꼭 고칠 것 없음, 미룰 것 다섯은 STATE)
