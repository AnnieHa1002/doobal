# 동행 트랙 T2b 남은 것 인계

브랜치 `claude/companion-t2b-rest-cdfe8a`, main `8e5e3e2`에서 시작해 커밋까지 했다(push·dev-batch 합치기 안 함).
`app_db.dart`·`.g.dart`, `lib/ui/shop/*`·`sync_shop.dart`·`domain/shop.dart`·`decorate_*`·props 읽기, `config.json`, `docs/개발_인계.md`, 기준 문서는 안 고쳤다. 새 패키지·그림 받기 없음.
`syncServiceProvider`를 기다리는 새 프로바이더는 없어서 시험 환경 파일(ui_env 등)은 안 고쳤다.

## 만든 곳

| 파일 | 내용 |
|---|---|
| `ui/companion/companion_slot.dart` (새) | `companionRestSlotProvider`: 함께 걷는 동행이 있고 쉼터에 와 앉았을 때만 불 옆 자리. 누르면 동행 화면, `notice` = `unreadStoryProvider` |
| `ui/rest/rest_slots.dart` | `restSlotsProvider`가 동행 자리를 읽는다. 상품 없음 갈래에도 동행 |
| `ui/rest/rest_screen.dart` | 흔들림 후보: 알림 점 있는 동행을 ‘알림 점 우선’에 넣음. 끼운 물건 그림(`_slotArt`)을 `PropWiggle`로 감쌈 |
| `ui/companion/companion_pacer.dart` (새) | `CompanionPacer`: 프레임마다 `stepPace`·`paceFrame`, 모습이 바뀔 때만 `ValueNotifier`로 알림(Riverpod 안 씀). 동행이 바뀌면 처음부터 |
| `ui/companion/companion_walk_layer.dart` (새) | 걷는 중 장면의 동행: 자리(`walkCompanionFootX`), 둥실, 화면 밖이면 안 그림 |
| `ui/walking/walking_screen.dart` | 이미 도는 프레임 티커(`_onTick`)에서 pacer를 돌림. 걷기를 마칠 때(마치기·도착·뒤로 나가기) `lateArrivalSec(lagM)`을 `campArrivalProvider`에 한 번 적음 |
| `ui/scene/scene_view.dart` | 걷는 중 동행 층 자리 `walkCompanion` + `SceneCompanionSpot`(정령 발·키, 땅 1m 화면 길이, 시간대 색, 배 위 동행 발). `_Tinted` → `SceneTinted`(동행도 같은 보정) |
| `ui/scene/scene_art.dart`·`scene_art_painter.dart` | 땅 그림 배율을 `SceneArtLayout.groundScale`로 옮김(값 그대로, 장면과 동행이 같은 값을 씀) |
| `app/companion_providers.dart` | `campArrivalProvider`(마친 때·늦은 초, 저장 안 함), `companionSeatedProvider`(`seatedAtCamp`, 그때가 되면 타이머로 다시 읽음) |
| `domain/companion.dart`·`companion_engine.dart` | companions v3 `speciesName`, `hideLayerWhen`(finaleRead) 읽기. `hiddenLayerOf`가 `hideLayerWhen`을 본다 |
| `ui/companion/companion_art.dart`·`meet_flow.dart` | `speciesNames` 상수 지움 → `companion.speciesName`. `CompanionRestArt`(불 옆 자리표시), `companionToSpirit`·`companionFigureAspect` 공개 |
| `ui/debug/debug_screen.dart` | 임시 ‘동행’ 입구와 점 지움. ‘이야기 알림’은 둠(T6c) |

## 판단한 곳 (다르면 말해 주세요)

1. **입구는 함께 걷는 동행만**(브리프대로). 만났지만 혼자 걷기면 불 옆은 빈자리다. 이때 동행 화면으로 가는 길이 N3 알림·걷기 기록 ‘읽기’뿐이라 다시 같이 걸을 수 없다(개발 화면 입구도 지웠다). 아래 디자인 기획 질문 1.
2. **흔들림**: 동행은 알림 점(안 읽은 장)이 있을 때만 흔들림 후보에 든다. 점이 없으면 안 흔든다. 캔버스 2-2 동행은 흔들림(wobble)이 아니라 둥실(`.pongi`)이고 T3도 동행을 뺐기 때문이다. 수레는 그대로 안 흔든다.
3. **늦은 도착**: 마친 뒤 `lateSec` 동안 불 옆이 비었다가 그때 나타난다. 명세의 ‘걸어 들어와 앉는다’ 연출은 캔버스에 없어 안 만들었다(동행 Rive 때). 다시 걷기를 마치면 새 값으로 바뀐다. 앱을 닫으면 없어진다.
4. **걷는 중 자리**(캔버스 3-1): 동행 발은 정령 발에서 정령 키의 2/3 뒤(390폭: 정령 가운데 194.5pt, 동행 74.5pt), 키는 정령의 1/2. 앞서 뛰기 1 = 화면 오른쪽 밖(동행 폭 절반 더). 뒤처짐은 땅 1m의 화면 길이 × lagM이라 땅과 같이 밀린다(390폭 13.65pt/m, 계산). 휴는 분당 150보(2.5m/s)로 뛰면 약 8m 뒤처진 때, 뛰기 시작 약 7초 뒤 화면 밖이다(계산, (75 + 34.7) ÷ 13.65 = 8.0m, ÷ 1.2m/s).
5. **배 위**: `placeBoat(...).companionFoot`에 정령 발과 같은 흔들림. 배 그림이 없으면(옛 배) 땅과 같은 정령 뒤 자리.
6. **둥실**: 자리표시라 동작 그림이 없어서 걷기 0.62초·뛰기 0.3초에 6pt 둥실(캔버스 `.mate`·`.runner`)로 동작을 보인다. 서 있으면 멈춤, 움직임 줄이기면 없음. 쉼터의 둥실(`.pongi` 2.8초 1.5pt)은 안 넣었다(쉼터 상시 프레임을 늘리지 않게, 그림 쪽 몫).
7. **길 위 만남 동안**은 장면에 동행을 두지 않는다(캔버스 3-4는 hasMate여도 장면에 동행 없음). 그동안 pace는 서 있기.
8. **프레임 끊김**: 프레임 사이 시간은 0.25초까지만 연출에 넣는다(앱이 뒤에 있던 틈이 한꺼번에 들어가지 않게). 규칙 숫자가 아니라 코드 상수다.
9. **성능**: 장면은 다시 안 그린다. 동행 층만 pace가 바뀔 때·둥실 동안 자리를 다시 잡고, 그림은 `RepaintBoundary`라 옮기기만 한다. 걷는 중 화면은 원래 티커가 매 프레임 돌아서 프레임 수는 안 는다. 쉼터는 바뀐 것 없음(타이머는 늦은 도착 때 하나).
10. **동행이 없어도 장면에 빈 층 자리를 둔다**: 동행이 생기거나 없어질 때 정령(Rive)이 다시 만들어지지 않게.
11. **`hideLayerWhen`**: finaleRead만 알고 모르는 값은 FormatException, 없으면 층이 있어도 안 숨긴다. 지금 데이터로는 동작이 같다.
12. **시간대 보정**: 걷는 중 동행은 정령과 같은 보정(M2 ‘캐릭터·동행에’). 쉼터 불 옆 동행은 보정이 없다. 쉼터 슬롯 그림(수레도)은 `rest_screen`이 보정 없이 그리기 때문이다.

## 시험

- `flutter analyze` 깨끗.
- `flutter test test/domain test/app test/data test/widget_test.dart`: 1,434개 통과(새 3개 포함).
- `test/ui` 55개 파일을 하나씩: 862개 통과, 14개 건너뜀(capture 2개 파일은 환경 변수가 없어 건너뜀, `text_scale_test`의 원래 12개). 실패 0.
  한 번에 돌릴 때 `decorate_screen_test`·`note_screen_test`가 10분 시간 초과로 멈췄는데(실제 시간 17분·138분이 흘러 맥이 멈췄던 것으로 보임), 따로 다시 돌리면 45·8개 모두 통과했다. 두 파일은 이번에 고친 코드를 안 쓴다.
- 새 시험
  - `test/ui/companion_rest_test.dart`(12): 함께 걸을 때만 입구·누르면 동행 화면, 혼자·첫날 빈자리, 상품 없음 갈래에도 동행(상품 있을 때도), 점 켜짐·읽고 돌아오면 꺼짐, 다른 동행의 안 읽은 장도 점, 점 있는 동행이 먼저 흔들림·점 없으면 안 흔들림, 늦은 도착 2분 동안 빈자리 → 앉음, 0초면 바로
  - `test/ui/companion_pace_walk_test.dart`(9): pacer(뒤처짐·따라옴·바뀔 때만 알림·동행 바뀌면 처음부터), 자리 계산(곁 120pt 뒤·앞서면 화면 밖·뒤처짐·배 위), 걷는 중 화면에서 휴가 뛰면 밀려 사라지고 마친 뒤 쉼터에 늦게 옴, 심 박사는 뛰어도 곁·바로 앉음, 혼자면 장면에 동행 없음
  - 종 이름: `meet_flow_test`(데이터의 speciesName을 바꾸면 카드에 그 이름), `catalogs_test`(v3 speciesName·hideLayerWhen, 모르는 값 FormatException), `companion_engine_test`(숨기는 때 없으면 안 숨김)
- 고친 기존 시험: `companion_walk_test` ‘개발 화면 입구에 점’ → ‘쉼터 불 옆 동행에 점, 개발 화면엔 동행 입구 없음’. `meet_flow_test` 개발 화면 묶음은 지운 ‘동행’ 버튼 대신 동행 화면을 바로 연다. `catalogs_test`의 만든 동행 JSON에 `speciesName` 한 줄. `shop_screen_test` ‘상품이 없으면 입구를 숨긴다’의 맨 컨테이너에 `companionRestSlotProvider.overrideWithValue(null)` 한 줄(쉼터 자리가 이제 동기화 서비스를 읽어서, 안 막으면 진짜 서비스가 떠 타이머가 남는다).

## 폰 확인 대기에 더할 줄 (`개발_인계.md`는 통합 세션이)

- 쉼터 불 옆 동행: 390·375·Z플립에서 자리·이름표, 안 읽은 장 점(‘이야기 한 장 더’ 뒤), 읽고 돌아오면 꺼짐, 점 있을 때 흔들림.
- 걷는 중: 동행이 정령 뒤에서 둥실, 휴와 뛰면 밀려 사라졌다 걸으면 다시 나타남, 퐁이는 90초마다 앞서 뛰어 화면 밖 → 돌아옴, 심 박사는 곁. 배 구간 동행 자리·흔들림. 밤 보정.
- 휴와 몇 분 뛰고 마친 뒤 쉼터: 불 옆이 비었다가 그때 나타나는지(5분 뛰기면 약 277초, M2 계산 예).
- 걷는 중·쉼터 프레임률(동행 층을 더한 뒤).

## 디자인 기획에 물을 것

1. **혼자 걷기일 때 동행 화면 입구**: 만난 동행이 있는데 혼자 걷기를 고르면 쉼터에 입구가 없어 다시 같이 걸을 수 없다. 추천: 불 옆 자리에 그림 없이 ‘동행’ 이름표만 남겨 누르면 동행 화면. 다른 안: 마지막 동행(lastWith)을 앉혀 둠, 나의 정보에 입구.
2. 쉼터 동행 읽기 라벨: 캔버스는 ‘불 옆의 퐁이 (새 이야기 있음)’인데 지금은 이름표와 같은 ‘동행’이다(`rest_screen`이 이름표 글로 읽기 라벨을 같이 씀).
3. 늦은 도착 때 ‘걸어 들어와 앉는’ 연출과 쉼터 동행 둥실: 캔버스에 걸어 들어오기가 없다. 동행 Rive(T2c) 때 정할지.
4. 쉼터 슬롯 그림(동행·수레)의 시간대 보정: 밤에 불 옆 동행만 밝게 보일 수 있다.

## 개발 기획에 물을 것

- 뒤처진 거리를 땅과 같은 배율로 보이게 했다(약 8m 뒤처지면 화면 밖, 분당 150보로 뛰면 약 7초 뒤, 계산). 더 천천히 사라지게 하려면 config에 화면 배율 키가 필요하다.
- `companions.pace.walkMps` 1.3(추정)은 그대로 원본 config 반영 대기(T2b 노트).

## 합칠 때 함께 고칠 것

- `docs/개발_계획.md` T2 절 ‘T2b 남은 것’ 체크, 7장 디자인 기획 줄에 위 질문 1~4.
- 16장 11/6 줄(안 읽은 장 점)은 쉼터 동행까지 반영됨. 15장 [개발] 줄.
- T3 파일(`rest_screen`·`scene_view`·`scene_art*`)을 고쳤다: 흔들림 후보·슬롯 흔들림, 걷는 중 동행 층 자리, `groundScale` 옮김, `SceneTinted` 이름. T4c는 이 파일들을 안 건드린다.
- `test/domain/catalogs_test.dart`에 줄을 더함(T4c도 이 파일에 더할 수 있음, 서로 다른 group).
- `test/ui/shop_screen_test.dart`에 import 한 줄과 override 한 줄을 더함(T4c 파일이라 겹칠 수 있음, 더하기만 함). T4c가 쉼터 자리를 맨 컨테이너로 읽는 시험을 새로 쓰면 같은 override가 필요하다.
- T2c가 이어 받을 자리: `CompanionFigure`(자리표시) → 동행 Rive. `WalkCompanionLayer`의 둥실 → `PaceFrame.motion`으로 걷기·뛰기·서기 입력(옆면). `CompanionRestArt` → 불 옆 앉기(정면) + `MetCompanion.hiddenLayer`(안경). 늦은 도착의 걸어 들어오기.
