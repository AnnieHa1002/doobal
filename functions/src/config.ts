// 설정 문서 읽기. 문서가 없거나 값이 빠졌으면 글을 받지 않는다 (숫자를 코드에 박지 않는다)
import { db, isEmulator } from './firebase';
import { Moderation } from './moderation';
import type { GuestbookConfig } from './rules';

/** 인스턴스마다 잠깐 들고 있는다. 금칙어 문서를 바꾸면 이 시간 안에 반영된다 */
const CACHE_MS = isEmulator ? 0 : 5 * 60 * 1000;

function cached<T>(path: string, parse: (data: Record<string, unknown>) => T): () => Promise<T> {
  let value: T | undefined;
  let at = 0;
  return async () => {
    if (value !== undefined && Date.now() - at < CACHE_MS) return value;
    const snap = await db.doc(path).get();
    const data = snap.data();
    if (data === undefined) throw new Error(`설정 문서가 없어요: ${path}`);
    value = parse(data);
    at = Date.now();
    return value;
  };
}

function parseGuestbook(data: Record<string, unknown>): GuestbookConfig {
  const numberKeys = [
    'maxChars',
    'readCount',
    'blindMinReports',
    'reportCountMinTotalSteps',
    'reviewHours',
    'banAfterDeletes',
    'banDays',
  ];
  for (const key of numberKeys) {
    if (typeof data[key] !== 'number') throw new Error(`config/guestbook ${key}가 숫자가 아니에요`);
  }
  if (typeof data.blindNeedsMoreThanHearts !== 'boolean') {
    throw new Error('config/guestbook blindNeedsMoreThanHearts가 참거짓이 아니에요');
  }
  return data as unknown as GuestbookConfig;
}

export const loadGuestbookConfig = cached('config/guestbook', parseGuestbook);
export const loadModeration = cached('config/moderation', (data) => new Moderation(data));
