// 에뮬레이터 시험 도구. npm test(firebase emulators:exec) 안에서만 돈다
import assert from 'node:assert/strict';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { seedConfig } from '../scripts/seed';

export const PROJECT = 'demo-doobal';

if (getApps().length === 0) initializeApp({ projectId: PROJECT });
export const db = getFirestore();
export const adminAuth = getAuth();

const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/asia-northeast3`;
const AUTH = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1`;

export const seed = () => seedConfig(db);

interface Account {
  uid: string;
  idToken: string;
}

async function authPost(path: string, body: unknown): Promise<Account> {
  const res = await fetch(`${AUTH}/${path}?key=fake`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const json = (await res.json()) as { idToken: string };
  assert.equal(res.status, 200, JSON.stringify(json));
  // uid는 ID 토큰 안의 값을 믿는다 (커스텀 토큰 응답에는 localId가 없다)
  const claims = JSON.parse(Buffer.from(json.idToken.split('.')[1], 'base64url').toString());
  return { uid: claims.user_id as string, idToken: json.idToken };
}

/** 앱의 익명 로그인 */
export const signInAnonymously = () => authPost('accounts:signUp', { returnSecureToken: true });

/** 앱이 kakaoSignIn에서 받은 커스텀 토큰으로 로그인 */
export const signInWithCustomToken = (token: string) =>
  authPost('accounts:signInWithCustomToken', { token, returnSecureToken: true });

export interface CallError {
  status: string;
  message: string;
  details?: Record<string, any>;
}

/** Callable을 앱과 같은 HTTP 규약으로 부른다 */
export async function call(name: string, data: unknown, idToken?: string) {
  const res = await fetch(`${FUNCTIONS}/${name}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(idToken === undefined ? {} : { authorization: `Bearer ${idToken}` }),
    },
    body: JSON.stringify({ data }),
  });
  return (await res.json()) as { result?: any; error?: CallError };
}

export async function ok(name: string, data: unknown, idToken?: string): Promise<any> {
  const { result, error } = await call(name, data, idToken);
  assert.equal(error, undefined, `${name}: ${JSON.stringify(error)}`);
  return result;
}

export async function rejects(
  name: string,
  data: unknown,
  idToken: string | undefined,
  status: string,
  reason?: string,
): Promise<CallError> {
  const { error } = await call(name, data, idToken);
  assert.ok(error !== undefined, `${name}: 실패해야 해요`);
  assert.equal(error.status, status, JSON.stringify(error));
  if (reason !== undefined) assert.equal(error.details?.reason, reason, JSON.stringify(error));
  return error;
}

/** 닉네임과 걸음이 서버에 있는 사용자 (앱이 users/{uid}에 올린 상태) */
export async function makeUser(
  fields: Record<string, unknown> = {},
): Promise<Account> {
  const account = await signInAnonymously();
  await db.doc(`users/${account.uid}`).set({ nickname: '두발이', totalSteps: 0, ...fields });
  return account;
}

let counter = 0;

/** 시험마다 겹치지 않는 걸음 숫자. 범위는 steps:N, 기회는 m:N */
export function freshMilestone(): { scope: string; ticketId: string } {
  counter += 1;
  const n = process.pid * 1000 + counter;
  return { scope: `steps:${n}`, ticketId: `m:${n}` };
}

export function fakePost(
  id: string,
  fields: Record<string, unknown> = {},
): Promise<FirebaseFirestore.WriteResult> {
  return db.doc(`guestbook/${id}`).set({
    uid: 'someone',
    nickname: '길벗',
    scope: 'kr001',
    ticketId: `m:${id}`,
    text: '좋은 길이에요',
    rand: Math.random(),
    hearts: 0,
    reportCount: 0,
    hidden: false,
    createdAt: Timestamp.now(),
    ...fields,
  });
}

/** 트리거가 처리할 때까지 기다린다 */
export async function waitFor(what: string, check: () => Promise<boolean>, ms = 20000): Promise<void> {
  const until = Date.now() + ms;
  while (Date.now() < until) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 100));
  }
  assert.fail(`시간 안에 끝나지 않았어요: ${what}`);
}
