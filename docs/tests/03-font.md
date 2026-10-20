# 3단계 글꼴·문구 테스트 표

> 설계: `docs/design.md` §3. 글꼴 파일은 `assets/fonts/Jua.ttf` (TrueType `cmap` 표를 읽어 글자가 있는지 본다).

| 번호 | 주어진 것 | 행동 | 기대값 |
|---|---|---|---|
| T3-01 | 저장소 | `assets/fonts/Jua.ttf`와 `assets/fonts/OFL.txt`가 있는지 본다 | 둘 다 있다. `pubspec.yaml`에 글꼴 family `Jua`로 `assets/fonts/Jua.ttf`가 등록되어 있다 |
| T3-02 | 글꼴 파일 | 영문·숫자·기본 기호(U+0020~U+007E, 백틱 U+0060 빼고)가 있는지 본다 | 빠진 글자 없음 |
| T3-03 | `Strings.lang` = ko, 그다음 en | 두 언어의 `Strings.title`, `Strings.subtitle` 글자 | 모두 글꼴에 있다 |
| T3-04 | `lib/` 아래 모든 `.dart` | 작은따옴표·큰따옴표 문자열에 쓰인 글자 (주석 `//` 뒤는 빼고) | U+007E보다 큰 글자가 모두 글꼴에 있다. 빠지면 어느 파일의 어떤 글자인지 알려 준다 |
| T3-05 | `Strings.lang` = ko | `Strings.title`, `Strings.subtitle` | '등대 지키기', '밤바다 등대를 지켜요' |
| T3-06 | `Strings.lang` = en | `Strings.title`, `Strings.subtitle` | 'Lighthouse Keepers', 'Keep the lighthouse shining' |
| T3-07 | 새 판 (`Strings.lang` = ko) | 제목 컴포넌트를 본다 | 글은 `Strings.title`('등대 지키기'), 글꼴 family는 `GameConfig.fontFamily`('Jua') |
| T3-08 | 없음 | `GameConfig.fontFamily` | 'Jua' |
| T3-09 | `lib/` 아래 모든 `.dart` (`strings.dart` 빼고) | 문자열 안의 한글(가~힣) | 없다 (화면 글은 `Strings`에서만). 주석은 상관없음 |

- 언어를 바꾸는 테스트는 끝나면 `Strings.lang`을 `Lang.ko`로 되돌린다
