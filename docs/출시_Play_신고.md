# Play 신고 초안 (T6c, 2026-11-16 통합 세션)

결론: 안드로이드 출시 전에 Play Console ‘앱 콘텐츠’에서 신고 3가지(건강 앱·Health Connect, 포그라운드 서비스, 데이터 보안)와 기본 양식을 채운다. 앱 쪽 빈 곳(Health Connect 권한 화면의 처리방침 링크)은 11/16에 고쳤다(아래 1-4).
양식 문항은 콘솔에서 바뀔 수 있어 아래 문구는 가안이다. 제출은 Annie가 콘솔에서 한다.

## 1. 건강 앱 신고 + Health Connect 질문

2024-08-31부터 Health Connect 권한 신고는 ‘건강 앱 신고(Health apps declaration)’ 양식 안의 Health Connect 질문으로 한다([Play 도움말](https://support.google.com/googleplay/android-developer/answer/12991134), [개발자 문서](https://developer.android.com/health-and-fitness/guides/health-connect/publish/declare-access)). 데이터 종류가 늘거나 줄면 다시 낸다.

1. **앱 종류**: 피트니스·활동 기록(걸은 만큼 캐릭터가 실제 명소로 여행하고 풍경화를 얻는 걷기 앱). 의료 기능 없음.
2. **권한과 쓰는 곳** (매니페스트 `app/android/app/src/main/AndroidManifest.xml`)

   | 권한 | 쓰는 기능(사용자에게 보이는 것) |
   |---|---|
   | `health.READ_STEPS` (읽기만, 쓰기 없음) | 걸음 → 거리 → 여정 진행·도착, 하루 카드·걷기 리포트·걷기 기록. 센서가 잰 걸음만 쓰고 수동 입력·다른 앱 기록은 뺀다 |
   | `health.READ_HEALTH_DATA_IN_BACKGROUND` | 앱을 열지 않아도 약 15분마다(config `sync.backgroundMin`) 걸음을 읽어 여정을 진행하고 도착·알림을 보낸다(`lib/app/background_sync.dart`) |

3. **최소한만**: 걸음 하나만 읽는다. 심박·수면·위치 등은 읽지 않는다.
4. **처리방침 보이기 (11/16 고침)**: Health Connect 권한 화면의 처리방침 링크(`ACTION_SHOW_PERMISSIONS_RATIONALE`, 14 이상은 `VIEW_PERMISSION_USAGE`)는 앱의 개인정보 처리방침을 보여 줘야 한다. 전에는 앱 첫 화면만 열었고, 지금은 `PrivacyPolicyActivity`가 방침 페이지를 브라우저로 연다(폰에서 볼 것).
   - 방침 글은 이미 있다: https://annieha1002.github.io/doobal-policy/ (privacy·terms·ai, `docs/개발_인계.md` 다음 할 일 10).
   - 앱 정보의 AI 고지·약관·처리방침 줄도 `url_launcher`(11/16 Annie 허락)로 같은 페이지를 연다.

## 2. 포그라운드 서비스 신고 (안드로이드 14 이상 대상)

‘앱 콘텐츠’의 포그라운드 서비스 신고에 쓰는 유형을 적고, 건강 유형은 동작을 보여 주는 **동영상 링크**가 필요하다([Play 도움말](https://support.google.com/googleplay/android-developer/answer/13392821), [유형 설명](https://developer.android.com/guide/components/fg-service-types)). 심사는 동영상·앱이 신고 내용과 맞는지 본다.

- **유형**: `health` (`FOREGROUND_SERVICE_HEALTH`, `flutter_local_notifications`의 ForegroundService, `lib/data/walk_notice.dart`)
- **기능**: 걷는 중(본격 걷기) 상시 알림. 사용자가 걷기를 시작하면 알림에 걸음·거리를 보여 주고, 화면을 꺼도 걸음 센서(`ACTIVITY_RECOGNITION`)로 실시간 걸음을 이어 센다. 걷기가 끝나거나 앱을 밀어 끄면 서비스와 알림이 끝난다(`stopWithTask`).
- **사용자 영향(이 서비스가 없으면)**: 화면을 끄거나 다른 앱을 쓰는 동안 실시간 걸음·물감 길이 멈춘다.
- **동영상(Annie가 찍음, 30초~1분 추정)**: 폰 화면 녹화로 ① 쉼터에서 걷기 시작 → ② 상단 알림이 생김 → ③ 걸으면 알림의 걸음이 늘어남 → ④ 화면을 껐다 켜도 이어짐 → ⑤ 걷기 끝내기 → 알림이 사라짐. 링크는 YouTube ‘일부 공개’ 등 심사자가 열 수 있는 곳.

## 3. 데이터 보안(Data safety) 양식

가안(코드 기준 추정, 서버 실제 연결 T1b 뒤 다시 본다):

| 데이터 종류 | 모음 | 서버로 보냄 | 쓰는 곳 |
|---|---|---|---|
| 건강·피트니스: 걸음 | 예 | 예(총 걸음 수를 방명록 자격용으로 프로필에, 백업에 기록 포함, 추정) | 앱 기능 |
| 앱 활동: 방명록 글·하트·신고 | 예 | 예 | 앱 기능(공개 글) |
| 기기 또는 기타 ID: Firebase 익명 계정 id | 예 | 예 | 앱 기능·계정 |
| 이름: 닉네임 | 예 | 예 | 앱 기능(방명록 표시) |
| 위치 | **아니오** | — | 날씨는 정령의 지도 위 여정 지점으로 묻는다(기기 위치 권한 없음) |
| 사진 | 아니오 | — | 그림 저장은 쓰기만(`gal`) |

- 전송은 암호화(HTTPS), 계정 지우기 있음(설정 → 서버 `deleteAccount`, 방명록 글·하트·백업도 지움).
- 광고(T7 AdMob)를 넣으면 ‘광고 ID’·‘광고’ 목적을 더해 다시 낸다.

## 4. 그 밖의 양식

- 앱 액세스: 로그인 없이 시작 → 제한 없음
- 광고 포함: T7 전 빌드는 ‘아니오’, 출시 빌드는 ‘예’
- 콘텐츠 등급 설문, 타겟 연령(13세 이상 가안 — 기획 확인), 뉴스·정부 앱 아님
- `ACTIVITY_RECOGNITION`·`POST_NOTIFICATIONS`·`RECEIVE_BOOT_COMPLETED`는 따로 신고하지 않는다(런타임 권한·데이터 보안에 포함, 추정)

## Annie가 할 일

1. 포그라운드 서비스 동영상 찍기(2)
2. 콘솔에서 1~4 양식 채우기(이 문서 문구를 가안으로)
3. 타겟 연령·콘텐츠 등급 답은 기획과 확인
