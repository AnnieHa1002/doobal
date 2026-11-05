# 상점 트랙 T4a 인계

브랜치 `claude/jolly-jackson-7adb75`, 끝 커밋 `4b2ed66`(data-v9 합침 포함). push·dev-batch 합치기 안 함.
커밋: `b596baf` 엔진, `0e21649` 고침·연결 시험, `4b2ed66` dev-batch `beb3918` 합침(충돌은 `rules.dart` 한 곳, 양쪽 줄 다 남김).

## 시험 결과 (합친 뒤)

- `flutter analyze` 깨끗.
- `test/domain test/app test/data test/widget_test.dart` 1,288개 통과.
- `test/ui` 43개 파일을 하나씩 돌려 모두 통과. `text_scale_test`는 258 통과, 12 건너뜀(원래 건너뛰는 12개).
- 새 시험 79개: `test/app/shop_sync_test.dart` 47, `test/domain/shop_rules_test.dart` 21, `test/ui/boat_scene_test.dart` 8, `test/ui/shop_wiring_test.dart` 2, `test/widget_test.dart` 1.
- M4.5 목록 8개 모두 있음(3km 상한, 보관 10번째, 여정 없을 때, 잔액 부족, 동기화 2번 럭, 액자·도장, 보상 배, 백업 왕복).
- 실기기는 안 돌림. 화면이 없어 구매·사용은 폰으로 볼 수 없고 T4b 뒤에 본다.

## 만든 곳

| 파일 | 내용 |
|---|---|
| `lib/app/sync_shop.dart` | `coinBalance`, `shopHeld`, `buyItem`, `useTravelEffect`, `ownedBoatIds`, `selectedBoat`, `chooseBoat`, `_shopMetersByDay`, `_journeyShopKm`, `_withoutShopKm`, `_unlockBoats` |
| `lib/domain/shop.dart` | `ShopBlock`·`ShopBlocked`, `coinBalanceOf`, `buyBlock`, `useBlock`, `clipEffectKm`, `walkedMBetween` |
| `lib/domain/boat.dart` | `BoatArt`, `placeBoat`, `boatLightOn`, `earnedRewardBoats`, `boatOf`, `newBoatToast` |
| `lib/app/shop_providers.dart` (새 파일) | `coinBalanceProvider`, `shopHeldProvider`, `ownedBoatIdsProvider`, `selectedBoatProvider`, `sceneBoatProvider` |
| `lib/app/auto_sync.dart` | 새 배 한 줄 토스트 |
| `lib/ui/scene/scene_art*.dart`, `scene_view.dart` | 배 그리는 부분만. 판 그림 읽기, 그림 순서, 흔들림 |
| `lib/ui/walking/walking_screen.dart` | `SceneView`에 `boat` 한 줄 |
| `lib/domain/rules.dart` | `characterCanvasHeightPx`(config `character.canvas.heightPx` 768, 배 크기 잣대) |

`sync_service.dart` 본문은 `_recomputeDays`의 `shopM` 말고 허락받은 3곳(`_journeyWalked`, `_advanceJourney`, `_badgeFacts` 세 갈래)만 고쳤다. T2의 `addEventDistance`와 겹치지 않는다. 계획 문서 6장 본문 제한은 통합 세션이 고친다고 했다.

## 판단한 곳 (다르면 말해 주세요)

1. **순풍은 열린 걷는 중에만 쓴다.** 쉼터에서 미리 켜 두려면 다음 걷기에 묶어야 하는데 `ShopUses`에 쓴 시각 열이 없어 어느 창이 '다음'인지 알 수 없다. **표가 부족한 곳**이다. 쉼터에서 쓰게 하려면 `ShopUses.usedUtc`가 필요하니 통합 세션이 번호를 잡아야 한다.
2. **순풍은 이번 걷는 중 전체를 본다.** 쓰기 전에 걸은 분도 친다(같은 까닭, 명세 '창 안 실제 거리'). 끝 무렵에 켜도 20% 전부 받는다.
3. **순풍 거리는 쓴 날에 모두 넣는다.** 걷기가 자정을 넘어도 그렇다. 하루 상한도 그 날 기준이다.
4. **상한이 일부만 남았으면 지름길을 남은 만큼만 더하고 1장을 쓴다.** 남은 양이 0이면 막고 장을 줄이지 않는다.
5. **순풍 km는 적힌 값보다 줄지 않는다.** 복원뿐 아니라 걸음이 빠진 기록으로 다시 동기화해도 그렇다. 늘어나는 것은 따라간다.
6. **순풍은 여정이 끝난 뒤(도착·멈춤)의 걸음을 치지 않는다.**
7. **디버그 거리 배수는 효과에 안 곱한다.** 넘친 거리는 효과를 먼저 뺀 뒤 배수로 나눈다.
8. **산 소품은 `seen`이 false다.** 배낭 점이 켜진다. 걸어서 얻을 때와 달리 토스트는 안 뜬다(구매 토스트는 T4b).
9. **막힘 문구는 '여정 중에만 쓸 수 있어요'만 명세 문구**이고 나머지와 `새 배를 얻었어요 · 이름`은 가안이다.
10. **창 불빛은 그 시각의 우세한 하늘 단계(`look.phase`)가 밤·새벽일 때 켠다.** 시간대 보정 밖에 얹는다.

## 규칙 해석이 필요한 곳 (일부러 안 고침, 기획 몫)

- **효과로 앞당겨 도착해도 그대로 인정된다.** 첫 명소 도착·명소 도착 수·첫 배 타기 도장, 조각배·돛단배 판정은 위치·도착으로 본다.
- **도착 예정일은 효과를 포함한 평균이다**(`travelM`, 명세대로).
- **효과로 목적지 10km 안에 들어가면 N4 알림이 안 뜰 수 있다.** N4는 동기화 전후를 비교하는데 효과를 쓴 시점에 이미 안쪽이 되기 때문이다.
- **'그동안 n km 걸었어요' 토스트에 순풍 증가분이 들어간다**(본격 걷기 보너스처럼).

## 디자인 기획에 물을 것

- **여행 효과를 쓰는 자리가 캔버스에 없다.** 상점은 구매만, 걷는 중 화면에도 입구가 없다. 1번 판단과 묶인다.
- **배 고르는(타기) 자리가 캔버스에 없다.** 상점 배 탭에는 '가짐'과 색 시트뿐이다. 엔진은 `chooseBoat`.
- **배 흔들림 값이 어느 문서에도 없다.** `scene_art.json` boat의 `swayPx`·`swaySec`를 읽게 해 뒀고 값이 없으면 안 흔들린다. 넣으면 배 판·정령이 같이 움직인다.

## 눈으로 볼 것

- **옛 배는 540 크기로 그려 봤다.** 세로 390×844·가로 844×390에서 정령 자리(타원으로 대신)의 발이 갑판에 닿고 배가 물 위에 앉는다. Rive 정령은 안 얹었다.
- **판 그림은 파일이 없어 못 봤다.** 규격대로면 배 캔버스 3072 × 0.703 = 2,160px로 기준 폭 1170의 약 1.85배다(계산). 옛 배 그림을 이 배율로 그리면 양끝이 잘렸다. 실제 9척의 선체 폭을 보고 정해야 한다.
- **메모리:** 판 한 장이 3072×1536이면 약 19MB(계산, RGBA), 유람선은 3장. 바다에서만 읽는다.

## 폰 확인 대기에 더할 줄 (`개발_인계.md`는 통합 세션이)

- 배 구간: 540 크기에서 정령 발과 갑판, 물결.
- 제주·울릉 도착 때 `새 배를 얻었어요 · 조각배` 토스트, 자동으로 안 갈아탐.
- T4b 뒤: 구매·잔액·보관함, 지름길로 바로 진행, 순풍, 효과로 도착.

## 다른 트랙이 알 것

- **T4b:** 구매·사용·배 고르기 뒤 `ref.invalidate(snapshotProvider)`면 상점 프로바이더가 따라온다. `ownedPropIdsProvider`는 따로 invalidate. 막힘은 `ShopBlocked`의 `.block`·`.message`. 오늘 쓴 횟수를 미리 보여 줄 값은 아직 없다. 럭 보석 그림은 안 넣었다(Drive 허락 전).
- **T4c:** `shop.json`의 `colorVariantItems`는 안 읽는다. 지금 `buyItem`으로 색 소품은 못 산다(`byId`에 없음). 배 색은 `BoatsOwned.colors`, `recolor`는 안 읽는다.
- **T2b:** 배 위 동행 자리는 `placeBoat(...).companionFoot`. 동행은 `SceneView`에서 정령과 같은 층(앞판 아래)에, 흔들림은 `SceneArtLayout.boatSwayY`를 같이 쓴다.
- **T3:** `scene_*` 고친 곳은 배 부분뿐이다. `SceneArt.boat`·`BoatImages`, `SceneArtHost.boat`, 그림 패스의 `_boat`·`_boatLight`·`_boatFront`·`_boatLayer`, `SceneView.boat`와 발의 흔들림.
- **WebP:** 배 그림을 WebP로 넣으면 `boats.json` 파일 이름도 같이 바꿔야 읽힌다. 뒤판이나 앞판이 없으면 옛 배로, 창 불빛만 없으면 불빛 없이 그린다.

## 합칠 때 함께 고칠 것 (범위 밖이라 안 고침)

- 낡은 주석: `app_db.dart` DaySummaries의 'shopM은 상점 효과(아직 0)', `sync_service.dart` `WalkRecord.travelM`의 '상점은 아직 0'.
- 계획 문서 T4a의 '보관 9개·럭 보석' 줄 상태, 6장 본문 제한.
- 명세 M4.5의 '효과 모양 추천(거리 한정)'은 기준 문서의 순풍과 달라 기준 문서대로 만들었다. 명세 쪽 줄 정리는 개발 기획 몫.
