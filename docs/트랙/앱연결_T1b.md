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
| `lib/data/firebase_backend.dart` (새) | `startServer()`: `DOOBAL_SERVER=off·emulator·real`(기본 off), 에뮬레이터 연결, App Check. Firebase 구현: Auth(가짜 구글·애플 자격 포함), Callable 6개, users·받은 하트·`config/moderation`, `FirestoreBackupStore`, `FakeKakaoLogin` |
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

1. **서버는 빌드 때 고른다.** `--dart-define=DOOBAL_SERVER=emulator|real|off`, 지금 기본은 off(옵션 파일이 없어서). off·시험에서는 `serverBackendProvider`가 null이라 모든 것이 지금처럼 기기 안에서 돈다. 실제 프로젝트를 붙이면 기본을 real로 바꾼다. 에뮬레이터는 디버그 빌드에서만 듣는다.
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
- iOS(T6b, 11/28): FlutterFire 새 판의 iOS 최소 판·Podfile, `GoogleService-Info.plist`, 애플 로그인 capability. 이번에 안 봤다.
- 빌드 중 Gradle이 Android SDK Platform 34를 스스로 받았다(플러그인이 요구). Kotlin 내장 이전 경고(`migrate-to-built-in-kotlin`)가 플러그인 쪽에서 난다(빌드는 됨).
- `CLAUDE.md` 리포 구조 `functions/` 줄(‘배포·앱 연결 전’), 계획 문서 T1b 줄.
- 손 확인 때 만든 AVD `doobal_t1b`(Homebrew SDK `~/.android/avd`)가 남아 있다. 필요 없으면 `avdmanager delete avd -n doobal_t1b`.

## 실제 프로젝트 연결에 남은 일 (Annie 체크리스트, 모두 Annie 허락 뒤)

1. **Blaze**: 콘솔 → 사용량 및 결제에서 요금제 확인(통합 세션이 확인 못 함). Functions 배포에 필요.
2. **로그인 방법**: Authentication → 로그인 방법에서 익명·Google 켜기. Apple은 Apple Developer(11/28) 뒤 Services ID·키를 넣어 켠다.
3. **안드로이드 앱 등록**: 패키지 `com.annieha.doobal`, SHA-1·SHA-256(디버그 키: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`, 출시 키는 T6a 서명 뒤 + Play 앱 서명 키). `flutterfire configure`(flutterfire_cli 설치 허락 필요)로 `firebase_options.dart`·`google-services.json`을 만들고 `realFirebaseOptions()`를 그것으로, `DOOBAL_SERVER` 기본을 real로. 구글 로그인은 웹 클라이언트 id가 필요하다(지금은 `--dart-define=DOOBAL_GOOGLE_SERVER_CLIENT_ID`, 등록 뒤 옵션에서 읽게 바꿈).
4. **`firebase login`**: 지금 CLI에 로그인된 계정이 없다(`functions/node_modules/.bin/firebase login:list` → 없음). 맥 gcloud 계정은 다른 사람 것이라 쓰지 않는다.
5. **카카오(1월 초)**: `functions/.env.doobal-47236`에 `KAKAO_APP_ID`, Functions 서비스 계정에 ‘서비스 계정 토큰 생성자’ 역할(`createCustomToken`). 앱은 `kakao_flutter_sdk` 허락 뒤 `KakaoLogin` 구현 한 곳만 바꾸면 된다.
6. **배포**: `firebase deploy --only firestore:rules,firestore:indexes,functions --project doobal-47236`. 지금 Firestore는 프로덕션 모드(전부 거부)라 규칙 배포 전에는 앱이 아무것도 못 읽고 쓴다.
7. **seed**: `GCLOUD_PROJECT=doobal-47236 npm run seed -- --real`(config/guestbook·config/moderation). 없으면 글을 받지 않는다.
8. **App Check**: 콘솔에 Play Integrity(SHA-256)·App Attest 등록, 디버그 빌드 로그의 디버그 토큰 등록. **함수는 배포 환경에서 이미 App Check를 강제한다**(`enforceAppCheck`)라 등록 전에 배포하면 Callable이 모두 거절된다. Firestore 강제는 지표를 본 뒤 켠다.
9. (선택) 쓰지 않는 익명 계정 자동 정리는 Identity Platform 업그레이드가 필요하다. 판단 11과 같이 본다.
