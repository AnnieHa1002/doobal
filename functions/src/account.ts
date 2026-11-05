// 계정 데이터 지우기·합치기와 계정 삭제 Callable.
// 어느 단계에서 끊겨도 같은 호출을 다시 하면 끝까지 간다 (각 단계가 옮긴 것을 다시 옮기지 않는다)
import { auth, callableOptions, db, requireUid } from './firebase';
import type { DocumentReference, Timestamp } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { countsOf } from './guestbook';
import { applyReaction, type Reaction } from './rules';

function isNotFound(e: unknown): boolean {
  return (e as { code?: string }).code === 'auth/user-not-found';
}

export async function authUserOrNull(uid: string) {
  try {
    return await auth.getUser(uid);
  } catch (e) {
    if (isNotFound(e)) return null;
    throw e;
  }
}

async function deleteAuthUser(uid: string): Promise<void> {
  try {
    await auth.deleteUser(uid);
  } catch (e) {
    if (!isNotFound(e)) throw e;
  }
}

/** 이 사람이 누른 반응 전부. 색인: firestore.indexes.json fieldOverrides */
function reactionsBy(uid: string) {
  return db.collectionGroup('reactions').where('uid', '==', uid).get();
}

/** 반응 하나를 지우고 그 글의 집계에서 뺀다. 이미 숨긴 글을 되살리지는 않는다 */
async function removeReaction(ref: DocumentReference): Promise<void> {
  const postRef = ref.parent.parent!;
  await db.runTransaction(async (tx) => {
    const reaction = await tx.get(ref);
    if (!reaction.exists) return;
    const post = await tx.get(postRef);
    if (post.exists) {
      tx.update(postRef, applyReaction(countsOf(post.data()!), reaction.data() as Reaction, null));
    }
    tx.delete(ref);
  });
}

/** 계정 삭제: 모두 즉시 파기한다 (약관 v02 제3조). 제재 기록도 users 문서와 함께 사라진다 */
export async function wipeUser(uid: string): Promise<void> {
  for (const r of (await reactionsBy(uid)).docs) await removeReaction(r.ref);
  const posts = await db.collection('guestbook').where('uid', '==', uid).get();
  for (const p of posts.docs) {
    await db.recursiveDelete(p.ref);
    await db.doc(`reviewQueue/${p.id}`).delete();
  }
  const links = await db.collection('kakaoLinks').where('uid', '==', uid).get();
  for (const l of links.docs) await l.ref.delete();
  await db.recursiveDelete(db.doc(`users/${uid}`));
  await deleteAuthUser(uid);
}

/** 내 반응을 합칠 계정 이름으로 옮긴다. 그 계정이 이미 눌렀거나 그 계정의 글이면 내 반응만 뺀다 */
async function moveReactions(from: string, to: string): Promise<void> {
  for (const r of (await reactionsBy(from)).docs) {
    const postRef = r.ref.parent.parent!;
    const targetRef = postRef.collection('reactions').doc(to);
    const moved = await db.runTransaction(async (tx) => {
      const [post, target] = [await tx.get(postRef), await tx.get(targetRef)];
      if (!post.exists || post.data()!.uid === to || target.exists) return false;
      tx.set(targetRef, { ...r.data(), uid: to });
      tx.delete(r.ref);
      return true;
    });
    if (!moved) await removeReaction(r.ref);
  }
}

/** 내 글을 합칠 계정 이름으로 옮긴다. 문서 id가 uid_ticketId라 새 문서를 만든다 */
async function movePosts(from: string, to: string): Promise<void> {
  const posts = await db.collection('guestbook').where('uid', '==', from).get();
  for (const p of posts.docs) {
    const data = p.data();
    const newId = `${to}_${data.ticketId}`;
    const newRef = db.doc(`guestbook/${newId}`);
    const oldQueueRef = db.doc(`reviewQueue/${p.id}`);
    const reactions = await p.ref.collection('reactions').get();
    await db.runTransaction(async (tx) => {
      const [existing, queue] = [await tx.get(newRef), await tx.get(oldQueueRef)];
      tx.delete(p.ref);
      if (queue.exists) tx.delete(oldQueueRef);
      // 같은 기회의 글이 그 계정에 이미 있으면 그쪽을 남긴다 (기회 하나에 글 하나)
      if (existing.exists) return;
      let counts = countsOf(data);
      for (const r of reactions.docs) {
        // 그 계정이 눌렀던 반응은 내 글이 되므로 뺀다
        if (r.id === to) counts = applyReaction(counts, r.data() as Reaction, null);
        else tx.set(newRef.collection('reactions').doc(r.id), r.data());
      }
      tx.create(newRef, { ...data, uid: to, ...counts });
      if (queue.exists) {
        tx.set(db.doc(`reviewQueue/${newId}`), { ...queue.data(), postId: newId, uid: to, ...counts });
      }
    });
    await db.recursiveDelete(p.ref.collection('reactions'));
  }
}

/** 백업 이전: 그 계정에 백업이 없을 때만 옮긴다. 있으면 그 기록을 쓰기로 한 것이라 덮어쓰지 않는다 */
async function moveBackup(from: string, to: string): Promise<boolean> {
  const fromRef = db.doc(`users/${from}/backup/state`);
  const toRef = db.doc(`users/${to}/backup/state`);
  return db.runTransaction(async (tx) => {
    const [source, target] = [await tx.get(fromRef), await tx.get(toRef)];
    if (!source.exists || target.exists) return false;
    tx.set(toRef, source.data()!);
    return true;
  });
}

function earlier(a?: Timestamp, b?: Timestamp): Timestamp | undefined {
  if (a === undefined || b === undefined) return a ?? b;
  return a.toMillis() <= b.toMillis() ? a : b;
}

function later(a?: Timestamp, b?: Timestamp): Timestamp | undefined {
  if (a === undefined || b === undefined) return a ?? b;
  return a.toMillis() >= b.toMillis() ? a : b;
}

/**
 * users 문서를 합치고 옛 문서를 지운다. 합치기로 제재가 풀리지 않게 삭제 횟수는 더하고 제한은 늦은 쪽을 쓴다.
 * 한 트랜잭션이라 다시 돌아도 두 번 더해지지 않는다
 */
async function mergeProfile(from: string, to: string): Promise<void> {
  const fromRef = db.doc(`users/${from}`);
  const toRef = db.doc(`users/${to}`);
  await db.runTransaction(async (tx) => {
    const [source, target] = [await tx.get(fromRef), await tx.get(toRef)];
    if (!source.exists) return;
    const a = source.data()!;
    const b = target.data() ?? {};
    const deleteCount = (a.deleteCount ?? 0) + (b.deleteCount ?? 0);
    const banUntil = later(a.banUntil, b.banUntil);
    const createdAt = earlier(a.createdAt, b.createdAt);
    const nickname = b.nickname ?? a.nickname;
    tx.set(
      toRef,
      {
        totalSteps: Math.max(a.totalSteps ?? 0, b.totalSteps ?? 0),
        ...(deleteCount > 0 ? { deleteCount } : {}),
        ...(banUntil === undefined ? {} : { banUntil }),
        ...(createdAt === undefined ? {} : { createdAt }),
        ...(nickname === undefined ? {} : { nickname }),
      },
      { merge: true },
    );
    tx.delete(fromRef);
  });
}

/** 익명 계정 from의 서버 기록을 to로 합치고 from을 없앤다. 돌려주는 값은 백업을 옮겼는지다 */
export async function mergeAnonymousInto(from: string, to: string): Promise<boolean> {
  await moveReactions(from, to);
  await movePosts(from, to);
  const backupMoved = await moveBackup(from, to);
  await mergeProfile(from, to);
  await db.recursiveDelete(db.doc(`users/${from}`));
  await deleteAuthUser(from);
  return backupMoved;
}

export const deleteAccount = onCall(callableOptions, async (request) => {
  await wipeUser(requireUid(request));
  return { deleted: true };
});
