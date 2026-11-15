// 날씨 (16장 11/14 물감 색, M2~M6 v0.20 Y, 기술 설계서 v0.8, 스키마 v10.5).
// 앱이 정령이 있는 지도 위 여정 지점(위치 권한 없음)으로 부르면 기상청 격자로 바꿔 지금 날씨를 준다.
// 격자별로 weatherCache/{nx_ny}에 config/weather.cacheMin(config.json paintColor.weatherSource) 동안 둔다.
// 키는 Secret Manager KMA_SERVICE_KEY (리포·앱에 두지 않는다). 에뮬레이터는 기상청을 부르지 않고 가짜 날씨
import { defineSecret } from 'firebase-functions/params';
import { onCall } from 'firebase-functions/v2/https';
import { loadWeatherConfig } from './config';
import { callableOptions, db, fail, isEmulator, requireUid } from './firebase';
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
  type Grid,
  type WeatherKind,
} from './kma';

const KMA_SERVICE_KEY = defineSecret('KMA_SERVICE_KEY');
const KMA_API = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0';
const KMA_TIMEOUT_MS = 5000;

/** 기상청 한 번 부르기 (JSON). 실패하면 Error */
async function kmaGet(path: string, g: Grid, base: { date: string; time: string }): Promise<unknown> {
  const q = new URLSearchParams({
    serviceKey: KMA_SERVICE_KEY.value(),
    pageNo: '1',
    numOfRows: '100',
    dataType: 'JSON',
    base_date: base.date,
    base_time: base.time,
    nx: String(g.nx),
    ny: String(g.ny),
  });
  const res = await fetch(`${KMA_API}/${path}?${q}`, { signal: AbortSignal.timeout(KMA_TIMEOUT_MS) });
  if (!res.ok) throw new Error(`기상청 HTTP ${res.status}`);
  // 키 오류 같은 것은 dataType과 상관없이 XML로 온다: JSON이 아니면 오류
  return JSON.parse(await res.text());
}

/** 기상청에서 지금 날씨: 초단기실황 강수 형태, 강수가 없으면 초단기예보 하늘 상태 */
async function fromKma(g: Grid, nowMs: number): Promise<{ kind: WeatherKind; at: number }> {
  const ncstBase = baseTime(nowMs, 0, 40);
  const rain = precipitationKind(kmaItems(await kmaGet('getUltraSrtNcst', g, ncstBase)));
  const at = kstToUtc(ncstBase.date, ncstBase.time);
  if (rain !== null) return { kind: rain, at };
  const sky = skyKind(kmaItems(await kmaGet('getUltraSrtFcst', g, baseTime(nowMs, 30, 45))), nowMs);
  return { kind: sky, at };
}

export const getWeather = onCall(
  // 에뮬레이터는 비밀 값을 읽지 않는다 (가짜 날씨). 배포할 때는 Secret Manager 값이 함수에 붙는다
  { ...callableOptions, secrets: isEmulator ? [] : [KMA_SERVICE_KEY] },
  async (request) => {
    requireUid(request);
    const { lat, lng } = request.data ?? {};
    if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw fail('invalid-argument', 'bad-point', '지점이 올바르지 않아요');
    }
    const grid = kmaGrid(lat, lng);
    if (!inGrid(grid)) throw fail('invalid-argument', 'bad-point', '날씨를 알 수 없는 곳이에요');

    const { cacheMin } = await loadWeatherConfig();
    const now = Date.now();
    const ref = db.doc(`weatherCache/${gridKey(grid)}`);
    const cached = (await ref.get()).data();
    if (cached !== undefined && now - (cached.fetchedAt as number) < cacheMin * 60 * 1000) {
      return { kind: cached.kind as WeatherKind, at: cached.at as number };
    }

    let fresh: { kind: WeatherKind; at: number };
    if (isEmulator) {
      fresh = { kind: fakeWeather(grid, now, process.env.KMA_FAKE_KIND), at: now };
    } else {
      try {
        fresh = await fromKma(grid, now);
      } catch (e) {
        console.error('기상청 실패', gridKey(grid), e instanceof Error ? e.message : e);
        throw fail('unavailable', 'weather-unavailable', '날씨를 받지 못했어요');
      }
    }
    await ref.set({ ...fresh, fetchedAt: now });
    return fresh;
  },
);
