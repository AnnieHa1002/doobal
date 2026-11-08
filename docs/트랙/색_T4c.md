# 색 소품 트랙 T4c 인계

색 소품 21개(props.json `variantOf`)를 상점에서 사고 꾸미기에서 입게 했다. 브랜치 `claude/color-t4c-c66e40`, main `8e5e3e2`에서 시작. push·dev-batch 합치기 안 함.
**실기기는 안 돌렸다.** Drive 그림은 받지 않았고, 새 패키지·`app_db.dart`·데이터 JSON 변경은 없다.
상점 배 6척 색 고르기, 기본 옷 색 고르기, 정령에 색 입히기는 범위 밖이라 안 했다.

## 시험 결과

- `flutter analyze` 깨끗. `python3 data/check_data.py` 틀림 0·경고 0.
- `test/domain test/app test/data test/widget_test.dart` 1,451개 통과.
- `test/ui` 53개 파일을 하나씩 돌려 849개 통과, 14개 건너뜀(`text_scale_test` 12, `rest_capture_test`·`shop_capture_test` 각 1, 환경 변수가 있을 때만 돈다).
- 합계 2,300개 통과, 실패 0. 코드 커밋 `6e20bda`에서 돌렸다.

## 만든 곳

| 파일 | 내용 |
|---|---|
| `lib/domain/prop.dart` | `Prop.requires`(unlock.requires)·`variantOf`·`colorName`(color)·`materialArgb`(material.hex), `isColorVariant`. hex 모양이 틀리면 멈춤 |
| `lib/domain/color_props.dart` (새 파일) | `havePropIds`(얻은 기록 + 처음부터 가진 기본 소품), `baseHeld`, `variantsAfterBase`(색 소품을 기본 소품 바로 뒤로), `colorShopItems`·`colorShopItem`·`shownColorItems`(색 소품 → 상품, 값은 props `unlock.price`) |
| `lib/domain/shop.dart` | `ShopItem.requires`, `ShopBlock.needsBase`('아직 살 수 없어요', 가안), `buyBlock(hasRequired:)` |
| `lib/app/sync_shop.dart` | `_shopItem`: shop.json에 없으면 색 소품. `whyNotBuy`가 기본 소품을 본다. `buyItem`은 같은 트랜잭션(spend 줄 + 얻은 소품, `seen` false) |
| `lib/app/sync_service.dart` | import 한 줄(`color_props.dart`)만 |
| `lib/ui/common/item_cell.dart` | `ItemSwatch`(56×50, 둥근 14, 잉크 1.4), `ItemArt(swatch:)`, `ItemArt.prop(p)`. 그림 파일 → 색 상자 → 점선 + 이름 순서 |
| `lib/ui/shop/shop_screen.dart` | 소품 탭 아래 `색 소품` 제목 + 선반(캔버스 8-1). 기본 소품을 가진 것만, 없으면 제목도 없음 |
| `lib/ui/decorate/decorate_screen.dart`, `decorate_tabs.dart` | 칸 목록을 `variantsAfterBase` 순서로, 기본 소품이 없으면 색 소품 숨김, 칸 그림 `ItemArt.prop` |
| `lib/ui/album/album_screen.dart`, `album_widgets.dart` | 소품 탭도 같은 순서·색 상자 |

입기는 따로 고칠 것이 없었다. 색 소품은 기본 소품과 같은 `slot`이라 `Look.withSlot`이 기본 소품을 벗긴다(한 칸에 하나). `Look` JSON은 소품 id 문자열이고 백업은 `PropsOwned`·`Profile.look`을 그대로 옮겨서 왕복이 된다(시험으로 확인).

## 판단한 곳 (다르면 말해 주세요)

1. **‘기본 소품 바로 뒤’를 상점에서는 ‘색 소품’ 묶음 안의 기본 소품 순서로 읽었다.** 기본 소품(베레모 등)은 상품이 아니라 상점에 칸이 없다. 캔버스 8-1도 소품 탭 아래 따로 된 `색 소품` 묶음이다. 순서는 props.json 기본 소품 순서(베레모 → 여행 모자 → 삿갓 → 금관 → 앞치마 → 여행복 → 갈색 신발), 색은 `_c1`~`_c3`. 꾸미기·화집은 같은 칸 안에서 기본 소품 바로 뒤(캔버스 9-2 ‘베레모, 봄하늘 베레모’).
2. **props.json에는 색 소품이 맨 뒤에 있어서 앱이 순서를 옮긴다**(`variantsAfterBase`). 데이터를 기본 소품 바로 뒤 순서로 빌드해도 결과는 같다.
3. **그림 없는 색 소품 칸은 캔버스처럼 색 상자**(material.hex)다. 점선 + 이름 대신. 이름은 꼬리표에만. 아이콘 파일 `item_hat_01_c1_icon_v01_clean.webp`처럼 이름에 id가 든 파일이 `assets/items/icons/`에 오면 그 그림이 뜬다(T4b 규칙 그대로, `hat_01` 아이콘과 섞이지 않는 것은 `asset_index_test`에 있음).
4. **색 상자는 색 소품만.** 기본 소품 7종도 material.hex가 있지만 지금처럼 그림 파일 또는 점선이다.
5. **상점 색 칸도 산 뒤에는 ‘가짐’이고 눌리지 않는다.** 캔버스는 늘 ‘100 럭’이지만 다른 소품 칸과 같게 했다.
6. **색 소품을 입어도 정령에는 아무것도 더 그리지 않는다.** (11/9 통합 세션: Annie 결정으로 T5 전까지 색 여행복은 기본 여행복 그림으로 보인다. `spiritLookOf(baseOf: variantBases(props))`라 맨몸이 되지 않는다. 아래는 합치기 전 그대로) 그림 없는 소품 규칙(16장 11/6). 그래서 별밤 여행복을 입으면 정령의 여행복(Rive `outfit` 1)이 빠지고 맨몸이 된다. 모자·앞치마·신발은 원래 정령에 안 그려서 차이가 없다.
7. **기본 소품을 가졌는지 = 얻은 기록 + 처음부터 가진 기본 소품.** 첫 동기화 전에도 베레모·앞치마·갈색 신발의 색은 보이고 산다.
8. **막힘 문구 ‘아직 살 수 없어요’는 가안이다.** 화면에는 기본 소품이 없으면 칸이 없어서 보통은 안 보인다.
9. **상품 id는 소품 id**(`hat_01_c1`), spend 줄 `refId`도 같다. shop.json 상품 id와 겹치지 않는다(시험). shop.json이 없으면 색 소품도 못 산다.

## 시험

- `flutter analyze` 깨끗. `python3 data/check_data.py` 틀림 0.
- 새 시험: `test/domain/color_props_test.dart` 11, `test/app/shop_sync_test.dart` 색 소품 8, `test/ui/shop_screen_test.dart` 색 소품 5, `test/ui/decorate_screen_test.dart` 색 소품 4.
  - 기본 소품이 없으면 상점·꾸미기에 안 보이고 못 삼(`needsBase`, 아무것도 안 바뀜), 얻으면 제 자리에 뜸
  - 사면 잔액·얻은 소품·새 표시·토스트, 두 번째는 막음, 잔액 부족은 시트 없이 까닭만
  - 기본 소품 바로 뒤 순서(상점 묶음, 꾸미기 칸), 색 상자 색·크기
  - 입으면 같은 칸 기본 소품이 ‘가짐’, 저장하면 `Look`에 남고 그 모습으로 다시 열림, 정령 값
  - 색 소품을 입은 모습 + 얻은 기록의 백업 왕복, 복원한 기기에서 다시 저장·다시 사기 막힘
- 고친 기존 시험: `shop_screen_test` ‘탭마다 그 탭 상품만’은 소품 탭 칸 수에 처음 보이는 색 소품 9를 더함.
- **맥 잠자기:** 이번에도 맥이 잠들어(pmset 기록 `Entering Sleep state`, 약 16분마다 45초 DarkWake) 10분 시간 초과가 여러 번 났다. 1초짜리 시험이 시계로 15분 걸린 것으로 보였다. 다시 돌리면 통과했고, 전체 시험은 `--timeout none`으로 돌렸다(멈춘 시험이 있으면 끝나지 않았을 것이다).

## 폰 확인 대기에 더할 줄 (`개발_인계.md`는 통합 세션이)

- 상점 소품 탭 아래 `색 소품` 제목과 9칸(베레모·앞치마·갈색 신발 색), 색 상자·‘100 럭’. 사면 토스트·‘가짐’·잔액·배낭 점.
- 여행 모자(25km)·삿갓·금관·여행복(300km)을 얻은 뒤 그 색 3칸이 제 자리에 뜨는지.
- 꾸미기 모자·옷·신발 탭: 기본 소품 바로 뒤 색 칸, 입으면 기본 소품 ‘가짐’, 저장 뒤 쉼터·다시 열기.
- 별밤 여행복 등을 입으면 정령의 여행복이 빠지는 것(판단 6)이 괜찮은지.
- 화집 소품 탭 색 칸. 큰 글자에서 `색 소품` 제목과 칸.

## 디자인 기획에 물을 것

- 상점 색 칸을 산 뒤 ‘가짐’으로 바꾸는 것(판단 5). 캔버스는 늘 ‘100 럭’.
- 꾸미기·화집에서도 색 소품은 색 상자로 둘지(판단 3·4). 캔버스 9-2는 모든 칸이 색 견본이지만 16장 11/6 뒤로는 점선 칸이 기준이라 색 소품만 상자로 했다.
- 색 소품을 입은 동안 정령에 그 소품을 안 그리는 것(판단 6). 컷아웃 연결(T5) 전까지 기본 색 그림을 대신 보일지.
- 색 아이콘 21(`color_items_icons_21.png`)은 한 장짜리 시트라 앱이 못 읽는다. 납품은 낱장 21장, 이름에 소품 id(`item_hat_01_c1_icon_v01_clean.webp`).

## 개발 기획·기획에 물을 것

- **16장 11/6 ‘기본 옷 색 고르기’와 데이터가 다르다.** 16장은 처음 받는 기본 옷을 여행복 `cloth_02`라고 하는데, props.json은 `cloth_02`가 거리 300km 소품이고 처음 옷은 앞치마 `cloth_01`(default, `Look` 기본 칸도 `cloth_01`)이다. 여행복이 처음 옷이 되면 여행복 색 소품 3개(별밤·벽돌길·숲길)가 첫날부터 상점에 뜬다. 시작 색 수가 11장 미정이라 이번에는 아무것도 안 바꿨다. 정해지면 props `cloth_02` unlock, `defaultSlots`·`initialPropIds`, 시작 화면을 같이 고친다.
- 막힘 문구 ‘아직 살 수 없어요’(가안).

## 합칠 때 함께 고칠 것

- `sync_service.dart`: import 한 줄(`../domain/color_props.dart`). 본문은 안 고쳤다.
- `item_cell.dart`: `ItemArt`에 `swatch` 인자와 `ItemArt.prop` 생성자를 더했다. 기존 `ItemArt(id:, name:)` 호출은 그대로 돈다.
- `decorate_*`(T5 전용): 색 소품 입기에 필요한 만큼만 고쳤다. `have` 계산을 `havePropIds`로, 칸 목록을 `variantsAfterBase` 순서 + `baseHeld`로, 칸 그림을 `ItemArt.prop`으로. T5가 이어받을 때 이 세 곳을 안다.
- 계획 문서 T4c 줄: 색 소품 21 끝, 상점 배 6척 색은 정령 컷아웃 연결(T5)과 묶인 채 남음.
- `rules.dart`·`catalog_providers.dart`·시험 환경 파일은 안 고쳤다. `syncServiceProvider`가 기다리는 새 프로바이더도 없다.

## 다른 트랙이 알 것

- **T5:** 정령에 색 입히기는 `Prop.materialArgb`(material.hex)를 쓰면 된다. 기준 밝기 `material.neutralReference`(소품마다 180·192), `catalogId`, `layout`은 아직 안 읽는다. 색 소품은 기본 소품과 같은 `catalogId`의 회색조 그림을 쓴다. `spirit_look.dart`의 `_outfitStyles`는 `cloth_02`만 1이고, 색 여행복은 `baseOf`로 기본 소품 값 1을 쓴다(11/9, 색은 아직 기본 색).
- **T2b:** 겹치는 파일 없음.
- **아이콘을 넣을 때:** `assets/items/icons/`에 이름에 id가 든 파일만 넣으면 색 상자 대신 그림이 뜬다. 코드 고칠 것 없음.
