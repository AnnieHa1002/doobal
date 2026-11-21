# 상점 배 색 T4c 인계 (16장 11/6 배 색, boats.json v4 `recolorRule`·배마다 `recolor`, 캔버스 8-1 색 시트)

브랜치 `claude/t10b-daycard-t4c-boat-9e5172`(T10b 커밋 뒤). push·dev-batch 합치기·폰 설치는 하지 않았다.
새 패키지 없음, `app_db.dart`·`.g.dart` 그대로(`BoatsOwned.colors` 열을 쓰기만), config·데이터 JSON 값 그대로, `dart format` 안 씀.
**Drive 그림은 받지 않았다**(Annie 허락 전). 리포에는 배 그림(`assets/boats/v01fix/`)도 색 층 그림도 아직 없어서, 코드와 작은 가짜 그림 시험까지 하고 멈췄다.
색 소품 21개는 11/8에 끝(`docs/트랙/색_T4c.md`). ‘배 고르는 자리’(T4b, 디자인 기획 답 대기)는 이 트랙이 아니다.

## 한 것

| 무엇 | 어떻게 |
|---|---|
| 도메인 | `domain/boat_color.dart`(새 파일, 순수 Dart): `BoatZone`(hull·upper·accent)·`BoatSide`(rear·front)·`RecolorMethod`, `BoatColors`(저장 꼴 `{zone:{kind swatch,i}\|{kind custom,hex}}`, 고른 구역만, 하나도 없으면 null = 원래 색, 견본·직접 색은 정령 몸 색과 같은 `BodyColor`), `BoatRecolorRule`(구역 이름·값 0), `BoatRecolor`(boats.json recolor: 방식·구역·대표색·폴더·premium 파일 이름·neutralMidpoint·검토 메모), 픽셀 계산 `recolorByShading`·`zoneMeanLuminance`·`recolorByNeutral`·`resampleNearest`, `boatZoneArgb` |
| 배 자료 | `domain/boat.dart`: `Boat.codexId`·`recolor`(pending이면 없음), `BoatCatalog.recolorRule`, `artOf(boat, colors:, argb:)`가 색 자료가 있는 배에만 고른 색을 싣고 `BoatArt.key`(배 + 색)를 준다 |
| 그림 읽기 | `ui/boat/boat_art_loader.dart`(새 파일) `loadBoatLayers(bundle, art, width)`: 뒤판·앞판·창 불빛을 읽고, 고른 색이 있으면 색 입힌 두 판을 만든다(픽셀 계산은 `Isolate.run`). **걷는 중 배 구간과 색 시트 미리보기가 이 함수 하나를 같이 쓴다** → 두 곳의 색이 같다. 색 층 그림이 하나라도 없거나 읽지 못하면 원래 그림(로그만). 색 층은 경로·크기마다 바이트로 기억(24MB 넘으면 오래된 것부터 버림)해 견본을 바꿀 때 다시 읽지 않는다 |
| 장면 | `ui/scene/scene_art.dart` 두 곳만: `_loadBoat`가 폭을 정한 뒤 `loadBoatLayers`를 부름, `SceneArtHost` 다시 읽기 열쇠를 `boat?.id` → `boat?.key`(색이 바뀌면 다시 읽음). 그리는 순서는 그대로 색 입힌 뒤판 → (밤 창 불빛) → 정령·동행 → 앞판 → 물결(`drawOrder`) |
| 저장 | `app/sync_boat.dart`(새 part, `BoatColorSync`): `colorableBoats`·`boatColors`(틀린 글은 원래 색)·`setBoatColors`(가진 상점 배만, 그 배 구역만 남김, 럭 안 씀). `sync_service.dart`는 `part` 1줄. 백업은 `BoatsOwned` 줄째 옮겨 색도 같이 간다 |
| provider | `app/boat_providers.dart`(새): `boatColorsProvider(id)`, `colorableBoatsProvider`. `shop_providers.dart`의 `sceneBoatProvider`가 고른 배의 색을 실어 준다 |
| 색 시트 | `ui/shop/boat_color_sheet.dart`(새): 캔버스 8-1 시트 — 제목 ‘○○ 색’ 21, 배 미리보기 150×80(뒤판 + 앞판, 정령 없음) + 고른 색 점 3(‘선체 기본/테라코타/직접’, 원래 색은 빗금), 구역 탭 3(44, 고른 탭 잉크), 견본 44 동그라미 6열(기본 점선 + 몸 색 10 + 직접 색상환, 고른 칸은 잉크 + 테라코타 고리), 직접 고르기는 꾸미기와 같은 색상환·밝기(`ColorPickerPanel`, 0~100%), ‘원래 색으로 되돌리기’(고른 색이 있을 때), 취소·저장. 저장하면 토스트 ‘○○ 색을 바꿨어요’ |
| 상점 알약 | `shop_screen.dart` `_BoatPill`: 누르면 색 시트(전에는 눌리지 않던 알약, T16 질문 대장 후보 ‘가진 배 알약’ 해결) |

## 판단 (개발 가안, 다르면 말해 주세요)

1. **premium(materialIds) 겹치는 차례**: 구역 shading 층(선체 → 지붕 → 장식)을 차례로 얹고 **고정 층(나무·금속·창틀·외곽선)을 맨 위**에. 외곽선이 칠 위에 또렷하게. `material_ids.png`·구역 마스크는 읽지 않는다(shading 알파가 구역을 나눈다).
2. **고르지 않은 구역**: premium은 그 자리 원래 그림 색을 shading 알파로 쓴다(recolorRule ‘평균색 쓰지 않음’), theme은 원래 그림 그대로. 한 구역만 바꿔도 나머지는 원래 색.
3. **theme(meanLuminance) 구역 평균 밝기는 앱이 계산**: 마스크 안 중립 그림의 밝기 평균(마스크 세기로 무게). 마스크 세기 = 흰 마스크면 알파, 불투명 흑백이면 밝기.
4. **theme 파일 이름 가안**: boats.json이 ‘이름은 리포에 넣을 때 확정’이라 `recolor/<codexId>/`에 판마다 `<판>_neutral.png`·`<판>_<구역>_mask.png`, 없으면 판 공통 `neutral.png`·`<구역>_mask.png`를 찾는다. 받으면 이 이름으로 넣거나 boats.json에 이름을 적는 쪽을 제안(아래 질문).
5. **마스크는 보간하지 않는다**: 원래 크기로 읽은 뒤 가장 가까운 픽셀로 판 크기에 맞춘다. shading·중립·고정 층은 연속 색이라 판 크기로 읽는다.
6. **색 시트 ‘기본’ 견본 = 그 구역 원래 색**(저장에서 그 구역 키를 뺌). ‘원래 색으로 되돌리기’는 세 구역 모두. 무료라 구매 확인 없음.
7. **미리보기는 배만**(정령·동행 없이). 배 그림이 아직 없으면 점선 칸 + 이름, 고른 색 점은 그대로(캔버스 8-1 메모 ‘지금은 구역별 색 점’).
8. 직접 고르기 처음 색은 캔버스처럼 테라코타 #C9775A, 구역마다 마지막 직접 색을 기억(시트를 닫으면 잊음).
9. 색 입히기가 실패해도 토스트 없이 원래 색(로그만). 배 구간은 계속 간다.
10. 색 층 PNG는 WebP로 바꾸지 않는다(손실 압축이 마스크·회색 값을 흐린다). 받으면 PNG 그대로 넣는다(제안).

## Annie 허락이 필요한 것 (받기 전 멈춤)

- **Drive 색 층 그림 받기**: boats.json premium 3척 출처 ‘Drive Assets/상점배3척_색변경_v01_검토본_20261106’(zip 4개)은 Drive 앱 폴더에서 찾지 못했다(이름만 찾아봄). 대신 `Assets/02_Backgrounds_배경/`에 `boats_recolor_v03`(11/13, premium 3척 `*_rear_neutral`·`*_rear_<구역>_mask`·`*_rear_fixed`·`meta/materials_D.json`·`premium_0x_material_ids.png`)과 `boats_recolor_v02`(같은 꼴), `boat_skins_cruise_speed_pirate_recolor_v01_검토_20261103`(theme, `풀어둔_파일/recolor/speed/`에 material_ids·shading·fixed·masks·neutral_full·materials.json, pirate는 한 장뿐)이 있다. 파일 내용은 열지 않았다.
- **premium 3척은 ‘미술 승인 전 검토본, 극단적 색 경계 확대 검수 남음’**(boats.json review) — 넣어도 검토본이라 적어 둔다.
- 배 원래 그림(`assets/boats/v01fix/` 앞판·뒤판·창 불빛)도 리포에 없다. 지금 배 구간은 옛 배 한 장(`prop_boat_01`)으로 그리고, 상점 선반·미리보기는 점선 칸이다.
- 받으면 할 일(약 0.25~0.5일, 추정): 배 그림·색 층을 `assets/boats/v01fix/`·`…/recolor/<codexId>/`에 넣고 `pubspec.yaml`에 `recolor/` 폴더를 하나씩 더함(Flutter는 아래 폴더를 저절로 안 넣는다), boats.json files 이름 맞추기(데이터는 개발 기획에 제안), 실제 그림으로 찍어 보기·폰 확인.

## 질문 대장 후보 (가안으로 진행함, 창구로)

- (11/21 T4c) **premium 색 층 묶음이 둘**: boats.json v4는 ‘materialIds’(shading·fixed·material_ids, 11/6 검토본), Drive 최신 `boats_recolor_v03`(11/13)은 neutral·mask·fixed 꼴. 어느 묶음을 넣을지, v03이면 boats.json method·files를 바꿀지 (개발 기획)
- (11/21 T4c) **theme 3척 파일 이름**: boats.json에 이름이 없다(‘리포에 넣을 때 확정’). 앱 가안 `recolor/theme_0x/<판>_neutral.png`·`<판>_<구역>_mask.png`(판 공통도 됨, 판단 4). boats.json에 premium처럼 files 표를 적을지 (개발 기획)
- (11/21 T4c) **고정 층을 맨 위에**(판단 1): 외곽선이 칠 위. 그림 분해가 반대(고정 층이 아래)면 바꾼다 (개발 기획·미술)
- (11/21 T4c) **‘기본’ 견본과 되돌리기**(판단 6): 구역마다 ‘기본’ + 전체 ‘원래 색으로 되돌리기’ 둘 다 둠. 캔버스는 구역 ‘기본’만 (디자인 기획)
- (11/21 T4c) **미리보기에 정령·동행 없음**(판단 7) (디자인 기획)

## 시험

두 트랙(T10b + T4c)을 합친 마지막 코드에서 돌린 값:

- `flutter analyze` 0. `python3 tools/check_secrets.py` 비밀 값 없음. 데이터 파일을 안 바꿔 `check_data`는 안 돌림.
- 핵심 `flutter test test/domain test/app test/data test/widget_test.dart` **1,698개 통과**, 실패 0.
- UI `test/ui/*_test.dart` 67개 파일을 하나씩: **948개 통과, 18개 건너뜀, 실패 0**. 건너뜀은 `text_scale_test` 12개(원래 건너뛰는 것)와 찍기 시험 6개(`day_card_capture`·`boat_color_ui`의 시트 찍기·`home_tabs_capture`·`rest_capture`·`shop_capture`·`walk_scene_capture`, 환경 변수가 있을 때만). 처음 돌릴 때 `note_paper_test` 1개가 실패해 T10b 커밋으로 고침(하루 카드는 메모지 바탕을 안 쓴다, 16장 11/19).

- 새 시험:
  - `test/domain/boat_color_test.dart` 15: 저장 꼴 왕복·null·모르는 구역·틀린 꼴, boats.json 6척 자료·규칙, artOf 열쇠·보상 배는 색 버림, premium 회색 192 = 고른 색·밝으면 255에서 자름·알파 그대로·고르지 않은 구역은 원래 그림·고정 층 맨 위·구역 차례·크기 다름, theme 평균 밝기·평균 = 고른 색·마스크 밖·반 마스크·흑백 마스크, 마스크 보간 없음, 견본·직접 색 → ARGB
  - `test/app/boat_color_sync_test.dart` 5: 색을 바꿀 수 있는 배 = 가진 상점 배, 저장·읽기·null·럭 그대로, 가진 배 아님 notOwned·보상 배 unknownItem, 틀린 저장 글은 원래 색, 백업 왕복
  - `test/ui/boat_color_ui_test.dart` 8 (+ 찍기 1, `DOOBAL_BOAT_CAPTURE_DIR`가 있을 때만): 가짜 96×48 그림 번들로 premium·theme 판 읽기, 색 층·배 그림이 없을 때, **장면(SceneArt.load 배 구간)과 미리보기가 같은 색**(같은 자리 세 점), 알약 → 시트(미리보기·점·탭·견본 12), 견본·직접 → 저장·토스트·`sceneBoatProvider` 색, 취소·되돌리기, 그림 없을 때 점선 칸
- 바꾼 기존 시험 없음. `shop_screen_test`의 ‘가진 배’ 시험은 그대로 통과(알약 글은 그대로, 읽어 주는 글만 ‘유람선 색 바꾸기’).
- 눈으로 봄: 찍기 시험으로 390 시트 두 장(원래 색·고른 뒤). 가짜 그림이라 미리보기는 단색 띠.
- 실기기·실제 그림으로는 안 돌렸다(그림 없음).

## 폰에서 볼 것 (그림을 받은 뒤)

- 상점 ‘가진 배 · 색 바꾸기’ 알약 → 색 시트: 미리보기 색이 견본을 누를 때마다 바로 바뀌는지(느리면 알려 주세요), 직접 고르기, 되돌리기, 저장 토스트.
- 그 배를 타고 배 구간에 가면 같은 색인지(밤 창 불빛·흔들림 그대로), 경계가 지저분하지 않은지(검토본 ‘극단적 색 경계’).
- 배 구간에 처음 들어갈 때 색 입히기로 멈칫하는지(한 번 계산, 2048px 판 두 장).

## 통합 세션이 합칠 때

- 충돌 주의: `lib/ui/scene/scene_art.dart`(`_loadBoat` 본문, `SceneArtHost` 열쇠 1줄 — 걷는 장면 파일, 배 그리기에 꼭 필요한 줄만), `lib/app/sync_service.dart`(`part 'sync_boat.dart';`), `lib/app/shop_providers.dart`(`sceneBoatProvider`), `lib/ui/shop/shop_screen.dart`(`_BoatPill` 누르기), `lib/domain/boat.dart`.
- 새 파일: `lib/domain/boat_color.dart`, `lib/ui/boat/boat_art_loader.dart`, `lib/app/sync_boat.dart`, `lib/app/boat_providers.dart`, `lib/ui/shop/boat_color_sheet.dart`, 시험 2.
- 꾸미기 `ui/decorate/color_picker.dart`(T5)는 import만 했다.
