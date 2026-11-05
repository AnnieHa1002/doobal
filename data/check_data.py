#!/usr/bin/env python3
"""두발 정적 데이터 파일끼리 값 맞춰 보기 (개발 기획, 2026-11-06)

    python3 data/check_data.py [데이터 폴더, 기본 app/assets/data]

한 파일 안의 모양 검사는 각 빌드 스크립트가 한다. 여기서는 파일 사이에 같은 값이 맞는지만 본다.
틀린 것이 있으면 목록을 찍고 1로 끝난다(빌드·CI에서 멈추게). 경고는 찍기만 한다.
"""
import json
import os
import sys

DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'app', 'assets', 'data')
errors, warns = [], []


def load(name):
    with open(os.path.join(DIR, name), encoding='utf-8') as f:
        return json.load(f)


def err(msg):
    errors.append(msg)


def warn(msg):
    warns.append(msg)


props_doc = load('props.json')
props = {p['id']: p for p in props_doc['props']}
mvp = {k: p for k, p in props.items() if p['status'] == 'mvp'}
shop = load('shop.json')
boats = load('boats.json')
boat_ids = {b['id']: b for b in boats['boats']}
companions = load('companions.json')
story = load('story_layers.json')
palette = load('palette.json')
config = load('config.json')
landmarks = {l['id']: l for l in load('landmarks.json')['landmarks']}
badges = load('badges.json')
scene = load('scene.json')

# 1. 상점 ↔ 소품
for it in shop['items']:
    if it['tab'] not in shop['tabs']:
        err(f"shop {it['id']}: 모르는 탭 {it['tab']}")
    if pid := it.get('propId'):
        p = props.get(pid)
        if not p:
            err(f"shop {it['id']}: props에 없는 소품 {pid}")
            continue
        if p['unlock']['kind'] != 'shop':
            err(f"shop {it['id']}: 소품 {pid}의 얻는 법이 shop이 아님({p['unlock']['kind']})")
        elif p['unlock']['price'] != it['price']:
            err(f"shop {it['id']}: 값 {it['price']} ≠ props {p['unlock']['price']}")
        if p['name'] != it['name']:
            err(f"shop {it['id']}: 이름 '{it['name']}' ≠ props '{p['name']}'")
        if p['slot'] != it.get('slot'):
            err(f"shop {it['id']}: 슬롯 {it.get('slot')} ≠ props {p['slot']}")
    if bid := it.get('boatId'):
        b = boat_ids.get(bid)
        if not b:
            err(f"shop {it['id']}: boats에 없는 배 {bid}")
        elif b['unlock'].get('price') != it['price']:
            err(f"shop {it['id']}: 값 {it['price']} ≠ boats {b['unlock'].get('price')}")
        elif b['name'] != it['name']:
            err(f"shop {it['id']}: 이름 '{it['name']}' ≠ boats '{b['name']}'")
shop_props = {it['propId'] for it in shop['items'] if it.get('propId')}
for pid, p in mvp.items():
    if p['unlock']['kind'] == 'shop' and 'variantOf' not in p and pid not in shop_props:
        err(f"props {pid}: 상점 소품인데 shop.json에 없음")
if shop.get('defaultBoat') not in boat_ids:
    err(f"shop defaultBoat {shop.get('defaultBoat')}가 boats에 없음")

# 2. 색 소품
cv = props_doc.get('colorVariants', {})
for pid, p in props.items():
    if base := p.get('variantOf'):
        b = props.get(base)
        if not b:
            err(f"props {pid}: 기본 소품 {base}가 없음")
            continue
        if p['unlock'].get('requires') != base:
            err(f"props {pid}: requires ≠ variantOf")
        if p['slot'] != b['slot']:
            err(f"props {pid}: 슬롯이 기본 소품과 다름")
        if 'material' not in b:
            err(f"props {pid}: 기본 소품 {base}에 material 없음(색을 바꿀 수 없는 소품)")
        if p['unlock'].get('price') != cv.get('price'):
            err(f"props {pid}: 값 {p['unlock'].get('price')} ≠ colorVariants.price {cv.get('price')}")
for base in cv.get('bases', []):
    if base not in props or 'material' not in props[base]:
        err(f"colorVariants.bases {base}: 소품이 없거나 material 없음")
    if not cv.get('pending'):
        n = sum(1 for p in props.values() if p.get('variantOf') == base)
        if n != cv.get('perBase'):
            err(f"색 소품 {base}: {n}개 ≠ perBase {cv.get('perBase')}")
swatch_names = {s['name'] for s in palette['body']['swatches']}
swatch_hex = {s['name']: s['hex'].upper() for s in palette['body']['swatches']}
for p in props.values():
    if 'variantOf' in p:
        c = p.get('color')
        if c not in swatch_names:
            err(f"props {p['id']}: color '{c}'가 palette body 견본에 없음")
        elif p['material']['hex'].upper() != swatch_hex[c]:
            err(f"props {p['id']}: hex {p['material']['hex']} ≠ 견본 {c} {swatch_hex[c]}")
for p in mvp.values():
    if p['slot'] == 'hand' and p.get('fit') not in ('wristOverlay', 'replaceArms'):
        err(f"props {p['id']}: 손 소품인데 fit(wristOverlay·replaceArms) 없음")
names = [p['name'] for p in mvp.values()]
for n in {n for n in names if names.count(n) > 1}:
    err(f"props: 같은 이름이 여럿 '{n}'")

# 3. 동행 ↔ 소품·이야기 그림
story_ids = {s['id'] for s in story['scenes']}
for c in companions['companions']:
    fp = c.get('finaleProp')
    if fp not in mvp or mvp[fp]['unlock'].get('companion') != c['id']:
        err(f"companions {c['id']}: 완결 소품 {fp}가 props(companion={c['id']})와 안 맞음")
    for ch in c['chapters']:
        if ch.get('art') and ch['art'] not in story_ids:
            err(f"companions {c['id']} {ch['no']}장: art {ch['art']}가 story_layers에 없음")
        if ch.get('prop') and ch['prop'] != fp:
            err(f"companions {c['id']} {ch['no']}장: prop {ch['prop']} ≠ finaleProp {fp}")
used_art = {ch['art'] for c in companions['companions'] for ch in c['chapters'] if ch.get('art')}
for sid in story_ids - used_art:
    warn(f"story_layers {sid}: 어느 동행 장도 안 씀")

# 4. 소품 얻는 조건 ↔ 명소·권역·동행
regions = {l['region'] for l in landmarks.values()}
comp_ids = {c['id'] for c in companions['companions']}
for p in mvp.values():
    u = p['unlock']
    if u['kind'] == 'region' and u['region'] not in regions:
        err(f"props {p['id']}: 모르는 권역 {u['region']}")
    if u['kind'] == 'companion' and u['companion'] not in comp_ids:
        err(f"props {p['id']}: 모르는 동행 {u['companion']}")

# 5. 배
for b in boats['boats']:
    shop_boat = b['unlock']['kind'] == 'shop'
    if shop_boat and not b.get('recolor'):
        err(f"boats {b['id']}: 상점 배인데 recolor 없음(11/4 6척 모두)")
    if not shop_boat and b.get('recolor'):
        err(f"boats {b['id']}: 보상 배인데 recolor 있음(고정 색)")
    if shop_boat and b['id'] not in {it.get('boatId') for it in shop['items']}:
        err(f"boats {b['id']}: 상점 배인데 shop.json에 없음")
    if b.get('recolor', {}) and b['recolor'].get('pending'):
        warn(f"boats {b['id']}: 색 구역 그림 대기")
    if b.get('recolor', {}) and b['recolor'].get('method') not in ('materialIds', 'meanLuminance'):
        err(f"boats {b['id']}: recolor.method가 materialIds·meanLuminance가 아님")
    if b.get('recolor', {}) and b['recolor'].get('fileNamesPending'):
        warn(f"boats {b['id']}: 색 구역 파일 이름 확인 대기(zip)")
    if not b.get('layers'):
        warn(f"boats {b['id']}: layers(그림·발 자리) 없음")

# 6. 배지·config·scene
badge_comp = [x for x in badges['badges'] if x['cond']['kind'] in ('companionsMet', 'finaleCount')]
for x in badge_comp:
    if x['cond'].get('n', 0) > len(comp_ids):
        err(f"badges {x['id']}: n {x['cond']['n']} > 동행 수 {len(comp_ids)}")
layers = config['scene']['layers']
for name in config['scene'].get('seaHiddenLayers', []):
    if name not in layers:
        err(f"config seaHiddenLayers {name}: scene.layers에 없음")
if scene['layout']['roadside'].get('tallObjectClearX') != layers['roadside'].get('tallObjectClearX'):
    err("tallObjectClearX: scene.json ≠ config")
ch = config['character']['canvas']
if config['scene']['characterHeightPx'] != ch['screenHeightPx']['portrait']:
    err(f"정령 화면 키: scene.characterHeightPx {config['scene']['characterHeightPx']} ≠ character.canvas {ch['screenHeightPx']['portrait']}")
if abs(ch['screenHeightPx']['portrait'] / ch['heightPx'] - ch['scale']['portrait']) > 0.005:
    err("character.canvas scale.portrait가 screenHeightPx ÷ heightPx와 다름")
if config['coins'].get('welcomeGift', 0) < cv.get('price', 0):
    warn("첫 선물로 색 소품 하나를 못 삼(럭_상점 v2.4 설계 의도와 다름)")

# 장면 조각·캠프 물건이 그림 목록(scene_art.json)에 있고 상자가 같은가
scene_doc = load('scene.json')
art_assets = {v['file'].split('/')[-1]: v for v in load('scene_art.json')['assets'].values()}
for group in ('grove', 'roadside'):
    for piece in scene_doc['pieces'][group]:
        if piece['file'] not in art_assets:
            err(f"장면 조각 {piece['id']}: 그림 {piece['file']}이 scene_art.json에 없음")
camp_doc = load('themes/camp_wide.json')
for obj in camp_doc['objects']:
    art = obj.get('art')
    if not art:
        continue
    spec = art_assets.get(art['file'].split('/')[-1])
    if spec is None:
        err(f"쉼터 물건 {obj['id']}: 그림 {art['file']}이 scene_art.json에 없음")
    elif spec['bbox'] != art['bbox']:
        err(f"쉼터 물건 {obj['id']}: bbox가 scene_art.json과 다름")
if camp_doc['drag']['farParallax'] != config['rest']['drag']['farParallax']:
    err("farParallax: camp_wide.json ≠ config")

for w in warns:
    print('경고:', w)
for e in errors:
    print('틀림:', e)
print(f"파일 사이 검사: 틀림 {len(errors)} · 경고 {len(warns)}")
sys.exit(1 if errors else 0)
