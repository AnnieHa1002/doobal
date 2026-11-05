// 금칙어 포팅 시험. 에뮬레이터 없이 돈다. 시험 문장은 앱 테스트와 같은 파일을 읽는다
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, test } from 'node:test';
import { foldForModeration, Moderation } from '../src/moderation';

const dataDir = join(__dirname, '..', '..', '..', 'app', 'assets', 'data');
const load = (name: string) => JSON.parse(readFileSync(join(dataDir, name), 'utf8'));

const doc = load('moderation.json');
const names: string[] = [
  ...load('landmarks.json').landmarks.map((x: { name: string }) => x.name),
  ...load('sigungu.json').items.map((x: { name: string }) => x.name),
];
const cases = load('moderation_cases.json').cases as {
  id: string;
  text: string;
  expect: 'block' | 'pass';
  cat?: string | string[];
}[];

const plain = new Moderation(doc);
const withNames = new Moderation({ ...doc, allow: { ...doc.allow, autoWords: names } });

describe('시험 문장 (moderation_cases.json, 앱 테스트와 같은 파일)', () => {
  test('100개를 읽는다', () => assert.equal(cases.length, 100));

  for (const [label, mod] of [
    ['허용 이름 없이', plain],
    ['허용 이름과 함께', withNames],
  ] as const) {
    for (const c of cases) {
      test(`${label} ${c.id} ${c.expect}: ${c.text}`, () => {
        const got = mod.check(c.text);
        assert.equal(got !== null, c.expect === 'block', `걸린 규칙: ${got?.id}`);
        if (got !== null && c.cat !== undefined) {
          const want = Array.isArray(c.cat) ? c.cat : [c.cat];
          assert.ok(want.includes(got.category), `${got.id} ${got.category}`);
        }
      });
    }
  }
});

describe('허용 이름', () => {
  test('명소·시군구 이름은 그 자체로 막히지 않는다', () => {
    assert.ok(names.length > 300);
    for (const n of names) assert.equal(withNames.check(n), null, n);
  });

  test('허용 이름은 가리고 나머지를 본다', () => {
    const mod = new Moderation({ ...doc, allow: { ...doc.allow, autoWords: ['이상한발산'] } });
    assert.equal(mod.check('이상한발산에서 출발해요'), null);
    assert.notEqual(mod.check('이상한발산에서 씨발'), null);
  });
});

describe('글 다듬기', () => {
  test('전각 글자는 반각으로, 영문은 소문자로', () => {
    assert.equal(foldForModeration('ＡＢｃ１'), 'abc1');
  });

  test('풀어 쓴 한글(맥 입력)을 모은다', () => {
    assert.equal(foldForModeration('각스'.normalize('NFD')), '각스');
    assert.notEqual(plain.check('씨발'.normalize('NFD')), null);
  });

  test('띄어쓰기·특수문자·늘임으로 피해도 걸린다', () => {
    for (const t of ['씨 .발', '씨이이발', 'ㅅㅂ']) assert.notEqual(plain.check(t), null, t);
  });
});

test('규칙은 123개, 막힌 글 안내는 한 줄', () => {
  assert.equal(doc.rules.length, 123);
  assert.equal(plain.message, '이 표현은 방명록에 남길 수 없어요');
});

test('모르는 규칙 자리는 오류', () => {
  const rules = [{ id: 'x', cat: 'A', on: 'elsewhere', re: 'a' }];
  assert.throws(() => new Moderation({ ...doc, rules }));
});

test('같은 규칙으로 여러 번 검사해도 결과가 같다 (정규식 상태가 남지 않는다)', () => {
  for (let i = 0; i < 3; i++) assert.notEqual(plain.check('씨 .발 진짜'), null);
});
