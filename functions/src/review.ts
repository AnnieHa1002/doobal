// 검토 대기열. 관리 화면은 없다(M5 명세): Annie가 콘솔에서 reviewQueue/{postId}의 decision을
// 'delete' 또는 'restore'로 바꾸면 이 트리거가 처리하고 대기열에서 지운다
import { db } from './firebase';
import { Timestamp } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { loadGuestbookConfig } from './config';
import { banUntilAfterDelete } from './rules';

export const onReviewDecision = onDocumentUpdated('reviewQueue/{postId}', async (event) => {
  const decision = event.data?.after.data()?.decision;
  if (decision === null || decision === undefined) return;
  const postId = event.params.postId;
  const queueRef = db.doc(`reviewQueue/${postId}`);
  const postRef = db.doc(`guestbook/${postId}`);

  if (decision === 'restore') {
    await db.runTransaction(async (tx) => {
      if (!(await tx.get(queueRef)).exists) return;
      if ((await tx.get(postRef)).exists) tx.update(postRef, { hidden: false, reviewed: true });
      tx.delete(queueRef);
    });
    logger.info('검토: 복구', { postId });
    return;
  }

  if (decision !== 'delete') {
    logger.warn('검토: 모르는 decision이라 그대로 둠', { postId, decision });
    return;
  }

  const cfg = await loadGuestbookConfig();
  // 반응을 먼저 지운다. 트리거가 다시 돌아도 같은 결과고, 작성자 삭제 횟수는 아래 트랜잭션에서 한 번만 는다
  await db.recursiveDelete(postRef.collection('reactions'));
  await db.runTransaction(async (tx) => {
    const queue = await tx.get(queueRef);
    if (!queue.exists) return;
    const authorRef = db.doc(`users/${queue.data()!.uid}`);
    const author = await tx.get(authorRef);
    if (author.exists) {
      const deleteCount = ((author.data()!.deleteCount as number | undefined) ?? 0) + 1;
      const banUntil = banUntilAfterDelete(deleteCount, Date.now(), cfg);
      tx.update(authorRef, {
        deleteCount,
        ...(banUntil === null ? {} : { banUntil: Timestamp.fromMillis(banUntil) }),
      });
    }
    tx.delete(postRef);
    tx.delete(queueRef);
  });
  logger.info('검토: 삭제', { postId });
});
