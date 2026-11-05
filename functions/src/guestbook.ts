// 방명록 Callable: 작성·읽기·반응 (기준 문서 6장, M2~M6 명세 M5·v0.11 ⑧)
import { callableOptions, db, fail, requireUid } from './firebase';
import { FieldValue, Timestamp, type DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onCall } from 'firebase-functions/v2/https';
import { loadGuestbookConfig, loadModeration } from './config';
import {
  applyReaction,
  cleanPost,
  isCounted,
  kstDate,
  reviewDeadline,
  shouldHide,
  validScope,
  validTicket,
  type Counts,
  type Reaction,
  type ReactionKind,
} from './rules';

const ALREADY_EXISTS = 6; // gRPC 상태 코드

export function countsOf(post: DocumentData): Counts {
  return { hearts: post.hearts ?? 0, reportCount: post.reportCount ?? 0 };
}

export const postGuestbook = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const { ticketId, scope, text } = request.data ?? {};
  if (!validScope(scope)) throw fail('invalid-argument', 'bad-scope', '범위가 올바르지 않아요');
  if (!validTicket(ticketId, scope)) {
    throw fail('invalid-argument', 'bad-ticket', '기회가 올바르지 않아요');
  }
  if (typeof text !== 'string') throw fail('invalid-argument', 'bad-text', '글이 올바르지 않아요');

  const [cfg, moderation, user] = await Promise.all([
    loadGuestbookConfig(),
    loadModeration(),
    db.doc(`users/${uid}`).get(),
  ]);

  const clean = cleanPost(text, cfg.maxChars);
  if (clean === null) {
    throw fail('invalid-argument', 'bad-length', `글은 1~${cfg.maxChars}자로 써 주세요`);
  }

  const profile = user.data();
  if (typeof profile?.nickname !== 'string') {
    throw fail('failed-precondition', 'no-profile', '닉네임이 아직 서버에 없어요');
  }

  const banUntil = profile.banUntil as Timestamp | undefined;
  if (banUntil !== undefined && banUntil.toMillis() > Date.now()) {
    throw fail('permission-denied', 'banned', '지금은 방명록을 쓸 수 없어요', {
      banUntil: banUntil.toMillis(),
    });
  }

  const rule = moderation.check(clean);
  if (rule !== null) {
    // 막힌 글은 저장하지 않고 하루 개수만 남긴다. 글과 걸린 낱말은 어디에도 적지 않는다
    await db
      .doc(`stats/moderation_${kstDate(Date.now())}`)
      .set({ count: FieldValue.increment(1) }, { merge: true });
    logger.info('금칙어로 막음', { ruleId: rule.id });
    throw fail('invalid-argument', 'moderation', moderation.message);
  }

  const postId = `${uid}_${ticketId}`;
  try {
    await db.doc(`guestbook/${postId}`).create({
      uid,
      nickname: profile.nickname,
      scope,
      ticketId,
      text: clean,
      rand: Math.random(),
      hearts: 0,
      reportCount: 0,
      hidden: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    if ((e as { code?: number }).code === ALREADY_EXISTS) {
      throw fail('already-exists', 'duplicate', '이 기회로 이미 글을 썼어요', { postId });
    }
    throw e;
  }
  return { postId };
});

export const readGuestbook = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const { scope } = request.data ?? {};
  if (!validScope(scope)) throw fail('invalid-argument', 'bad-scope', '범위가 올바르지 않아요');

  const cfg = await loadGuestbookConfig();
  const n = cfg.readCount;
  // 내 글은 앱이 따로 보여 주므로 뺀다. 한 범위에 내 글이 여럿일 수 있어 넉넉히 읽는다
  const fetchCount = n * 2;
  const r = Math.random();
  const base = db.collection('guestbook').where('scope', '==', scope).where('hidden', '==', false);
  const first = await base.where('rand', '>=', r).orderBy('rand').limit(fetchCount).get();
  let docs = first.docs.filter((d) => d.data().uid !== uid);
  if (docs.length < n) {
    const rest = await base.where('rand', '<', r).orderBy('rand').limit(fetchCount).get();
    docs = docs.concat(rest.docs.filter((d) => d.data().uid !== uid));
  }
  docs = docs.slice(0, n);

  const [mine, count] = await Promise.all([
    docs.length === 0
      ? Promise.resolve([])
      : db.getAll(...docs.map((d) => d.ref.collection('reactions').doc(uid))),
    base.count().get(),
  ]);
  return {
    // 화면 머리의 'n명 중 5명'. 숨긴 글은 빼고 내 글은 센다
    total: count.data().count,
    posts: docs.map((d, i) => {
      const p = d.data();
      return {
        postId: d.id,
        nickname: p.nickname,
        text: p.text,
        hearts: p.hearts,
        createdAt: (p.createdAt as Timestamp).toMillis(),
        myReaction: (mine[i].data()?.kind as ReactionKind | undefined) ?? null,
      };
    }),
  };
});

export const react = onCall(callableOptions, async (request) => {
  const uid = requireUid(request);
  const { postId, kind } = request.data ?? {};
  if (typeof postId !== 'string' || postId.length === 0 || postId.includes('/')) {
    throw fail('invalid-argument', 'bad-post', '글이 올바르지 않아요');
  }
  // null은 내 반응 취소다 (화면 5-2: 하트를 다시 누르면 꺼진다)
  if (kind !== 'heart' && kind !== 'report' && kind !== null) {
    throw fail('invalid-argument', 'bad-kind', '반응이 올바르지 않아요');
  }

  const cfg = await loadGuestbookConfig();
  const postRef = db.doc(`guestbook/${postId}`);
  const reactionRef = postRef.collection('reactions').doc(uid);
  const queueRef = db.doc(`reviewQueue/${postId}`);
  const userRef = db.doc(`users/${uid}`);

  const hearts = await db.runTransaction(async (tx) => {
    const post = await tx.get(postRef);
    const data = post.data();
    // 숨긴 글은 다른 사람에게 없는 글이다
    if (data === undefined || data.hidden === true) {
      throw fail('not-found', 'no-post', '글이 없어요');
    }
    if (data.uid === uid) throw fail('permission-denied', 'own-post', '내 글에는 누를 수 없어요');

    const prev = (await tx.get(reactionRef)).data() as Reaction | undefined;
    if ((prev?.kind ?? null) === kind) return data.hearts as number;

    if (kind === null) {
      const counts = applyReaction(countsOf(data), prev!, null);
      tx.delete(reactionRef);
      tx.update(postRef, { ...counts });
      return counts.hearts;
    }

    const totalSteps = ((await tx.get(userRef)).data()?.totalSteps as number | undefined) ?? 0;
    const next: Reaction = { kind, counted: isCounted(kind, totalSteps, cfg) };
    const counts = applyReaction(countsOf(data), prev ?? null, next);
    // 검토에서 복구한 글(reviewed)은 글이 바뀌지 않으니 다시 숨기지 않는다
    const hide = data.reviewed !== true && shouldHide(counts, cfg);

    tx.set(reactionRef, { uid, ...next, at: FieldValue.serverTimestamp() });
    tx.update(postRef, { ...counts, ...(hide ? { hidden: true } : {}) });
    if (hide) {
      const now = Date.now();
      tx.set(queueRef, {
        postId,
        uid: data.uid,
        nickname: data.nickname,
        scope: data.scope,
        text: data.text,
        ...counts,
        queuedAt: Timestamp.fromMillis(now),
        reviewBy: Timestamp.fromMillis(reviewDeadline(now, cfg)),
        decision: null,
      });
    }
    return counts.hearts;
  });
  return { hearts, myReaction: kind };
});
