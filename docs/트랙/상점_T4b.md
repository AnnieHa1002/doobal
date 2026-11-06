# 상점 트랙 T4b 인계

칸 공용 위젯과 상점 화면을 만들어 쉼터 수레·보석에 끼웠다. 브랜치 `claude/shop-t4b-2d9533`. push·dev-batch 합치기 안 함.
**실기기는 안 돌렸다.** 맥에서 캡처로만 봤다. Drive 그림은 받지 않았고, 새 패키지와 `app_db.dart` 변경은 없다.

커밋은 순서대로 칸 위젯 → 상점 화면 → 화집 → 상점 칸 작은 고침 → 이 노트 → 꾸미기 교체다. **맨 끝 커밋이 `decorate_*`·`basic_item_art.dart` 교체**이고, 해시는 끝 보고에 있다.

## 시험 결과

- `flutter analyze` 깨끗.
- `test/domain test/app test/data test/widget_test.dart` 1,432개 통과.
- `test/ui` 53개 파일을 하나씩 돌려 838개 통과, 14개 건너뜀. 건너뛴 것은 `text_scale_test` 12개(원래 건너뛰는 것), `rest_capture_test`·`shop_capture_test` 각 1개(환경 변수가 있을 때만 돈다).
- 합계 2,270개 통과, 실패 0. `python3 data/check_data.py` 틀림 0·경고 0.

- 새 시험: `test/domain/asset_index_test.dart` 7, `test/ui/item_cell_test.dart` 12, `test/ui/shop_screen_test.dart` 19, `test/ui/decorate_screen_test.dart` 공용 칸 1, `test/ui/text_scale_test.dart` 상점 6.
- 눈으로 볼 때: `DOOBAL_SHOP_CAPTURE_DIR=<폴더> flutter test test/ui/shop_capture_test.dart` (390·375, 탭 4와 구매 시트). 환경 변수가 없으면 건너뛴다.
- 고친 기존 시험: `rest_stage_test`(수레가 기본으로 서서 ‘안 끼우면 빈자리’ 시험은 빈 슬롯을 직접 넣음), `album_screen_test`(줄 → 칸), `decorate_screen_test`(`ShelfCell` → `ItemCell`), `basic_item_art_test`(`BasicItemIcon` 삭제).

## 만든 곳

| 파일 | 내용 |
|---|---|
| `lib/domain/asset_index.dart` (새 파일) | 앱에 든 파일 목록에서 그림 찾기: `itemIcon`, `gem`, `file` |
| `lib/ui/common/item_cell.dart` (새 파일) | `ItemArt`(파일 또는 점선 + 이름), `ItemImage`, `ItemPlaceholder`, `ItemCell`(선반 + 꼬리표), `ItemShelf`(3열) |
| `lib/ui/shop/shop_screen.dart` (새 파일) | 탭 4, 선반, 잔액, 구매 시트·토스트 |
| `lib/ui/shop/shop_art.dart` (새 파일) | `LuckGemArt`, `ShopCartArt`(밤 랜턴 층 포함), `BoatShelfArt` |
| `lib/ui/shop/shop_slots.dart` (새 파일) | `openShop`, 쉼터 수레·보석 슬롯 |
| `lib/ui/rest/rest_slots.dart` | `restSlotsProvider`가 수레·보석을 채움. 상품이 없으면 입구를 숨김(스키마 13장) |
| `lib/app/sync_shop.dart` | `whyNotBuy`(시트를 열기 전에 막힘을 봄, `buyItem`도 같은 판정) |
| `lib/domain/shop.dart`, `rules.dart` | 값·질문·토스트 글. `config coins.format`의 `amount`·`buyQuestion`·`buyButton`을 읽음 |
| `lib/domain/camp_theme.dart` | `CampObject.artSourceFile`·`artSourceNight` |
| `lib/ui/common/confirm_sheet.dart` | 둘째 줄 `detail`(남는 럭). 안 주면 예전과 같다 |
| `lib/ui/album/*` | `PropRow` 삭제 → `PropSlotCard`(칸 이름·개수 + 선반) |
| `lib/ui/decorate/*`, `common/basic_item_art.dart` | `ShelfCell`·`BasicItemIcon` 삭제 → 공용 칸. `StampFace`는 그대로 |
| `pubspec.yaml`, `assets/items/icons/` | 칸 그림 폴더 등록 |

## 그림을 넣는 곳 (받으면 파일만 넣으면 된다, 코드 고칠 것 없음)

| 그림 | 넣을 곳 | Drive 파일(이름만 확인, 받지 않음) |
|---|---|---|
| 소품·상품 아이콘 | `assets/items/icons/` 이름에 id: `item_hat_02_icon_v01_clean.webp` | 소품 아이콘 37은 납품 전 |
| 여행 효과 2 | 같은 폴더 | `05_UI_화면/shop_effects_v01_검토_20261103/clean/ui_shop_fx_{shortcut,tailwind}_v01_clean.png` |
| 럭 보석 | `assets/ui/ui_gem_sky*` | `05_UI_화면/shop_luck_sky_v01/clean/ui_gem_sky_v01_clean.png` (`pile`·`small`은 안 읽음) |
| 수레·랜턴 | `assets/backgrounds/v11/` camp_wide `artSource` 이름 | `obj_rest_cart_v01_clean`, `obj_rest_cart_lantern_v01_clean` |
| 배 | `assets/boats/v01fix/` boats.json 이름. 칸은 뒤판 + 앞판을 줄여 얹음 | T4a 노트 |

- 찾는 순서: 아이콘 폴더 → 다른 소품 묶음의 `*_<id>_icon*`. WebP를 먼저, 그다음 새 버전. 그래서 옛 `basic_v02` 아이콘 6개는 지금 칸에 나오고, 새 파일이 오거나 폴더를 지우면 저절로 바뀐다.
- 수레·보석 그림이 오면 여백을 본다. 지금은 상자에 `contain`으로 넣고, 다른 물건처럼 `art.bbox`로 잘라 넣지 않는다.
- 색 소품 아이콘 `color_items_icons_21.png`은 한 장짜리 시트라 잘라야 이 규칙으로 읽힌다(T4c).

## 판단한 곳 (다르면 말해 주세요)

1. **점선 칸 안에도 이름을 쓴다.** 16장 ‘점선 + 이름’과 캔버스(칸 안 글자)를 따랐다. 꼬리표 이름과 겹친다. 글자는 캔버스 10pt 대신 최소 11pt(config `ui.fontPt.min`), 칸 크기 60×56.
2. **칸을 누르면 시트를 열기 전에 막힘을 본다.** 잔액 부족·보관 한도는 시트 없이 토스트만. 시트를 연 사이 럭이 줄면 사지 않고 까닭을 보여 준다. 가진 칸은 눌리지 않는다.
3. **막힘 문구는 T4a 가안 그대로**(`럭이 모자라요`, `더 보관할 수 없어요`). 토스트 `○○을 구매했어요`·`남는 럭 n`은 캔버스 글.
4. **구매 시트는 공용 시트**(`confirm_sheet.dart`)라 버튼이 위아래(구매 위, 취소 아래), 질문 16pt다. 캔버스는 좌우, 21pt. 토스트도 공용(아래 스낵바), 캔버스는 위.
5. **제목은 공용 머리(`ScreenHeader`)** 22pt, 캔버스 23pt.
6. **상품 순서는 shop.json `order`**. 연두 망토가 소품 3번째다(캔버스는 맨 끝).
7. **상점 칸에는 ‘입는 중’·고리를 안 쓴다.** 값 또는 ‘가짐’뿐(캔버스 8-1, `ringOp` 0). 공용 칸은 지원한다.
8. **배 탭은 뗏목 + 상점 6척**(캔버스). 얻은 조각배·돛단배는 안 보인다.
9. **수레 자리표시**는 점선 칸 + 상점 아이콘, 이름표 ‘상점’(캔버스 2-2). 쉼터 물건처럼 흔들리지 않는다.
10. **화집 칸은 꾸미기와 같은 84pt**다(캔버스 72pt, 그림 50×44). 공용 칸 하나로 두려고 줄이지 않았다. 캔버스의 ‘꾸미기에서 입어 보기’ 버튼은 범위 밖이라 안 넣었다.
11. **수레 랜턴은 밤·새벽에 얹는다**(배 창 불빛과 같은 기준, `artSource` 메모 ‘밤에 얹는 층(추정)’). 파일이 없어 그림은 못 봤고 층 수만 시험했다.
12. **광고 카드는 없다**(T7). 지금 상점 첫 줄은 탭이다.

## 만들지 않은 자리 (캔버스에 없음, 제안)

보드 15개(상점·쉼터·걷는 중·걷기 기록·지도·꾸미기·화집·나의 정보·동행·만남·도착·목적지·동네·설정·노트)와 메모를 찾았고 **둘 다 없다**. 그래서 사는 곳까지만 만들었다. 그래서 지금 **여행 효과를 사도 쓸 곳이 없고**, 몇 개 있는지도 안 보이며, **산 배로 갈아탈 수 없다.**

**여행 효과 쓰는 자리. 추천: 걷는 중 펼침 카드(3-1)에 ‘지름길 n · 순풍 n’ 쓰기 줄.** 순풍은 지금 엔진이 ‘열린 걷는 중에만’이라 이 자리면 DB를 안 고쳐도 된다. 지름길도 여정 중이면 된다. 칸 꼬리표에 ‘보관 n’을 더해 산 뒤 개수도 보이게 한다.
다른 안: 쉼터나 지도에서도 쓰기. 쉼터에서 순풍을 미리 켜려면 `ShopUses.usedUtc`가 필요해 DB 번호를 잡아야 한다.

**배 고르는 자리. 추천: 상점 배 탭에서 가진 배를 눌러 타기.** 뗏목·보상 배는 누르면 바로 갈아타고 토스트, 상점 배는 T4c 색 시트 안에 ‘이 배 타기’. 타는 배 꼬리표는 ‘타는 중’ + 고리(ItemCard `is-equipped`). 얻은 보상 배도 선반에 올린다. 엔진은 `chooseBoat`로 이미 있다.

둘 다 기획 변경이라 확정하지 않았다. 답이 오면 약 0.5일씩(추정).

**시험과 묶인 점:** 요청의 ‘하루 한도·여정 없을 때 막힘’은 살 때가 아니라 쓸 때의 규칙이다. 그래서 화면 시험은 ‘살 때는 안 막힌다’를 보고, 쓸 때의 막힘과 문구는 `useTravelEffect`로 직접 본다.

## 디자인 기획에 물을 것

- 위 두 자리.
- 점선 칸 안 이름이 꼬리표와 겹치는데 뺄지(판단 1).
- **수레 알림 점 조건.** 캔버스 2-2에 점과 ‘새 상품 있음’이 있지만 언제 켜는지 없다. 지금 안 켠다. 상품이 바뀌지 않는 MVP라 빼는 쪽을 추천.
- 소품 순서 shop.json과 캔버스 중 어느 쪽인지(판단 6).
- 기본 소품 6개의 옛 아이콘(`basic_v02`, 폐기된 묶음)을 칸에 계속 쓸지(계획 문서 7장에서 이어짐). 지금 쓴다.

## 개발 기획에 물을 것

- 소품 아이콘 37 납품 이름에 소품 id가 들어가게. 안 들어가면 넣을 때 이름만 바꾼다.
- `shop.json priceFormat`과 `config coins.format.amount`가 같은 값이 두 곳이다. 앱은 config를 읽는다. `shop.json maxHold`와 `config shop.maxHoldPerItem`도 같고 앱은 config를 읽는다(T4a).
- 명세 M4.5 ⑨ ‘상품 설명 없음’대로 효과 설명이 없다. 지름길·순풍이 무엇인지 화면 어디에도 없다. 쓰는 자리와 같이 본다.

## 폰 확인 대기에 더할 줄 (`개발_인계.md`는 통합 세션이)

- 쉼터 끝까지 밀어 수레 자리표시·이름표 ‘상점’, 눌러서 상점. 보석 눌러서 상점, 돌아오면 쉼터 숫자가 바뀌는지.
- 탭 4, 선반 칸, 점선 칸 글자, 구매 시트(남는 럭), 토스트 자리, 잔액 갱신.
- 잔액 부족·보관 9개 토스트. 소품을 산 뒤 배낭 점, 꾸미기 칸(점선 + 이름, 정령에는 안 그림).
- 화집 소품 탭 새 모양. 꾸미기 칸(기본 소품 6개는 64×64 그림).
- 그림 파일을 하나 넣어 칸이 바뀌는지(릴리스 빌드 파일 목록 포함).

## 합칠 때 함께 고칠 것

**통합 폴더의 꾸미기 수정 5개 파일과 겹치는 곳. 맨 끝 커밋과 부딪힌다.** 공용 칸이 그 동작(그림 64×64, `cacheWidth` 192)을 이어받았으니 이렇게 푼다.

| 파일 | 푸는 법 |
|---|---|
| `common/basic_item_art.dart` | 이쪽을 쓴다. `BasicItemIcon`이 없어져 `cacheWidth` 변경이 필요 없다 |
| `decorate/decorate_widgets.dart` | 이쪽을 쓴다. `ShelfCell`이 없어졌다 |
| `decorate/decorate_tabs.dart` | 이쪽을 쓴다. `art:` 인자와 `basic_item_art` import는 필요 없다 |
| `decorate/figure_preview.dart` | 저쪽을 쓴다. 이 브랜치는 안 고쳤다 |
| `test/ui/decorate_screen_test.dart` | 둘 다 남긴다. 저쪽 새 시험의 `find.byType(BasicItemIcon)` → `find.byType(Image)`, `basic_item_art` import 삭제 |

그 밖:

- `rest_slots.dart`: T2b가 `companion:`을 더할 때 상품 없음 갈래(`const RestSlots()`)에도 동행을 넣는다. 쉼터 슬롯은 `shopCartSlot`·`shopGemSlot`.
- `rules.dart`: 생성자·필드·`fromJson`에 세 줄씩(`coinAmountFormat`, `coinBuyQuestion`, `coinBuyButton`). T4c·T2와 겹치면 양쪽 다 남긴다.
- `Palette`에 `terracottaDeep`, `line`, `lineDashed`를 더했다. `decorate_widgets`의 `lineColor`는 같은 값이고 합치기 편하게 그대로 뒀다(T5가 정리).
- `CLAUDE.md` 구조 줄: `assets/items/icons/`(칸 그림), `lib/ui/shop/`.
- 계획 문서: 칸 공용 위젯·T4b 체크, 남은 것은 ‘쓰는 자리·배 고르는 자리(답 대기)’. 7장의 `ShelfCell` 줄 정리.
- `test/ui/ui_env.dart`: `UiEnv(assets:)`로 파일 목록을 바꿀 수 있다. `assetIndexProvider`는 `syncServiceProvider`가 기다리지 않아서 다른 시험의 override 목록에는 안 더했다.

## 다른 트랙이 알 것

- **T4c:** 색 소품은 `shop.json colorVariantItems`와 `props.json`에서 읽어 소품 탭 아래 ‘색 소품’ 묶음으로. 칸은 `ItemCell` + 색 상자(캔버스 56×50) 또는 아이콘. 가진 배를 누르는 동작이 지금 없다(`onTap: null`)라 색 시트는 `_cells`의 `owned` 갈래에서 건다. `ItemArt`는 `item.propId ?? item.id`로 찾는다.
- **T5:** `decorate_*`의 칸은 이제 `ItemCell`이다. 정령에 그리는 소품 파츠와 칸 아이콘은 따로다.
- **T7:** 광고 카드는 `shop_screen.dart`의 탭 위. 캔버스 8-1 첫 카드.
- **T2b:** `restSlotsProvider` 위 줄.
