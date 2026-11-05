#!/usr/bin/env python3
"""동행 이야기 → companions.json (정적 데이터 스키마 9장)

    python3 build_companions.py <기획/동행_이야기.md> <출력 companions.json>

- 동행 3명(bright·rest·doctor) × 장 9개(0 = 프롤로그, 1~8). 그림은 0·8장만.
- 이름은 기준 문서 5장 값으로 쓴다(퐁이·휴·심 박사, 10/30). 문구 파일의 옛 이름(OLD_NAMES)은 바꿔 넣는다.
- 줄 종류(who): companion(동행 대사), me(내 대사), narr(지문, 괄호 한 줄).
- [H1]~[H5]는 source로 옮기고 본문에서 지운다. [함께 걷기 / 혼자 걷기]는 choice, [완결 소품: …]은 prop.
- face는 시작값(문구로 추정): '와!'·'호호!'·'헤헤'로 시작·끝나면 laugh, '어이쿠'면 surprised, 4·5장에서 '…'로 시작하면 calm(눈 감음), 나머지 smile.
  표정 그림 4종(smile·laugh·surprised·closed)과 이름이 다르면 디자인이 나온 뒤 FACE_MAP만 고친다.
- (v2, 11/6) 그림(art)은 story_layers.json의 장면 id(m01_prologue·m01_finale…): 정령 없는 뒤판 + 앱이 지금 입은 정령 뒷면을 얹음(16장 11/4).
- 검사: 동행 3명, 장 9개씩, 그림 0·8장만(합계 6), 장마다 대사 6~10줄(지문 제외, 넘으면 경고만).
"""
import json
import re
import sys

COMPANIONS = [
    # (id, 문구 파일의 제목 키워드, 이름, 종, 지형, pace, 완결 소품, 완결 뒤 숨길 층, 그림 id)
    ('bright', '밝은 친구', '퐁이', 'duck', 'coast', 'ahead', 'hat_10', None, 'm01'),
    ('rest', '쉬어가는 친구', '휴', 'cat', 'city', 'walkOnly', 'hand_09', None, 'm02'),
    ('doctor', '박사 친구', '심 박사', 'ginseng', 'mountain', 'match', 'hat_11', 'glasses', 'm03'),
]
OLD_NAMES = {}  # 옛 이름이 생기면 {'id': ['옛 이름']}로 넣는다(10/30 퐁이로 통일, 폐이 폐기)
FACE_MAP = {'smile': 'smile', 'laugh': 'laugh', 'surprised': 'surprised', 'calm': 'closed'}
H_RE = re.compile(r'\s*\[(H\d+)\]')
CH_RE = re.compile(r'^###\s*(프롤로그|(\d)장)\s*—\s*(.+?)\s*$')


def face_for(text, chapter_no):
    t = text.strip()
    if t.startswith('어이쿠'):
        return FACE_MAP['surprised']
    if t.startswith(('와!', '호호!', '와,')) or t.endswith(('헤헤.', '호호.', '호호!')):
        return FACE_MAP['laugh']
    if chapter_no in (4, 5) and t.startswith('…'):
        return FACE_MAP['calm']
    return FACE_MAP['smile']


def parse(md):
    sections, cur, ch = {}, None, None
    for raw in md.splitlines():
        line = raw.strip()
        if line.startswith('## '):
            cur = next((c for c in COMPANIONS if c[1] in line), None)
            ch = None
            if cur:
                sections[cur[0]] = []
            continue
        if line == '---':
            cur, ch = None, None
            continue
        if not cur:
            continue
        m = CH_RE.match(line)
        if m:
            no = 0 if m.group(1) == '프롤로그' else int(m.group(2))
            title = m.group(3).replace('[그림]', '').strip()
            ch = {'no': no, 'title': title, 'hasArt': '[그림]' in line, 'raw': []}
            sections[cur[0]].append(ch)
            continue
        if ch is not None and line:
            ch['raw'].append(line)
    return sections


def build_lines(c, ch):
    cid, _, name = c[0], c[1], c[2]
    lines, extra = [], {}
    for line in ch['raw']:
        if line.startswith('- '):
            line = line[2:].strip()
        for old in OLD_NAMES.get(cid, []):
            line = line.replace(old, name)
        if line.startswith('[함께 걷기'):
            extra['choice'] = ['together', 'solo']
            continue
        if line.startswith('[완결 소품'):
            extra['prop'] = c[6]
            continue
        narr = None
        m = re.match(r'^\(([^)]*)\)\s*(.*)$', line)
        if m:  # 지문, 또는 '(지문) 이름: 대사'
            narr, line = m.group(1), m.group(2)
            lines.append({'who': 'narr', 'text': narr})
            if not line:
                continue
        src = H_RE.findall(line)
        text = H_RE.sub('', line).strip()
        if text.startswith('나:'):
            lines.append({'who': 'me', 'text': text[2:].strip()})
        elif text.startswith(name + ':'):
            body = text[len(name) + 1:].strip()
            item = {'who': 'companion', 'face': face_for(body, ch['no']), 'text': body}
            if src:
                item['source'] = src[0]
            lines.append(item)
        else:
            raise ValueError(f'{cid} {ch["no"]}장: 읽지 못한 줄 → {line}')
    return lines, extra


def main(src, out):
    md = open(src, encoding='utf-8').read()
    secs = parse(md)
    result, warns = [], []
    for c in COMPANIONS:
        chs = secs.get(c[0], [])
        assert [x['no'] for x in chs] == list(range(9)), f'{c[0]}: 장 번호 {[x["no"] for x in chs]}'
        chapters = []
        for ch in chs:
            lines, extra = build_lines(c, ch)
            n = sum(1 for l in lines if l['who'] != 'narr')
            if not 4 <= n <= 10:
                warns.append(f'{c[0]} {ch["no"]}장 대사 {n}줄')
            item = {'no': ch['no'], 'title': ch['title'],
                    'art': f'{c[8]}_{"prologue" if ch["no"] == 0 else "finale"}' if ch['hasArt'] else None,
                    'lines': lines}
            item.update(extra)
            chapters.append(item)
        arts = [x['no'] for x in chapters if x['art']]
        assert arts == [0, 8], f'{c[0]}: 그림 장 {arts}'
        assert chapters[0].get('choice') and chapters[8].get('prop') == c[6], c[0]
        result.append({'id': c[0], 'name': c[2], 'species': c[3], 'terrain': c[4], 'pace': c[5],
                       'finaleProp': c[6], 'hideLayerOnFinale': c[7],
                       'faces': sorted(set(FACE_MAP.values())), 'chapters': chapters})
    assert len(result) == 3 and sum(len([x for x in r['chapters'] if x['art']]) for r in result) == 6
    with open(out, 'w', encoding='utf-8') as f:
        json.dump({'version': 2, 'storyLayersFile': 'story_layers.json', 'companions': result}, f, ensure_ascii=False, indent=1)
        f.write('\n')
    for w in warns:
        print('경고:', w)
    print(f'완료 → {out}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
