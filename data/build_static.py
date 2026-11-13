#!/usr/bin/env python3
"""두발 정적 데이터 빌드: data/명소_한국101.csv → app/assets/data/*.json

    python data/build_static.py

- landmarks.json, props.json, milestones.json 은 매번 새로 만든다.
- 시도 이름은 2026-07-01 행정구역(광주·전남 → 전남광주통합특별시, 인천 중구 → 제물포구).
  옛 이름이 CSV에 남아 있으면 멈춘다. 권역(region)은 그대로.
- landmarks.json v3(11/3): firstPainting(첫 방문 그림 파일 이름, 디자인기획/명소_첫그림_101_v01.md)·note(설명 줄).
- props.json v5(11/6): 화면 이름 짧게(11/4 Annie, 기획/소품_목록.md v04.3 — 두 낱말 이내, id·파일 이름은 그대로),
  사용자 색 고르기(tint) 폐기 → 색 소품(11/4 밤 Annie): 색 바꿀 수 있는 기본 소품 7종에 material(Codex materials_v07 catalogId·기본 색),
  색마다 따로 된 상점 소품은 COLOR_VARIANTS 표(디자인 기획이 색을 고르면 채움, id = <기본 id>_c<n>, 이름 = '<색 이름> <기본 이름>', 100 럭).
- props.json v6(11/6): 손 소품 fit(장갑 wristOverlay·날개 팔 replaceArms, 컷아웃 공정).
- props.json v7(11/10): 기본 옷을 여행복 cloth_02로, 앞치마 cloth_01을 300km 보상으로 맞바꿈(16장 11/8 Annie, 기획/소품_목록.md v04.4),
  cloth_02 startColors 4(정령 만들기에서 한 번 고르는 색): 카키·크림·살구·라벤더(16장 11/10, 흙은 카키와 구분이 어려워 뺌).
  v8(11/13 개발 기획): icon = 칸 그림 파일 이름(Drive Assets/05_UI_화면/item_icons_v01_채택_20261113, Rive v32에서 뽑은 256px PNG, 16장 11/13).
  같은 v7 안 고침(11/10 개발 기획): cloth_02 material.hex #B5A576 → #C0A475(startColors 첫 색 = 둥둥 정령 v06 기본색). 시작 색은 palette가 아니라 props에 둔다.
- props.json v4(11/4): 둥실 나침반·큰 팔레트(hand_03·hand_04) → 몽실 구름 float_02(150km)·꼬마 열기구 float_03(200km),
  베레모 hat_01 tint(색 바꾸기, 견본은 palette.json body), cloth_02 이름 '여행복'(화면 글 원칙: '일체형' 같은 설명 없음).
  props.json v3(11/3): 정령 슬롯 9개(hat·face·cloth·shoe·hand·bag·pet·float·effect), 기획/소품_목록.md v04.1.
  MVP 37 + 효과 5. 상점 전용은 unlock.kind shop{price}(값은 shop.json과 같아야 함).
- events.json 은 만들지 않는다: data/build_events.py 가 기획/이벤트_문구.md 에서 만든다(v3).
- config.json·shop.json·boats.json 은 손으로 고치는 파일이라 이 스크립트가 건드리지 않는다.
"""
import collections
import csv
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '명소_한국101.csv')
OUT = os.path.normpath(os.path.join(HERE, '..', 'app', 'assets', 'data'))

T = {'산길': 'mountain', '바닷가': 'coast', '들판': 'field', '도시': 'city'}
REGION = {'서울특별시': 'capital', '인천광역시': 'capital', '경기도': 'capital', '강원특별자치도': 'gangwon',
          '대전광역시': 'chungcheong', '세종특별자치시': 'chungcheong', '충청북도': 'chungcheong', '충청남도': 'chungcheong',
          '전남광주통합특별시': 'jeolla', '전북특별자치도': 'jeolla',
          '부산광역시': 'gyeongsang', '대구광역시': 'gyeongsang', '울산광역시': 'gyeongsang', '경상북도': 'gyeongsang', '경상남도': 'gyeongsang',
          '제주특별자치도': 'jeju'}
TYPE = {'역사': 'history', '자연': 'nature', '도시': 'city'}

# 첫 방문 그림 B안(나머지는 A). 11/3 채택: 001~060·066·073·091은 디자인/landmark_review_63_v01.md(10/31 확정),
# 나머지 38곳은 디자인기획/명소_첫그림_101_v01.md.
FIRST_B = {3, 4, 5, 7, 8, 11, 12, 13, 15, 17, 20, 33, 38, 48, 70, 78, 79, 81}
NOTES = {88: '산불 이전 모습'}

SLOTS = ['hat', 'face', 'cloth', 'shoe', 'hand', 'bag', 'pet', 'float', 'effect']

# 색을 바꿀 수 있는 소품(11/4): 회색조 파츠에 견본색을 입힘. swatches = palette.json의 어느 견본 묶음을 쓰는지.
# 색을 바꿀 수 있게 그린 기본 소품 7종(Codex 기본 소품 v07 materials_v07.json, 11/4).
# 그림 = 회색조 층 × 색 ÷ 180 + 고정 무늬 층. 사용자가 고르지 않고, 색마다 따로 된 소품(COLOR_VARIANTS)으로 판다(11/4 밤).
MATERIAL = {
    'hat_01': ('beret', '#A4502F'),  # 기준 문서 7장 기본 테라코타(Codex v07 미리보기 #D78A51 대신, 11/6)
    'hat_02': ('feather_hat', '#B2815D'),
    'hat_04': ('bamboo_hat', '#E4AE5D'),
    'hat_05': ('silla_crown', '#D6A24C'),
    'cloth_01': ('work_apron', '#B79B78'),
    'cloth_02': ('travel_vest', '#C0A475'),  # 16장 11/10: 카키는 Codex 납품 #C0A475 하나로 (v07 미리보기 #B5A576 대신)
    'shoe_01': ('brown_shoes', '#B18B67'),
}
# 소품별로 따로 납품된 회색조(11/4 Codex 베레모 회색조 v07): 기준 밝기 192, 갈색 선은 가중치 혼합으로 지킴(식은 layout_v07.json)
MATERIAL_SOURCE = {'hat_01': {'neutralReference': 192, 'source': 'beret_grayscale_v07 (Assets/베레모_회색조_배9척_검증_v02_20261104 zip)',
                              'blend': 'weighted', 'layout': 'beret_grayscale_v07/layout_v07.json'}}
# 색 소품: {기본 id: [(색 이름, hex), ...]} — 가안 7종 × 3색, 각 100 럭(기준 문서 11장). 색은 디자인 기획이 고른다.
# 비어 있으면 색 소품을 만들지 않는다(앱은 상점·꾸미기에 안 보임).
SW = {'크림': '#F3E4C4', '살구': '#F5C9A3', '분홍': '#EFC0BE', '라벤더': '#D3C6E6', '하늘': '#BCD9E8',
      '연두': '#CDE0AC', '이끼': '#9FAE7E', '흙': '#C4A07C', '테라코타': '#C9775A', '남청': '#7F8DB3'}  # palette body 견본
# 기준 문서 11장(11/6 Annie): 색 = 몸 색 견본, 이름 = 색을 떠올리게 하는 말 + 소품(세 낱말까지). (색, 이름 앞말)
COLOR_VARIANTS = {k: [(c, SW[c], w) for c, w in v] for k, v in {
    'hat_01': [('하늘', '봄하늘'), ('남청', '밤바다'), ('이끼', '이끼숲')],
    'hat_02': [('남청', '새벽'), ('이끼', '풀밭'), ('테라코타', '노을')],
    'hat_04': [('흙', '흙길'), ('이끼', '대숲'), ('남청', '밤비')],
    'hat_05': [('분홍', '벚꽃'), ('하늘', '서리'), ('라벤더', '라일락')],
    'cloth_01': [('하늘', '물빛'), ('분홍', '복숭아'), ('연두', '새싹')],
    'cloth_02': [('남청', '별밤'), ('테라코타', '벽돌길'), ('이끼', '숲길')],
    'shoe_01': [('테라코타', '단풍'), ('남청', '밤길'), ('이끼', '들풀')]}.items()}
# 이름 뒷말(기준 문서 11장 그대로): 갈색 신발은 '신발', 나머지는 기본 이름
VARIANT_STEM = {'shoe_01': '신발'}
COLOR_VARIANT_PRICE = 100
# 기본 옷 시작 색(16장 11/8·11/10 Annie): 정령 만들기에서 한 번 고름, 첫 색이 기본.
# 카키는 여행복 기본색(material.hex)과 같은 값, 나머지는 몸 색 견본 값. 흙은 카키와 구분이 어려워 라벤더로 바꿈(11/10)
START_COLORS = {'cloth_02': [('카키', MATERIAL['cloth_02'][1]), ('크림', SW['크림']), ('살구', SW['살구']), ('라벤더', SW['라벤더'])]}


def dump(name, obj, ascii_ok=False):
    with open(os.path.join(OUT, name), 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=ascii_ok, indent=1)
        f.write('\n')


def build_landmarks():
    with open(SRC, encoding='utf-8-sig') as f:
        rows = list(csv.DictReader(f))
    unknown = sorted({r['시도'] for r in rows} - set(REGION))
    assert not unknown, f'모르는 시도 이름(2026-07-01 행정구역인지 확인): {unknown}'
    lms = []
    for r in rows:
        region = 'ulleung' if r['시군구'] == '울릉군' else REGION[r['시도']]
        island = region if region in ('jeju', 'ulleung') else 'mainland'
        backdrop = 'sea' if region == 'ulleung' else region
        no = int(r['id'][2:])
        lm = {'id': r['id'], 'name': r['명소'], 'sido': r['시도'], 'sigungu': r['시군구'], 'region': region,
              'backdrop': backdrop, 'terrain': T[r['지형']], 'types': [TYPE[t] for t in r['유형'].split('·')],
              'lat': float(r['위도']), 'lng': float(r['경도']), 'island': island, 'painting': f'landmark_{no:03d}',
              'firstPainting': f"landmark_{no:03d}_v1_{'b' if no in FIRST_B else 'a'}"}
        if no in NOTES:
            lm['note'] = NOTES[no]
        lms.append(lm)
    cnt = collections.Counter(l['region'] for l in lms)
    assert dict(cnt) == {'capital': 12, 'gangwon': 17, 'chungcheong': 17, 'jeolla': 21,
                         'gyeongsang': 31, 'jeju': 2, 'ulleung': 1}, cnt
    assert len(lms) == 101 and sum(l['firstPainting'].endswith('_b') for l in lms) == len(FIRST_B)
    dump('landmarks.json', {'version': 3, 'asOf': '2026-07-01', 'landmarks': lms})
    return lms


# 손 슬롯 붙는 법 (16장 11/6 컷아웃): 날개 팔은 팔 조각을 바꾸고, 장갑은 손목 기준점에 덧층
HAND_FIT = {'hand_09': 'wristOverlay', 'hand_11': 'wristOverlay', 'hand_13': 'wristOverlay',
            'hand_10': 'replaceArms', 'hand_12': 'replaceArms'}


def p(id, slot, name, kind, status='mvp', **k):
    o = {'id': id, 'slot': slot, 'name': name, 'unlock': {'kind': kind, **k}, 'status': status}
    if id in HAND_FIT:
        o['fit'] = HAND_FIT[id]
    if id in MATERIAL:
        o['material'] = {'catalogId': MATERIAL[id][0], 'hex': MATERIAL[id][1]}
        if id in MATERIAL_SOURCE:
            o['material'].update(MATERIAL_SOURCE[id])
    return o


# 칸 그림(16장 11/13 Annie: Rive v32에서 뽑은 소품 아이콘, README 표 그대로). 효과 5는 codex_effects_v01 납품 뒤
ICONS = {
    'hat_01': 'beret', 'hat_02': 'feather_hat', 'hat_04': 'bamboo_hat', 'hat_05': 'silla_crown',
    'hat_11': 'round_glasses', 'face_01': 'headphones', 'face_02': 'earmuffs',
    'cloth_01': 'work_apron', 'cloth_02': 'travel_vest_khaki', 'cloth_03': 'starry_cape', 'cloth_04': 'gold_artist_coat', 'cloth_05': 'travel_cape',
    'shoe_01': 'brown_shoes', 'shoe_02': 'hiking_boots', 'shoe_04': 'green_boots', 'shoe_05': 'cat_slippers', 'shoe_06': 'straw_sandals',
    'hand_09': 'cat_paw_mittens', 'hand_10': 'gold_wing_arms', 'hand_11': 'wool_mittens', 'hand_12': 'bird_wings', 'hand_13': 'leaf_gloves',
    'hand_01': 'brush_bag', 'bag_01': 'art_satchel', 'hand_02': 'walking_stick_pack', 'bag_02': 'easel_backpack', 'bag_03': 'scroll_case',
    'pet_01': 'paper_bird', 'pet_02': 'haechi_friend', 'pet_03': 'lamb_friend', 'pet_04': 'dolhareubang_friend', 'pet_05': 'gull_friend',
    'hand_05': 'lotus_leaf_float', 'float_02': 'float_cloud', 'float_03': 'float_balloon', 'hat_10': 'small_moon_float', 'float_01': 'star_lantern',
}
VARIANT_ICON_WORDS = {
    'hat_01': ['spring_sky', 'night_sea', 'moss_forest'], 'hat_02': ['dawn', 'meadow', 'sunset'],
    'hat_04': ['dirt_road', 'bamboo', 'night_rain'], 'hat_05': ['cherry', 'frost', 'lilac'],
    'cloth_01': ['water', 'peach', 'sprout'], 'cloth_02': ['starry_night', 'brick_road', 'forest_path'],
    'shoe_01': ['autumn', 'night_road', 'wild_grass'],
}

# Rive 정령(16장 11/11·11/13, 계약 v0.4): 소품 = 뷰 모델 WardrobeColors의 <slot>Choice 번호 + 색 속성.
# 번호는 소품 아이콘 README 순서(v32에서 Choice를 1부터 차례로 입혀 뽑음, clothChoice 4 = 여행복이 인계 문서와 맞음).
# 색 속성 이름은 영어 이름의 camelCase + Color(인계 문서 예 beretColor·travelVestColor). 11/13 v33 inputs.md·runtime_inputs.json과 대조 끝(riveVerified true)
RIVE_ORDER = {
    'hat': ['hat_01', 'hat_02', 'hat_04', 'hat_05'],
    'face': ['hat_11', 'face_01', 'face_02'],
    'cloth': ['cloth_05', 'cloth_03', 'cloth_01', 'cloth_02', 'cloth_04'],
    'shoe': ['shoe_04', 'shoe_05', 'shoe_06', 'shoe_01', 'shoe_02'],
    'hand': ['hand_11', 'hand_12', 'hand_13', 'hand_09', 'hand_10'],
    'bag': ['hand_01', 'bag_01', 'bag_02', 'bag_03', 'hand_02'],
    'pet': ['pet_01', 'pet_02', 'pet_03', 'pet_04', 'pet_05'],
    'float': ['float_01', 'hand_05', 'hat_10', 'float_02', 'float_03'],
}
def _camel(stem):
    a = stem.split('_')
    return a[0] + ''.join(w[:1].upper() + w[1:] for w in a[1:])

def build_props():
    props = [
        # 모자 4 (베레모는 색 바꾸기, 11/4)
        p('hat_01', 'hat', '베레모', 'default'),
        p('hat_02', 'hat', '깃털 꽂은 여행 모자', 'distance', km=25),
        p('hat_04', 'hat', '대나무 삿갓', 'region', region='jeolla'),
        p('hat_05', 'hat', '신라 금관', 'region', region='gyeongsang'),
        # 얼굴 소품 3 (모자와 같이 씀)
        p('hat_11', 'face', '동그란 안경', 'companion', companion='doctor'),
        p('face_01', 'face', '헤드폰', 'shop', price=300),
        p('face_02', 'face', '털 귀마개', 'shop', price=300),
        # 옷 5
        p('cloth_01', 'cloth', '앞치마 작업복', 'distance', km=300),
        p('cloth_02', 'cloth', '여행복', 'default'),
        p('cloth_03', 'cloth', '별밤 망토', 'distance', km=700),
        p('cloth_04', 'cloth', '금빛 화가 코트', 'steps', steps=1000000),
        p('cloth_05', 'cloth', '연두 여행 망토', 'shop', price=600),
        # 신발 5
        p('shoe_01', 'shoe', '갈색 신발', 'default'),
        p('shoe_02', 'shoe', '등산화', 'distance', km=100),
        p('shoe_04', 'shoe', '초록 장화', 'shop', price=300),
        p('shoe_05', 'shoe', '고양이 얼굴 슬리퍼', 'shop', price=300),
        p('shoe_06', 'shoe', '짚신', 'shop', price=300),
        # 손 5 (장갑·팔 바꾸기만, 기본은 맨손)
        p('hand_09', 'hand', '꾹꾹이 장갑', 'companion', companion='rest'),
        p('hand_10', 'hand', '금빛 날개 팔', 'distance', km=1000),
        p('hand_11', 'hand', '털실 벙어리장갑', 'shop', price=400),
        p('hand_12', 'hand', '작은 새 날개 팔', 'shop', price=400),
        p('hand_13', 'hand', '잎사귀 장갑', 'shop', price=400),
        # 가방 5 (큰 붓은 등에 메는 기본 가방)
        p('hand_01', 'bag', '큰 붓', 'default'),
        p('bag_01', 'bag', '화구 가방', 'default'),
        p('hand_02', 'bag', '봇짐 지팡이', 'distance', km=10),
        p('bag_02', 'bag', '이젤 배낭', 'distance', km=50),
        p('bag_03', 'bag', '두루마리 통', 'distance', km=500),
        # 미니 친구 5
        p('pet_01', 'pet', '종이새', 'default'),
        p('pet_02', 'pet', '해치', 'region', region='capital'),
        p('pet_03', 'pet', '아기 양', 'region', region='gangwon'),
        p('pet_04', 'pet', '돌하르방', 'region', region='jeju'),
        p('pet_05', 'pet', '괭이갈매기', 'region', region='ulleung'),
        # 둥실 5 (머리 위·옆에 떠다님). 11/4: 나침반 hand_03·큰 팔레트 hand_04 → 몽실 구름·꼬마 열기구
        p('hand_05', 'float', '연잎', 'region', region='chungcheong'),
        p('float_02', 'float', '몽실 구름', 'distance', km=150),
        p('float_03', 'float', '꼬마 열기구', 'distance', km=200),
        p('hat_10', 'float', '작은 달', 'companion', companion='bright'),
        p('float_01', 'float', '별 랜턴', 'shop', price=500),
        # 효과 5 (앱 입자 효과, 상점에서만)
        p('effect_01', 'effect', '떨어지는 나뭇잎', 'shop', price=200),
        p('effect_02', 'effect', '빗방울 + 발밑 물웅덩이', 'shop', price=200),
        p('effect_03', 'effect', '별 반짝이', 'shop', price=200),
        p('effect_04', 'effect', '물감 방울', 'shop', price=200),
        p('effect_05', 'effect', '반딧불 빛', 'shop', price=200),
        # 출시 후(pending): 길 위 이벤트 12개 — 정령 슬롯은 추가할 때 다시 정함
        p('hat_06', 'hat', '화관', 'event', 'pending', terrain='field', season='spring'),
        p('hat_07', 'hat', '밀짚모자', 'event', 'pending', terrain='field', season='summer'),
        p('hat_08', 'hat', '단풍잎 모자', 'event', 'pending', terrain='mountain', season='autumn'),
        p('hat_09', 'hat', '털모자', 'event', 'pending', terrain='mountain', season='winter'),
        p('bag_04', 'bag', '꽃 바구니', 'event', 'pending', terrain='city', season='spring'),
        p('hand_06', 'bag', '등에 멘 낚싯대', 'event', 'pending', terrain='coast', dayNight='day'),
        p('hand_07', 'float', '바람개비', 'event', 'pending', terrain='coast'),
        p('hand_08', None, '랜턴', 'event', 'pending', terrain='city', dayNight='night'),
        p('shoe_03', None, '장화', 'event', 'pending', terrain='coast'),
        p('pet_06', 'pet', '다람쥐', 'event', 'pending', terrain='mountain', dayNight='day'),
        p('pet_07', 'pet', '길고양이', 'event', 'pending', terrain='city', dayNight='day'),
        p('pet_08', 'pet', '반딧불이', 'event', 'pending', terrain='field', season='summer', dayNight='night'),
        # 출시 후: 1,000km 자리를 금빛 날개 팔에 넘김
        p('hat_03', 'hat', '금빛 베레모', 'none', 'later'),
    ]
    # 화면 이름 짧게(11/4 Annie, 기획/소품_목록.md v04.3·럭_상점.md v2.3)
    SHORT = {'hat_02': '여행 모자', 'hat_04': '삿갓', 'hat_05': '금관', 'hat_11': '안경', 'face_02': '귀마개',
             'cloth_01': '앞치마', 'cloth_04': '금빛 코트', 'cloth_05': '연두 망토', 'shoe_04': '장화',
             'shoe_05': '고양이 슬리퍼', 'hand_10': '금빛 날개', 'hand_11': '벙어리장갑', 'hand_12': '새 날개',
             'hand_13': '잎 장갑', 'hand_02': '봇짐', 'pet_05': '갈매기', 'float_02': '구름', 'float_03': '열기구',
             'hat_10': '달', 'effect_01': '나뭇잎', 'effect_02': '빗방울', 'effect_03': '반짝이', 'effect_04': '물감',
             'effect_05': '반딧불'}
    for x in props:
        x['name'] = SHORT.get(x['id'], x['name'])
    # 색 소품: 기본 소품과 같은 슬롯, 고정 색, 상점 100 럭, 기본 소품을 가져야 보임
    base = {x['id']: x for x in props}
    for bid, colors in START_COLORS.items():
        assert base[bid]['unlock']['kind'] == 'default', f'시작 색은 기본 소품만: {bid}'
        base[bid]['startColors'] = [{'name': n, 'hex': h} for n, h in colors]
        assert base[bid]['material']['hex'] == colors[0][1], f'기본 색(material.hex) = 시작 첫 색: {bid}'
    for bid, colors in COLOR_VARIANTS.items():
        assert bid in MATERIAL, f'색을 바꿀 수 없는 소품: {bid}'
        for n, (cname, hexv, word) in enumerate(colors, 1):
            props.append({'id': f'{bid}_c{n}', 'slot': base[bid]['slot'], 'name': f"{word} {VARIANT_STEM.get(bid, base[bid]['name'])}", 'color': cname,
                          'unlock': {'kind': 'shop', 'price': COLOR_VARIANT_PRICE, 'requires': bid},
                          'status': 'mvp', 'variantOf': bid,
                          'material': {'catalogId': MATERIAL[bid][0], 'hex': hexv, **MATERIAL_SOURCE.get(bid, {})}})
    for x in props:
        if x['id'] in ICONS:
            x['icon'] = f"item_{ICONS[x['id']]}_v01"
        elif 'variantOf' in x:
            b = x['variantOf']; n = int(x['id'].rsplit('_c', 1)[1])
            x['icon'] = f"item_color_{ICONS[b].replace('_khaki', '')}_{VARIANT_ICON_WORDS[b][n - 1]}_v01"
    assert all('icon' in x for x in props if x['status'] == 'mvp' and x['slot'] != 'effect'), '칸 그림 없는 소품'
    rive = {pid: (slot, n) for slot, ids in RIVE_ORDER.items() for n, pid in enumerate(ids, 1)}
    for x in props:
        b = x.get('variantOf', x['id'])
        if b in rive:
            slot, n = rive[b]
            assert x['slot'] == slot, f'Rive 슬롯이 다름: {x["id"]}'
            x['rive'] = {'choice': f'{slot}Choice', 'n': n, 'color': _camel(ICONS[b].replace('_khaki', '')) + 'Color'}
    assert len(rive) == 37 and all('rive' in x for x in props if x['status'] == 'mvp' and x['slot'] != 'effect'), 'Rive 번호 없는 소품'
    assert rive['cloth_02'] == ('cloth', 4), '인계 문서: 여행복 = clothChoice 4'

    assert len({x['icon'] for x in props if 'icon' in x}) == 37 + 21, '칸 그림 이름 중복'
    ids = [x['id'] for x in props]
    assert len(ids) == len(set(ids)), 'id 중복'
    assert all(len(x['name'].split()) <= 2 for x in props if x['status'] == 'mvp' and 'variantOf' not in x), '이름은 두 낱말 이내(14장)'
    assert all(len(x['name'].split()) <= 3 for x in props if 'variantOf' in x), '색 소품 이름은 세 낱말까지(11장, 11/6)'
    assert not {'hand_03', 'hand_04'} & set(ids), '11/4 빠진 소품(나침반·큰 팔레트)'
    mvp = [x for x in props if x['status'] == 'mvp' and 'variantOf' not in x]
    assert all(x['slot'] in SLOTS for x in mvp)
    c = collections.Counter(x['slot'] for x in mvp)
    assert dict(c) == {'hat': 4, 'face': 3, 'cloth': 5, 'shoe': 5, 'hand': 5, 'bag': 5, 'pet': 5, 'float': 5, 'effect': 5}, c
    k = collections.Counter(x['unlock']['kind'] for x in mvp)
    assert dict(k) == {'default': 6, 'distance': 10, 'region': 7, 'companion': 3, 'steps': 1, 'shop': 15}, k
    assert len(mvp) - c['effect'] == 37
    assert sorted(x['unlock']['companion'] for x in mvp if x['unlock']['kind'] == 'companion') == ['bright', 'doctor', 'rest']
    assert sorted(x['unlock']['km'] for x in mvp if x['unlock']['kind'] == 'distance') == [10, 25, 50, 100, 150, 200, 300, 500, 700, 1000]
    assert sum(x['status'] == 'pending' for x in props) == 12
    assert all('일체형' not in x['name'] for x in props), '화면 글 원칙: 이름에 설명을 넣지 않음'
    dump('props.json', {'version': 8, 'slots': SLOTS, 'rive': {'viewModel': 'WardrobeColors', 'riveVerified': True, 'note': '계약 v0.5 5장. 11/13 v33 색 속성 38개 이름·슬롯별 순서 대조 끝(그림 확인은 개발 T5). choice 0 = 안 입음, 색 소품은 같은 번호 + 그 색 hex를 color 속성에. 효과는 Rive 밖(앱 입자)'},
                        'material': {'neutralReference': 180, 'formula': 'rgb = clamp(neutral.rgb × hex.rgb ÷ 180) 위에 고정 무늬 층',
                                     'source': 'Codex 기본 소품 v07 recolor/materials_v07.json'},
                        'colorVariants': {'price': COLOR_VARIANT_PRICE, 'perBase': 3, 'bases': list(MATERIAL),
                                          'pending': not COLOR_VARIANTS,
                                          'note': '기준 문서 11장(11/6 Annie): 색 = 몸 색 견본, 이름 = 색을 떠올리게 하는 말 + 소품(세 낱말까지), id <기본 id>_c<n>, color = 견본 이름'},
                        'props': props})
    return props


def build_milestones():
    ms = [100, 1000, 5000, 7777, 10000, 12345, 30000, 50000, 77777, 100000, 123456, 200000, 300000, 333333,
          400000, 500000, 600000, 700000, 777777, 800000, 900000, 1000000, 1234567]
    assert len(ms) == 23 and ms == sorted(ms)
    dump('milestones.json', {'version': 1, 'stepMilestones': ms}, ascii_ok=True)


if __name__ == '__main__':
    import sys
    os.makedirs(OUT, exist_ok=True)
    if '--props-only' not in sys.argv:
        build_landmarks()
    build_props()
    build_milestones()
    print(f'완료 → {OUT}')
    # 파일 사이 값 맞춰 보기(11/6). 틀리면 여기서 멈춘다
    import subprocess
    r = subprocess.run([sys.executable, os.path.join(HERE, 'check_data.py'), OUT])
    if r.returncode:
        sys.exit(r.returncode)
