#!/usr/bin/env python3
"""길 위 이벤트 문구(기획/이벤트_문구.md) → events.json v3

    python3 data/build_events.py 이벤트_문구.md app/assets/data/events.json

- 풍경 96(32장면 × 3), 기록 칭찬 17(조건 9 + 기본 8)을 읽는다.
- 10/30: 다음 2km 제안(S1~S6)은 삭제(배지로 대체, 기준 문서 4장). 문구 파일에 S줄이 남아 있어도 건너뛴다.
- 한국어 변수 {목적지} 등을 영어 키 {dest} 등으로 바꾼다.
- 칭찬 조건(cond·value)은 문구 파일의 '조건' 열을 사람이 읽고 아래 표로 옮긴 시작값이다.
  문구 파일의 조건을 바꾸면 이 표도 함께 고친다.
- 개수·id·변수가 맞지 않으면 실패한다.
- 원본 문구 파일은 Claude 프로젝트 문서 기획/이벤트_문구.md 에 있다(리포에는 없음).
"""
import json
import re
import sys

VARS = {
    '목적지': 'dest', '남은거리': 'remainingKm', '진행률': 'progressPct', '당겨진일수': 'etaGainDays',
    '차이': 'todayOverAvgKm', '뛴거리': 'runKm', '오늘걸음': 'todaySteps', '이번거리': 'sessionKm',
    '누적거리': 'totalKm',
}

# 칭찬 조건: 문구 파일 R01~R09의 '조건' 열
PRAISE_COND = {
    'R01': ('remainingKmLte', 10),
    'R02': ('progressPctCross', [25, 50, 75]),
    'R03': ('etaGainDaysGte', 1),
    'R04': ('todayOverAvg', None),
    'R05': ('runKmGte', 0.5),
    'R06': ('todayStepsGte', 7000),
    'R07': ('sessionKmGte', 4),
    'R08': ('isNight', None),
    'R09': ('totalKmGte', 10),
}

TERRAIN = {'MTN': 'mountain', 'COA': 'coast', 'FLD': 'field', 'CTY': 'city'}
SEASON = {'SPR': 'spring', 'SUM': 'summer', 'AUT': 'autumn', 'WIN': 'winter'}
DAYNIGHT = {'DAY': 'day', 'NIG': 'night'}


def conv(text):
    def rep(m):
        k = m.group(1)
        if k not in VARS:
            raise SystemExit(f'모르는 변수 {{{k}}}: {text}')
        return '{' + VARS[k] + '}'
    return re.sub(r'\{([^}]+)\}', rep, text.strip())


def rows(md):
    """표의 데이터 줄을 칸 목록으로 (머리줄·구분줄 제외)"""
    out = []
    for line in md.splitlines():
        line = line.strip()
        if not line.startswith('|') or set(line) <= set('|-: '):
            continue
        cells = [c.strip() for c in line.strip('|').split('|')]
        if cells[0] in ('ID',):
            continue
        out.append(cells)
    return out


def main(src, dst):
    md = open(src, encoding='utf-8').read()
    texts, cond, deflt, skipped = {}, [], [], 0
    for c in rows(md):
        rid = c[0]
        if re.fullmatch(r'(MTN|COA|FLD|CTY)_(SPR|SUM|AUT|WIN)_(DAY|NIG)_[ABC]', rid):
            texts[rid] = conv(c[1])
        elif re.fullmatch(r'R0[1-9]', rid):
            kind, value = PRAISE_COND[rid]
            item = {'id': rid, 'priority': int(c[1]), 'cond': kind, 'text': conv(c[3])}
            if value is not None:
                item['value'] = value
            cond.append(item)
        elif re.fullmatch(r'R1[0-7]', rid):
            deflt.append({'id': rid, 'text': conv(c[1])})
        elif re.fullmatch(r'S[1-6]', rid):
            skipped += 1  # 10/30 제안 삭제
        else:
            raise SystemExit(f'모르는 id: {rid}')

    scenes = []
    for tk, t in TERRAIN.items():
        for sk, s in SEASON.items():
            for dk, d in DAYNIGHT.items():
                ids = [f'{tk}_{sk}_{dk}_{r}' for r in 'ABC']
                missing = [i for i in ids if i not in texts]
                if missing:
                    raise SystemExit(f'빠진 문구: {missing}')
                sid = f'{t}_{s}_{d}'
                scenes.append({'id': sid, 'terrain': t, 'season': s, 'dayNight': d,
                               'texts': [{'id': i, 'text': texts[i]} for i in ids],
                               'art': f'event_{sid}'})

    cond.sort(key=lambda x: x['priority'])
    assert len(texts) == 96, len(texts)
    assert len(scenes) == 32
    assert [x['priority'] for x in cond] == list(range(1, 10))
    assert len(deflt) == 8

    out = {
        'version': 3,
        'source': '기획/이벤트_문구.md v01 (2026-10-29), 10/30 다음 2km 제안 삭제',
        'propChance': 0.0,
        'propChanceAfterLaunch': 0.1,
        'vars': sorted(VARS.values()),
        'scenes': scenes,
        'praise': {'conditional': cond, 'default': deflt},
    }
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'events.json: 장면 {len(scenes)}, 풍경 {len(texts)}, 칭찬 {len(cond)}+{len(deflt)}'
          + (f' (제안 {skipped}줄 건너뜀)' if skipped else ''))


if __name__ == '__main__':
    main(*(sys.argv[1:3] if len(sys.argv) >= 3 else ('이벤트_문구.md', 'events.json')))
