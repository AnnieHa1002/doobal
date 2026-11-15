// 기상청 초단기실황·초단기예보 (공공데이터포털 VilageFcstInfoService_2.0) 계산 — 순수 함수.
// 기술 설계서 v0.8·스키마 v10.5: 위경도 → 격자 변환은 서버에서, 격자별 캐시. 함수는 weather.ts

/** 앱에 돌려주는 날씨 (M2~M6 v0.20 Y). 맑음이면 앱은 시간대 색 */
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

/** 캐시 문서 id (weatherCache/{nx_ny}) */
export const gridKey = (g: Grid) => `${g.nx}_${g.ny}`;

const KST_MS = 9 * 60 * 60 * 1000;
const MIN = 60 * 1000;

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

/**
 * 지금 부를 수 있는 가장 새 발표 시각. 초단기실황은 매시 정각 발표·40분쯤부터 받을 수 있고(publishMin 40),
 * 초단기예보는 매시 30분 발표·45분쯤부터 (기상청 활용 가이드). 발표 시각은 [baseMin]분(실황 0, 예보 30)
 */
export function baseTime(nowMs: number, baseMin: number, publishMin: number): { date: string; time: string } {
  const at = nowMs - (publishMin - baseMin) * MIN;
  // at이 든 시각의 baseMin분 (at의 분이 baseMin보다 앞이면 그 앞 시각)
  const hour = Math.floor((at + KST_MS - baseMin * MIN) / (60 * MIN));
  const baseMs = hour * 60 * MIN + baseMin * MIN - KST_MS;
  const { date, hhmm } = kstParts(baseMs);
  return { date, time: hhmm };
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
 * 초단기실황의 강수 형태(PTY) → 날씨. 0 없음, 1 비, 2 비/눈, 3 눈, 5 빗방울, 6 빗방울눈날림, 7 눈날림.
 * 비와 눈이 섞이면 비로 본다. 강수가 없으면 null (하늘 상태는 초단기예보에서)
 */
export function precipitationKind(items: KmaItem[]): WeatherKind | null {
  const pty = Number(items.find((i) => i.category === 'PTY')?.obsrValue);
  if (!Number.isFinite(pty)) throw new Error('초단기실황에 PTY가 없어요');
  if (pty === 3 || pty === 7) return 'snow';
  if (pty === 1 || pty === 2 || pty === 5 || pty === 6) return 'rain';
  return null;
}

/**
 * 초단기예보의 하늘 상태(SKY) 중 [nowMs]에 가장 가까운 앞 시각(없으면 첫 시각) → 흐림(4)이면 cloudy, 아니면 clear
 * (1 맑음·3 구름많음). SKY가 없으면 clear
 */
export function skyKind(items: KmaItem[], nowMs: number): WeatherKind {
  const sky = items
    .filter((i) => i.category === 'SKY' && i.fcstDate && i.fcstTime)
    .map((i) => ({ at: kstToUtc(i.fcstDate!, i.fcstTime!), value: Number(i.fcstValue) }))
    .sort((a, b) => a.at - b.at);
  if (sky.length === 0) return 'clear';
  const past = sky.filter((s) => s.at <= nowMs);
  const pick = past.length > 0 ? past[past.length - 1] : sky[0];
  return pick.value === 4 ? 'cloudy' : 'clear';
}

/**
 * 에뮬레이터의 가짜 날씨 (실제 기상청을 부르지 않는다): [fixed]가 날씨 이름이면 그것, 아니면 격자와 한국 시각의
 * 시(時)로 돌아가며. 같은 격자·같은 시면 같다
 */
export function fakeWeather(g: Grid, nowMs: number, fixed?: string): WeatherKind {
  if (fixed !== undefined && (WEATHER_KINDS as readonly string[]).includes(fixed)) return fixed as WeatherKind;
  const hour = Math.floor((nowMs + KST_MS) / (60 * MIN));
  return WEATHER_KINDS[(g.nx + g.ny + hour) % WEATHER_KINDS.length];
}
