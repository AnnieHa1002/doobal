"""방명록 금칙어 기준 구현 + 시험 문장 검사 (데이터/check_moderation.py, v1 2026-11-03 개발 기획)

앱(Dart)·서버(TypeScript)는 이 파일과 같은 순서로 구현한다. 이 파일이 '정답지'다.
  python3 -I check_moderation.py moderation.json moderation_cases.json [landmarks.json sigungu.json]
landmarks·sigungu를 주면 이름을 허용 목록에 넣고, 이름 하나하나가 막히지 않는지도 검사한다.
"""
import json, re, sys, unicodedata

HANGUL_RE = re.compile(r'[가-힣ㄱ-ㅣ]')
KEEP_RE = re.compile(r'[가-힣ㄱ-ㅣa-z#]')  # tight에 남기는 글자 (#는 허용 목록 가림 자리)
CHO = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ'
JUNG = 'ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ'


def split_syl(c):
    o = ord(c) - 0xAC00
    if 0 <= o < 11172:
        return o // 588, (o % 588) // 28, o % 28
    return None


def fold(text):
    """1단계: NFC, 전각 ASCII → 반각, 영문 소문자. (NFKC는 쓰지 않는다: 자모 ㅅ이 다른 글자로 바뀜)"""
    t = unicodedata.normalize('NFC', text)
    t = ''.join(chr(ord(c) - 0xFEE0) if 0xFF01 <= ord(c) <= 0xFF5E else c for c in t)
    return t.lower()


def mask_allow(t, allow):
    """2단계: 허용 목록 단어를 같은 길이의 #으로 가린다(긴 단어부터). 위치가 그대로라 원문 대응이 쉽다."""
    for w in sorted(allow, key=len, reverse=True):
        w = fold(w)
        if w:
            t = t.replace(w, '#' * len(w))
    return t


def tight(t, lookalike):
    """3단계: 닮은꼴 치환 → 한글·자모·영문·#만 남김 → 낱자 모아쓰기 → 같은 글자 2번까지 → 늘임 모음 빼기. 원문 위치표 함께."""
    chars, idx = [], []
    for i, c in enumerate(t):
        c = lookalike.get(c, c)
        if c and KEEP_RE.match(c):
            chars.append(c); idx.append(i)
    # 낱자 모음: ㄱ+ㅐ → 개 (자음 뒤에 모음이 오면 받침 없는 글자로)
    cc, ci = [], []
    for c, i in zip(chars, idx):
        if cc and c in JUNG and cc[-1] in CHO:
            cc[-1] = chr(0xAC00 + CHO.index(cc[-1]) * 588 + JUNG.index(c) * 28)
            continue
        cc.append(c); ci.append(i)
    out, oidx = [], []
    for c, i in zip(cc, ci):
        if len(out) >= 2 and out[-1] == c == out[-2]:   # 같은 글자는 2번까지만 (씨씨씨발 → 씨씨발, 성매매는 그대로)
            continue
        if out:                              # 씨이발 → 씨발, 새애끼 → 새끼 (ㅇ+같은 모음, 앞 글자 받침 없음)
            p, s = split_syl(out[-1]), split_syl(c)
            if p and s and p[2] == 0 and s[0] == CHO.index('ㅇ') and s[2] == 0 and s[1] == p[1]:
                continue
        out.append(c); oidx.append(i)
    return ''.join(out), oidx


def word_start(t, i):
    return i == 0 or not re.match(r'[가-힣ㄱ-ㅣa-z0-9#]', t[i - 1])


def check(text, cfg):
    """결과: None(통과) 또는 (분류, 규칙 id). 화면에는 분류·단어를 보여 주지 않는다."""
    t = mask_allow(fold(text), cfg['allow']['words'] + cfg['allow'].get('autoWords', []))
    for r in cfg['rules']:                       # 원문(가린 글) 규칙: 라이브러리 정규식·D·E·raw 단어
        if r['on'] == 'raw' and re.search(r['re'], t, re.I if r.get('i') else 0):
            return r['cat'], r['id']
    tt, oidx = tight(t, cfg['normalize']['lookalike'])
    for r in cfg['rules']:                       # 붙여 쓴 글 규칙: 직접 만든 단어 목록
        if r['on'] != 'tight':
            continue
        for m in re.finditer(r['re'], tt):
            s, e = oidx[m.start()], oidx[m.end() - 1] + 1
            if re.search(r'\s', t[s:e]) and not word_start(t, s):
                continue                          # 띄어쓰기를 건너뛴 일치는 낱말 첫머리에서 시작할 때만 (도시 발전 ≠ 시발)
            return r['cat'], r['id']
    return None


def main():
    cfg = json.load(open(sys.argv[1], encoding='utf-8'))
    cases = json.load(open(sys.argv[2], encoding='utf-8'))
    names = []
    if len(sys.argv) >= 5:
        names += [x['name'] for x in json.load(open(sys.argv[3], encoding='utf-8'))['landmarks']]
        names += [x['name'] for x in json.load(open(sys.argv[4], encoding='utf-8'))['items']]
        cfg['allow']['autoWords'] = sorted(set(names))
    for r in cfg['rules']:
        re.compile(r['re'])
    fails = 0
    for c in cases['cases']:
        got = check(c['text'], cfg)
        ok = (got is not None) == (c['expect'] == 'block') and (got is None or c.get('cat') is None or got[0] in (c['cat'] if isinstance(c['cat'], list) else [c['cat']]))
        if not ok:
            fails += 1
            print('FAIL', c['id'], c['text'], '→', got, '기대', c['expect'], c.get('cat', ''))
    for n in names:
        got = check(n, cfg)
        if got:
            fails += 1; print('FAIL 이름', n, got)
    nb = sum(c['expect'] == 'block' for c in cases['cases'])
    print(f"문장 {len(cases['cases'])}개(막기 {nb}·통과 {len(cases['cases']) - nb}), 이름 {len(names)}개, 실패 {fails}")
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
