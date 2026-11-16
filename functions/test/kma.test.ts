// 날씨 계산 시험 (기상청 격자·발표 시각·응답 읽기·가짜 날씨). 에뮬레이터 없이 돈다
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { weatherDoc } from '../scripts/seed';
import {
  cacheKey,
  dailyBase,
  dailyKind,
  fakeWeather,
  gridKey,
  inGrid,
  kmaGrid,
  kmaItems,
  kstDateKey,
  kstToUtc,
  WEATHER_KINDS,
} from '../src/kma';

/** 한국 시각 → UTC ms */
const kst = (y: number, m: number, d: number, h: number, min = 0) => Date.UTC(y, m - 1, d, h, min) - 9 * 3600 * 1000;

describe('위경도 → 기상청 격자', () => {
  test('알려진 곳: 서울시청 60,127 · 부산시청 98,76 · 제주시청 53,38 · 울릉도 127,127', () => {
    assert.deepEqual(kmaGrid(37.5665, 126.978), { nx: 60, ny: 127 });
    assert.deepEqual(kmaGrid(35.1796, 129.0756), { nx: 98, ny: 76 });
    assert.deepEqual(kmaGrid(33.4996, 126.5312), { nx: 53, ny: 38 });
    assert.deepEqual(kmaGrid(37.4844, 130.9057), { nx: 127, ny: 127 });
    assert.equal(gridKey({ nx: 60, ny: 127 }), '60_127');
  });

  test('한국 밖은 격자 범위 밖', () => {
    assert.ok(inGrid(kmaGrid(37.5665, 126.978)));
    assert.ok(!inGrid(kmaGrid(35.6762, 139.6503))); // 도쿄
    assert.ok(!inGrid(kmaGrid(0, 0)));
  });
});

describe('단기예보 발표 시각 (그날 06~21시를 모두 담은 가장 새 발표)', () => {
  test('05:10 뒤면 그날 05시, 02:10 뒤면 그날 02시, 그 전이면 어제 23시', () => {
    assert.deepEqual(dailyBase(kst(2026, 11, 18, 15, 0)), { date: '20261118', time: '0500' });
    assert.deepEqual(dailyBase(kst(2026, 11, 18, 5, 10)), { date: '20261118', time: '0500' });
    assert.deepEqual(dailyBase(kst(2026, 11, 18, 5, 9)), { date: '20261118', time: '0200' });
    assert.deepEqual(dailyBase(kst(2026, 11, 18, 2, 10)), { date: '20261118', time: '0200' });
    assert.deepEqual(dailyBase(kst(2026, 11, 18, 2, 9)), { date: '20261117', time: '2300' });
    assert.deepEqual(dailyBase(kst(2026, 11, 18, 0, 0)), { date: '20261117', time: '2300' });
    assert.deepEqual(dailyBase(kst(2026, 11, 18, 23, 59)), { date: '20261118', time: '0500' });
    // 달·해가 바뀌는 자정 앞
    assert.deepEqual(dailyBase(kst(2027, 1, 1, 1, 0)), { date: '20261231', time: '2300' });
  });

  test('한국 날짜·시각 글자 ↔ UTC, 캐시 문서 키 = 격자 + 한국 날짜', () => {
    assert.equal(kstToUtc('20261118', '1000'), kst(2026, 11, 18, 10));
    assert.equal(kstDateKey(kst(2026, 11, 18, 0, 0)), '20261118');
    assert.equal(kstDateKey(kst(2026, 11, 17, 23, 59)), '20261117');
    assert.equal(cacheKey({ nx: 60, ny: 127 }, '20261118'), '60_127_20261118');
  });
});

const ok = (item: unknown[]) => ({
  response: { header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' }, body: { items: { item } } },
});

/** 그날 06~21시 16시간 예보: [pty] 값과 [sky] 값을 시마다 (모자라면 마지막 값으로) */
function day(date: string, pty: number[], sky: number[], extra: unknown[] = []) {
  const items: unknown[] = [...extra];
  for (let h = 6; h <= 21; h++) {
    const t = `${String(h).padStart(2, '0')}00`;
    const i = h - 6;
    items.push({ category: 'TMP', fcstDate: date, fcstTime: t, fcstValue: '5' });
    items.push({ category: 'SKY', fcstDate: date, fcstTime: t, fcstValue: String(sky[Math.min(i, sky.length - 1)]) });
    items.push({ category: 'PTY', fcstDate: date, fcstTime: t, fcstValue: String(pty[Math.min(i, pty.length - 1)]) });
  }
  return kmaItems(ok(items));
}

describe('그날 대표 날씨 (config weatherSource.dailyRule)', () => {
  const D = '20261118';
  test('06~21시에 비가 한 시간이라도 있으면 비: 비·비/눈·소나기는 비, 눈은 눈', () => {
    assert.equal(dailyKind(day(D, [0, 0, 0, 1, 0], [1]), D), 'rain');
    assert.equal(dailyKind(day(D, [0, 2, 0], [1]), D), 'rain');
    assert.equal(dailyKind(day(D, [0, 4, 0], [1]), D), 'rain');
    assert.equal(dailyKind(day(D, [3, 3, 0], [4]), D), 'snow');
  });

  test('비·눈이 둘 다면 시간이 많은 쪽, 같으면 비', () => {
    assert.equal(dailyKind(day(D, [3, 3, 3, 1, 0], [4]), D), 'snow');
    assert.equal(dailyKind(day(D, [1, 1, 3, 0], [4]), D), 'rain');
    assert.equal(dailyKind(day(D, [1, 3, 0], [4]), D), 'rain');
  });

  test('강수가 없으면 흐림(4) 시간이 절반 이상이면 흐림, 구름많음(3)·맑음(1)은 맑음', () => {
    const half = [4, 4, 4, 4, 4, 4, 4, 4, 1];
    assert.equal(dailyKind(day(D, [0], half), D), 'cloudy');
    assert.equal(dailyKind(day(D, [0], [4, 4, 4, 4, 4, 4, 4, 1]), D), 'clear');
    assert.equal(dailyKind(day(D, [0], [3]), D), 'clear');
    assert.equal(dailyKind(day(D, [0], [1]), D), 'clear');
  });

  test('06시 전·21시 뒤·다른 날 예보는 보지 않는다', () => {
    const outside = [
      { category: 'PTY', fcstDate: D, fcstTime: '0500', fcstValue: '1' },
      { category: 'PTY', fcstDate: D, fcstTime: '2200', fcstValue: '3' },
      { category: 'PTY', fcstDate: '20261119', fcstTime: '1200', fcstValue: '1' },
      { category: 'SKY', fcstDate: '20261119', fcstTime: '1200', fcstValue: '4' },
    ];
    assert.equal(dailyKind(day(D, [0], [1], outside), D), 'clear');
  });

  test('그날 PTY가 없으면 Error, 오류 응답(키 오류·모양이 다름)도 Error', () => {
    assert.throws(() => dailyKind(day(D, [0], [1]), '20261119'));
    assert.throws(() => kmaItems({ response: { header: { resultCode: '30', resultMsg: 'SERVICE_KEY_IS_NOT_REGISTERED_ERROR' } } }));
    assert.throws(() => kmaItems(null));
    assert.deepEqual(kmaItems(ok([])), []);
  });
});

describe('에뮬레이터 가짜 날씨', () => {
  test('같은 격자·같은 날이면 하루 내내 같고, 날이 바뀌면 돌아가며, 이름을 고정할 수 있다', () => {
    const g = { nx: 60, ny: 127 };
    const a = fakeWeather(g, kst(2026, 11, 18, 0, 5));
    assert.ok(WEATHER_KINDS.includes(a));
    assert.equal(fakeWeather(g, kst(2026, 11, 18, 23, 55)), a);
    const days = new Set(Array.from({ length: 4 }, (_, d) => fakeWeather(g, kst(2026, 11, 18 + d, 10))));
    assert.equal(days.size, 4);
    assert.equal(fakeWeather(g, kst(2026, 11, 18, 10), 'snow'), 'snow');
    assert.equal(fakeWeather(g, kst(2026, 11, 18, 10), 'hail'), a);
  });
});

describe('설정 문서', () => {
  test('config/weather = config.json paintColor.weatherSource.cacheKey (격자 + 한국 날짜)', () => {
    assert.deepEqual(weatherDoc(), { cacheKey: 'grid+kstDate' });
  });
});
