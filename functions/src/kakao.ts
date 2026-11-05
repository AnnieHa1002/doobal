// 카카오 로그인 (기술 설계서 5장 B안, M2~M6 명세 M5 계정).
// 앱이 카카오 토큰과 지금 uid의 ID 토큰으로 부르면 kakaoLinks/{kakaoId}를 보고 커스텀 토큰을 준다
import { auth, callableOptions, db, fail, isEmulator, requireUid } from './firebase';
import { defineString } from 'firebase-functions/params';
import { onCall, type CallableRequest } from 'firebase-functions/v2/https';
import { authUserOrNull, deleteKakaoLinks, mergeAnonymousInto } from './account';
import { FieldValue } from 'firebase-admin/firestore';

/** 카카오 앱 ID. 다른 앱에서 받은 토큰을 막는 값이다. 진짜 값은 .env.<프로젝트 id>에 둔다 */
const KAKAO_APP_ID = defineString('KAKAO_APP_ID');
const KAKAO_API = 'https://kapi.kakao.com';
const KAKAO_TIMEOUT_MS = 5000;

/** 시험은 가짜 카카오 서버로 보낸다. 주소를 바꾸는 값은 에뮬레이터에서만 듣는다 */
function kakaoApiBase(): string {
  return isEmulator ? (process.env.KAKAO_API_BASE ?? KAKAO_API) : KAKAO_API;
}

/** 토큰을 카카오에 확인하고 카카오 id를 돌려준다 */
async function kakaoIdOf(accessToken: string): Promise<string> {
  let res: Response;
  try {
    res = await fetch(`${kakaoApiBase()}/v1/user/access_token_info`, {
      headers: { Authorization: `Bearer ${accessToken}` },
      signal: AbortSignal.timeout(KAKAO_TIMEOUT_MS),
    });
  } catch {
    throw fail('unavailable', 'kakao-unavailable', '카카오에 연결하지 못했어요');
  }
  if (res.status === 400 || res.status === 401) {
    throw fail('unauthenticated', 'kakao-token', '카카오 로그인이 끝났어요');
  }
  if (!res.ok) throw fail('unavailable', 'kakao-unavailable', '카카오에 연결하지 못했어요');

  const body = (await res.json()) as { id?: unknown; app_id?: unknown };
  if (String(body.app_id) !== KAKAO_APP_ID.value()) {
    throw fail('permission-denied', 'kakao-app', '이 앱의 카카오 로그인이 아니에요');
  }
  if (typeof body.id !== 'number' || !Number.isSafeInteger(body.id)) {
    throw fail('unavailable', 'kakao-unavailable', '카카오 응답이 올바르지 않아요');
  }
  return String(body.id);
}

/** 그냥 익명 계정인지. 구글·애플·다른 카카오에 연결된 계정은 다시 들어올 수 있으니 합치지 않는다 */
async function isPlainAnonymous(request: CallableRequest, uid: string): Promise<boolean> {
  if (request.auth?.token.firebase?.sign_in_provider !== 'anonymous') return false;
  const user = await authUserOrNull(uid);
  if (user !== null && user.providerData.length > 0) return false;
  const links = await db.collection('kakaoLinks').where('uid', '==', uid).limit(1).get();
  return links.empty;
}

async function hasBackup(uid: string): Promise<boolean> {
  return (await db.doc(`users/${uid}/backup/state`).get()).exists;
}

export const kakaoSignIn = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const { kakaoAccessToken, confirmSwitch } = request.data ?? {};
  if (typeof kakaoAccessToken !== 'string' || kakaoAccessToken.length === 0) {
    throw fail('invalid-argument', 'bad-token', '카카오 토큰이 없어요');
  }

  const kakaoId = await kakaoIdOf(kakaoAccessToken);
  const linkRef = db.doc(`kakaoLinks/${kakaoId}`);

  // 처음 보는 카카오 id면 지금 uid에 연결한다. 기록을 옮길 일이 없다
  let owner = await db.runTransaction(async (tx) => {
    const link = await tx.get(linkRef);
    const linked = link.data()?.uid as string | undefined;
    if (linked !== undefined) return linked;
    tx.create(linkRef, { uid, linkedAt: FieldValue.serverTimestamp() });
    return uid;
  });

  // 연결된 계정이 Auth에 없으면 끊어진 연결이다. 지금 uid로 다시 잇는다
  if (owner !== uid && (await authUserOrNull(owner)) === null) {
    await linkRef.set({ uid, linkedAt: FieldValue.serverTimestamp() });
    owner = uid;
  }

  if (owner === uid) {
    return { status: 'linked', uid, customToken: await auth.createCustomToken(uid) };
  }

  // 다른 계정에 연결돼 있으면 앱이 "그 계정의 기록으로 바꿀까요?"를 물은 뒤 confirmSwitch로 다시 부른다
  if (confirmSwitch !== true) {
    return { status: 'needsConfirm', hasBackup: await hasBackup(owner) };
  }

  // 토큰부터 만든다. 서명 권한 문제로 실패해도 지금 계정이 그대로 남는다
  const customToken = await auth.createCustomToken(owner);
  const merged = await isPlainAnonymous(request, uid);
  const backupMoved = merged ? await mergeAnonymousInto(uid, owner) : false;
  return {
    status: 'switched',
    uid: owner,
    customToken,
    merged,
    backupMoved,
    hasBackup: await hasBackup(owner),
  };
});

/**
 * 카카오 연결 해제 (M6 설정: 서버 기록은 그대로). 구글·애플은 Auth unlink로 끝나지만 카카오는
 * Auth 연결이 아니라 kakaoLinks 문서라 서버가 지운다. 이 기기의 로그인은 유지된다
 */
export const kakaoUnlink = onCall(callableOptions, async (request) => {
  return { unlinked: await deleteKakaoLinks(requireUid(request)) };
});
