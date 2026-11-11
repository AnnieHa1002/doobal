# CLAUDE.md — 두발: 여행하는 예술가 (DooBal)

걸은 만큼 내 캐릭터(떠도는 화가)가 실제 명소로 여행하고, 도착하면 풍경화를 얻는 걷기·러닝 앱.
Annie 1인 개발, MVP 2027년 3월(한국 명소 101곳, iOS + 안드로이드, 무료, 로그인 없이 시작).

## 기준 문서 (가장 먼저)

- 기준: Google Drive 「두발 프로젝트 요약 (기준)」 `1N7o9fRCJV-fpDivij7S7bNo1NAA5NHdq5ldXy7MRBAc`
  - 이 리포·다른 문서와 다르면 기준 문서를 따른다. 확정된 결정은 다시 묻지 않는다.
  - 11장 「아직 정하지 않은 것」은 추측으로 확정하지 말고 선택지와 추천을 준다.
- 구현 명세 (Drive 문서 ID)
  - 기술 설계서 `14xDk17qDyzG-Gdus6Kb6E2JEPYdFmkZemiipyPkKq-c`
  - M1 명세 (걸음·여정 엔진) `1k_CpZQwv3Z1BY_v5y2Kte5RAPMDl1tcFX1De-Z-rADM`
  - M2~M6 명세 `1k4BjYeshIUqhehwn3JTRaVS4feDmnpJTl8zrNGjYoj8`
  - 정적 데이터 스키마 `1Jr9W7utyy1sfR_epIqWr9x5Vb1oD7-By2WeYt9a_k94`
  - 화면 기준: 프로토타입 캔버스 https://claude.ai/artifact/5ZZogKRDLU4eT4npM1Qhqn (11/4, 화면마다 메모). UI 명세 v3 `1HVcK3sqXFsPTDGF353ePuuYIrTPukdoG7eGd_ssneEg`는 보관
- Drive에 접근할 수 없으면 추측하지 말고 Annie에게 해당 부분을 붙여 달라고 한다.

## 세션 규칙

1. 이 리포에서의 작업은 기본적으로 **[개발]** 단계다. 시작할 때 "이 세션은 [개발] 단계로 진행할게요"라고 밝힌다.
2. 기준 문서 16장 「기획 변경 기록」에서 '확인 대기'에 개발이 있는 줄을 먼저 처리한다
   (코드·명세 영향 확인 → 고치거나 할 일로 남김 → 확인 대기에서 '개발' 삭제).
3. 15장 「진행 현황판」의 [개발] 줄 '다음 할 일'부터 이어서 한다. 병렬 트랙의 순서와 충돌 규칙은 `docs/개발_계획.md`를 따른다.
4. 기획 변경이 필요해 보이면 직접 확정하지 말고 이유와 함께 제안만 한다.
5. Annie가 "마무리"라고 하면: 바뀐 결정을 기준 문서에 반영하고, 15장 [개발] 줄(상태·다음 할 일·막힌 것)을 고치고, 바뀐 것을 세 줄 안으로 알려 준다.

## 리포 구조

```
app/                Flutter 앱 (패키지 doobal, 번들 ID com.annieha.doobal)
  assets/data/      정적 데이터 JSON: landmarks·props·events·milestones·config·sigungu·notifications·palette·companions·badges·shop·boats·scene·scene_art·moderation
  assets/data/themes/  쉼터 테마(camp_wide.json: 장면 pt 좌표, 물건·정령·동행·불꽃·누름 순서)
  assets/map/       지도 시도 경계 SVG·위경도 투영 JSON (Drive 05_UI_화면 ui_map_*_v01 사본)
  assets/items/icons/  칸 그림(파일 이름에 소품·상품 id, 파일만 넣으면 읽음)
  assets/rive/      Rive 시험 파일
functions/          Firebase Cloud Functions (에뮬레이터 시험까지, 앱은 에뮬레이터로 연결(11/9), 실제 프로젝트 doobal-47236 배포 전. 실행법은 functions/README.md)
data/               명소 CSV, build_static.py, build_events.py, geocode_landmarks.py
tools/              clean_assets.py (에셋 정리), check_secrets.py (키·토큰 검사)
```

## 기술 스택 (확정)

- Flutter 3.47 / Dart 3.13, 상태관리 Riverpod, 로컬 DB Drift
- 걸음: `health` 패키지 → HealthKit(iOS) / Health Connect(안드로이드). Google Fit 쓰지 않음.
  센서가 잰 걸음만 인정, 수동 입력·다른 앱 기록 제외
- 애니메이션: Rive
- 서버: Firebase (Auth + Firestore + Cloud Functions), 리전 asia-northeast3, Blaze.
  카카오 로그인은 Functions 커스텀 토큰
- 오프라인: 방명록 빼고 모두 오프라인 동작. 하루 기준은 한국 시간 자정(서버 시간)

## 코딩 방침

- 1인 개발이 감당할 수 있는 가장 단순한 방법을 고른다. 새 패키지는 이유를 말하고 추가한다.
- 규칙 숫자(보폭, 분당 걸음 경계, 액자 기준 km, 경비 상한 등)는 코드에 박지 말고 `assets/data/config.json`에서 읽는다.
- 걸음·여정 엔진(거리 계산, 걷기/뛰기 판정, 도착 예정일, 액자 등급, 배 구간 환산)은 순수 Dart로 두고 단위 테스트를 붙인다(M1 명세의 테스트 목록 기준).
- 숫자(거리·걸음·일정)는 계산해서 말하고, 추정이면 추정이라고 밝힌다.
- 화면 이름은 프로토타입 이름을 쓴다: 쉼터, 걷는 중, 걷기 기록, 길 위 만남, 지도, 도착, 방명록, 화집, 나의 정보, 꾸미기.
- 답과 주석은 한국어, 짧게, 결론 먼저.

## 비밀 값 (키·토큰·인증서): 어떤 경우에도 리포에 올리지 않는다 (11/11 Annie)

- 올리지 않는 것: 실제 Firebase 설정(`firebase_options.dart`·`google-services.json`·`GoogleService-Info.plist`), API 키(Google·카카오·AdMob 등), 서비스 계정 JSON, 서명 키·인증서(`*.jks`·`key.properties`·`*.p8`·`*.p12`), `.env`·`functions/.env.<프로젝트 id>`, 토큰·비밀번호. 리포가 private이어도, 앱에 들어가는 공개용 키여도 같다. 이 파일들은 `.gitignore`에 있다.
- 넣는 법: 앱은 빌드 때 `--dart-define-from-file=app/secrets.json`(무시 목록)으로 받고, 안드로이드·iOS 설정에 들어갈 키는 `local.properties`·`Secrets.xcconfig`(무시 목록)에서 읽는다. 함수 비밀은 Firebase Secret Manager(`firebase functions:secrets:set`)나 `functions/.env.<프로젝트 id>`(무시 목록). 원본은 Annie의 비밀번호 관리자에 두고 Drive·문서·채팅에 적지 않는다.
- 가짜 값: 에뮬레이터·시험용만 리포에 둔다. 값에 `Demo`·`Fake`·`EmulatorOnly` 같은 말을 넣고 `tools/check_secrets.py`의 `FAKE`에 적는다.
- 검사: 커밋 전 `python3 tools/check_secrets.py`, push 전 `python3 tools/check_secrets.py --range origin/main..HEAD`. 1로 끝나면 커밋·push하지 않고 Annie에게 알린다. 무시 목록을 줄이거나 검사 규칙·`FAKE`를 느슨하게 하려면 먼저 묻는다.
- 키 값은 채팅·커밋 메시지·문서·로그에 적지 않는다. 보여야 하면 앞 몇 글자만.
- 새어 나갔으면: 바로 Annie에게 알린다. 폐기·재발급은 콘솔에서 Annie가 하고, 기록 정리(force push)는 Annie와 정한 뒤에만 한다.

## 정적 데이터

- `python3 data/build_static.py` → landmarks·props·milestones 재생성. 시도 이름은 2026-07-01 행정구역(옛 이름이면 멈춤).
- `events.json`(v3: 풍경 96·칭찬 17, 10/30 제안 삭제)은 `python3 data/build_events.py <이벤트_문구.md> app/assets/data/events.json`으로 만든다. 문구 원본은 Claude 프로젝트 문서 `기획/이벤트_문구.md`.
- `sigungu.json`·`notifications.json`·`palette.json`·`companions.json`·`badges.json`은 Claude 프로젝트 문서 `데이터/app/`의 사본이다(companions는 `데이터/build_companions.py`로 만듦). 원본이 바뀌면 같이 바꾼다.
- `config.json`은 손으로 고친다.
- 데이터를 고친 뒤 `python3 data/check_data.py`로 파일 사이 값(상점↔소품·배 값과 이름, 색 소품↔견본, 동행↔이야기 그림, 정령 크기 등)을 맞춰 본다. 틀리면 1로 끝난다. build_static.py 끝에서도 돈다.

## 에셋

- 그림체: 양피지·수채 위 판화풍 + 2~2.5등신. 색·글꼴·캔버스 규격은 기준 문서 9장.
- 생성 원본은 `tools/clean_assets.py`로 정리하고, 정리본은 이름 끝에 `_clean`. 이미지 파일은 Drive Assets 폴더가 원본 저장소다.
