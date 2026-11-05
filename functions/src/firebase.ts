// 공용 초기화. 함수 정의보다 먼저 돌도록 모든 파일이 이 파일을 가장 먼저 읽는다
import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { setGlobalOptions } from 'firebase-functions/v2';
import { HttpsError, type CallableRequest, type FunctionsErrorCode } from 'firebase-functions/v2/https';

setGlobalOptions({ region: 'asia-northeast3', maxInstances: 10 });

if (getApps().length === 0) initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';

/** App Check는 배포 환경에서만 강제한다 (M5 명세). 에뮬레이터에는 앱이 없어서 끈다 */
export const callableOptions = { enforceAppCheck: !isEmulator };

/** 앱이 details.reason으로 나눠 처리하는 오류 */
export function fail(
  code: FunctionsErrorCode,
  reason: string,
  message: string,
  extra: Record<string, unknown> = {},
): HttpsError {
  return new HttpsError(code, message, { reason, ...extra });
}

export function requireUid(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (uid === undefined) throw fail('unauthenticated', 'signed-out', '로그인이 필요해요');
  return uid;
}
