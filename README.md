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

## 처음 설정

```bash
# 1) Flutter 플랫폼 폴더 만들기 (app/assets/data 는 그대로 둔다)
flutter create --org com.annieha --project-name doobal --platforms ios,android app

# 2) 패키지
cd app
flutter pub add flutter_riverpod drift drift_flutter health rive
flutter pub add --dev drift_dev build_runner
```

그다음 `app/pubspec.yaml`의 `flutter:` 아래에 데이터 폴더를 등록한다.

```yaml
flutter:
  assets:
    - assets/data/
```

## 정적 데이터 다시 만들기

```bash
python3 data/build_static.py           # landmarks·props·milestones 갱신
python3 data/build_static.py --events  # 이벤트 장면 구성을 바꿀 때만 (문구는 id 기준으로 유지)
```

`config.json`과 `events.json`의 문구는 손으로 고친다.
