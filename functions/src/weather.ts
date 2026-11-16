// 날씨 (16장 11/14 물감 색·11/16 ‘날씨는 그날 하루 하나’, M2~M6 v0.22 AA, 기술 설계서 v0.9, 스키마 v10.7).
// 앱이 그날 처음 물감 길을 열 때 정령이 있는 지도 위 여정 지점(위치 권한 없음)으로 부르면 기상청 격자로 바꿔
// 그날 대표 날씨 하나를 준다. 격자 + 한국 날짜로 weatherCache/{nx_ny}_{yyyymmdd}에 두고 그날 안에는 다시 부르지
// 않는다 (격자마다 하루 1번 기상청 호출). 키는 Secret Manager KMA_SERVICE_KEY (리포·앱에 두지 않는다).
// 에뮬레이터는 기상청을 부르지 않고 가짜 날씨
import { defineSecret } from 'firebase-functions/params';
import { onCall } from 'firebase-functions/v2/https';
import { loadWeatherConfig } from './config';
import { callableOptions, db, fail, isEmulator, requireUid } from './firebase';
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
  type Grid,
  type WeatherKind,
} from './kma';

const KMA_SERVICE_KEY = defineSecret('KMA_SERVICE_KEY');
const KMA_API = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0';
const KMA_TIMEOUT_MS = 5000;
// 어제 23시 발표부터 그날 21시까지 한 시에 12~13칸이라 300칸 남짓. 한 번에 받는다
const KMA_ROWS = 1000;

/** 기상청 한 번 부르기 (JSON). 실패하면 Error */
async function kmaGet(path: string, g: Grid, base: { date: string; time: string }): Promise<unknown> {
  const q = new URLSearchParams({
    serviceKey: KMA_SERVICE_KEY.value(),
    pageNo: '1',
    numOfRows: String(KMA_ROWS),
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

/** 기상청 단기예보로 그날 대표 날씨: 그날 06~21시를 모두 담은 가장 새 발표 하나 (at = 그 발표 시각) */
async function fromKma(g: Grid, nowMs: number, date: string): Promise<{ kind: WeatherKind; at: number }> {
  const base = dailyBase(nowMs);
  const kind = dailyKind(kmaItems(await kmaGet('getVilageFcst', g, base)), date);
  return { kind, at: kstToUtc(base.date, base.time) };
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

    // 캐시 키 모양 확인 (config.json paintColor.weatherSource.cacheKey grid+kstDate)
    await loadWeatherConfig();
    const now = Date.now();
    const day = kstDateKey(now);
    const ref = db.doc(`weatherCache/${cacheKey(grid, day)}`);
    const cached = (await ref.get()).data();
    if (cached !== undefined) {
      return { kind: cached.kind as WeatherKind, at: cached.at as number, day };
    }

    let fresh: { kind: WeatherKind; at: number };
    if (isEmulator) {
      fresh = { kind: fakeWeather(grid, now, process.env.KMA_FAKE_KIND), at: now };
    } else {
      try {
        fresh = await fromKma(grid, now, day);
      } catch (e) {
        console.error('기상청 실패', gridKey(grid), day, e instanceof Error ? e.message : e);
        throw fail('unavailable', 'weather-unavailable', '날씨를 받지 못했어요');
      }
    }
    await ref.set({ ...fresh, fetchedAt: now });
    return { ...fresh, day };
  },
);
