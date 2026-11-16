// 기상청 단기예보 (공공데이터포털 VilageFcstInfoService_2.0) 하루 대표 날씨 계산 — 순수 함수.
// 16장 11/16 ‘날씨는 그날 하루 하나’, 기술 설계서 v0.9·스키마 v10.7: 위경도 → 격자 변환은 서버에서,
// 격자 + 한국 날짜 캐시. 함수는 weather.ts

/** 앱에 돌려주는 날씨 (M2~M6 v0.20 Y·v0.22 AA). 맑음이면 앱은 시간대 색 */
export type WeatherKind = 'clear' | 'cloudy' | 'rain' | 'snow';
export const WEATHER_KINDS: readonly WeatherKind[] = ['clear', 'cloudy', 'rain', 'snow'];

export interface Grid {
  nx: number;
  ny: number;
}

// 기상청 격자 변환 규약 값 (바깥 API의 약속이라 설정 문서에 두지 않는다): 지구 반경 6371.00877km, 격자 5km,
// 표준 위도 30°·60°, 기준점 북위 38°·동경 126° = 격자 (43, 136)
const RE = 6371.00877;
const GRID = 5.0;
const SLAT1 = 30.0;
const SLAT2 = 60.0;
const OLON = 126.0;
const OLAT = 38.0;
const XO = 43;
const YO = 136;

/** 격자 범위 (기상청 동네예보 격자 149 × 253) */
export const GRID_MAX = { nx: 149, ny: 253 };

/** 위경도 → 기상청 격자 (람베르트 정각원추도법, 기상청 변환 코드). 서울시청 (37.5665, 126.978) = (60, 127) */
export function kmaGrid(lat: number, lng: number): Grid {
  const deg = Math.PI / 180;
  const re = RE / GRID;
  const s1 = SLAT1 * deg;
  const s2 = SLAT2 * deg;
  const olon = OLON * deg;
  const olat = OLAT * deg;
  const t = (v: number) => Math.tan(Math.PI * 0.25 + v * 0.5);
  const sn = Math.log(Math.cos(s1) / Math.cos(s2)) / Math.log(t(s2) / t(s1));
  const sf = (Math.pow(t(s1), sn) * Math.cos(s1)) / sn;
  const ro = (re * sf) / Math.pow(t(olat), sn);
  const ra = (re * sf) / Math.pow(t(lat * deg), sn);
  let theta = lng * deg - olon;
  if (theta > Math.PI) theta -= 2 * Math.PI;
  if (theta < -Math.PI) theta += 2 * Math.PI;
  theta *= sn;
  return {
    nx: Math.floor(ra * Math.sin(theta) + XO + 0.5),
    ny: Math.floor(ro - ra * Math.cos(theta) + YO + 0.5),
  };
}

/** 격자가 기상청 범위 안인가 (한국 밖 지점은 날씨를 묻지 않는다) */
export function inGrid(g: Grid): boolean {
  return g.nx >= 1 && g.nx <= GRID_MAX.nx && g.ny >= 1 && g.ny <= GRID_MAX.ny;
}

/** 격자 키 nx_ny */
export const gridKey = (g: Grid) => `${g.nx}_${g.ny}`;

/** 캐시 문서 id (스키마 v10.7: weatherCache/{nx_ny}_{yyyymmdd}, 그날 안에는 다시 부르지 않는다) */
export const cacheKey = (g: Grid, date: string) => `${gridKey(g)}_${date}`;

const KST_MS = 9 * 60 * 60 * 1000;
const MIN = 60 * 1000;
const DAY_MS = 24 * 60 * MIN;

// 단기예보 발표 시각(한국 시)과 받을 수 있게 되는 분 (기상청 규약, 바깥 API의 약속)
const SHORT_ISSUE_HOURS = [2, 5, 8, 11, 14, 17, 20, 23];
const SHORT_PUBLISH_MIN = 10;

// 하루 대표 날씨 규칙 (config paintColor.weatherSource.dailyRule 글 ‘06~21시 … 흐림이 절반 이상’, 가안).
// config에 숫자 키가 생기면 설정 문서로 옮긴다 (개발 기획에 넘김)
const DAY_FROM_HOUR = 6;
const DAY_TO_HOUR = 21;
const DAILY_RULE = { fromHour: DAY_FROM_HOUR, toHour: DAY_TO_HOUR, cloudyShare: 0.5 };

/** 한국 시각 ms를 'YYYYMMDD'·'HHmm'으로 */
function kstParts(ms: number): { date: string; hhmm: string } {
  const d = new Date(ms + KST_MS);
  const p = (n: number) => String(n).padStart(2, '0');
  return {
    date: `${d.getUTCFullYear()}${p(d.getUTCMonth() + 1)}${p(d.getUTCDate())}`,
    hhmm: `${p(d.getUTCHours())}${p(d.getUTCMinutes())}`,
  };
}

/** 'YYYYMMDD'·'HHmm'(한국 시각) → UTC ms */
export function kstToUtc(date: string, hhmm: string): number {
  const y = Number(date.slice(0, 4));
  const m = Number(date.slice(4, 6));
  const d = Number(date.slice(6, 8));
  return Date.UTC(y, m - 1, d, Number(hhmm.slice(0, 2)), Number(hhmm.slice(2, 4))) - KST_MS;
}

/** 'YYYYMMDD' 한국 날짜 (캐시 문서 키·그날 예보 고르기) */
export function kstDateKey(nowMs: number): string {
  return kstParts(nowMs).date;
}

/**
 * 단기예보 발표 시각: 02·05·08·11·14·17·20·23시, 발표 10분 뒤부터 받을 수 있다 (기상청 활용 가이드).
 * 그날 대표 날씨 칸(dayFromHour~dayToHour시)을 모두 담은 가장 새 발표를 고른다 (기술 설계서 v0.9):
 * 발표 시각 다음 시부터 예보가 있으니 그날 05시 발표까지가 06시를 담는다. 그래서 05:10 뒤면 그날 05시,
 * 02:10 뒤면 그날 02시, 그 전이면 어제 23시
 */
export function dailyBase(nowMs: number, dayFromHour = DAY_FROM_HOUR): { date: string; time: string } {
  const today = kstDateKey(nowMs);
  const sinceMidnight = nowMs + KST_MS - Math.floor((nowMs + KST_MS) / DAY_MS) * DAY_MS;
  let pick: number | null = null;
  for (const h of SHORT_ISSUE_HOURS) {
    if (h >= dayFromHour) break;
    if (sinceMidnight >= h * 60 * MIN + SHORT_PUBLISH_MIN * MIN) pick = h;
  }
  if (pick === null) return { date: kstDateKey(nowMs - DAY_MS), time: '2300' };
  return { date: today, time: `${String(pick).padStart(2, '0')}00` };
}

interface KmaItem {
  category?: string;
  obsrValue?: string | number;
  fcstDate?: string;
  fcstTime?: string;
  fcstValue?: string | number;
}

/** 기상청 응답(JSON)의 항목들. 오류 응답(resultCode가 00이 아니거나 XML)이면 Error */
export function kmaItems(body: unknown): KmaItem[] {
  const res = (body as { response?: any } | null)?.response;
  const code = res?.header?.resultCode;
  if (code !== '00') throw new Error(`기상청 응답 오류: ${code ?? '모양이 다름'} ${res?.header?.resultMsg ?? ''}`);
  const item = res?.body?.items?.item;
  return Array.isArray(item) ? item : [];
}

/**
 * 단기예보로 그날([date] 'YYYYMMDD') 대표 날씨 하나 (config paintColor.weatherSource.dailyRule, 가안):
 * dayFromHour~dayToHour시 예보 중 강수(PTY) 시간이 하나라도 있으면 그 강수 — 비·눈이 둘 다면 시간이 많은 쪽(같으면 비).
 * 단기예보 PTY는 0 없음·1 비·2 비/눈·3 눈·4 소나기이고 비/눈·소나기는 비로 본다.
 * 강수가 없으면 하늘 상태(SKY)가 흐림(4)인 시간이 cloudyShare 이상이면 흐림, 아니면 맑음(1 맑음·3 구름많음).
 * 그 시간 PTY가 하나도 없으면 Error (응답 모양이 다름)
 */
export function dailyKind(
  items: KmaItem[],
  date: string,
  rule: { fromHour: number; toHour: number; cloudyShare: number } = DAILY_RULE,
): WeatherKind {
  const inDay = items.filter((i) => {
    if (i.fcstDate !== date || !i.fcstTime) return false;
    const h = Number(i.fcstTime.slice(0, 2));
    return h >= rule.fromHour && h <= rule.toHour;
  });
  const pty = inDay.filter((i) => i.category === 'PTY').map((i) => Number(i.fcstValue));
  if (pty.length === 0) throw new Error(`단기예보에 ${date} PTY가 없어요`);
  const snow = pty.filter((v) => v === 3).length;
  const rain = pty.filter((v) => v === 1 || v === 2 || v === 4).length;
  if (rain + snow > 0) return snow > rain ? 'snow' : 'rain';
  const sky = inDay.filter((i) => i.category === 'SKY').map((i) => Number(i.fcstValue));
  const cloudy = sky.filter((v) => v === 4).length;
  return sky.length > 0 && cloudy >= sky.length * rule.cloudyShare ? 'cloudy' : 'clear';
}

/**
 * 에뮬레이터의 가짜 날씨 (실제 기상청을 부르지 않는다): [fixed]가 날씨 이름이면 그것, 아니면 격자와 한국 날짜로
 * 돌아가며. 같은 격자·같은 날이면 같다 (하루 대표 날씨처럼)
 */
export function fakeWeather(g: Grid, nowMs: number, fixed?: string): WeatherKind {
  if (fixed !== undefined && (WEATHER_KINDS as readonly string[]).includes(fixed)) return fixed as WeatherKind;
  const day = Math.floor((nowMs + KST_MS) / DAY_MS);
  return WEATHER_KINDS[(g.nx + g.ny + day) % WEATHER_KINDS.length];
}
