// 방명록 규칙 계산. Firebase에 기대지 않는 순수 함수라 에뮬레이터 없이 시험한다

/** Firestore config/guestbook. 키는 app/assets/data/config.json guestbook과 같다 */
export interface GuestbookConfig {
  maxChars: number;
  readCount: number;
  blindMinReports: number;
  blindNeedsMoreThanHearts: boolean;
  reportCountMinTotalSteps: number;
  reviewHours: number;
  banAfterDeletes: number;
  banDays: number;
}

export type ReactionKind = 'heart' | 'report';

export interface Reaction {
  kind: ReactionKind;
  counted: boolean;
}

export interface Counts {
  hearts: number;
  reportCount: number;
}

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;
const KST_OFFSET_MS = 9 * HOUR_MS;

/** 하루 기준은 한국 시간 자정이다: 'yyyy-MM-dd' */
export function kstDate(nowMs: number): string {
  return new Date(nowMs + KST_OFFSET_MS).toISOString().slice(0, 10);
}

/** 글 길이. 앱과 같이 글자(코드 포인트) 수라서 이모지 하나도 한 글자로 센다 */
export function postLength(text: string): number {
  return [...text].length;
}

/** 앞뒤 공백을 자른 글이 비어 있지 않고 maxChars 이하면 그 글, 아니면 null */
export function cleanPost(text: string, maxChars: number): string | null {
  const t = text.trim();
  return t.length === 0 || postLength(t) > maxChars ? null : t;
}

const TICKET = /^(?:a:[A-Za-z0-9_-]{1,64}|m:\d{1,9})$/;
const SCOPE = /^(?:[a-z]{2}\d{3}|sketch|steps:\d{1,9})$/;

export function validScope(scope: unknown): scope is string {
  return typeof scope === 'string' && SCOPE.test(scope);
}

/** 기회와 범위가 짝이 맞는지: 걸음 숫자 기회 m:N은 steps:N, 도착 기회 a:…는 명소(또는 첫 여정 sketch) */
export function validTicket(ticketId: unknown, scope: string): ticketId is string {
  if (typeof ticketId !== 'string' || !TICKET.test(ticketId)) return false;
  return ticketId.startsWith('m:')
    ? scope === `steps:${ticketId.slice(2)}`
    : !scope.startsWith('steps:');
}

/** 반응 하나를 바꾼 뒤의 집계. 셈에서 빠진 신고(counted false)는 어느 쪽으로도 세지 않는다 */
export function applyReaction(counts: Counts, prev: Reaction | null, next: Reaction | null): Counts {
  let { hearts, reportCount } = counts;
  for (const [r, delta] of [
    [prev, -1],
    [next, 1],
  ] as const) {
    if (r === null) continue;
    if (r.kind === 'heart') hearts += delta;
    else if (r.counted) reportCount += delta;
  }
  return { hearts: Math.max(0, hearts), reportCount: Math.max(0, reportCount) };
}

/** 누른 사람의 누적 걸음으로 이 반응을 셈에 넣을지. 1만 보 미만의 신고만 뺀다 */
export function isCounted(kind: ReactionKind, totalSteps: number, cfg: GuestbookConfig): boolean {
  return kind === 'heart' || totalSteps >= cfg.reportCountMinTotalSteps;
}

/** 임시 블라인드: 신고 n개 이상이면서 하트보다 많을 때 */
export function shouldHide(counts: Counts, cfg: GuestbookConfig): boolean {
  if (counts.reportCount < cfg.blindMinReports) return false;
  return !cfg.blindNeedsMoreThanHearts || counts.reportCount > counts.hearts;
}

/** 삭제 확정 뒤의 작성 제한 끝 시각(ms). 제한이 없으면 null. 기준을 넘긴 뒤의 삭제는 다시 제한한다 */
export function banUntilAfterDelete(
  deleteCount: number,
  nowMs: number,
  cfg: GuestbookConfig,
): number | null {
  return deleteCount >= cfg.banAfterDeletes ? nowMs + cfg.banDays * DAY_MS : null;
}

/** 검토 기한(ms): 숨긴 뒤 reviewHours 안에 Annie가 본다 */
export function reviewDeadline(nowMs: number, cfg: GuestbookConfig): number {
  return nowMs + cfg.reviewHours * HOUR_MS;
}
