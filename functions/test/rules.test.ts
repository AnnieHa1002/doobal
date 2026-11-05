// 보안 규칙 시험 (M5 완료 기준: 남의 backup 읽기 거부, guestbook 직접 쓰기 거부)
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { after, before, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

let env: RulesTestEnvironment;

const me = () => env.authenticatedContext('me').firestore();
const other = () => env.authenticatedContext('other').firestore();
const stranger = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-doobal-rules',
    firestore: { rules: readFileSync(join(__dirname, '..', '..', '..', 'firestore.rules'), 'utf8') },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/me'), { nickname: '나', totalSteps: 10, deleteCount: 2 });
    await setDoc(doc(db, 'users/me/backup/state'), { data: 'gz' });
    await setDoc(doc(db, 'users/other/backup/state'), { data: 'gz' });
    await setDoc(doc(db, 'guestbook/shown'), { uid: 'other', scope: 'kr001', hidden: false, rand: 0.5 });
    await setDoc(doc(db, 'guestbook/hiddenOther'), { uid: 'other', scope: 'kr001', hidden: true, rand: 0.5 });
    await setDoc(doc(db, 'guestbook/hiddenMine'), { uid: 'me', scope: 'kr001', hidden: true, rand: 0.5 });
    await setDoc(doc(db, 'guestbook/shown/reactions/me'), { uid: 'me', kind: 'report', counted: false });
    await setDoc(doc(db, 'config/moderation'), { version: 1 });
    await setDoc(doc(db, 'kakaoLinks/1'), { uid: 'me' });
    await setDoc(doc(db, 'reviewQueue/shown'), { uid: 'other' });
    await setDoc(doc(db, 'stats/moderation_2026-11-05'), { count: 1 });
  });
});

after(() => env.cleanup());

describe('users', () => {
  test('본인만 읽는다', async () => {
    await assertSucceeds(getDoc(doc(me(), 'users/me')));
    await assertFails(getDoc(doc(other(), 'users/me')));
    await assertFails(getDoc(doc(stranger(), 'users/me')));
  });

  test('본인은 닉네임·걸음을 만들고 고친다', async () => {
    const db = env.authenticatedContext('fresh').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users/fresh'), { nickname: '새싹', totalSteps: 0, createdAt: serverTimestamp() }),
    );
    await assertSucceeds(updateDoc(doc(db, 'users/fresh'), { nickname: '새싹이', totalSteps: 120 }));
    await assertSucceeds(setDoc(doc(db, 'users/fresh'), { totalSteps: 130 }, { merge: true }));
  });

  test('남의 문서는 쓰지 못한다', async () => {
    await assertFails(setDoc(doc(other(), 'users/me'), { nickname: '해킹' }, { merge: true }));
    await assertFails(setDoc(doc(stranger(), 'users/new'), { nickname: '해킹' }));
  });

  test('제재 기록은 본인도 만들거나 고치지 못한다', async () => {
    const db = env.authenticatedContext('banned').firestore();
    await assertFails(setDoc(doc(db, 'users/banned'), { nickname: '길벗', deleteCount: 0 }));
    await assertFails(setDoc(doc(db, 'users/banned'), { nickname: '길벗', banUntil: null }));
    await assertFails(updateDoc(doc(me(), 'users/me'), { deleteCount: 0 }));
    await assertFails(updateDoc(doc(me(), 'users/me'), { banUntil: null }));
  });

  test('문서를 지워 제재를 없애지 못한다', async () => {
    await assertFails(deleteDoc(doc(me(), 'users/me')));
  });

  test('값이 이상하면 막는다', async () => {
    await assertFails(updateDoc(doc(me(), 'users/me'), { totalSteps: -1 }));
    await assertFails(updateDoc(doc(me(), 'users/me'), { totalSteps: 1.5 }));
    await assertFails(updateDoc(doc(me(), 'users/me'), { nickname: '' }));
    await assertFails(updateDoc(doc(me(), 'users/me'), { nickname: '가'.repeat(21) }));
    await assertFails(updateDoc(doc(me(), 'users/me'), { createdAt: serverTimestamp() }));
  });
});

describe('backup', () => {
  test('본인만 읽고 쓴다', async () => {
    await assertSucceeds(getDoc(doc(me(), 'users/me/backup/state')));
    await assertSucceeds(setDoc(doc(me(), 'users/me/backup/state'), { data: 'gz2' }));
    await assertFails(getDoc(doc(me(), 'users/other/backup/state')));
    await assertFails(setDoc(doc(me(), 'users/other/backup/state'), { data: 'x' }));
    await assertFails(getDoc(doc(stranger(), 'users/me/backup/state')));
  });

  test('state 문서 하나뿐이다', async () => {
    await assertFails(setDoc(doc(me(), 'users/me/backup/other'), { data: 'x' }));
  });
});

describe('guestbook', () => {
  test('로그인하면 읽고, 안 하면 못 읽는다', async () => {
    await assertSucceeds(getDoc(doc(me(), 'guestbook/shown')));
    await assertFails(getDoc(doc(stranger(), 'guestbook/shown')));
  });

  test('숨긴 글은 쓴 사람만 읽는다', async () => {
    await assertFails(getDoc(doc(me(), 'guestbook/hiddenOther')));
    await assertSucceeds(getDoc(doc(me(), 'guestbook/hiddenMine')));
  });

  test('숨김을 뺀 목록과 내 글 목록은 읽고, 전체 목록은 못 읽는다', async () => {
    const col = collection(me(), 'guestbook');
    await assertSucceeds(
      getDocs(
        query(col, where('scope', '==', 'kr001'), where('hidden', '==', false), orderBy('rand'), limit(5)),
      ),
    );
    await assertSucceeds(getDocs(query(col, where('uid', '==', 'me'))));
    await assertFails(getDocs(query(col, limit(5))));
  });

  test('글쓴이도 직접 쓰지 못한다', async () => {
    const db = me();
    await assertFails(setDoc(doc(db, 'guestbook/me_m:100'), { uid: 'me', text: '직접', hidden: false }));
    await assertFails(updateDoc(doc(db, 'guestbook/hiddenMine'), { hidden: false }));
    await assertFails(updateDoc(doc(other(), 'guestbook/shown'), { hearts: 100 }));
    await assertFails(deleteDoc(doc(db, 'guestbook/hiddenMine')));
  });

  test('반응은 내 것도 직접 읽거나 쓰지 못한다', async () => {
    await assertFails(getDoc(doc(me(), 'guestbook/shown/reactions/me')));
    await assertFails(setDoc(doc(me(), 'guestbook/shown/reactions/me'), { kind: 'heart' }));
  });
});

describe('그 밖의 문서', () => {
  test('설정은 로그인 읽기만', async () => {
    await assertSucceeds(getDoc(doc(me(), 'config/moderation')));
    await assertFails(getDoc(doc(stranger(), 'config/moderation')));
    await assertFails(setDoc(doc(me(), 'config/moderation'), { version: 2 }));
    await assertFails(setDoc(doc(me(), 'config/guestbook'), { banDays: 0 }));
  });

  test('카카오 연결·검토 대기열·통계에는 닿지 못한다', async () => {
    for (const path of ['kakaoLinks/1', 'reviewQueue/shown', 'stats/moderation_2026-11-05', 'anything/else']) {
      await assertFails(getDoc(doc(me(), path)));
      await assertFails(setDoc(doc(me(), path), { x: 1 }));
    }
  });
});
