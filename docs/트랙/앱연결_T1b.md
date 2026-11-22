# 앱 연결 트랙 T1b 인계

앱을 Firebase에 붙였다: 익명 로그인, `users/{uid}`, Firestore 백업, 방명록(남기기·읽기 5개·하트·신고·받은 하트), 계정 연결(구글·애플·카카오 흐름), 설정 계정 줄·서버 계정 삭제·카카오 해제, `config/moderation` 받기, App Check.
브랜치 `claude/app-connect-t1b-6d3d42`, main `01aeccf`에서 시작. 코드 커밋 `c3a9dce`(연결), `33b560f`(손 확인에서 찾은 것 고침). push·dev-batch 합치기 안 함.
**에뮬레이터(`demo-doobal`)에서만 돌렸다.** 실제 프로젝트 `doobal-47236`에는 아무것도 하지 않았다(앱 등록·배포·seed·App Check 모두 안 함). 무선 실기기·iOS도 안 돌렸다.

## 시험 결과

- `flutter analyze` 깨끗.
- `test/domain test/app test/data test/widget_test.dart` 1,496개 통과.
- `test/ui` 56개 파일을 하나씩 돌려 885개 통과, 14개 건너뜀(`text_scale_test` 12, `rest_capture_test`·`shop_capture_test` 각 1, 환경 변수가 있을 때만 돈다).
- 합계 2,381개 통과, 실패 0. 커밋 `33b560f`에서 `caffeinate -i`로 돌렸다.
- `functions`의 `npm test`(에뮬레이터 켜고 끔) 301개 통과. `functions/src`·`firestore.rules`는 안 고쳤다.
- 새 시험(가짜 서버 `test/app/fake_server.dart`): `account_service_test` 25, `guestbook_server_test` 14, `server_providers_test` 3, `test/ui/server_ui_test` 14.
  - 만 14세 확인 전 Auth 0회, 동시에 불러도 익명 로그인 1번, 오프라인이면 null이고 다음에 다시
  - users 문서: 값이 같으면 다시 안 올림, 동시에 불러도 차례로 1번, 실패해도 다음은 됨
  - 연결한 계정 판정(`linkedOf`), 구글 연결·창 닫기·오프라인, 다른 계정 → 묻기 → 바꾸면 그 계정 백업으로 복원(기기에만 두는 값은 유지)·백업 없으면 그대로
  - 카카오: SDK 없음(준비 중)·창 닫기·`linked`·`needsConfirm`→`switched`+복원·백업 없음·토큰 만료·오프라인
  - 해제(카카오는 서버 연결 지우고 동의 시각 지움, 구글은 Auth unlink, 오프라인이면 그대로), 서버 계정 삭제(로그인 전·성공·오프라인)
  - 남기기: 서버 없음 → pending, 서버 → sent, `no-profile` → users 올리고 다시, `already-exists` → sent, 금칙어 → 남기지 않고 기회 열림, 작성 제한, 오프라인, 로그인 실패, 지난 기회
  - pending 다시 올리기: 순서·금칙어는 rejected·오프라인은 멈춤·작성 제한은 그대로
  - 화면: 읽기 5개·`n명 중 5명`·다른 5개 보기·하트·신고·신고 취소·지워진 글·빈 안내·오프라인, 쓰기 서버 금칙어 → 초안·고쳐서 남김, 노트 받은 하트, 설정 계정 줄·연결·해제·바꾸기·그대로 두기, 계정 삭제(서버 먼저, 오프라인이면 기기도 안 지움), `formatAgo`
  - 백업 uid는 연결한 사용자만, 금칙어는 서버 문서 → 없거나 깨지면 번들

## 에뮬레이터 손 확인 (11/9)

안드로이드 에뮬레이터(API 35, 이 트랙용 AVD `doobal_t1b`를 Homebrew SDK의 이미지로 새로 만듦) + Firebase 에뮬레이터 + 가짜 카카오(`functions/scripts/fake_kakao.ts`). 다른 사람 글 6개는 Firestore에 직접 넣고, 방명록 기회는 기기 DB에 직접 넣었다(걸음이 없어서).

| # | 본 것 | 결과 |
|---|---|---|
| 1 | 만 14세 확인 전 Auth 사용자 0, 누르면 익명 1 | 됨 |
| 2 | 닉네임 정하면 `users/{uid}` = 닉네임·totalSteps 0·createdAt 서버 시각 | 됨 |
| 3 | 비행기 모드로 만 14세 확인 → 다음 화면으로 넘어감(막히지 않음), 로그인 0 → 연결 뒤 앱이 앞으로 오면 로그인 | 됨 |
| 4 | 방명록 남기기 → 서버 글(sent), 읽기 `7명 중 5명`·다른 글 5개·`n일 전` | 됨 |
| 5 | 서버만 막는 말(시험 규칙을 문서에 더함) → 초안 그대로·칸 아래 안내·버튼 꺼짐·기기 저장 없음·기회 열림 → 고쳐 남기면 sent | 됨 |
| 6 | 서버가 막혔던 때의 pending 글 → 연결 뒤 다시 올리다 서버 금칙어 → rejected, 노트에 `올리지 못했어요` | 됨 |
| 7 | 하트 → 서버 하트 +1·채운 하트, 신고 → `신고함`+토스트, 1만 보 미만이라 `counted:false`·신고 수 0 | 됨 |
| 8 | 노트 받은 하트(`guestbook where uid == 나`가 보안 규칙 통과) | 됨 |
| 9 | 카카오(가짜 토큰) → `linked`, `kakaoLinks/9001` = 지금 uid, 앱을 다시 켜도 `카카오로 연결됨` | 됨 |
| 10 | 앱을 뒤로 보내면 자동 백업 → `users/{uid}/backup/state` | 됨 |
| 11 | 앱 데이터 지움(새 기기) → 같은 카카오 → `needsConfirm`(백업 있음) → 바꾸기 → `switched`, 서버가 새 익명 계정을 합치고 지움, 기기 기록이 첫 기기 것(닉네임·출발 동네·방명록)으로 | 됨 |
| 12 | 카카오 해제 → `kakaoLinks` 비움 → 구글(가짜) 연결 → 같은 uid에 google.com | 됨 |
| 13 | 앱 데이터 지움 → 같은 구글 → `credential-already-in-use` → 바꾸기 → 그 계정으로 들어가 복원 | 됨. 새 익명 계정은 서버에 남음(아래 판단 11) |
| 14 | 애플(가짜) 연결 | 됨 |
| 15 | 백업 시험 화면: 로그인 uid의 Firestore로 내보내기·되돌리기 | 됨 |
| 16 | 계정 삭제 → 서버 Auth·users·내 글·내 반응(하트 집계 2→1) 삭제, 기기 지움, 환영 화면 | 됨 |

손으로 못 본 것: 진짜 구글·애플 창(실제 프로젝트 전), 카카오 SDK(1월), App Check(실제 프로젝트), 무선 실기기, iOS, 작성 제한(banned)·`다른 5개 보기` 누르기·오프라인에서 남기기(시험으로만 봄).

손 확인에서 찾아 고친 것(`33b560f`): ① 에뮬레이터에서 App Check를 켜면 가짜 API 키로 토큰을 받다 실패해 함수 호출이 모두 막힘 → 실제 프로젝트에서만 켬 ② 함수 SDK가 API 키 꼴(AIza…, 39자)을 검사함 → 가짜 키를 그 꼴로 ③ 새 기기 시작 때 users 문서 올리기가 동시에 두 번 돌아 두 번째가 규칙에 막힘 → 차례로 ④ 노트의 ♥ 글자가 빨간 이모지로 그려짐 → 아이콘으로.

### 다시 해 보는 법

```bash
cd functions && npm ci && npm run emulators          # 창 1
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-doobal npm run seed   # 창 2
node lib/scripts/fake_kakao.js                        # 창 3 (카카오를 볼 때)
cd app && flutter run --dart-define=DOOBAL_SERVER=emulator
```

- 안드로이드 에뮬레이터는 주소를 안 주면 10.0.2.2로 붙는다.
- 무선 adb 실기기: `adb reverse tcp:9099 tcp:9099`(8080·5001도) 뒤 `--dart-define=DOOBAL_EMULATOR_HOST=127.0.0.1`. 맥 LAN 주소로 붙이려면 `firebase.json` 에뮬레이터 host를 `0.0.0.0`으로 바꾸고 `app/android/app/src/debug/res/xml/network_security_config.xml`에 그 주소를 더한다(reverse를 추천).
- 가짜 로그인 사람 번호: `--dart-define=DOOBAL_FAKE_LOGIN=2`처럼 바꾸면 다른 구글·애플·카카오 사람이 된다(기본 1). 같은 번호면 같은 사람이라 다른 기기에서 ‘바꾸기’를 볼 수 있다.

## 만든 곳

| 파일 | 내용 |
|---|---|
| `lib/data/server.dart` (새) | Firebase를 읽지 않는 약속: `AuthGateway`·`ServerApi`·`RemoteStore`·`KakaoLogin`·`ServerBackend`, `ServerError`(code·`details.reason`·offline), `KakaoSignIn`(linked·needsConfirm·switched), `LinkConflict` |
| `lib/data/firebase_backend.dart` (새) | `startServer()`: `DOOBAL_SERVER=off·emulator·real`(11/22부터 기본 real, 값 없으면 off), 에뮬레이터 연결, App Check. Firebase 구현: Auth(가짜 구글·애플 자격 포함), Callable 6개, users·받은 하트·`config/moderation`, `FirestoreBackupStore`, `FakeKakaoLogin` |
| `lib/data/server_options.dart` (새, 11/22) | 순수 함수 `planServer()`·`realFirebaseOptions()`, 값 이름 `SecretKeys`, `buildSecrets`(secrets.json), 에뮬레이터 가짜 옵션 |
| `lib/app/account_service.dart` (새) | 익명 로그인(만 14세 확인 뒤, 한 번만), users 올리기(차례로, 같은 값 건너뜀), 연결·바꾸기+복원·해제, 서버 계정 삭제, `linkedOf` |
| `lib/app/guestbook_server.dart` (새) | 남기기(서버 먼저, 오프라인이면 pending), pending 다시 올리기, 읽기·반응·받은 하트 |
| `lib/app/server_providers.dart` (새) | `serverBackendProvider`(기본 null), `authUserProvider`, `accountServiceProvider`, `accountStateProvider`, `guestbookServerProvider`, `myHeartsProvider` |
| `lib/app/server_link.dart` (새) | 화면 없이 서버와 맞춤: 만 14세 확인 뒤 로그인, users 올리기, pending 올리기(로그인·동기화 뒤·앞으로 올 때), 백업 uid 계속 듣기 |
| `lib/app/providers.dart` | 본문만: `backupStoreProvider`(서버 있으면 Firestore), `backupUidProvider`(연결한 사용자만), `moderationProvider`(서버 → 번들). `server_providers.dart`를 export. 새 provider 없음 |
| `lib/main.dart` | `startServer()` 뒤 override, `ServerLink`로 감쌈 |
| `lib/ui/guestbook/*` | 읽기 화면 새로(다른 글 5개·하트·신고·빈 안내·오프라인), 쓰기 저장을 `GuestbookServer`로(서버 금칙어·작성 제한 안내), 쓰기 화면 열 때 금칙어 다시 받기, `formatAgo` |
| `lib/ui/note/note_screen.dart` | 받은 하트(아이콘+숫자), rejected 줄 `올리지 못했어요` |
| `lib/ui/settings/settings_account.dart` (새), `settings_screen.dart` | 계정 줄(서버 없으면 예전 `준비 중` 세 줄), 계정 삭제가 서버 먼저 |
| `lib/ui/debug/backup_debug_screen.dart` | 서버가 있으면 로그인 uid의 Firestore 백업으로 시험, 연결 상태 한 줄 |
| `android/app/src/debug/…` | 디버그 빌드만 에뮬레이터 주소에 평문 통신 허용 |
| `functions/scripts/fake_kakao.ts` (새) | 손 확인용 가짜 카카오 API(시험의 가짜 서버와 같은 토큰 꼴) |
| `pubspec.yaml` | `firebase_core` 5.1·`firebase_auth` 7.0·`cloud_firestore` 7.1·`cloud_functions` 7.0·`firebase_app_check` 0.5·`google_sign_in` 7.2 |

## 판단한 곳 (다르면 말해 주세요)

1. **서버는 빌드 때 고른다.** `--dart-define=DOOBAL_SERVER=emulator|real|off`, 지금 기본은 off(옵션 파일이 없어서). off·시험에서는 `serverBackendProvider`가 null이라 모든 것이 지금처럼 기기 안에서 돈다. 실제 프로젝트를 붙이면 기본을 real로 바꾼다. 에뮬레이터는 디버그 빌드에서만 듣는다. **11/22: 기본을 real로 바꿨다. secrets.json 값이 없으면 지금처럼 서버 없이 돈다(아래 ‘실제 연결 준비’).**
2. **`sign_in_with_apple`은 넣지 않았다.** `firebase_auth`의 `AppleAuthProvider`가 iOS는 기기 창, 안드로이드는 웹 창을 띄워서 패키지 6개로 된다. 허락받은 7개 중 하나를 안 쓴 것.
3. **App Check는 실제 프로젝트에서만 켠다.** 디버그 빌드는 디버그 제공자(로그의 토큰을 콘솔에 등록), 출시 빌드는 Play Integrity·App Attest(+DeviceCheck). 에뮬레이터에서 켜면 호출이 모두 막혀서 끈다(손 확인 ①).
4. **카카오 연결 상태는 DB 열 대신 `Profile.linkConsentAt`으로 버틴다.** 구글·애플은 Firebase Auth가 알지만 카카오는 Auth 연결이 아니다. ‘커스텀 토큰 세션 + 연결 동의 시각 있음’이면 카카오로 보고, 해제하면 동의 시각을 지운다(다시 연결할 때 동의 줄이 다시 보이니 뜻도 맞다). 제대로 하려면 열이 필요하다(합칠 때 함께 고칠 것).
5. **계정 줄은 한 번에 하나**(캔버스 10-1): 연결 전 구글·애플·카카오 + 동의 줄, 연결 뒤 `○○로 연결됨` + `연결 해제`.
6. **남기기는 연결돼 있으면 서버에 먼저 올린다.** 서버가 금칙어로 막으면 기기에도 안 남기고 초안을 둬서 고치게 한다(명세 ‘초안을 남겨 고치게’). 오프라인·장애면 기기에만 남기고(pending) 로그인·동기화 뒤·앱이 앞으로 올 때 다시 올린다. 다시 올린 글이 서버 금칙어에 막히면 rejected(고쳐 쓰는 화면은 없음, 아래 물을 것). 작성 제한이면 초안을 두고 `11월 16일까지 방명록을 쓸 수 없어요`(가안). `already-exists`는 보낸 것.
7. **방명록을 열 때 금칙어 문서를 다시 받는다.** 기기 저장은 Firestore 자체 기기 저장(오프라인이면 마지막 값)을 쓰고, 그것도 없거나 읽을 수 없으면 번들 `moderation.json`. 새 저장 자리를 만들지 않았다.
8. **읽기 화면**: 글쓴이 동그라미·‘동행과/혼자’는 빼고(T1a 결정 3번 추천대로) 닉네임·`n일 전`. 하트·신고는 서버대로 한 값(신고하면 하트가 빠진다). `신고함`을 다시 누르면 취소. 신고 확인 창은 없다(명세대로 한 번 누름). `다른 5개 보기`는 보여 준 글 밖에도 글이 있을 때만. 연결이 안 되면 내 글과 `연결되면 다른 여행자의 글을 볼 수 있어요`(가안).
9. **노트 받은 하트**는 노트를 열 때 서버에서 읽는다(`guestbook where uid == 나`). 오프라인이면 기기 저장, 그것도 없으면 하트 없이.
10. **‘바꾸기’ 뒤 그 계정에 백업이 없으면 이 기기 기록을 그대로 둔다**(다음 백업이 그 계정에 올라감). 카카오는 `hasBackup`을 미리 알아서 이때 문구를 바꾼다(`그 계정으로 이어져요`, 가안). 구글·애플은 들어가 보기 전에는 몰라서 늘 명세 문구.
11. **구글·애플 바꾸기에는 서버 합치기가 없다.** 카카오(`kakaoSignIn`)는 서버가 익명 계정의 글·반응을 합치고 지우지만, 구글·애플은 앱이 그 계정으로 들어가기만 해서 새 기기의 익명 계정과 그 글이 서버에 남는다(앱을 지우면 찾을 길 없음). Annie에게 물을 것 1.
12. **계정 삭제는 서버 먼저.** 로그인한 적이 있는데 서버를 못 지우면(오프라인) 기기 기록도 지우지 않고 `인터넷에 연결한 뒤 다시 해 주세요`(먼저 지우면 서버 기록을 찾아 지울 길이 없어진다). 로그인한 적이 없으면 기기만. 첫 확인 문구는 서버가 있으면 `이 기기와 서버의 기록(방명록 포함)이 모두 지워져요`(가안).
13. **users 문서는 닉네임이 있을 때, 값이 바뀔 때마다** 올린다(로그인·동기화로 누적 걸음이 바뀔 때·글 올리기 전). 쓰기 수는 동기화 수 정도.
14. **연결 해제 버튼·안내는 가안**: `연결 해제` 줄 → 시트 `해제하면 앱을 지우거나 기기를 바꿨을 때 이 기록을 찾을 수 없어요. 해제할까요?` / `해제`·`그대로 두기`. 서버 기록과 이 기기 로그인은 그대로(M6).
15. **오류 문구(가안)**: 오프라인 `인터넷에 연결한 뒤 다시 해 주세요`, 준비 전 `아직 준비 중이에요`, 카카오 토큰 `카카오 로그인이 끝났어요. 다시 해 주세요`, 연결 `구글로 연결했어요`·`연결을 해제했어요`·`그 계정의 기록으로 바꿨어요`.
16. **Riverpod 3은 듣는 곳이 없는 provider를 멈춘다.** 자동 백업은 백업 uid를 read로만 읽어서 `ServerLink`가 계속 듣는다.

## 폰 확인 대기에 더할 줄 (`개발_인계.md`는 통합 세션이)

- (실제 프로젝트 연결 뒤) 첫 실행 만 14세 확인 → 익명 로그인, 오프라인에서도 시작이 막히지 않는지.
- 방명록 남기기 → 읽기 5개·하트·신고, 노트 받은 하트, 비행기 모드에서 남기고 연결 뒤 올라가는지.
- 진짜 구글 창(Credential Manager)·애플 웹 창, 다른 폰에서 같은 계정 → 바꾸기 → 복원.
- 설정 계정 줄·해제 시트·계정 삭제(서버 포함) 문구, 큰 글자.
- 배터리·데이터: users 문서가 동기화마다 올라가는 수가 괜찮은지.

## 디자인 기획에 물을 것

- 연결 해제 줄·안내 시트(판단 14), 바꾸기 시트의 백업 없을 때 문구(판단 10), 계정 삭제 첫 확인 문구(판단 12). 캔버스에 없다.
- 읽기 화면 연결 안 됨 문구, 노트 `올리지 못했어요`, 작성 제한 문구.
- 애플 버튼을 안드로이드에도 둘지(지금은 둠, 안드로이드는 웹 창).
- 신고를 다시 눌러 취소하게 둘지, 하트와 신고가 한 값인 것(신고하면 하트가 빠짐)이 괜찮은지.
- 노트 받은 하트를 아이콘+숫자(테라코타)로 그린 것. 캔버스는 `♥ 7` 글자.

## 개발 기획에 물을 것

- 금칙어 안내가 명세(`이 표현은 방명록에 남길 수 없어요`)와 캔버스(`올릴 수 없어요 · 쓸 수 없는 말을 고쳐 주세요`)가 다르다. 앱은 지금 `moderation.json`·서버 `message`를 그대로 쓴다.
- 쓰기 화면 동의 줄이 앱(`남긴 글은 다른 사람들에게 보여요. 이용약관에 동의하고 남겨요`)과 캔버스(`글과 닉네임은 다른 여행자에게 보이고 서버에 저장돼요. 남기면 동의한 거예요.`)가 다르다(계획 7장에 이미 있음).
- 명세 M5는 읽기를 ‘Firestore 직접 조회’, 코드는 Callable `readGuestbook`(T1a). 명세를 코드에 맞출지.

## Annie에게 물을 것

1. **구글·애플로 바꿀 때 새 기기의 익명 기록**(판단 11): ① 그대로 둠(지금) ② 바꾸기 전에 그 익명 계정을 `deleteAccount`로 지움(그 기기에서 쓴 글이 사라짐) ③ 서버에 합치기 함수를 더함(카카오처럼, 약 0.5일, 추정). 추천은 ②: ‘이 기기의 기록은 사라져요’ 문구와 맞고 찾을 수 없는 기록이 서버에 남지 않는다.
2. **서버가 받지 않은 글(rejected)을 고쳐 다시 올리는 곳**이 필요한지. 오프라인에서 쓴 글이 나중에 서버 금칙어에 걸릴 때만 생긴다(앱과 서버가 같은 규칙이라 드묾). 추천: MVP는 두고 노트에 `올리지 못했어요`만.
3. T1a에서 넘어온 **닉네임 금칙어**(T1a 결정 2번)는 이번에도 안 했다.

## 합칠 때 함께 고칠 것

- `providers.dart`: 세 provider 본문과 `export 'server_providers.dart'`. 새 provider는 없다.
- `main.dart`: `main`이 async, `ServerLink`로 감쌈. 시험의 `DoobalApp`은 서버가 null이라 `ServerLink`가 아무것도 안 한다.
- **override**: `syncServiceProvider`가 기다리는 새 provider가 없어서 네 시험 파일(`ui_env.dart` 등)은 안 고쳤다.
- **DB 열 제안**(통합 세션이 번호를 잡을 때): `Profile.kakaoLinkedAt`(또는 `linkedProvider`). 생기면 판단 4의 `linkConsentAt` 겸용을 걷어 낸다. 그 밖의 열은 필요 없었다(글 상태는 기존 `PostStatus` pending·sent·rejected).
- `firestore.rules`·`functions/src`는 안 고쳤다. `functions/scripts/fake_kakao.ts`만 더함(빌드에 들어가지만 배포 `ignore`에 `lib/scripts`가 있다).
- iOS(T6b, 11/28): FlutterFire 새 판의 iOS 최소 판·Podfile, 애플 로그인 capability. 이번에 안 봤다. `GoogleService-Info.plist`는 쓰지 않는다(11/22, secrets.json iOS 키).
- 빌드 중 Gradle이 Android SDK Platform 34를 스스로 받았다(플러그인이 요구). Kotlin 내장 이전 경고(`migrate-to-built-in-kotlin`)가 플러그인 쪽에서 난다(빌드는 됨).
- `CLAUDE.md` 리포 구조 `functions/` 줄(‘배포·앱 연결 전’), 계획 문서 T1b 줄.
- 손 확인 때 만든 AVD `doobal_t1b`(Homebrew SDK `~/.android/avd`)가 남아 있다. 필요 없으면 `avdmanager delete avd -n doobal_t1b`.

## 실제 연결 준비 (11/22, 키·콘솔 없이 한 코드)

브랜치 `claude/t1b-real-prep-bd51b4`, dev-batch `013ac4e`에서 시작했다. 실제 키를 만들거나 적지 않았고, 콘솔과 `firebase login`도 하지 않았다.

- `lib/data/server_options.dart`(새): 순수 함수 `planServer()`·`realFirebaseOptions()`. 빌드 때 `--dart-define-from-file=secrets.json`으로 받은 값(`SecretKeys`)으로 `FirebaseOptions`를 만든다. flutterfire 파일(`firebase_options.dart`·`google-services.json`·`GoogleService-Info.plist`)과 안드로이드 google-services 플러그인은 쓰지 않는다.
- `DOOBAL_SERVER` 기본을 off에서 **real**로 바꿨다. 그 플랫폼의 필수 값이 하나라도 비었거나 견본 값(`Fake…`)이면 서버 없이 돈다(지금과 같음). 꺼진 까닭은 디버그 로그 `서버 끔: …`에 키 이름만 남는다.
- `app/secrets.json.example`(새): 키 9개와 설명. 값은 모두 `Fake: …`다. 이름은 11/22 통합 세션이 정했다(무시 목록·검사 규칙을 바꾸지 않음). 쓰는 법: 리포 루트에서 `cp app/secrets.json.example app/secrets.json` 뒤 값을 채운다(9).
- App Check 디버그 토큰을 secrets.json에서 받는다(`DOOBAL_APP_CHECK_DEBUG_TOKEN`, 디버그 빌드만). iOS 구글 로그인은 옵션의 iOS 클라이언트 id를 쓰고, 없으면 `준비 중`이다(iOS 손 확인 전).
- 시험 `test/data/server_options_test.dart` 18개: off·emulator(디버그·출시)·모르는 이름·기본 real·값 다 있음·하나씩 빠짐·빈칸·앞뒤 공백·견본 값·선택 값·iOS·다른 플랫폼, 견본 파일 키가 코드와 같은지.

| 키 (secrets.json) | 필수 | 어디서 |
|---|---|---|
| `DOOBAL_FIREBASE_PROJECT_ID` | 둘 다 | `doobal-47236` |
| `DOOBAL_FIREBASE_SENDER_ID` | 둘 다 | Firebase 콘솔 → 프로젝트 설정 → 일반 → 프로젝트 번호 |
| `DOOBAL_FIREBASE_ANDROID_API_KEY` | 안드로이드 | Google Cloud 콘솔 → API 및 서비스 → 사용자 인증 정보 → `Android key (auto created by Firebase)` → 키 표시 |
| `DOOBAL_FIREBASE_ANDROID_APP_ID` | 안드로이드 | 프로젝트 설정 → 일반 → 내 앱 → 안드로이드 앱 → 앱 ID |
| `DOOBAL_FIREBASE_IOS_API_KEY` | iOS (11/28 뒤) | 사용자 인증 정보 → `iOS key (auto created by Firebase)` |
| `DOOBAL_FIREBASE_IOS_APP_ID` | iOS (11/28 뒤) | 내 앱 → iOS 앱 → 앱 ID |
| `DOOBAL_FIREBASE_IOS_CLIENT_ID` | 아님 | iOS 앱 등록 뒤 사용자 인증 정보 → OAuth 2.0 클라이언트 ID → iOS 클라이언트. 없으면 iOS 구글 연결만 준비 중 |
| `DOOBAL_GOOGLE_SERVER_CLIENT_ID` | 아님 | Authentication → 로그인 방법 → Google → 웹 SDK 구성 → 웹 클라이언트 ID. 없으면 안드로이드 구글 연결만 준비 중 |
| `DOOBAL_APP_CHECK_DEBUG_TOKEN` | 아님 (디버그 빌드) | App Check → 앱 → 디버그 토큰 관리 → 생성. 없으면 로그에 나오는 기기 토큰을 쓴다(설치할 때마다 바뀜) |

## 실제 프로젝트 연결 (Annie 체크리스트, 순서대로, 모두 Annie가 직접)

키 값은 어디에도 적지 않는다. 콘솔에서 본 값은 먼저 비밀번호 관리자의 ‘두발 Firebase’ 항목에 넣고, secrets.json에는 **비밀번호 관리자에서 복사**해 붙인다. 채팅·문서·커밋 메시지·Drive에는 붙이지 않는다. `.firebaserc`가 없어서 명령마다 `--project doobal-47236`을 붙인다.

### 1. 콘솔 확인 (11/10 켠 것)

- Firebase 콘솔 → 사용량 및 결제: Blaze인지.
- Firestore → 데이터베이스: 위치가 `asia-northeast3`인지(함수 트리거 리전과 같아야 한다).
- Authentication → 로그인 방법: 익명·Google이 켜져 있는지. Apple은 11/28 뒤.

### 2. `firebase login` (리포 `functions/`에서)

```bash
cd functions && npm ci
```

```bash
npx firebase login
```

```bash
npx firebase projects:list
```

- 브라우저가 열리면 프로젝트 주인 Google 계정으로 들어간다. 목록에 `doobal-47236`이 보이면 된다.
- 이 맥의 gcloud 계정은 다른 사람 것이라 쓰지 않는다. `firebase login`은 gcloud와 따로 저장된다.

### 3. 안드로이드 앱 등록과 SHA

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep -E "SHA1|SHA256"
```

(`android`는 디버그 키의 공개 기본 비밀번호다. 출시 키가 아니다.)

- Firebase 콘솔 → 프로젝트 설정(톱니) → 일반 → 내 앱 → 앱 추가 → Android.
  - 패키지 이름 `com.annieha.doobal`, 앱 닉네임 `두발 안드로이드`, ‘디버그 서명 인증서 SHA-1’에 위 SHA1.
  - ‘google-services.json 다운로드’와 ‘Firebase SDK 추가’ 단계는 받지 않고 다음으로 넘긴다(앱이 쓰지 않는다). 받았으면 리포에 두지 말고 지운다.
- 등록한 안드로이드 앱 칸 → ‘디지털 지문 추가’ → SHA-256도 넣는다(App Check Play Integrity가 쓴다).
- 출시 키(T6a 업로드 키)와 Play 앱 서명 키(Play Console → 앱 무결성 → 앱 서명)의 SHA-1·SHA-256은 생기면 같은 곳에 더한다.

### 4. 값 모으기 → 비밀번호 관리자

위 표의 ‘어디서’를 따라 프로젝트 번호·안드로이드 앱 ID·안드로이드 API 키·웹 클라이언트 ID를 비밀번호 관리자에 넣는다. `Android key (auto created by Firebase)`가 목록에 없으면, 프로젝트 설정 → 내 앱에서 google-services.json을 리포 밖(다운로드 폴더)에 받는다. 그 파일의 `current_key` 값을 비밀번호 관리자로 옮기고 파일은 지운다.

### 5. API 키 제한

Google Cloud 콘솔(프로젝트 `doobal-47236`) → API 및 서비스 → 사용자 인증 정보 → `Android key (auto created by Firebase)` → 수정.

- 애플리케이션 제한사항: ‘Android 앱’ → 항목 추가: 패키지 `com.annieha.doobal` + 3의 디버그 SHA-1 → 저장.
- 출시·Play 앱 서명 SHA-1이 생기면 항목을 더한다. 빠진 SHA-1로 서명한 빌드는 로그인·Firestore가 막힌다.
- API 제한사항: Firebase가 정해 둔 목록을 바꾸지 않는다.
- 적용까지 몇 분 걸린다.
- iOS 키(11/28 뒤): ‘iOS 앱’ 제한 + 번들 ID `com.annieha.doobal`.

### 6. App Check 등록 (함수 배포 전에)

함수는 배포 환경에서 App Check를 강제한다(`enforceAppCheck`). 등록하기 전에는 Callable(방명록 남기기·읽기·반응, 카카오, 날씨, 계정 삭제)이 모두 거절된다.

- Firebase 콘솔 → App Check → 앱 → 안드로이드 앱 → Play Integrity → 등록(3의 SHA-256이 필요하다).
- 같은 줄 메뉴(⋮) → 디버그 토큰 관리 → 디버그 토큰 추가 → 이름 `두발 디버그` → 생성 → 값을 비밀번호 관리자에 넣는다. 이것이 `DOOBAL_APP_CHECK_DEBUG_TOKEN`이다.
- App Check → API 탭에서 Firestore·Authentication **강제는 켜지 않는다**(지표를 본 뒤).

### 7. 규칙·함수 배포 (`functions/`에서, firebase.json은 리포 루트에서 찾는다)

기상청 키가 들어 있는지 본다(버전 목록만 나오고 값은 나오지 않는다):

```bash
npx firebase functions:secrets:get KMA_SERVICE_KEY --project doobal-47236
```

없으면 넣는다. 값은 묻는 칸에 비밀번호 관리자에서 복사해 붙인다:

```bash
npx firebase functions:secrets:set KMA_SERVICE_KEY --project doobal-47236
```

배포:

```bash
npx firebase deploy --only firestore:rules,firestore:indexes,functions --project doobal-47236
```

- `KAKAO_APP_ID`를 물으면 1월 카카오 앱 키 전까지 `0`을 넣는다(가안: 어떤 카카오 토큰도 통과하지 않는다). 답은 `functions/.env.doobal-47236`(무시 목록)에 저장된다.
- 첫 배포는 필요한 API(Cloud Functions·Cloud Build·Artifact Registry·Eventarc 등)를 켜자고 묻는다 → 예. 권한이 퍼지기 전이라 트리거 함수가 실패하면 몇 분 뒤 같은 명령을 다시 친다.
- 배포 뒤 콘솔 → Functions에 함수가 `asia-northeast3`으로 보이는지 본다. 규칙을 배포하기 전에는 Firestore가 프로덕션 모드(전부 거부)라 앱이 아무것도 읽고 쓰지 못한다.

### 8. seed (`config/guestbook`·`config/moderation`·`config/weather`)

seed는 Firebase Admin을 써서, `firebase login`이 아니라 Google 기본 자격(ADC)이 필요하다. 이 맥에 있는 다른 사람의 gcloud 설정을 건드리지 않게 Annie 전용 설정 폴더를 쓴다(가안):

```bash
CLOUDSDK_CONFIG=$HOME/.config/gcloud-annie gcloud auth application-default login
```

```bash
npm run build && GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud-annie/application_default_credentials.json GCLOUD_PROJECT=doobal-47236 npm run seed -- --real
```

- `설정 문서를 넣었어요 (doobal-47236)`가 나오면 Firestore에 문서 3개가 보인다. 없으면 방명록이 글을 받지 않는다.
- 다 쓰면 자격을 지울 수 있다:

```bash
CLOUDSDK_CONFIG=$HOME/.config/gcloud-annie gcloud auth application-default revoke
```

### 9. secrets.json 채우기 (리포 루트에서)

견본 `app/secrets.json.example`을 복사한다(리포에 올라가는 것은 견본뿐이다):

```bash
cp app/secrets.json.example app/secrets.json
```

```bash
git check-ignore -v app/secrets.json
```

- 두 번째 명령이 `.gitignore:…:secrets.json`을 보여 줘야 한다(무시 목록). 아무것도 안 나오면 멈추고 묻는다.
- `git status`에 `app/secrets.json`이 보이면 안 된다.
- 편집기로 secrets.json을 열어 `"Fake: …"`를 하나씩 **비밀번호 관리자에서 복사**한 값으로 바꾼다. iOS 세 줄은 11/28 전까지 `Fake…` 그대로 둔다(빈 값으로 본다).
- 이 파일은 그 체크아웃에만 있다. 워크트리에서 빌드하면 값이 없어 서버 없이 돈다. 그때는 이 파일의 절대 경로를 준다.

### 10. 빌드 (리포 `app/`에서)

디버그(폰 확인용, App Check 디버그 토큰):

```bash
flutter run --dart-define-from-file=secrets.json
```

- 로그에 `서버 끔: …`이 없으면 붙은 것이다. `서버 끔: 실제 프로젝트 값이 비었다: <키>`가 나오면 그 키가 비었거나 `Fake`로 남았다.
- 디버그 메뉴의 백업 시험 화면 연결 줄이 `실제 프로젝트 doobal-47236`이다.
- 첫 실행 → 만 14세 확인 → 콘솔 Authentication 사용자에 익명 1명. 닉네임을 정하면 Firestore `users/{uid}`.

출시(Play 내부 테스트에 올릴 때, T6a 서명 뒤):

```bash
flutter build appbundle --release --dart-define-from-file=secrets.json
```

- `--dart-define-from-file`을 빠뜨리면 서버 없이 도는 앱이 된다. 출시 빌드는 까닭 로그도 남기지 않는다.
- 에뮬레이터는 그대로 `--dart-define=DOOBAL_SERVER=emulator`(실제 값을 보지 않는다). 값을 줘도 서버를 끄려면 `--dart-define=DOOBAL_SERVER=off`.

### 11. 나중에

- 카카오(1월 초): `functions/.env.doobal-47236`의 `KAKAO_APP_ID`를 진짜 앱 ID로 바꾼다. Google Cloud 콘솔 → IAM에서 Functions 실행 서비스 계정에 ‘서비스 계정 토큰 생성자’ 역할을 준다(`createCustomToken`). 함수를 다시 배포한다. 앱은 `kakao_flutter_sdk` 허락 뒤 `KakaoLogin` 한 곳만 바꾼다.
- iOS(11/28 뒤, T6b): iOS 앱을 등록한다(번들 ID `com.annieha.doobal`). iOS 세 줄을 secrets.json에 넣고, iOS 키를 제한하고(5), App Check App Attest를 등록한다.
- 애플 로그인: Services ID와 키를 Firebase 콘솔에만 넣는다(`.p8`은 리포에 두지 않는다).
- iOS 구글 로그인: `Info.plist` URL 스킴(거꾸로 쓴 클라이언트 id)이 더 필요하다. `Secrets.xcconfig`(무시 목록)에서 읽게 할 일이고 코드는 아직이다.
- (선택) 쓰지 않는 익명 계정 자동 정리는 Identity Platform 업그레이드가 필요하다.

## 판단 (11/22 실제 연결 준비, 다르면 말해 주세요)

1. **기본 real, 값이 없으면 off.** secrets.json을 주는 것만으로 붙고, 값 없는 빌드·시험·워크트리 빌드는 지금처럼 기기 안에서 돈다. 에뮬레이터는 그대로 `DOOBAL_SERVER=emulator`.
2. **`Fake`로 시작하는 값은 빈 값으로 본다.** 견본을 그대로 복사해 빌드해도 실제 연결을 켜지 않게 했다. 실제 값은 `AIza`·`1:`·숫자·`doobal`로 시작해 겹치지 않는다.
3. **필수는 플랫폼마다 4개**(프로젝트 id·프로젝트 번호·API 키·앱 ID). 구글 클라이언트 id 둘과 App Check 디버그 토큰은 선택이다. 없으면 그 기능만 `준비 중`이고 디버그 로그에 한 줄 남는다.
4. **견본 이름은 `app/secrets.json.example`**(11/22 통합 세션이 정함). `secrets.example.json`은 `.gitignore`의 `secrets.*.json`과 `check_secrets.py`의 비밀 값 파일 이름 규칙에 둘 다 걸린다. 이 이름은 규칙을 바꾸지 않고 통과하고, 내용 검사는 그대로 받는다.
5. **Dart 상수 이름은 `androidKey`·`iosKey`·`appCheckDebug`.** `androidApiKey = 'DOOBAL_…'` 꼴이 검사의 ‘키처럼 보이는 값’에 오탐돼서다. 검사 규칙은 바꾸지 않았다.
6. **꺼진 까닭은 디버그·프로필 빌드에서만 로그를 남긴다.** 키 이름만 남고 값은 남기지 않는다. 기존 `서버 시작 실패: …` 로그는 그대로 뒀다.
7. **넣지 않은 옵션**: `storageBucket`·`authDomain`·웹 앱 값(Storage·웹을 쓰지 않음). iOS 번들 ID는 코드 상수(`com.annieha.doobal`).
8. **`flutterfire_cli`는 이제 필요 없다.** 계획 T1b 줄의 ‘`flutterfire_cli` 허락’은 뺄 수 있다.
9. **App Check 디버그 토큰을 secrets.json에 둔다.** 다시 설치해도 같은 토큰이라 콘솔에 한 번만 등록한다. 새어 나가면 콘솔에서 그 토큰만 지우면 된다.

## 질문 대장 후보 (11/22)

1. ~~견본 파일 이름~~: 11/22 통합 세션이 `app/secrets.json.example`로 정했다(규칙 그대로라 Annie 허락이 필요 없음). `secrets.example.json` + 무시 목록·검사 예외는 하지 않는다.
2. **1월 전 배포 때 `KAKAO_APP_ID`**: ① `0`(가안, 카카오 토큰이 하나도 통과하지 않음) ② 카카오 함수 둘을 빼고 배포(명령이 함수 목록으로 길어진다). 추천 ①.
3. **seed 자격**: ① Annie 전용 gcloud 설정 폴더(가안, 다른 사람 gcloud 설정을 건드리지 않음) ② 콘솔에서 손으로 문서 3개(moderation이 커서 틀리기 쉬움). 추천 ①.
4. **폰 확인 빌드**: 폰에 직접 설치한 출시 빌드는 Play Integrity를 통과하지 못할 수 있다(Play에서 받은 앱이 아니라서, 추정). 그러면 Callable이 거절된다. 추천: 폰 확인은 디버그 빌드 + 디버그 토큰으로 하고, 출시 빌드 확인은 Play 내부 테스트(T6a) 뒤에.
5. **합칠 때(통합 세션)**: `CLAUDE.md` 리포 구조에 `app/secrets.json.example` 한 줄, 계획 T1b 줄에서 `flutterfire_cli` 허락 빼기·‘서버 기본값을 real로’ 끝냄 표시. `tools/check_secrets.py` `FAKE`의 에뮬레이터 키 옆 주석이 `firebase_backend.dart`를 가리키는데, 가짜 옵션은 `server_options.dart`로 옮겼다(값으로 맞추니 검사는 통과, 주석만 낡음, 이 트랙은 그 파일을 안 고침). DB 열 `Profile.kakaoLinkedAt`은 그대로 통합 세션 몫.
