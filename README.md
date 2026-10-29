# 두발: 여행하는 예술가 (DooBal: Wandering Artist)

걸은 만큼 내 캐릭터(떠도는 화가)가 실제 명소를 향해 여행하고, 도착하면 그곳의 풍경화를 얻는 걷기·러닝 앱.
1인 개발, MVP 2027년 3월(한국 명소 101곳, iOS + 안드로이드, 무료).

기획·규칙의 기준은 Google Drive 「두발 프로젝트 요약 (기준)」 문서다. 이 리포와 다르면 그 문서를 따른다.

## 폴더

```
doobal/
├─ app/          Flutter 앱 (패키지 doobal, 번들 ID com.annieha.doobal)
│  └─ assets/data/   정적 데이터 JSON (landmarks·props·events·milestones·config)
├─ functions/    Firebase Cloud Functions (카카오 커스텀 토큰 등)
├─ data/         명소 CSV와 JSON 빌드·좌표 보정 스크립트
└─ tools/        에셋 정리 스크립트 (clean_assets.py)
```

## 기술 스택

- 앱: Flutter, Riverpod, Drift, health(HealthKit / Health Connect), Rive
- 서버: Firebase (Auth + Firestore + Cloud Functions), 리전 asia-northeast3

## 실행

```bash
cd app
flutter pub get
flutter test
flutter run
```

iOS 빌드는 Xcode, 안드로이드 빌드는 Android SDK가 있어야 한다(`flutter doctor`로 확인).

Drift 테이블(`lib/data/db/app_db.dart`)을 고치면 생성 코드를 다시 만든다. 생성된 `app_db.g.dart`도 커밋한다.

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 걸음 권한 (플랫폼 설정)

걸음은 읽기만 한다. 쓰기 권한은 넣지 않는다.

- iOS
  - `Runner/Info.plist`: `NSHealthShareUsageDescription`
  - `Runner/Runner.entitlements`: HealthKit (빌드 설정 `CODE_SIGN_ENTITLEMENTS`에 연결됨)
  - 처음 Xcode로 열 때 Signing & Capabilities에서 팀을 고르고 HealthKit이 보이는지 확인한다.
- Android
  - `AndroidManifest.xml`: `health.READ_STEPS`, `health.READ_HEALTH_DATA_IN_BACKGROUND`(백그라운드 동기화)
  - Health Connect 권한 화면의 개인정보 처리방침 링크(`ACTION_SHOW_PERMISSIONS_RATIONALE`, `ViewPermissionUsageActivity`)는 `MainActivity`로 연결되어 있다. 처리방침 화면은 아직 없다.
  - `MainActivity`는 `FlutterFragmentActivity`, `minSdk` 26 (health 패키지 요구)
- 화면은 세로 고정(iPhone·Android). iPad는 템플릿 설정 그대로다.

## 정적 데이터 다시 만들기

```bash
python3 data/build_static.py           # landmarks·props·milestones 갱신
python3 data/build_static.py --events  # 이벤트 장면 구성을 바꿀 때만 (문구는 id 기준으로 유지)
```

`config.json`과 `events.json`의 문구는 손으로 고친다.
