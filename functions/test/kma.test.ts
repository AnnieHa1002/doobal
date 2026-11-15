// 날씨 계산 시험 (기상청 격자·발표 시각·응답 읽기·가짜 날씨). 에뮬레이터 없이 돈다
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { weatherDoc } from '../scripts/seed';
import {
  baseTime,
  fakeWeather,
  gridKey,
  inGrid,
  kmaGrid,
  kmaItems,
  kstToUtc,
  precipitationKind,
  skyKind,
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

describe('발표 시각', () => {
  test('초단기실황: 매시 정각 발표, 40분부터 그 시각', () => {
    assert.deepEqual(baseTime(kst(2026, 11, 18, 10, 39), 0, 40), { date: '20261118', time: '0900' });
    assert.deepEqual(baseTime(kst(2026, 11, 18, 10, 40), 0, 40), { date: '20261118', time: '1000' });
    // 자정 넘어 40분 전이면 어제 23시
    assert.deepEqual(baseTime(kst(2026, 11, 19, 0, 10), 0, 40), { date: '20261118', time: '2300' });
  });

  test('초단기예보: 매시 30분 발표, 45분부터 그 시각', () => {
    assert.deepEqual(baseTime(kst(2026, 11, 18, 10, 44), 30, 45), { date: '20261118', time: '0930' });
    assert.deepEqual(baseTime(kst(2026, 11, 18, 10, 45), 30, 45), { date: '20261118', time: '1030' });
    assert.deepEqual(baseTime(kst(2026, 11, 18, 10, 5), 30, 45), { date: '20261118', time: '0930' });
  });

  test('한국 시각 글자 → UTC', () => {
    assert.equal(kstToUtc('20261118', '1000'), kst(2026, 11, 18, 10));
  });
});

const ok = (item: unknown[]) => ({
  response: { header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' }, body: { items: { item } } },
});

describe('응답 읽기', () => {
  test('초단기실황 PTY: 비·비/눈·빗방울 → rain, 눈·눈날림 → snow, 없음 → null', () => {
    const pty = (v: string) => precipitationKind(kmaItems(ok([{ category: 'T1H', obsrValue: '3.1' }, { category: 'PTY', obsrValue: v }])));
    assert.equal(pty('0'), null);
    for (const v of ['1', '2', '5', '6']) assert.equal(pty(v), 'rain');
    for (const v of ['3', '7']) assert.equal(pty(v), 'snow');
    assert.throws(() => precipitationKind(kmaItems(ok([{ category: 'T1H', obsrValue: '3' }]))));
  });

  test('초단기예보 SKY: 지금에 가장 가까운 앞 시각, 흐림(4)이면 cloudy, 맑음·구름많음은 clear', () => {
    const items = kmaItems(ok([
      { category: 'SKY', fcstDate: '20261118', fcstTime: '1100', fcstValue: '1' },
      { category: 'SKY', fcstDate: '20261118', fcstTime: '1200', fcstValue: '4' },
      { category: 'LGT', fcstDate: '20261118', fcstTime: '1100', fcstValue: '0' },
      { category: 'SKY', fcstDate: '20261118', fcstTime: '1300', fcstValue: '3' },
    ]));
    assert.equal(skyKind(items, kst(2026, 11, 18, 11, 50)), 'clear');
    assert.equal(skyKind(items, kst(2026, 11, 18, 12, 10)), 'cloudy');
    assert.equal(skyKind(items, kst(2026, 11, 18, 13, 30)), 'clear');
    // 아직 앞 시각이 없으면 첫 시각
    assert.equal(skyKind(items, kst(2026, 11, 18, 10, 50)), 'clear');
    assert.equal(skyKind([], kst(2026, 11, 18, 10)), 'clear');
  });

  test('오류 응답(키 오류·모양이 다름)은 Error', () => {
    assert.throws(() => kmaItems({ response: { header: { resultCode: '30', resultMsg: 'SERVICE_KEY_IS_NOT_REGISTERED_ERROR' } } }));
    assert.throws(() => kmaItems(null));
    assert.deepEqual(kmaItems(ok([])), []);
  });
});

describe('에뮬레이터 가짜 날씨', () => {
  test('같은 격자·같은 시면 같고, 시가 바뀌면 돌아가며, 이름을 고정할 수 있다', () => {
    const g = { nx: 60, ny: 127 };
    const a = fakeWeather(g, kst(2026, 11, 18, 10, 5));
    assert.ok(WEATHER_KINDS.includes(a));
    assert.equal(fakeWeather(g, kst(2026, 11, 18, 10, 55)), a);
    const day = new Set(Array.from({ length: 4 }, (_, h) => fakeWeather(g, kst(2026, 11, 18, 10 + h))));
    assert.equal(day.size, 4);
    assert.equal(fakeWeather(g, kst(2026, 11, 18, 10), 'snow'), 'snow');
    assert.equal(fakeWeather(g, kst(2026, 11, 18, 10), 'hail'), a);
  });
});

describe('설정 문서', () => {
  test('config/weather = config.json paintColor.weatherSource.cacheMin (60분)', () => {
    assert.deepEqual(weatherDoc(), { cacheMin: 60 });
  });
});
