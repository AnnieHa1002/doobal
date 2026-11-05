// 규칙 계산·설정 파일 시험. 에뮬레이터 없이 돈다
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, test } from 'node:test';
import { guestbookDoc, moderationDoc } from '../scripts/seed';
import {
  applyReaction,
  banUntilAfterDelete,
  cleanPost,
  isCounted,
  kstDate,
  reviewDeadline,
  shouldHide,
  validScope,
  validTicket,
  type GuestbookConfig,
} from '../src/rules';
import { Moderation } from '../src/moderation';

const repo = join(__dirname, '..', '..', '..');
const cfg = guestbookDoc() as GuestbookConfig;
const DAY = 24 * 60 * 60 * 1000;

describe('하루 기준은 한국 시간 자정', () => {
  test('UTC 15시가 한국의 다음 날 0시다', () => {
    assert.equal(kstDate(Date.UTC(2026, 10, 4, 14, 59, 59)), '2026-11-04');
    assert.equal(kstDate(Date.UTC(2026, 10, 4, 15, 0, 0)), '2026-11-05');
  });
});

describe('글 길이', () => {
  test('200자까지, 이모지는 한 글자, 앞뒤 공백은 자른다', () => {
    assert.equal(cfg.maxChars, 200);
    assert.equal(cleanPost('가'.repeat(200), cfg.maxChars), '가'.repeat(200));
    assert.equal(cleanPost('가'.repeat(201), cfg.maxChars), null);
    assert.equal(cleanPost('😀'.repeat(200), cfg.maxChars), '😀'.repeat(200));
    assert.equal(cleanPost('  안녕  ', cfg.maxChars), '안녕');
    assert.equal(cleanPost('   ', cfg.maxChars), null);
  });
});

describe('기회와 범위', () => {
  test('앱이 쓰는 꼴만 받는다', () => {
    for (const s of ['kr001', 'sketch', 'steps:12345']) assert.ok(validScope(s), s);
    for (const s of ['', 'KR001', 'steps:', 'kr001/x', '__x__', 12]) assert.ok(!validScope(s), String(s));
  });

  test('걸음 숫자 기회는 그 숫자 범위에만, 도착 기회는 명소에만 쓴다', () => {
    assert.ok(validTicket('m:100', 'steps:100'));
    assert.ok(!validTicket('m:100', 'steps:101'));
    assert.ok(!validTicket('m:100', 'kr001'));
    assert.ok(validTicket('a:j1730000000000', 'kr001'));
    assert.ok(validTicket('a:j1730000000000', 'sketch'));
    assert.ok(!validTicket('a:j1730000000000', 'steps:100'));
    assert.ok(!validTicket('a:x/y', 'kr001'));
    assert.ok(!validTicket(undefined, 'kr001'));
  });
});

describe('반응 집계', () => {
  const zero = { hearts: 0, reportCount: 0 };
  const heart = { kind: 'heart', counted: true } as const;
  const report = { kind: 'report', counted: true } as const;
  const quiet = { kind: 'report', counted: false } as const;

  test('하트와 셈에 드는 신고를 더하고 뺀다', () => {
    assert.deepEqual(applyReaction(zero, null, heart), { hearts: 1, reportCount: 0 });
    assert.deepEqual(applyReaction(zero, null, report), { hearts: 0, reportCount: 1 });
    assert.deepEqual(applyReaction({ hearts: 1, reportCount: 0 }, heart, report), {
      hearts: 0,
      reportCount: 1,
    });
    assert.deepEqual(applyReaction({ hearts: 1, reportCount: 1 }, report, null), {
      hearts: 1,
      reportCount: 0,
    });
  });

  test('셈에서 빠진 신고는 더하지도 빼지도 않고, 0 아래로 가지 않는다', () => {
    assert.deepEqual(applyReaction(zero, null, quiet), zero);
    assert.deepEqual(applyReaction({ hearts: 2, reportCount: 3 }, quiet, heart), {
      hearts: 3,
      reportCount: 3,
    });
    assert.deepEqual(applyReaction(zero, heart, null), zero);
  });

  test('1만 보 미만의 신고만 셈에서 빠진다', () => {
    assert.equal(cfg.reportCountMinTotalSteps, 10000);
    assert.ok(!isCounted('report', 9999, cfg));
    assert.ok(isCounted('report', 10000, cfg));
    assert.ok(isCounted('heart', 0, cfg));
  });

  test('신고 5개 이상이면서 하트보다 많으면 숨긴다', () => {
    assert.ok(!shouldHide({ hearts: 0, reportCount: 4 }, cfg));
    assert.ok(shouldHide({ hearts: 0, reportCount: 5 }, cfg));
    assert.ok(shouldHide({ hearts: 4, reportCount: 5 }, cfg));
    assert.ok(!shouldHide({ hearts: 5, reportCount: 5 }, cfg));
    assert.ok(shouldHide({ hearts: 5, reportCount: 6 }, cfg));
  });

  test('blindNeedsMoreThanHearts를 끄면 하트와 상관없이 숨긴다', () => {
    const off = { ...cfg, blindNeedsMoreThanHearts: false };
    assert.ok(shouldHide({ hearts: 9, reportCount: 5 }, off));
  });
});

describe('제재', () => {
  test('삭제 3번째부터 7일 제한, 검토 기한은 48시간', () => {
    const now = Date.UTC(2026, 10, 5);
    assert.equal(banUntilAfterDelete(2, now, cfg), null);
    assert.equal(banUntilAfterDelete(3, now, cfg), now + 7 * DAY);
    assert.equal(banUntilAfterDelete(4, now, cfg), now + 7 * DAY);
    assert.equal(reviewDeadline(now, cfg), now + 2 * DAY);
  });
});

describe('설정 문서와 색인', () => {
  test('config/guestbook은 앱 config.json guestbook과 키가 같다', () => {
    const app = JSON.parse(readFileSync(join(repo, 'app/assets/data/config.json'), 'utf8')).guestbook;
    assert.deepEqual(guestbookDoc(), app);
    for (const key of [
      'maxChars',
      'readCount',
      'blindMinReports',
      'blindNeedsMoreThanHearts',
      'reportCountMinTotalSteps',
      'reviewHours',
      'banAfterDeletes',
      'banDays',
    ]) {
      assert.ok(key in app, key);
    }
  });

  test('config/moderation으로 올릴 문서는 허용 이름을 담고 그대로 읽힌다', () => {
    const doc = moderationDoc();
    assert.ok(doc.allow.autoWords.length > 300);
    assert.equal(new Moderation(doc).check('경복궁에 왔어요'), null);
    assert.ok(Buffer.byteLength(JSON.stringify(doc)) < 1024 * 1024, 'Firestore 문서 한도 1MiB');
  });

  test('읽기 복합 색인과 반응 collectionGroup 색인이 있다', () => {
    const ix = JSON.parse(readFileSync(join(repo, 'firestore.indexes.json'), 'utf8'));
    assert.deepEqual(
      ix.indexes[0].fields.map((f: { fieldPath: string }) => f.fieldPath),
      ['scope', 'hidden', 'rand'],
    );
    const over = ix.fieldOverrides[0];
    assert.equal(over.collectionGroup, 'reactions');
    assert.equal(over.fieldPath, 'uid');
    assert.ok(over.indexes.some((i: { queryScope: string }) => i.queryScope === 'COLLECTION_GROUP'));
  });
});
