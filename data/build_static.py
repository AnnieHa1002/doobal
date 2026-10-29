#!/usr/bin/env python3
"""두발 정적 데이터 빌드: data/명소_한국101.csv → app/assets/data/*.json

    python data/build_static.py

- landmarks.json, props.json, milestones.json 은 매번 새로 만든다.
- events.json 은 파일이 없을 때만 만든다(문구 96개를 손으로 채우므로 덮어쓰지 않음).
  장면 구성을 바꿔 다시 만들려면 --events 를 붙인다(기존 문구는 같은 id면 유지).
- config.json 은 손으로 고치는 파일이라 이 스크립트가 건드리지 않는다.
"""
import collections
import csv
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '명소_한국101.csv')
OUT = os.path.normpath(os.path.join(HERE, '..', 'app', 'assets', 'data'))

T = {'산길': 'mountain', '바닷가': 'coast', '들판': 'field', '도시': 'city'}
REGION = {'서울특별시': 'capital', '인천광역시': 'capital', '경기도': 'capital', '강원특별자치도': 'gangwon',
          '대전광역시': 'chungcheong', '세종특별자치시': 'chungcheong', '충청북도': 'chungcheong', '충청남도': 'chungcheong',
          '광주광역시': 'jeolla', '전북특별자치도': 'jeolla', '전라남도': 'jeolla',
          '부산광역시': 'gyeongsang', '대구광역시': 'gyeongsang', '울산광역시': 'gyeongsang', '경상북도': 'gyeongsang', '경상남도': 'gyeongsang',
          '제주특별자치도': 'jeju'}
TYPE = {'역사': 'history', '자연': 'nature', '도시': 'city'}


def dump(name, obj, ascii_ok=False):
    with open(os.path.join(OUT, name), 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=ascii_ok, indent=1)
        f.write('\n')


def build_landmarks():
    with open(SRC, encoding='utf-8-sig') as f:
        rows = list(csv.DictReader(f))
    lms = []
    for r in rows:
        region = 'ulleung' if r['시군구'] == '울릉군' else REGION[r['시도']]
        island = region if region in ('jeju', 'ulleung') else 'mainland'
        backdrop = 'sea' if region == 'ulleung' else region
        no = int(r['id'][2:])
        lms.append({'id': r['id'], 'name': r['명소'], 'sido': r['시도'], 'sigungu': r['시군구'], 'region': region,
                    'backdrop': backdrop, 'terrain': T[r['지형']], 'types': [TYPE[t] for t in r['유형'].split('·')],
                    'lat': float(r['위도']), 'lng': float(r['경도']), 'island': island, 'painting': f'landmark_{no:03d}'})
    cnt = collections.Counter(l['region'] for l in lms)
    assert dict(cnt) == {'capital': 12, 'gangwon': 17, 'chungcheong': 17, 'jeolla': 21,
                         'gyeongsang': 31, 'jeju': 2, 'ulleung': 1}, cnt
    dump('landmarks.json', {'version': 1, 'landmarks': lms})
    return lms


def p(id, slot, name, kind, **k):
    return {'id': id, 'slot': slot, 'name': name, 'unlock': {'kind': kind, **k}}


def build_props():
    props = [
        p('hat_01', 'hat', '베레모', 'default'), p('hat_02', 'hat', '깃털 꽂은 여행 모자', 'distance', km=25),
        p('hat_03', 'hat', '금빛 베레모', 'distance', km=1000), p('hat_04', 'hat', '대나무 삿갓', 'region', region='jeolla'),
        p('hat_05', 'hat', '신라 금관', 'region', region='gyeongsang'),
        p('hat_06', 'hat', '화관', 'event', terrain='field', season='spring'),
        p('hat_07', 'hat', '밀짚모자', 'event', terrain='field', season='summer'),
        p('hat_08', 'hat', '단풍잎 모자', 'event', terrain='mountain', season='autumn'),
        p('hat_09', 'hat', '털모자', 'event', terrain='mountain', season='winter'),
        # 동료 소품: companion id는 companions.json이 생기면 채운다
        # (폐이 달 핀, 휴 꾹꾹이 장갑, 심 박사 동그란 안경)
        p('hat_10', 'hat', '달 핀', 'companion', companion=None),
        p('hat_11', 'hat', '동그란 안경', 'companion', companion=None),
        p('hand_01', 'hand', '붓', 'default'), p('hand_02', 'hand', '지팡이', 'distance', km=10),
        p('hand_03', 'hand', '나침반', 'distance', km=150), p('hand_04', 'hand', '큰 팔레트', 'distance', km=200),
        p('hand_05', 'hand', '연잎 우산', 'region', region='chungcheong'),
        p('hand_06', 'hand', '낚싯대', 'event', terrain='coast', dayNight='day'),
        p('hand_07', 'hand', '바람개비', 'event', terrain='coast'),
        p('hand_08', 'hand', '랜턴', 'event', terrain='city', dayNight='night'),
        p('hand_09', 'hand', '꾹꾹이 장갑', 'companion', companion=None),
        p('pet_01', 'pet', '종이새', 'default'), p('pet_02', 'pet', '해치', 'region', region='capital'),
        p('pet_03', 'pet', '아기 양', 'region', region='gangwon'), p('pet_04', 'pet', '돌하르방', 'region', region='jeju'),
        p('pet_05', 'pet', '괭이갈매기', 'region', region='ulleung'),
        p('pet_06', 'pet', '다람쥐', 'event', terrain='mountain', dayNight='day'),
        p('pet_07', 'pet', '길고양이', 'event', terrain='city', dayNight='day'),
        p('pet_08', 'pet', '반딧불이', 'event', terrain='field', season='summer', dayNight='night'),
        p('bag_01', 'bag', '화구 가방', 'default'), p('bag_02', 'bag', '이젤 배낭', 'distance', km=50),
        p('bag_03', 'bag', '두루마리 통', 'distance', km=500),
        p('bag_04', 'bag', '꽃 바구니', 'event', terrain='city', season='spring'),
        p('shoe_01', 'shoe', '갈색 신발', 'default'), p('shoe_02', 'shoe', '등산화', 'distance', km=100),
        p('shoe_03', 'shoe', '장화', 'event', terrain='coast'),
        p('cloth_01', 'cloth', '앞치마 작업복', 'default'), p('cloth_02', 'cloth', '여행 조끼', 'distance', km=300),
        p('cloth_03', 'cloth', '별밤 망토', 'distance', km=700), p('cloth_04', 'cloth', '금빛 화가 코트', 'steps', steps=1000000),
    ]
    for x in props:
        x['status'] = 'pending' if (x['name'] is None or x['unlock']['kind'] == 'event') else 'mvp'
    c = collections.Counter(x['slot'] for x in props)
    k = collections.Counter(x['unlock']['kind'] for x in props)
    assert len(props) == 39 and dict(c) == {'hat': 11, 'hand': 9, 'pet': 8, 'bag': 4, 'shoe': 3, 'cloth': 4}, c
    assert dict(k) == {'default': 6, 'distance': 10, 'region': 7, 'event': 12, 'companion': 3, 'steps': 1}, k
    assert sum(x['status'] == 'mvp' for x in props) == 27
    dump('props.json', {'version': 1, 'props': props})
    return props


def build_events(force):
    path = os.path.join(OUT, 'events.json')
    old = {}
    if os.path.exists(path):
        if not force:
            print('events.json 있음: 건너뜀 (--events 로 다시 만들기)')
            return
        with open(path, encoding='utf-8') as f:
            old = {s['id']: s['texts'] for s in json.load(f)['scenes']}
    scenes = []
    for t in T.values():
        for s in ['spring', 'summer', 'autumn', 'winter']:
            for d in ['day', 'night']:
                sid = f'{t}_{s}_{d}'
                scenes.append({'id': sid, 'terrain': t, 'season': s, 'dayNight': d,
                               'texts': old.get(sid, ['', '', '']), 'art': f'event_{sid}'})
    assert len(scenes) == 32
    dump('events.json', {'version': 1, 'propChance': 0.0, 'propChanceAfterLaunch': 0.1, 'scenes': scenes})


def build_milestones():
    ms = [100, 1000, 5000, 7777, 10000, 12345, 30000, 50000, 77777, 100000, 123456, 200000, 300000, 333333,
          400000, 500000, 600000, 700000, 777777, 800000, 900000, 1000000, 1234567]
    assert len(ms) == 23 and ms == sorted(ms)
    dump('milestones.json', {'version': 1, 'stepMilestones': ms}, ascii_ok=True)


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    build_landmarks()
    build_props()
    build_events('--events' in sys.argv)
    build_milestones()
    print(f'완료 → {OUT}')
