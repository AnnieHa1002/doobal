// 카카오 로그인·계정 합치기·계정 삭제 흐름 시험. 카카오 서버는 가짜를 띄운다
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createServer, type Server } from 'node:http';
import { join } from 'node:path';
import { after, before, describe, test } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  adminAuth,
  db,
  fakePost,
  freshMilestone,
  makeUser,
  ok,
  rejects,
  seed,
  signInWithCustomToken,
} from './helpers';

// .env.demo-doobal의 가짜 값과 맞춘다
const env = Object.fromEntries(
  readFileSync(join(__dirname, '..', '..', '.env.demo-doobal'), 'utf8')
    .split('\n')
    .filter((l) => l.includes('=') && !l.startsWith('#'))
    .map((l) => l.split('=', 2)),
);
const APP_ID = Number(env.KAKAO_APP_ID);
const fakeUrl = new URL(env.KAKAO_API_BASE);

let kakao: Server;
let nextKakaoId = 1000 + process.pid;
let kakaoDown = false;

/** 토큰 꼴: valid:<카카오 id>[:<앱 id>] */
function startFakeKakao(): Promise<void> {
  kakao = createServer((req, res) => {
    const send = (status: number, body: unknown) => {
      res.writeHead(status, { 'content-type': 'application/json' });
      res.end(JSON.stringify(body));
    };
    if (kakaoDown) return send(503, {});
    const [kind, id, appId] = (req.headers.authorization ?? '').replace('Bearer ', '').split(':');
    if (req.url !== '/v1/user/access_token_info' || kind !== 'valid') {
      return send(401, { code: -401, msg: 'this access token does not exist' });
    }
    return send(200, { id: Number(id), expires_in: 7199, app_id: Number(appId ?? APP_ID) });
  });
  return new Promise((resolve) => kakao.listen(Number(fakeUrl.port), fakeUrl.hostname, resolve));
}

const freshKakao = () => `valid:${nextKakaoId++}`;
const kakaoIdOf = (token: string) => token.split(':')[1];

/** A가 kakao에 먼저 연결해 둔 상태 */
async function linkedOwner(fields: Record<string, unknown> = {}) {
  const owner = await makeUser(fields);
  const kakaoAccessToken = freshKakao();
  await ok('kakaoSignIn', { kakaoAccessToken }, owner.idToken);
  return { ...owner, kakaoAccessToken };
}

const exists = async (path: string) => (await db.doc(path).get()).exists;
const authExists = (uid: string) =>
  adminAuth.getUser(uid).then(
    () => true,
    () => false,
  );

before(async () => {
  await seed();
  await startFakeKakao();
});

after(() => new Promise((resolve) => kakao.close(resolve)));

describe('kakaoSignIn: 처음 연결', () => {
  test('지금 uid에 연결하고, 커스텀 토큰으로 같은 uid에 들어간다', async () => {
    const me = await makeUser();
    const kakaoAccessToken = freshKakao();
    const r = await ok('kakaoSignIn', { kakaoAccessToken }, me.idToken);
    assert.equal(r.status, 'linked');
    assert.equal(r.uid, me.uid);
    assert.equal((await db.doc(`kakaoLinks/${kakaoIdOf(kakaoAccessToken)}`).get()).data()!.uid, me.uid);
    const signedIn = await signInWithCustomToken(r.customToken);
    assert.equal(signedIn.uid, me.uid);
    assert.ok(await exists(`users/${me.uid}`), '기록을 옮길 일이 없다');
  });

  test('이미 내 연결이면 다시 불러도 같다 (다음 기기에서 다시 로그인)', async () => {
    const me = await makeUser();
    const kakaoAccessToken = freshKakao();
    await ok('kakaoSignIn', { kakaoAccessToken }, me.idToken);
    const again = await ok('kakaoSignIn', { kakaoAccessToken }, me.idToken);
    assert.equal(again.status, 'linked');
    assert.equal(again.uid, me.uid);
  });

  test('연결된 계정이 Auth에 없으면 지금 uid로 다시 잇는다', async () => {
    const me = await makeUser();
    const kakaoAccessToken = freshKakao();
    await db.doc(`kakaoLinks/${kakaoIdOf(kakaoAccessToken)}`).set({ uid: 'gone-account' });
    const r = await ok('kakaoSignIn', { kakaoAccessToken }, me.idToken);
    assert.equal(r.status, 'linked');
    assert.equal(r.uid, me.uid);
    assert.equal((await db.doc(`kakaoLinks/${kakaoIdOf(kakaoAccessToken)}`).get()).data()!.uid, me.uid);
  });
});

describe('kakaoSignIn: 토큰 확인', () => {
  test('로그인과 토큰이 있어야 한다', async () => {
    const me = await makeUser();
    await rejects('kakaoSignIn', { kakaoAccessToken: freshKakao() }, undefined, 'UNAUTHENTICATED', 'signed-out');
    await rejects('kakaoSignIn', {}, me.idToken, 'INVALID_ARGUMENT', 'bad-token');
  });

  test('카카오가 거절한 토큰은 막고 연결을 만들지 않는다', async () => {
    const me = await makeUser();
    await rejects('kakaoSignIn', { kakaoAccessToken: 'expired:1' }, me.idToken, 'UNAUTHENTICATED', 'kakao-token');
  });

  test('다른 앱에서 받은 토큰은 막는다', async () => {
    const me = await makeUser();
    const id = nextKakaoId++;
    await rejects('kakaoSignIn', { kakaoAccessToken: `valid:${id}:999` }, me.idToken, 'PERMISSION_DENIED', 'kakao-app');
    assert.equal(await exists(`kakaoLinks/${id}`), false);
  });

  test('카카오 장애는 다시 시도할 수 있는 오류다', async () => {
    const me = await makeUser();
    kakaoDown = true;
    try {
      await rejects('kakaoSignIn', { kakaoAccessToken: freshKakao() }, me.idToken, 'UNAVAILABLE', 'kakao-unavailable');
    } finally {
      kakaoDown = false;
    }
  });
});

describe('kakaoSignIn: 다른 계정에 연결된 카카오', () => {
  test('확인 전에는 토큰을 주지 않고 아무것도 바꾸지 않는다', async () => {
    const owner = await linkedOwner();
    await db.doc(`users/${owner.uid}/backup/state`).set({ data: 'a' });
    const me = await makeUser();
    const r = await ok('kakaoSignIn', { kakaoAccessToken: owner.kakaoAccessToken }, me.idToken);
    assert.deepEqual(r, { status: 'needsConfirm', hasBackup: true });
    assert.ok(await exists(`users/${me.uid}`));
    assert.ok(await authExists(me.uid));
  });

  test('확인하면 그 계정 토큰을 주고, 그 계정 백업을 그대로 둔 채 익명 계정을 없앤다', async () => {
    const owner = await linkedOwner();
    await db.doc(`users/${owner.uid}/backup/state`).set({ data: 'phone-a' });
    const me = await makeUser();
    await db.doc(`users/${me.uid}/backup/state`).set({ data: 'phone-b' });
    const r = await ok(
      'kakaoSignIn',
      { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true },
      me.idToken,
    );
    assert.equal(r.status, 'switched');
    assert.equal(r.uid, owner.uid);
    assert.equal(r.merged, true);
    assert.equal(r.backupMoved, false);
    assert.equal(r.hasBackup, true);
    const signedIn = await signInWithCustomToken(r.customToken);
    assert.equal(signedIn.uid, owner.uid);
    assert.equal((await db.doc(`users/${owner.uid}/backup/state`).get()).data()!.data, 'phone-a');
    assert.equal(await exists(`users/${me.uid}`), false);
    assert.equal(await exists(`users/${me.uid}/backup/state`), false);
    assert.equal(await authExists(me.uid), false);
  });

  test('그 계정에 백업이 없으면 지금 계정 백업을 옮긴다', async () => {
    const owner = await linkedOwner();
    const me = await makeUser();
    await db.doc(`users/${me.uid}/backup/state`).set({ data: 'phone-b' });
    const r = await ok(
      'kakaoSignIn',
      { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true },
      me.idToken,
    );
    assert.equal(r.backupMoved, true);
    assert.equal(r.hasBackup, true);
    assert.equal((await db.doc(`users/${owner.uid}/backup/state`).get()).data()!.data, 'phone-b');
    assert.equal(await exists(`users/${me.uid}/backup/state`), false);
  });

  test('제재는 합쳐도 풀리지 않고, 걸음은 큰 쪽, 닉네임은 그 계정 것을 쓴다', async () => {
    const soon = Timestamp.fromMillis(Date.now() + 60_000);
    const late = Timestamp.fromMillis(Date.now() + 600_000);
    const owner = await linkedOwner({ nickname: '본계정', totalSteps: 100, deleteCount: 1, banUntil: soon });
    const me = await makeUser({ nickname: '익명', totalSteps: 500, deleteCount: 2, banUntil: late });
    await ok('kakaoSignIn', { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true }, me.idToken);
    const u = (await db.doc(`users/${owner.uid}`).get()).data()!;
    assert.equal(u.nickname, '본계정');
    assert.equal(u.totalSteps, 500);
    assert.equal(u.deleteCount, 3);
    assert.equal(u.banUntil.toMillis(), late.toMillis());
  });

  test('내 글은 그 계정 글이 되고, 같은 기회의 글이 있으면 그쪽을 남긴다', async () => {
    const owner = await linkedOwner();
    const me = await makeUser();
    const shared = freshMilestone();
    const mineOnly = freshMilestone();
    await ok('postGuestbook', { ...shared, text: '본계정 글' }, owner.idToken);
    await ok('postGuestbook', { ...shared, text: '익명 글(같은 기회)' }, me.idToken);
    await ok('postGuestbook', { ...mineOnly, text: '익명 글' }, me.idToken);
    const fan = await makeUser();
    await ok('react', { postId: `${me.uid}_${mineOnly.ticketId}`, kind: 'heart' }, fan.idToken);

    await ok('kakaoSignIn', { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true }, me.idToken);

    assert.equal((await db.doc(`guestbook/${owner.uid}_${shared.ticketId}`).get()).data()!.text, '본계정 글');
    assert.equal(await exists(`guestbook/${me.uid}_${shared.ticketId}`), false);
    const moved = (await db.doc(`guestbook/${owner.uid}_${mineOnly.ticketId}`).get()).data()!;
    assert.equal(moved.uid, owner.uid);
    assert.equal(moved.text, '익명 글');
    assert.equal(moved.hearts, 1);
    assert.ok(await exists(`guestbook/${owner.uid}_${mineOnly.ticketId}/reactions/${fan.uid}`));
    assert.equal(await exists(`guestbook/${me.uid}_${mineOnly.ticketId}`), false);
    assert.equal(await exists(`guestbook/${me.uid}_${mineOnly.ticketId}/reactions/${fan.uid}`), false);
  });

  test('내 반응은 그 계정 반응이 되고, 겹치거나 그 계정 글이면 집계에서 뺀다', async () => {
    const owner = await linkedOwner();
    const me = await makeUser();
    const stamp = `${process.pid}-${Date.now()}`;
    const [moved, both, ownersPost] = [`moved-${stamp}`, `both-${stamp}`, `owners-${stamp}`];
    await fakePost(moved);
    await fakePost(both);
    await fakePost(ownersPost, { uid: owner.uid });
    await ok('react', { postId: moved, kind: 'heart' }, me.idToken);
    await ok('react', { postId: both, kind: 'heart' }, me.idToken);
    await ok('react', { postId: both, kind: 'heart' }, owner.idToken);
    await ok('react', { postId: ownersPost, kind: 'heart' }, me.idToken);

    await ok('kakaoSignIn', { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true }, me.idToken);

    assert.equal((await db.doc(`guestbook/${moved}`).get()).data()!.hearts, 1);
    const r = (await db.doc(`guestbook/${moved}/reactions/${owner.uid}`).get()).data()!;
    assert.equal(r.uid, owner.uid);
    assert.equal(r.kind, 'heart');
    assert.equal((await db.doc(`guestbook/${both}`).get()).data()!.hearts, 1);
    assert.equal((await db.doc(`guestbook/${ownersPost}`).get()).data()!.hearts, 0);
    for (const p of [moved, both, ownersPost]) {
      assert.equal(await exists(`guestbook/${p}/reactions/${me.uid}`), false);
    }
  });

  test('검토 중인 글은 대기열도 함께 옮긴다', async () => {
    const owner = await linkedOwner();
    const me = await makeUser();
    const { ticketId } = freshMilestone();
    const oldId = `${me.uid}_${ticketId}`;
    await fakePost(oldId, { uid: me.uid, ticketId, hidden: true, reportCount: 5 });
    await db.doc(`reviewQueue/${oldId}`).set({ postId: oldId, uid: me.uid, decision: null });
    await ok('kakaoSignIn', { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true }, me.idToken);
    const newId = `${owner.uid}_${ticketId}`;
    assert.equal(await exists(`reviewQueue/${oldId}`), false);
    const q = (await db.doc(`reviewQueue/${newId}`).get()).data()!;
    assert.equal(q.postId, newId);
    assert.equal(q.uid, owner.uid);
    assert.equal((await db.doc(`guestbook/${newId}`).get()).data()!.hidden, true);
  });

  test('응답을 못 받아 다시 불러도 끝까지 간다', async () => {
    const owner = await linkedOwner();
    const me = await makeUser({ deleteCount: 1 });
    const data = { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true };
    await ok('kakaoSignIn', data, me.idToken);
    const again = await ok('kakaoSignIn', data, me.idToken);
    assert.equal(again.status, 'switched');
    assert.equal(again.uid, owner.uid);
    assert.equal((await db.doc(`users/${owner.uid}`).get()).data()!.deleteCount, 1, '두 번 더하지 않는다');
  });

  test('익명이 아닌 계정은 합치지 않고 토큰만 준다', async () => {
    const owner = await linkedOwner();
    const other = await linkedOwner({ nickname: '다른 계정' });
    // 커스텀 토큰으로 들어온, 다른 카카오에 연결된 계정
    const { customToken } = await ok('kakaoSignIn', { kakaoAccessToken: other.kakaoAccessToken }, other.idToken);
    const signedIn = await signInWithCustomToken(customToken);
    const r = await ok(
      'kakaoSignIn',
      { kakaoAccessToken: owner.kakaoAccessToken, confirmSwitch: true },
      signedIn.idToken,
    );
    assert.equal(r.status, 'switched');
    assert.equal(r.uid, owner.uid);
    assert.equal(r.merged, false);
    assert.equal((await db.doc(`users/${other.uid}`).get()).data()!.nickname, '다른 계정');
    assert.ok(await authExists(other.uid));
  });
});

describe('deleteAccount', () => {
  test('로그인해야 한다', async () => {
    await rejects('deleteAccount', {}, undefined, 'UNAUTHENTICATED', 'signed-out');
  });

  test('users·백업·내 글·반응·kakaoLinks·Auth를 모두 지우고 집계를 되돌린다', async () => {
    const me = await linkedOwner({ totalSteps: 10000, deleteCount: 2 });
    await db.doc(`users/${me.uid}/backup/state`).set({ data: 'gz' });

    // 내 글: 남의 반응까지 함께 사라진다
    const { scope, ticketId } = freshMilestone();
    await ok('postGuestbook', { ticketId, scope, text: '내 글' }, me.idToken);
    const myPost = `${me.uid}_${ticketId}`;
    const fan = await makeUser();
    await ok('react', { postId: myPost, kind: 'heart' }, fan.idToken);
    await db.doc(`reviewQueue/${myPost}`).set({ postId: myPost, uid: me.uid, text: '내 글', decision: null });

    // 내가 누른 반응: 남의 글 집계에서 빠진다
    const stamp = `${process.pid}-${Date.now()}`;
    const [hearted, reported] = [`hearted-${stamp}`, `reported-${stamp}`];
    await fakePost(hearted, { hearts: 3 });
    await fakePost(reported, { reportCount: 2, hidden: false });
    await ok('react', { postId: hearted, kind: 'heart' }, me.idToken);
    await ok('react', { postId: reported, kind: 'report' }, me.idToken);
    assert.equal((await db.doc(`guestbook/${hearted}`).get()).data()!.hearts, 4);
    assert.equal((await db.doc(`guestbook/${reported}`).get()).data()!.reportCount, 3);

    assert.deepEqual(await ok('deleteAccount', {}, me.idToken), { deleted: true });

    assert.equal(await exists(`users/${me.uid}`), false);
    assert.equal(await exists(`users/${me.uid}/backup/state`), false);
    assert.equal(await exists(`guestbook/${myPost}`), false);
    assert.equal(await exists(`guestbook/${myPost}/reactions/${fan.uid}`), false);
    assert.equal(await exists(`reviewQueue/${myPost}`), false);
    assert.equal(await exists(`kakaoLinks/${kakaoIdOf(me.kakaoAccessToken)}`), false);
    assert.equal(await authExists(me.uid), false);

    assert.equal((await db.doc(`guestbook/${hearted}`).get()).data()!.hearts, 3);
    assert.equal((await db.doc(`guestbook/${reported}`).get()).data()!.reportCount, 2);
    assert.equal(await exists(`guestbook/${hearted}/reactions/${me.uid}`), false);
    assert.equal(await exists(`guestbook/${reported}/reactions/${me.uid}`), false);
  });

  test('셈에서 빠진 신고는 집계를 건드리지 않고, 남의 숨긴 글을 되살리지 않는다', async () => {
    const quiet = await makeUser({ totalSteps: 1 });
    const stamp = `${process.pid}-${Date.now()}`;
    const open = `quiet-${stamp}`;
    await fakePost(open, { reportCount: 4 });
    await ok('react', { postId: open, kind: 'report' }, quiet.idToken);

    const loud = await makeUser({ totalSteps: 10000 });
    const blinded = `blinded-${stamp}`;
    await fakePost(blinded, { reportCount: 4 });
    await ok('react', { postId: blinded, kind: 'report' }, loud.idToken);
    assert.equal((await db.doc(`guestbook/${blinded}`).get()).data()!.hidden, true);

    await ok('deleteAccount', {}, quiet.idToken);
    await ok('deleteAccount', {}, loud.idToken);

    assert.equal((await db.doc(`guestbook/${open}`).get()).data()!.reportCount, 4);
    const b = (await db.doc(`guestbook/${blinded}`).get()).data()!;
    assert.equal(b.reportCount, 4);
    assert.equal(b.hidden, true);
  });

  test('글이 지워진 뒤 남은 반응도 지운다', async () => {
    const me = await makeUser();
    await db.doc(`guestbook/removed-post/reactions/${me.uid}`).set({ uid: me.uid, kind: 'heart', counted: true });
    await ok('deleteAccount', {}, me.idToken);
    assert.equal(await exists(`guestbook/removed-post/reactions/${me.uid}`), false);
  });

  test('다시 불러도 오류가 나지 않는다 (앱이 응답을 놓친 경우)', async () => {
    const me = await makeUser();
    await ok('deleteAccount', {}, me.idToken);
    assert.deepEqual(await ok('deleteAccount', {}, me.idToken), { deleted: true });
  });

  test('삭제한 계정의 ID 토큰으로는 글을 못 쓴다 (프로필이 없다)', async () => {
    const me = await makeUser();
    await ok('deleteAccount', {}, me.idToken);
    await rejects(
      'postGuestbook',
      { ...freshMilestone(), text: '안녕' },
      me.idToken,
      'FAILED_PRECONDITION',
      'no-profile',
    );
  });
});
