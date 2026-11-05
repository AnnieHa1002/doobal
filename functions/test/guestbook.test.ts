// 방명록 흐름 시험: 작성·읽기·반응·검토·제재
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { before, describe, test } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import { kstDate } from '../src/rules';
import { db, fakePost, freshMilestone, makeUser, ok, rejects, seed, waitFor } from './helpers';

before(seed);

describe('postGuestbook', () => {
  test('글을 저장하고 문서 id는 uid_ticketId다', async () => {
    const { uid, idToken } = await makeUser({ nickname: '솔길' });
    const { scope, ticketId } = freshMilestone();
    const { postId } = await ok('postGuestbook', { ticketId, scope, text: '  안개 낀 아침이에요  ' }, idToken);
    assert.equal(postId, `${uid}_${ticketId}`);
    const post = (await db.doc(`guestbook/${postId}`).get()).data()!;
    assert.equal(post.uid, uid);
    assert.equal(post.nickname, '솔길');
    assert.equal(post.scope, scope);
    assert.equal(post.text, '안개 낀 아침이에요');
    assert.equal(post.hearts, 0);
    assert.equal(post.reportCount, 0);
    assert.equal(post.hidden, false);
    assert.ok(post.rand >= 0 && post.rand < 1);
    assert.ok(post.createdAt instanceof Timestamp);
  });

  test('도착 기회는 명소·첫 여정 범위에 쓴다', async () => {
    const { uid, idToken } = await makeUser();
    await ok('postGuestbook', { ticketId: 'a:j1', scope: 'kr001', text: '도착했어요' }, idToken);
    await ok('postGuestbook', { ticketId: 'a:j2', scope: 'sketch', text: '첫 그림이에요' }, idToken);
    assert.ok((await db.doc(`guestbook/${uid}_a:j1`).get()).exists);
    assert.ok((await db.doc(`guestbook/${uid}_a:j2`).get()).exists);
  });

  test('로그인해야 한다', async () => {
    const { scope, ticketId } = freshMilestone();
    await rejects('postGuestbook', { ticketId, scope, text: '안녕' }, undefined, 'UNAUTHENTICATED');
  });

  test('같은 기회로 두 번 못 쓴다', async () => {
    const { uid, idToken } = await makeUser();
    const { scope, ticketId } = freshMilestone();
    await ok('postGuestbook', { ticketId, scope, text: '처음' }, idToken);
    const e = await rejects(
      'postGuestbook',
      { ticketId, scope, text: '두 번째' },
      idToken,
      'ALREADY_EXISTS',
      'duplicate',
    );
    assert.equal(e.details?.postId, `${uid}_${ticketId}`);
    assert.equal((await db.doc(`guestbook/${uid}_${ticketId}`).get()).data()!.text, '처음');
  });

  test('200자까지 받고, 빈 글·201자는 막는다', async () => {
    const { idToken } = await makeUser();
    const a = freshMilestone();
    await ok('postGuestbook', { ...a, text: '가'.repeat(200) }, idToken);
    const b = freshMilestone();
    await rejects('postGuestbook', { ...b, text: '가'.repeat(201) }, idToken, 'INVALID_ARGUMENT', 'bad-length');
    await rejects('postGuestbook', { ...b, text: '   ' }, idToken, 'INVALID_ARGUMENT', 'bad-length');
    await rejects('postGuestbook', { ...b, text: 3 }, idToken, 'INVALID_ARGUMENT', 'bad-text');
  });

  test('기회·범위 꼴이 틀리면 막는다', async () => {
    const { idToken } = await makeUser();
    await rejects('postGuestbook', { ticketId: 'm:1', scope: 'bad/scope', text: '글' }, idToken, 'INVALID_ARGUMENT', 'bad-scope');
    await rejects('postGuestbook', { ticketId: 'x/y', scope: 'kr001', text: '글' }, idToken, 'INVALID_ARGUMENT', 'bad-ticket');
    await rejects('postGuestbook', { ticketId: 'm:100', scope: 'steps:200', text: '글' }, idToken, 'INVALID_ARGUMENT', 'bad-ticket');
  });

  test('닉네임이 서버에 없으면 막는다', async () => {
    const account = await makeUser();
    await db.doc(`users/${account.uid}`).delete();
    const { scope, ticketId } = freshMilestone();
    await rejects('postGuestbook', { ticketId, scope, text: '글' }, account.idToken, 'FAILED_PRECONDITION', 'no-profile');
  });

  test('금칙어는 저장하지 않고 하루 개수만 늘린다. 어떤 낱말인지 알려 주지 않는다', async () => {
    const { uid, idToken } = await makeUser();
    const { scope, ticketId } = freshMilestone();
    const statsRef = db.doc(`stats/moderation_${kstDate(Date.now())}`);
    const before = (await statsRef.get()).data()?.count ?? 0;
    const e = await rejects('postGuestbook', { ticketId, scope, text: '씨 .발 진짜' }, idToken, 'INVALID_ARGUMENT', 'moderation');
    assert.equal(e.message, '이 표현은 방명록에 남길 수 없어요');
    assert.deepEqual(Object.keys(e.details!), ['reason']);
    assert.equal((await db.doc(`guestbook/${uid}_${ticketId}`).get()).exists, false);
    assert.equal((await statsRef.get()).data()!.count, before + 1);
  });

  test('허용 목록은 통과한다 (낱말·명소 이름)', async () => {
    const { idToken } = await makeUser();
    await ok('postGuestbook', { ...freshMilestone(), text: '시발점에서 한남대교까지 걸었어요' }, idToken);
  });

  test('금칙어는 Firestore 문서를 읽는다 (앱 업데이트 없이 교체)', async () => {
    const { idToken } = await makeUser();
    const ref = db.doc('config/moderation');
    const doc = (await ref.get()).data()!;
    try {
      await ref.set({
        ...doc,
        rules: [...doc.rules, { id: 'T1', cat: 'A', on: 'raw', re: '시험낱말' }],
      });
      await rejects('postGuestbook', { ...freshMilestone(), text: '시험낱말' }, idToken, 'INVALID_ARGUMENT', 'moderation');
    } finally {
      await seed();
    }
    await ok('postGuestbook', { ...freshMilestone(), text: '시험낱말' }, idToken);
  });

  test('규칙 숫자는 config/guestbook을 읽는다', async () => {
    const { idToken } = await makeUser();
    const ref = db.doc('config/guestbook');
    try {
      await ref.update({ maxChars: 3 });
      await rejects('postGuestbook', { ...freshMilestone(), text: '네 글자요' }, idToken, 'INVALID_ARGUMENT', 'bad-length');
    } finally {
      await seed();
    }
  });

  test('설정 문서가 없으면 글을 받지 않는다', async () => {
    const { idToken } = await makeUser();
    await db.doc('config/moderation').delete();
    try {
      await rejects('postGuestbook', { ...freshMilestone(), text: '안녕' }, idToken, 'INTERNAL');
    } finally {
      await seed();
    }
  });

  test('작성 제한 중에는 막고 끝 시각을 알려 주며, 지나면 쓴다', async () => {
    const until = Timestamp.fromMillis(Date.now() + 60_000);
    const { uid, idToken } = await makeUser({ banUntil: until });
    const { scope, ticketId } = freshMilestone();
    const e = await rejects('postGuestbook', { ticketId, scope, text: '안녕' }, idToken, 'PERMISSION_DENIED', 'banned');
    assert.equal(e.details?.banUntil, until.toMillis());
    await db.doc(`users/${uid}`).update({ banUntil: Timestamp.fromMillis(Date.now() - 1000) });
    await ok('postGuestbook', { ticketId, scope, text: '안녕' }, idToken);
  });
});

describe('readGuestbook', () => {
  // 시험마다 범위가 겹치지 않게 명소 id를 따로 쓴다
  let scopeNo = 100;
  const freshScope = () => `zz${scopeNo++}`;

  test('로그인해야 하고 범위 꼴을 본다', async () => {
    const { idToken } = await makeUser();
    await rejects('readGuestbook', { scope: 'kr001' }, undefined, 'UNAUTHENTICATED');
    await rejects('readGuestbook', { scope: '' }, idToken, 'INVALID_ARGUMENT', 'bad-scope');
  });

  test('같은 범위 글만, 숨김과 내 글을 빼고 준다', async () => {
    const { uid, idToken } = await makeUser();
    const scope = freshScope();
    await fakePost(`${scope}-a`, { scope });
    await fakePost(`${scope}-hidden`, { scope, hidden: true });
    await fakePost(`${scope}-mine`, { scope, uid });
    await fakePost(`${scope}-other`, { scope: freshScope() });
    const { posts } = await ok('readGuestbook', { scope }, idToken);
    assert.deepEqual(posts.map((p: { postId: string }) => p.postId), [`${scope}-a`]);
  });

  test('응답에는 화면에 쓸 값만 있다 (uid·rand·신고 수 없음)', async () => {
    const { idToken } = await makeUser();
    const scope = freshScope();
    await fakePost(`${scope}-a`, { scope, hearts: 2, reportCount: 1 });
    const { posts } = await ok('readGuestbook', { scope }, idToken);
    assert.deepEqual(Object.keys(posts[0]).sort(), [
      'createdAt',
      'hearts',
      'myReaction',
      'nickname',
      'postId',
      'text',
    ]);
    assert.equal(posts[0].hearts, 2);
    assert.equal(posts[0].myReaction, null);
    assert.equal(typeof posts[0].createdAt, 'number');
  });

  test('5개까지만 주고, 난수 뒤쪽이 모자라면 앞쪽에서 채운다', async () => {
    const { idToken } = await makeUser();
    const scope = freshScope();
    await Promise.all(
      [...Array(8).keys()].map((i) => fakePost(`${scope}-${i}`, { scope, rand: (i + 0.5) / 8 })),
    );
    const seen = new Set<string>();
    for (let i = 0; i < 12; i++) {
      const { posts } = await ok('readGuestbook', { scope }, idToken);
      assert.equal(posts.length, 5);
      assert.equal(new Set(posts.map((p: { postId: string }) => p.postId)).size, 5);
      for (const p of posts) seen.add(p.postId);
    }
    assert.ok(seen.size > 5, '부를 때마다 다른 글이 섞인다');
  });

  test('글이 적으면 있는 만큼, 없으면 빈 목록', async () => {
    const { idToken } = await makeUser();
    const scope = freshScope();
    assert.deepEqual((await ok('readGuestbook', { scope }, idToken)).posts, []);
    await fakePost(`${scope}-low`, { scope, rand: 0.000001 });
    await fakePost(`${scope}-high`, { scope, rand: 0.999999 });
    for (let i = 0; i < 5; i++) {
      assert.equal((await ok('readGuestbook', { scope }, idToken)).posts.length, 2);
    }
  });

  test('내 글이 많아도 남의 글로 채운다', async () => {
    const { uid, idToken } = await makeUser();
    const scope = freshScope();
    await Promise.all([
      ...[...Array(3).keys()].map((i) => fakePost(`${scope}-m${i}`, { scope, uid })),
      ...[...Array(5).keys()].map((i) => fakePost(`${scope}-o${i}`, { scope })),
    ]);
    const { posts } = await ok('readGuestbook', { scope }, idToken);
    assert.equal(posts.length, 5);
    assert.ok(posts.every((p: { postId: string }) => p.postId.includes('-o')));
  });

  test('total은 숨김을 뺀 그 범위의 글 수다 (화면의 n명 중 5명)', async () => {
    const { uid, idToken } = await makeUser();
    const scope = freshScope();
    await Promise.all([
      ...[...Array(7).keys()].map((i) => fakePost(`${scope}-${i}`, { scope })),
      fakePost(`${scope}-mine`, { scope, uid }),
      fakePost(`${scope}-hidden`, { scope, hidden: true }),
      fakePost(`${scope}-other`, { scope: freshScope() }),
    ]);
    const { total, posts } = await ok('readGuestbook', { scope }, idToken);
    assert.equal(total, 8);
    assert.equal(posts.length, 5);
  });

  test('내가 누른 반응을 함께 준다', async () => {
    const { idToken } = await makeUser();
    const scope = freshScope();
    await fakePost(`${scope}-h`, { scope });
    await fakePost(`${scope}-r`, { scope });
    await ok('react', { postId: `${scope}-h`, kind: 'heart' }, idToken);
    await ok('react', { postId: `${scope}-r`, kind: 'report' }, idToken);
    const { posts } = await ok('readGuestbook', { scope }, idToken);
    const byId = Object.fromEntries(posts.map((p: any) => [p.postId, p.myReaction]));
    assert.deepEqual(byId, { [`${scope}-h`]: 'heart', [`${scope}-r`]: 'report' });
  });
});

describe('react', () => {
  const freshPost = async (fields: Record<string, unknown> = {}) => {
    const id = randomUUID();
    await fakePost(id, fields);
    return id;
  };
  const post = async (id: string) => (await db.doc(`guestbook/${id}`).get()).data()!;
  const reaction = async (id: string, uid: string) =>
    (await db.doc(`guestbook/${id}/reactions/${uid}`).get()).data();
  const reporters = (n: number, steps = 10000) =>
    Promise.all([...Array(n).keys()].map(() => makeUser({ totalSteps: steps })));

  test('하트를 세고, 다시 눌러도 그대로다', async () => {
    const { uid, idToken } = await makeUser();
    const id = await freshPost();
    assert.deepEqual(await ok('react', { postId: id, kind: 'heart' }, idToken), {
      hearts: 1,
      myReaction: 'heart',
    });
    assert.deepEqual(await ok('react', { postId: id, kind: 'heart' }, idToken), {
      hearts: 1,
      myReaction: 'heart',
    });
    assert.equal((await post(id)).hearts, 1);
    const r = (await reaction(id, uid))!;
    assert.equal(r.kind, 'heart');
    assert.equal(r.counted, true);
    assert.equal(r.uid, uid);
  });

  test('반응을 바꾸면 집계도 옮긴다', async () => {
    const { idToken } = await makeUser({ totalSteps: 10000 });
    const id = await freshPost();
    await ok('react', { postId: id, kind: 'heart' }, idToken);
    await ok('react', { postId: id, kind: 'report' }, idToken);
    let p = await post(id);
    assert.equal(p.hearts, 0);
    assert.equal(p.reportCount, 1);
    await ok('react', { postId: id, kind: 'heart' }, idToken);
    p = await post(id);
    assert.equal(p.hearts, 1);
    assert.equal(p.reportCount, 0);
  });

  test('null이면 내 반응을 취소한다 (하트 다시 누르기)', async () => {
    const { uid, idToken } = await makeUser({ totalSteps: 10000 });
    const id = await freshPost();
    assert.deepEqual(await ok('react', { postId: id, kind: null }, idToken), {
      hearts: 0,
      myReaction: null,
    });
    await ok('react', { postId: id, kind: 'heart' }, idToken);
    assert.deepEqual(await ok('react', { postId: id, kind: null }, idToken), {
      hearts: 0,
      myReaction: null,
    });
    assert.equal(await reaction(id, uid), undefined);
    assert.equal((await post(id)).hearts, 0);

    await ok('react', { postId: id, kind: 'report' }, idToken);
    assert.equal((await post(id)).reportCount, 1);
    await ok('react', { postId: id, kind: null }, idToken);
    assert.equal((await post(id)).reportCount, 0);
    assert.equal(await reaction(id, uid), undefined);
  });

  test('1만 보 미만의 신고는 받아 두되 셈에서 빼고, 응답은 똑같다', async () => {
    const { uid, idToken } = await makeUser({ totalSteps: 9999 });
    const id = await freshPost();
    assert.deepEqual(await ok('react', { postId: id, kind: 'report' }, idToken), {
      hearts: 0,
      myReaction: 'report',
    });
    assert.equal((await post(id)).reportCount, 0);
    const r = (await reaction(id, uid))!;
    assert.equal(r.kind, 'report');
    assert.equal(r.counted, false);
  });

  test('셈에서 빠진 신고를 하트로 바꿔도 신고 수는 그대로다', async () => {
    const { idToken } = await makeUser({ totalSteps: 10 });
    const id = await freshPost({ reportCount: 2 });
    await ok('react', { postId: id, kind: 'report' }, idToken);
    await ok('react', { postId: id, kind: 'heart' }, idToken);
    const p = await post(id);
    assert.equal(p.reportCount, 2);
    assert.equal(p.hearts, 1);
  });

  test('내 글·없는 글·숨긴 글에는 못 누른다', async () => {
    const { uid, idToken } = await makeUser();
    await rejects('react', { postId: await freshPost({ uid }), kind: 'heart' }, idToken, 'PERMISSION_DENIED', 'own-post');
    await rejects('react', { postId: 'nope', kind: 'heart' }, idToken, 'NOT_FOUND', 'no-post');
    await rejects('react', { postId: await freshPost({ hidden: true }), kind: 'heart' }, idToken, 'NOT_FOUND', 'no-post');
  });

  test('입력이 틀리면 막고, 로그인해야 한다', async () => {
    const { idToken } = await makeUser();
    const id = await freshPost();
    await rejects('react', { postId: id, kind: 'x' }, idToken, 'INVALID_ARGUMENT', 'bad-kind');
    await rejects('react', { postId: id }, idToken, 'INVALID_ARGUMENT', 'bad-kind');
    await rejects('react', { postId: 'a/b', kind: 'heart' }, idToken, 'INVALID_ARGUMENT', 'bad-post');
    await rejects('react', { postId: id, kind: 'heart' }, undefined, 'UNAUTHENTICATED');
  });

  test('신고 5개면 숨기고 검토 대기열에 넣는다', async () => {
    const id = await freshPost({ uid: 'author', text: '문제의 글' });
    for (const u of await reporters(4)) await ok('react', { postId: id, kind: 'report' }, u.idToken);
    assert.equal((await post(id)).hidden, false);
    assert.equal((await db.doc(`reviewQueue/${id}`).get()).exists, false);

    const [last] = await reporters(1);
    await ok('react', { postId: id, kind: 'report' }, last.idToken);
    const p = await post(id);
    assert.equal(p.hidden, true);
    assert.equal(p.reportCount, 5);
    const q = (await db.doc(`reviewQueue/${id}`).get()).data()!;
    assert.equal(q.uid, 'author');
    assert.equal(q.text, '문제의 글');
    assert.equal(q.reportCount, 5);
    assert.equal(q.decision, null);
    assert.equal(q.reviewBy.toMillis() - q.queuedAt.toMillis(), 48 * 60 * 60 * 1000);
  });

  test('신고가 하트보다 많아야 숨긴다', async () => {
    const id = await freshPost({ hearts: 5 });
    for (const u of await reporters(5)) await ok('react', { postId: id, kind: 'report' }, u.idToken);
    assert.equal((await post(id)).hidden, false);
    const [sixth] = await reporters(1);
    await ok('react', { postId: id, kind: 'report' }, sixth.idToken);
    assert.equal((await post(id)).hidden, true);
  });

  test('1만 보 미만의 신고는 몇 개여도 숨기지 않는다', async () => {
    const id = await freshPost();
    for (const u of await reporters(5, 9999)) await ok('react', { postId: id, kind: 'report' }, u.idToken);
    const p = await post(id);
    assert.equal(p.reportCount, 0);
    assert.equal(p.hidden, false);
  });

  test('동시에 눌러도 집계가 맞는다', async () => {
    const id = await freshPost();
    const users = await Promise.all([...Array(8).keys()].map(() => makeUser()));
    await Promise.all(users.map((u) => ok('react', { postId: id, kind: 'heart' }, u.idToken)));
    assert.equal((await post(id)).hearts, 8);
  });
});

describe('검토 (reviewQueue decision)', () => {
  const hiddenPost = async (authorUid: string) => {
    const id = randomUUID();
    await fakePost(id, { uid: authorUid, hidden: true, reportCount: 5 });
    await db.doc(`guestbook/${id}/reactions/r1`).set({ uid: 'r1', kind: 'report', counted: true });
    await db.doc(`reviewQueue/${id}`).set({ postId: id, uid: authorUid, text: '글', decision: null });
    return id;
  };
  const decide = async (id: string, decision: string) => {
    await db.doc(`reviewQueue/${id}`).update({ decision });
    await waitFor(`${decision} 처리`, async () => !(await db.doc(`reviewQueue/${id}`).get()).exists);
  };

  test('복구하면 다시 보이고, 또 신고해도 숨기지 않는다', async () => {
    const author = await makeUser();
    const id = await hiddenPost(author.uid);
    await decide(id, 'restore');
    const p = (await db.doc(`guestbook/${id}`).get()).data()!;
    assert.equal(p.hidden, false);
    assert.equal(p.reviewed, true);
    assert.equal((await db.doc(`users/${author.uid}`).get()).data()!.deleteCount, undefined);

    const reporter = await makeUser({ totalSteps: 10000 });
    await ok('react', { postId: id, kind: 'report' }, reporter.idToken);
    const after = (await db.doc(`guestbook/${id}`).get()).data()!;
    assert.equal(after.reportCount, 6);
    assert.equal(after.hidden, false);
    assert.equal((await db.doc(`reviewQueue/${id}`).get()).exists, false);
  });

  test('삭제하면 글과 반응이 사라지고 삭제 횟수가 는다', async () => {
    const author = await makeUser();
    const id = await hiddenPost(author.uid);
    await decide(id, 'delete');
    assert.equal((await db.doc(`guestbook/${id}`).get()).exists, false);
    assert.equal((await db.doc(`guestbook/${id}/reactions/r1`).get()).exists, false);
    const u = (await db.doc(`users/${author.uid}`).get()).data()!;
    assert.equal(u.deleteCount, 1);
    assert.equal(u.banUntil, undefined);
  });

  test('삭제 확정 3번이면 7일 동안 쓰지 못한다', async () => {
    const author = await makeUser();
    for (let i = 0; i < 3; i++) await decide(await hiddenPost(author.uid), 'delete');
    const u = (await db.doc(`users/${author.uid}`).get()).data()!;
    assert.equal(u.deleteCount, 3);
    const left = u.banUntil.toMillis() - Date.now();
    const week = 7 * 24 * 60 * 60 * 1000;
    assert.ok(left > week - 60_000 && left <= week, `남은 시간 ${left}`);
    await rejects('postGuestbook', { ...freshMilestone(), text: '안녕' }, author.idToken, 'PERMISSION_DENIED', 'banned');
  });

  test('작성자가 없어도 글은 지운다', async () => {
    const id = await hiddenPost('gone-user');
    await decide(id, 'delete');
    assert.equal((await db.doc(`guestbook/${id}`).get()).exists, false);
    assert.equal((await db.doc('users/gone-user').get()).exists, false);
  });

  test('모르는 decision은 건드리지 않는다', async () => {
    const author = await makeUser();
    const id = await hiddenPost(author.uid);
    await db.doc(`reviewQueue/${id}`).update({ decision: 'later' });
    await new Promise((r) => setTimeout(r, 1500));
    assert.equal((await db.doc(`reviewQueue/${id}`).get()).exists, true);
    assert.equal((await db.doc(`guestbook/${id}`).get()).data()!.hidden, true);
  });
});
