# functions

두발 서버: 방명록, 카카오 로그인, 계정 삭제. 리전 asia-northeast3, Node 24.
규칙의 기준은 「두발 프로젝트 요약 (기준)」 6장, 구현은 기술 설계서 5장과 M2~M6 명세 M5·M6.

## 실행

Java가 있어야 한다(Firestore 에뮬레이터). 도구는 모두 이 폴더 안에 설치되고, 에뮬레이터 JAR만 처음 실행 때 `~/.cache/firebase/emulators`로 받는다.

```bash
npm ci
```

금칙어·규칙 계산만 시험(에뮬레이터 없음):

```bash
npm run test:unit
```

전부 시험(에뮬레이터 `demo-doobal`을 켜고 끈다. 금칙어 100개, 보안 규칙, 함수 흐름):

```bash
npm test
```

에뮬레이터를 켜 두고 손으로 볼 때:

```bash
npm run emulators
```

그 상태에서 다른 창으로 설정 문서를 넣는다:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-doobal npm run seed
```

## 앱이 부를 Callable

모두 `asia-northeast3`, 로그인 필수. 배포 환경에서는 App Check도 필요하다(에뮬레이터는 끔).

| 이름 | 입력 | 출력 |
|---|---|---|
| `postGuestbook` | `ticketId` `scope` `text` | `{ postId }` |
| `readGuestbook` | `scope` | `{ total, posts: [{ postId, nickname, text, hearts, createdAt(ms), myReaction: heart\|report\|null }] }` |
| `react` | `postId` `kind: heart\|report\|null` | `{ hearts, myReaction }` |
| `kakaoSignIn` | `kakaoAccessToken` `confirmSwitch?: bool` | 아래 표 |
| `kakaoUnlink` | 없음 | `{ unlinked }` (지운 연결 수) |
| `deleteAccount` | 없음 | `{ deleted: true }` |

- `ticketId`·`scope`는 앱 `domain/guestbook.dart` 꼴 그대로: `a:<여정 id>`와 명소 id·`sketch`, `m:<숫자>`와 `steps:<숫자>`.
- `readGuestbook`은 내 글을 빼고 준다. 내 글은 앱이 로컬 DB로 보여 주고, 전체 목록이 필요하면 `guestbook where uid == 내 uid`를 직접 읽는다. `total`은 화면의 ‘n명 중 5명’ 값으로, 숨김을 뺀 그 범위의 글 수다(내 글 포함). ‘다른 5개 보기’는 다시 호출하면 된다.
- `react`는 글 하나에 내 반응 하나만 둔다. `kind`를 바꾸면 옮겨지고 `null`이면 취소다. 프로토타입은 하트와 신고가 따로 켜지지만, 서버는 설계대로 한 값이라 신고하면 내 하트가 빠진다.

`kakaoSignIn` 결과:

| `status` | 뜻 | 나머지 값 | 앱이 할 일 |
|---|---|---|---|
| `linked` | 처음 연결했거나 이미 내 연결 | `uid` `customToken` | 토큰으로 로그인(uid 그대로) |
| `needsConfirm` | 다른 계정에 연결된 카카오 | `hasBackup` | "그 계정의 기록으로 바꿀까요? 이 기기의 기록은 사라져요" 뒤 `confirmSwitch: true`로 다시 호출 |
| `switched` | 그 계정으로 바꿈 | `uid` `customToken` `merged` `backupMoved` `hasBackup` | 토큰으로 로그인 → `hasBackup`이면 복원 |

`merged`가 참이면 그냥 익명 계정이라서 서버 기록을 그 계정으로 합치고 익명 계정을 없앴다는 뜻이다: 글·반응은 옮기고(같은 기회의 글이 있으면 그 계정 것을 남김), 백업은 그 계정에 없을 때만 옮기고(`backupMoved`), 제재는 삭제 횟수를 더하고 늦은 제한을 쓴다. 구글·애플·다른 카카오에 연결된 계정은 합치지 않고 그대로 둔다.

`kakaoUnlink`는 이 계정의 `kakaoLinks`만 지운다(M6: 서버 기록은 그대로). 이 기기의 로그인은 유지되지만, 다른 연결이 없으면 앱을 지운 뒤나 다른 기기에서 이 기록을 찾을 수 없으니 앱이 해제 전에 알려야 한다. 같은 카카오로 다시 로그인하면 처음처럼 그때의 uid에 연결된다. 카카오 쪽 연결 끊기가 필요하면 앱의 카카오 SDK가 한다.

### 오류

`HttpsError`의 `details.reason`으로 나눈다. 금칙어 안내는 `message`를 그대로 보여 주고, 어떤 낱말인지는 알려 주지 않는다.

| 코드 | `reason` | 언제 |
|---|---|---|
| `unauthenticated` | `signed-out` | 로그인 안 함 |
| `invalid-argument` | `bad-scope` `bad-ticket` `bad-text` `bad-length` `bad-post` `bad-kind` `bad-token` | 입력이 틀림(글은 1~200자) |
| `invalid-argument` | `moderation` | 금칙어. 초안을 남겨 고치게 한다 |
| `permission-denied` | `banned` | 작성 제한 중. `details.banUntil`(ms) |
| `already-exists` | `duplicate` | 그 기회로 이미 씀. 재전송이면 보낸 것으로 처리. `details.postId` |
| `failed-precondition` | `no-profile` | `users/{uid}`에 닉네임이 없음 |
| `not-found` | `no-post` | 지워졌거나 숨긴 글 |
| `permission-denied` | `own-post` | 내 글에 반응 |
| `unauthenticated` | `kakao-token` | 카카오 토큰 만료·거절 |
| `permission-denied` | `kakao-app` | 다른 앱에서 받은 카카오 토큰 |
| `unavailable` | `kakao-unavailable` | 카카오 장애. 다시 시도 |

## Firestore 구조

| 문서 | 값 | 쓰는 쪽 |
|---|---|---|
| `users/{uid}` | `nickname` `totalSteps` `createdAt` / `banUntil` `deleteCount` | 앱(본인) / 서버만 |
| `users/{uid}/backup/state` | 백업 | 앱(본인) |
| `guestbook/{uid_ticketId}` | `uid` `nickname` `scope` `ticketId` `text` `rand` `hearts` `reportCount` `hidden` `createdAt` `reviewed?` | 서버만 |
| `guestbook/{id}/reactions/{uid}` | `uid` `kind` `counted` `at` | 서버만 |
| `kakaoLinks/{kakaoId}` | `uid` `linkedAt` | 서버만 |
| `reviewQueue/{postId}` | 글 사본, `reviewBy`, `decision` | 서버 + Annie(콘솔) |
| `stats/moderation_{yyyy-MM-dd}` | `count` (한국 날짜) | 서버만 |
| `config/guestbook` | config.json `guestbook`과 같은 키 | `npm run seed` |
| `config/moderation` | moderation.json + `allow.autoWords`(명소·시군구 이름) | `npm run seed` |

앱은 `users/{uid}`를 직접 만들고(`createdAt`은 서버 시각만) `nickname`·`totalSteps`를 올려야 한다. 닉네임이 없으면 글을 못 쓰고, `totalSteps`가 없으면 신고가 셈에 들지 않는다.

## 검토 (Annie, Firebase 콘솔)

1. 콘솔에서 `reviewQueue`를 연다. 숨겨진 글이 `reviewBy`(48시간)와 함께 쌓인다.
2. 문서의 `decision`을 문자열 `delete` 또는 `restore`로 바꾼다.
3. 트리거 `onReviewDecision`이 처리하고 대기열 문서를 지운다.
   - `delete`: 글·반응 삭제, 작성자 `deleteCount` +1, 3 이상이면 `banUntil` = 7일 뒤.
   - `restore`: 다시 보이게 하고 `reviewed` 표시. 글이 바뀌지 않으니 이후 신고로 다시 숨기지 않는다.

## 배포 전 할 일 (아직 안 함)

1. Firebase 프로젝트를 Blaze로 만들고 Firestore 위치를 `asia-northeast3`으로 정한다. 트리거 리전과 같아야 한다.
2. `functions/.env.<프로젝트 id>`에 카카오 앱 ID를 넣는다.

   ```
   KAKAO_APP_ID=진짜_앱_ID
   ```

3. Functions 실행 서비스 계정에 `서비스 계정 토큰 생성자` 역할을 준다. `createCustomToken`이 쓴다.
4. 설정 문서를 넣는다(구글 로그인 필요): `GCLOUD_PROJECT=<프로젝트 id> npm run seed -- --real`
5. App Check를 켠다(iOS App Attest, 안드로이드 Play Integrity). 앱이 토큰을 붙이기 전에 배포하면 Callable이 모두 거절된다.

금칙어 문서를 바꾸면 인스턴스 캐시(5분) 뒤에 반영된다.

## 파일

- `src/moderation.ts`: 금칙어(MIT 고지 포함). `app/lib/domain/moderation.dart`와 같은 코드다. 고치면 양쪽을 같이 고친다.
- `src/rules.ts`: 규칙 계산(순수 함수). `src/guestbook.ts` `src/review.ts` `src/kakao.ts` `src/account.ts`: 함수.
- `scripts/seed.ts`: 설정 문서 넣기. `test/`: 시험. 카카오는 `test/account.test.ts`의 가짜 서버를 쓰고 값은 `.env.demo-doobal`에 있다.
- 리포 루트의 `firebase.json` `firestore.rules` `firestore.indexes.json`.
