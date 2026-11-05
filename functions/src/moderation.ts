/*
 * 방명록 금칙어 (Firestore config/moderation). 앱의 app/lib/domain/moderation.dart와 같은 코드이고,
 * 검사 순서는 data/check_moderation.py가 정답지다. 시험 문장은 앱·서버가 moderation_cases.json을 함께 읽는다.
 * 정규식은 Dart와 같은 뜻이 되도록 u 플래그 없이 만든다.
 *
 * 규칙 L01~L62는 korean_profanity_filter 1.0.0(https://github.com/Xim-ya/korean_profanity_filter)의
 * 정규식을 옮겨 고친 것이고, 이 파일이 그 정규식을 읽는 로더다.
 *
 * MIT License
 *
 * Copyright (c) 2023 XimYa
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/** 규칙 하나. tight면 붙여 쓴 글에, 아니면 가린 원문에 검사한다 */
export interface ModerationRule {
  id: string;
  category: string;
  tight: boolean;
  re: RegExp;
}

const SYLLABLE_BASE = 0xac00;
const CHO = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
const JUNG = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';
const KEEP = /^[가-힣ㄱ-ㅣa-z#]/;
const SPACE = /\s/;
const WORD_CHAR = /[가-힣ㄱ-ㅣa-z0-9#]/;

/** 1단계: NFC·전각 ASCII → 반각·영문 소문자 (NFKC는 쓰지 않는다: 자모 ㅅ이 다른 글자로 바뀐다) */
export function foldForModeration(text: string): string {
  let out = '';
  for (const ch of text.normalize('NFC')) {
    const code = ch.codePointAt(0)!;
    out += code >= 0xff01 && code <= 0xff5e ? String.fromCharCode(code - 0xfee0) : ch;
  }
  return out.toLowerCase();
}

/** 2단계: 허용 낱말을 같은 길이의 #으로 가린다(긴 것부터). 자리가 그대로라 원문과 맞출 수 있다 */
function maskAllowed(t: string, allow: string[]): string {
  const words = allow.filter((w) => w.length > 0).sort((a, b) => b.length - a.length);
  let out = t;
  for (const raw of words) {
    const w = foldForModeration(raw);
    if (w.length > 0) out = out.replaceAll(w, '#'.repeat(w.length));
  }
  return out;
}

function splitSyllable(c: string): [number, number, number] | null {
  const o = c.charCodeAt(0) - SYLLABLE_BASE;
  if (o < 0 || o >= 11172) return null;
  return [Math.floor(o / 588), Math.floor((o % 588) / 28), o % 28];
}

/** 씨이발 → 씨발, 새애끼 → 새끼: 앞 글자에 받침이 없고, 뒤가 ㅇ + 앞과 같은 모음이면 늘임이다 */
function isStretch(prev: string, next: string): boolean {
  const p = splitSyllable(prev);
  const s = splitSyllable(next);
  if (p === null || s === null) return false;
  return p[2] === 0 && s[0] === CHO.indexOf('ㅇ') && s[2] === 0 && s[1] === p[1];
}

/**
 * 3단계: 닮은꼴 치환 → 한글·자모·영문·#만 남김 → 낱자 모아쓰기 → 같은 글자 2번까지 → 늘임 모음 빼기.
 * 돌려주는 목록은 남은 글자마다 t에서의 자리다
 */
function tighten(t: string, lookalike: Record<string, string>): [string, number[]] {
  const chars: string[] = [];
  const index: number[] = [];
  for (let i = 0; i < t.length; i++) {
    const c = lookalike[t[i]] ?? t[i];
    if (c.length === 0 || !KEEP.test(c)) continue;
    // 자음 뒤에 모음이 오면 받침 없는 글자로 모은다 (ㄱ+ㅐ → 개). 자리는 자음 것을 쓴다
    const v = JUNG.indexOf(c);
    if (v >= 0 && chars.length > 0) {
      const l = CHO.indexOf(chars[chars.length - 1]);
      if (l >= 0) {
        chars[chars.length - 1] = String.fromCharCode(SYLLABLE_BASE + l * 588 + v * 28);
        continue;
      }
    }
    chars.push(c);
    index.push(i);
  }
  const out: string[] = [];
  const outIndex: number[] = [];
  for (let i = 0; i < chars.length; i++) {
    const c = chars[i];
    const n = out.length;
    if (n >= 2 && out[n - 1] === c && out[n - 2] === c) continue;
    if (n > 0 && isStretch(out[n - 1], c)) continue;
    out.push(c);
    outIndex.push(index[i]);
  }
  return [out.join(''), outIndex];
}

function wordStart(t: string, i: number): boolean {
  return i === 0 || !WORD_CHAR.test(t[i - 1]);
}

function parseRule(j: Record<string, unknown>): ModerationRule {
  if (j.on !== 'raw' && j.on !== 'tight') {
    throw new Error(`모르는 금칙어 규칙 자리: ${String(j.on)} (${String(j.id)})`);
  }
  const tight = j.on === 'tight';
  // tight는 일치한 자리를 모두 봐야 해서 g를 붙인다
  const flags = (tight ? 'g' : '') + (j.i === true ? 'i' : '');
  return { id: String(j.id), category: String(j.cat), tight, re: new RegExp(String(j.re), flags) };
}

export class Moderation {
  readonly message: string;
  private readonly allowWords: string[];
  private readonly lookalike: Record<string, string>;
  private readonly raw: ModerationRule[];
  private readonly tight: ModerationRule[];

  /** j는 config/moderation 문서: moderation.json + allow.autoWords(명소·시군구 이름) */
  constructor(j: Record<string, any>) {
    this.message = j.message as string;
    this.allowWords = [...(j.allow.words as string[]), ...((j.allow.autoWords as string[]) ?? [])];
    this.lookalike = j.normalize.lookalike as Record<string, string>;
    const rules = (j.rules as Record<string, unknown>[]).map(parseRule);
    this.raw = rules.filter((r) => !r.tight);
    this.tight = rules.filter((r) => r.tight);
  }

  /** 걸린 규칙. 통과면 null. 어떤 낱말인지는 화면에 알려 주지 않는다 (기준 문서 6장) */
  check(text: string): ModerationRule | null {
    const t = maskAllowed(foldForModeration(text), this.allowWords);
    for (const r of this.raw) {
      if (r.re.test(t)) return r;
    }
    const [tt, index] = tighten(t, this.lookalike);
    for (const r of this.tight) {
      for (const m of tt.matchAll(r.re)) {
        if (m[0].length === 0) continue;
        const start = index[m.index];
        const end = index[m.index + m[0].length - 1] + 1;
        // 띄어쓰기를 건너뛴 일치는 낱말 첫머리에서 시작할 때만 인정한다 (도시 발전 ≠ 시발)
        if (SPACE.test(t.substring(start, end)) && !wordStart(t, start)) continue;
        return r;
      }
    }
    return null;
  }
}
