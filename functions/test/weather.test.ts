// getWeather 흐름 시험 (에뮬레이터: 기상청을 부르지 않고 가짜 날씨)
import assert from 'node:assert/strict';
import { before, describe, test } from 'node:test';
import { WEATHER_KINDS } from '../src/kma';
import { db, makeUser, ok, rejects, seed } from './helpers';

before(seed);

describe('getWeather', () => {
  test('여정 지점의 날씨: 가짜 날씨를 주고 격자별로 캐시한다 (두 번째는 같은 값)', async () => {
    const { idToken } = await makeUser();
    await db.doc('weatherCache/60_127').delete();
    const first = await ok('getWeather', { lat: 37.5665, lng: 126.978 }, idToken);
    assert.ok(WEATHER_KINDS.includes(first.kind));
    assert.equal(typeof first.at, 'number');
    const doc = (await db.doc('weatherCache/60_127').get()).data()!;
    assert.equal(doc.kind, first.kind);
    assert.equal(typeof doc.fetchedAt, 'number');
    // 같은 격자 안의 다른 지점도 캐시 값
    const again = await ok('getWeather', { lat: 37.57, lng: 126.98 }, idToken);
    assert.deepEqual(again, first);
  });

  test('캐시가 cacheMin보다 오래되면 새로 받는다', async () => {
    const { idToken } = await makeUser();
    await db.doc('weatherCache/98_76').set({ kind: 'snow', at: 1, fetchedAt: Date.now() - 61 * 60 * 1000 });
    const fresh = await ok('getWeather', { lat: 35.1796, lng: 129.0756 }, idToken);
    assert.notEqual(fresh.at, 1);
    await db.doc('weatherCache/98_76').set({ kind: 'snow', at: 2, fetchedAt: Date.now() - 59 * 60 * 1000 });
    assert.deepEqual(await ok('getWeather', { lat: 35.1796, lng: 129.0756 }, idToken), { kind: 'snow', at: 2 });
  });

  test('로그인해야 하고, 지점이 틀리거나 한국 밖이면 bad-point', async () => {
    await rejects('getWeather', { lat: 37.5, lng: 127 }, undefined, 'UNAUTHENTICATED');
    const { idToken } = await makeUser();
    await rejects('getWeather', { lat: '37.5', lng: 127 }, idToken, 'INVALID_ARGUMENT', 'bad-point');
    await rejects('getWeather', {}, idToken, 'INVALID_ARGUMENT', 'bad-point');
    await rejects('getWeather', { lat: 35.68, lng: 139.65 }, idToken, 'INVALID_ARGUMENT', 'bad-point');
  });

  test('앱은 캐시 문서를 직접 읽지 못한다 (보안 규칙: 그 밖의 모든 곳)', async () => {
    const rules = await import('node:fs').then((fs) => fs.readFileSync(`${__dirname}/../../../firestore.rules`, 'utf8'));
    assert.ok(!rules.includes('weatherCache'));
    assert.ok(rules.includes('match /{document=**}'));
  });
});
