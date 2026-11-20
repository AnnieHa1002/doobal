#!/usr/bin/env python3
"""두발 정적 데이터 파일끼리 값 맞춰 보기 (개발 기획, 2026-11-06 / 11-20 프로젝트 사본 검사 합침·상점 안 가진 것만·무늬 규칙·연출 5)

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
# 16장 11/19: 탭 대신 분류(category) 하나 — shop v7~
for it in shop['items']:
    if it.get('category') not in shop['categories']:
        err(f"shop {it['id']}: 모르는 분류 {it.get('category')}")
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
# scene.json·camp_wide.json은 납품 PNG 이름으로 적고, scene_art.json에는 WebP로 넣은 파일도 있다(T6c)
def art_name(path):
    name = path.split('/')[-1]
    return name[:-5] + '.png' if name.endswith('.webp') else name
art_assets = {art_name(v['file']): v for v in load('scene_art.json')['assets'].values()}
# scene_art.json이 적은 그림이 앱 폴더에 있는가 (WebP로 바꾼 뒤 옛 PNG 이름이 남지 않게). 앱 데이터 폴더를 볼 때만
APP_DIR = os.path.normpath(os.path.join(DIR, '..', '..'))
if os.path.isdir(os.path.join(APP_DIR, 'assets', 'backgrounds')):
    for key, v in load('scene_art.json')['assets'].items():
        if not os.path.isfile(os.path.join(APP_DIR, v['file'])):
            err(f"scene_art.json {key}: 그림 {v['file']}이 앱에 없음")
for group in ('grove', 'roadside'):
    for piece in scene_doc['pieces'][group]:
        if piece['file'] not in art_assets:
            err(f"장면 조각 {piece['id']}: 그림 {piece['file']}이 scene_art.json에 없음")
camp_doc = load('themes/camp_wide.json')
for obj in camp_doc['objects']:
    art = obj.get('art')
    if not art:
        continue
    spec = art_assets.get(art_name(art['file']))
    if spec is None:
        err(f"쉼터 물건 {obj['id']}: 그림 {art['file']}이 scene_art.json에 없음")
    elif spec['bbox'] != art['bbox']:
        err(f"쉼터 물건 {obj['id']}: bbox가 scene_art.json과 다름")
if camp_doc['drag']['farParallax'] != config['rest']['drag']['farParallax']:
    err("farParallax: camp_wide.json ≠ config")

# Rive 정령(계약 v0.4, 16장 11/11·11/13): 자세 번호 0~6, 화면별 자세가 표 안에 있음, 얼굴 번호 범위, 키 = 동행 × 0.75
rv = config['character'].get('rive')
if rv:
    poses = rv['poses']
    if sorted(poses.values()) != list(range(7)):
        err("character.rive.poses가 0~6 일곱 개가 아님")
    for scr, pose in rv['screens'].items():
        if pose != 'restSwap' and pose not in poses:
            err(f"character.rive.screens {scr}: 모르는 자세 {pose}")
    for pose in rv['restSwap']['poses'] + [rv['restSwap']['night']]:
        if pose not in poses:
            err(f"character.rive.restSwap: 모르는 자세 {pose}")
    if set(rv['triggers'].values()) != {'greet', 'joy', 'tapHead', 'tapBelly', 'angry', 'resetMotion'}:
        err("character.rive.triggers가 v32 트리거 6개와 다름")
fl = config['character'].get('float')
if fl and not 0.6 <= fl['scaleToCompanion'] <= 0.9:
    err(f"character.float scaleToCompanion {fl['scaleToCompanion']}가 0.6~0.9 밖")
pal = load('palette.json').get('customPartsV33')
if pal:
    want = {'eyes': (1, 6), 'brows': (0, 6), 'nose': (0, 7), 'mouth': (1, 8)}
    for part, (lo, hi) in want.items():
        nums = [x['rive'] for x in pal[part]]
        if nums != list(range(lo, hi + 1)):
            err(f"palette customPartsV33 {part}: rive 번호 {nums} ≠ {lo}~{hi}")
    for part, pid in pal['defaultFace'].items():
        if pid not in {x['id'] for x in pal[part]}:
            err(f"palette customPartsV33 defaultFace {part} {pid} 없음")
    if [x['rive'] for x in pal['expressions']] != list(range(6)):
        err("palette customPartsV33 expressions가 0~5가 아님")
riv_props = [x for x in props_doc['props'] if 'rive' in x]
seen = {}
for x in riv_props:
    key = (x['rive']['choice'], x['rive']['n'])
    base = x.get('variantOf', x['id'])
    if seen.setdefault(key, base) != base:
        err(f"props {x['id']}: Rive 번호 {key}가 {seen[key]}와 겹침")

# 같은 값이 두 파일에 있는 곳(개발 계획 7장, 11/13 개발 기획: 하나로 합치지 않고 같은지만 본다. 앱이 읽는 쪽은 config)
if shop.get('priceFormat') != config['coins']['format']['amount']:
    err(f"shop priceFormat {shop.get('priceFormat')} ≠ config coins.format.amount")
for it in shop['items']:
    if it.get('effect') and it.get('maxHold') != config['shop']['maxHoldPerItem']:
        err(f"shop {it['id']}: maxHold {it.get('maxHold')} ≠ config shop.maxHoldPerItem")
    if it.get('desc') and not it.get('effect'):
        err(f"shop {it['id']}: 설명 줄(desc)은 여행 효과만(16장 11/13)")
    if it.get('effect') and not it.get('desc'):
        err(f"shop {it['id']}: 여행 효과인데 설명 줄(desc) 없음")
    ef = it.get('effect') or {}
    if ef.get('km') is not None and f"{ef['km']:g}km" not in it.get('desc', ''):
        err(f"shop {it['id']}: desc에 {ef['km']:g}km가 없음")
    if ef.get('ratio') is not None and f"{round(ef['ratio'] * 100)}%" not in it.get('desc', ''):
        err(f"shop {it['id']}: desc에 {round(ef['ratio'] * 100)}%가 없음")
unused = props_doc.get('rive', {}).get('unusedChoices', {})
for x in riv_props:
    if x['rive']['n'] in unused.get(x['rive']['choice'], []):
        err(f"props {x['id']}: Rive {x['rive']['choice']} {x['rive']['n']}은 쓰지 않는 번호(16장 11/14 새싹·꽃)")
if unused.get('hatChoice') != config['character']['rive'].get('unusedChoices', {}).get('hatChoice'):
    err("props rive.unusedChoices ≠ config character.rive.unusedChoices")
pc = config.get('paintColor')
if pc:
    if set(pc['timePhase']) - {'note'} != set(config['scene']['sky']['keys']):
        err("paintColor.timePhase 키가 scene.sky.keys와 다름")
    n = (len(set(pc['timePhase']) - {'note'}) + len(set(pc['weather']) - {'note'})) * 2
    if n != pc['colorCount']:
        err(f"paintColor.colorCount {pc['colorCount']} ≠ (시간대 + 날씨) × 2 = {n}")
    for sea, tbl in pc.get('season', {}).get('hex', {}).items():
        if sea not in config['seasons']:
            err(f"paintColor.season.hex {sea}: config seasons에 없음")
        if set(tbl) != (set(pc['timePhase']) | set(pc['weather'])) - {'note'}:
            err(f"paintColor.season.hex.{sea}: 16색 id가 timePhase·weather와 다름")
    if pc.get('season') and len(pc['season']['hex']) * len(pc['season']['hex']['spring']) * 2 != 64:
        err("paintColor.season: 계절 4 × 16색 = 64가 아님")
    if pc.get('region'):
        lm_regions = {l['region'] for l in landmarks.values()}
        if set(pc['region']['colors']) != lm_regions:
            err(f"paintColor.region.colors 키 {sorted(pc['region']['colors'])} ≠ landmarks region {sorted(lm_regions)}")
        rids = [v['id'] for v in pc['region']['colors'].values()]
        if len(set(rids)) != len(rids):
            err("paintColor.region.colors id 중복")
    rw = config['paintDrop'].get('rewards', [])
    if sum(r['chance'] for r in rw) > 1:
        err("paintDrop.rewards 확률 합 > 1")
    lo, hi = pc['tube']['amountWalkMin']
    if pc['tube']['amountM'] != [lo * pc['tube']['walkMPerMin'], hi * pc['tube']['walkMPerMin']]:
        err("paintColor.tube.amountM ≠ amountWalkMin × walkMPerMin")
fx_ids = {x['id'] for x in props_doc['props'] if x['slot'] == 'effect' and x['status'] == 'mvp'}
if set(config.get('effects', {}).get('items', {})) != fx_ids: err(f"config effects.items {sorted(config.get('effects',{}).get('items',{}))} ≠ props 효과 {sorted(fx_ids)}")
art_doc = load('scene_art.json')
for o in ('portrait', 'landscape'):
    if art_doc[o].get('figureHeight') != config['character']['canvas']['screenHeightPx'][o]:
        err(f"정령 화면 키: scene_art {o}.figureHeight ≠ config character.canvas.screenHeightPx.{o}")

# 11/19 밤(data-v14): 무늬(trails.json)·물감 통·상점 미니 친구·시작 선물·쉼터 물품
trails = load('trails.json')
trail_ids = {t['id']: t for t in trails['patterns']}
if trails.get('default') not in trail_ids:
    err(f"trails default {trails.get('default')}가 patterns에 없음")
pp = config.get('paintPattern', {})
if pp.get('default') != trails.get('default'):
    err("config paintPattern.default ≠ trails.json default")
kms = [t['unlock']['km'] for t in trails['patterns'] if t['unlock']['kind'] == 'trailKm']
if kms != sorted(kms) or len(set(kms)) != len(kms):
    err(f"trails 거리 보상 {kms}가 오름차순·서로 다름이 아님")
for it in shop['items']:
    if it.get('slot') == 'trail':
        t = trail_ids.get(it.get('trailId'))
        if not t:
            err(f"shop {it['id']}: trails에 없는 무늬 {it.get('trailId')}")
        elif t['unlock'].get('shopPrice') != it['price'] or t['name'] != it['name']:
            err(f"shop {it['id']}: 값·이름이 trails.json과 다름")
for tid, t in trail_ids.items():
    if t['unlock'].get('shopPrice') and tid not in {it.get('trailId') for it in shop['items']}:
        err(f"trails {tid}: shopPrice가 있는데 shop.json에 없음")
cart = config['shop']['cart']
kinds = [k for b in cart['kindsByKm'] for k in b['kinds']]
known_kinds = set(props_doc['slots']) | {'decor', 'boat', 'trail', 'paintTube'}
for k in kinds:
    if k not in known_kinds:
        err(f"config shop.cart.kindsByKm: 모르는 종류 {k}")
if len(set(kinds)) != len(kinds):
    err("config shop.cart.kindsByKm: 같은 종류가 두 묶음에")
for it in shop['items']:
    if it.get('category') == 'travel':
        continue
    k = it.get('slot') or it.get('category')
    if k not in kinds:
        err(f"shop {it['id']}: 수레 종류 {k}가 kindsByKm에 없음(수레에 안 나옴)")
    if it.get('consumable'):
        if k not in cart.get('consumableKinds', []):
            err(f"shop {it['id']}: 소모품인데 consumableKinds에 없음")
        c = it.get('cart', {})
        if not (0 < c.get('chancePerDay', 0) <= 1) or c.get('maxPerDay', 0) < 1:
            err(f"shop {it['id']}: cart.chancePerDay(0~1]·maxPerDay ≥ 1 아님")
        if it.get('paint', {}).get('tubes', 0) < 1:
            err(f"shop {it['id']}: paint.tubes ≥ 1 아님")
shop_pets = [p for p in mvp.values() if p.get('shopPet')]
for p in shop_pets:
    if p['slot'] != 'pet' or p['unlock']['kind'] != 'shop':
        err(f"props {p['id']}: 상점 미니 친구인데 slot pet·unlock shop이 아님")
    if p.get('stance') not in ('float', 'ground'):
        err(f"props {p['id']}: stance가 float·ground가 아님")
if len(shop_pets) != 8:
    warn(f"상점 미니 친구 {len(shop_pets)}종(16장 11/19: 8종, 12/19 점검에서 4종만이면 나머지 status later)")
gift = config.get('maker', {}).get('startGift', {})
if gift:
    g = props.get(gift.get('prop'))
    if not g or g['unlock']['kind'] != 'gift' or g['status'] != 'mvp':
        err(f"config maker.startGift {gift.get('prop')}: props에 unlock gift mvp 소품이 아님")
for p in mvp.values():
    if p['unlock']['kind'] == 'gift' and p['id'] != gift.get('prop'):
        err(f"props {p['id']}: unlock gift인데 maker.startGift가 아님")
n_props = len([p for p in mvp.values() if 'variantOf' not in p and p['slot'] != 'effect'])
if n_props != 46:
    warn(f"MVP 소품(색 소품·꾸밈 효과 빼고) {n_props}개 ≠ 기준 문서 7장 46")
decor = load('decor.json')
decor_ids = {d['id']: d for d in decor['items']}
for it in shop['items']:
    if did := it.get('decorId'):
        d = decor_ids.get(did)
        if not d:
            err(f"shop {it['id']}: decor.json에 없는 물품 {did}")
        elif d['unlock'].get('price') != it['price'] or d['name'] != it['name']:
            err(f"shop {it['id']}: 값·이름이 decor.json과 다름")
for did, d in decor_ids.items():
    if d['unlock']['kind'] == 'shop' and did not in {it.get('decorId') for it in shop['items']}:
        err(f"decor {did}: 상점 물품인데 shop.json에 없음")
for c in companions['companions']:
    if len(c.get('restLines', [])) != config['companions']['finaleRoam']['tap']['linesPerCompanion']:
        err(f"companions {c['id']}: restLines 수 ≠ config finaleRoam.tap.linesPerCompanion")
wp = config['character']['rive'].get('walkPlayback', {})
if not (0 < wp.get('min', 0) <= wp.get('max', 0)) or wp.get('refStepsPerMin', 0) <= 0:
    err("character.rive.walkPlayback: refStepsPerMin > 0, 0 < min ≤ max 아님")

# 11/20 밤(개발 기획): 프로젝트 사본 데이터/check_data.py(11/19)에만 있던 검사를 합침 — 이제 이 파일 하나가 원본
def _get(d, *keys):
    for k in keys:
        if not isinstance(d, dict) or k not in d:
            return None
        d = d[k]
    return d
for it in shop['items']:
    if 'tab' in it:
        err(f"shop {it['id']}: tab은 11/19부터 안 씀(category)")
    if it.get('propId') and it.get('category') != 'prop':
        err(f"shop {it['id']}: 소품인데 분류가 prop이 아님")
    if it.get('decorId') and it.get('category') != 'decor':
        err(f"shop {it['id']}: 쉼터 물품인데 분류가 decor가 아님")
night_items = _get(config, 'rest', 'decor', 'nightLight', 'items') or []
for did, d in decor_ids.items():
    k = d['unlock']['kind']
    if k not in ('shop', 'gift', 'landmarksVisited'):
        err(f"decor {did}: 모르는 얻는 법 {k}")
    if k == 'landmarksVisited' and not 1 <= d['unlock']['n'] <= len(landmarks):
        err(f"decor {did}: 명소 수 {d['unlock']['n']}가 1~{len(landmarks)} 밖")
    if d.get('nightLight') and did not in night_items:
        err(f"decor {did}: nightLight인데 config rest.decor.nightLight.items에 없음")
for did in night_items:
    if not decor_ids.get(did, {}).get('nightLight'):
        err(f"config rest.decor.nightLight {did}: decor.json에서 nightLight가 아님")
sk = _get(config, 'coins', 'firstSketchGift', 'decor')
if sk and _get(decor_ids.get(sk, {}), 'unlock', 'kind') != 'gift':
    err(f"config coins.firstSketchGift.decor {sk}: decor.json의 gift 물품이 아님")
if decor.get('maxPlaced') != _get(config, 'rest', 'decor', 'maxPlaced'):
    err("decor.json maxPlaced ≠ config rest.decor.maxPlaced")
for n in {d['name'] for d in decor_ids.values()} & {p['name'] for p in mvp.values()}:
    err(f"decor 이름 '{n}'이 소품 이름과 겹침")
dsum = sum(d['unlock']['price'] for d in decor_ids.values() if d['unlock']['kind'] == 'shop')
if dsum != 3100:
    warn(f"쉼터 상점 물품 합계 {dsum} 럭 ≠ 럭_상점 v2.7 3,100 럭")
if 'tallNearCharacterOpacity' in layers['roadside'] or 'tallNearCharacterOpacity' in scene['layout']['roadside']:
    err("tallNearCharacterOpacity: 16장 11/19 장면 물체는 투명하게 하지 않음(키 지울 것)")
if rv:
    for pose in rv['restSwap']['poses']:
        if not pose.endswith('Front'):
            err(f"character.rive.restSwap: 쉼터는 정면만인데 {pose}(16장 11/19)")
    for scr in ('walking', 'walkingIdle'):
        if scr in rv['screens'] and not rv['screens'][scr].endswith('Side'):
            err(f"character.rive.screens {scr}: 걷기 탭은 옆면만(16장 11/19)")
    if _get(config, 'companions', 'facing', 'walkTabIdle') not in (None, 'side'):
        err("companions.facing.walkTabIdle: 걷기 탭 쉬는 중 동행은 옆면")
tabs = config['ui'].get('tabs')
if isinstance(tabs, dict) and 'labels' in tabs and 'items' in tabs:
    if set(tabs['labels']) != set(tabs['items']):
        err("ui.tabs labels 키 ≠ items")
    for lab in tabs['labels'].values():
        if len(lab) > 3:
            warn(f"ui.tabs 이름 '{lab}'이 김(화면 글 짧게)")
cdec = camp_doc.get('decor')
if cdec:
    gb = cdec['groundBand']
    if not (0 <= gb['xMin'] < gb['xMax'] <= camp_doc['scene']['widthPt']):
        err("camp_wide decor.groundBand x가 장면 폭 밖")
    es = cdec.get('easelStart')
    if es and not (gb['xMin'] <= es['footX'] <= gb['xMax'] and gb['footYMin'] <= es['footY'] <= gb['footYMax']):
        err("camp_wide decor.easelStart가 땅 띠 밖")
    for b in cdec.get('blocked', []):
        if b['id'] not in (_get(config, 'rest', 'decor', 'blocked') or []):
            err(f"camp_wide decor.blocked {b['id']}: config rest.decor.blocked에 없음")
for oid in ('companion', 'guestbookSign'):
    if oid in camp_doc or any(o['id'] == oid for o in camp_doc['objects']):
        err(f"camp_wide {oid}: 16장 11/18 쉼터에서 뺌")
for pkg in config.get('allowedSources', {}).get('android', []):
    if pkg != pkg.strip() or pkg.endswith('.'):
        err(f"allowedSources.android '{pkg}': 앞뒤 공백·끝 점 없이")
fx_ids = {x['id'] for x in mvp.values() if x['slot'] == 'effect'}
if 'items' in config.get('effects', {}) and set(config['effects']['items']) != fx_ids:
    err(f"config effects.items ≠ props 꾸밈 효과 {sorted(fx_ids)}")
for c in companions['companions']:
    rl = [x.get('text', '') for x in c.get('restLines', [])]
    if len(set(rl)) != len(rl) or not all(rl):
        err(f"companions {c['id']}: restLines에 빈 줄·같은 줄")

# 11/20 밤(16장 11/20 4줄): 상점은 안 가진 것만·팔림 도장, 배낭은 가진 것만, 무늬 숫자 규칙, 연출 5, 쉼터 물품 자리, 정령 v11
if cart.get('boughtToday') != 'removeOnBuy':
    err("shop.cart.boughtToday: 16장 11/20 산 칸은 빠짐(removeOnBuy)")
if 'owned' not in cart.get('exclude', []):
    err("shop.cart.exclude에 owned가 없음(가진 것은 수레에 안 나옴)")
sm = cart.get('soldMark') or {}
for k in ('diameterPt', 'color', 'text', 'rotateDeg', 'opacity'):
    if k not in sm:
        err(f"shop.cart.soldMark.{k} 없음(팔림 도장, 16장 11/20 Q016)")
if sm.get('tappable') is not False:
    err("shop.cart.soldMark.tappable: 팔림 칸은 누를 수 없음(false)")
for k in cart.get('ownedStillSold', []):
    if k not in set(cart.get('consumableKinds', [])) | set(cart.get('fixed', [])):
        err(f"shop.cart.ownedStillSold {k}: 소모품·고정 칸만 예외")
if config['album'].get('ownedOnly') is not True or pp.get('choose', {}).get('ownedOnly') is not True:
    err("album.ownedOnly·paintPattern.choose.ownedOnly: 16장 11/20 배낭은 가진 것만(true)")
for t in trails['patterns']:
    if t.get('pending'):
        err(f"trails {t['id']}: 그림이 들어왔는데 pending(검수 A27 통과)")
mp = config['mapTrail'].get('patterns', {})
if _get(mp, 'night', 'outlinePt') != 1.2 or str(_get(mp, 'night', 'outlineColor')).upper() != '#D9E4EF':
    err("mapTrail.patterns.night: 밤 윤곽 #D9E4EF 1.2pt(16장 11/20 Q010·Q012)")
if (_get(mp, 'shortSegment', 'underPt'), _get(mp, 'shortSegment', 'gapPt')) != (36, 18):
    err("mapTrail.patterns.shortSegment: 36pt 미만 끝 1개·여백 18pt(Q010 ③)")
if _get(mp, 'curve', 'chunkPx') != 64:
    err("mapTrail.patterns.curve.chunkPx 64가 아님(Q010 ③)")
if _get(mp, 'switch', 'gapPt') != 8:
    err("mapTrail.patterns.switch.gapPt 8이 아님(Q010 ④)")
mo = config['ui'].get('motion', {})
for k in ('arrivalPin', 'restPet', 'decorWiggle', 'cartSlot', 'dropPickup', 'albumFlip'):
    if k not in mo:
        err(f"ui.motion.{k} 없음(16장 11/20 연출 5개)")
for did, d in decor_ids.items():
    cw, chh = d.get('canvasPx', [0, 0])
    if not cw:
        if not decor.get('art', {}).get('pending'):
            err(f"decor {did}: 그림이 들어왔는데 canvasPx·groundAt 없음(검수 A29)")
        continue
    gx, gy = d['groundAt']
    if not (0 <= gx <= cw and 0 <= gy <= chh):
        err(f"decor {did}: groundAt이 캔버스 밖")
    slots = d.get('paintingSlotsAt', [])
    if len(slots) != d.get('paintingSlots', 0):
        err(f"decor {did}: paintingSlotsAt {len(slots)}개 ≠ paintingSlots {d.get('paintingSlots', 0)}")
    for sl in slots:
        x, y, w, h = sl['slot']
        if x < 0 or y < 0 or x + w > cw or y + h > chh:
            err(f"decor {did}: 걸 자리 {sl['slot']}가 캔버스 밖")
    if d.get('nightLight') and 'light' not in d:
        err(f"decor {did}: nightLight인데 light(lightAt·lightRadiusPx) 없음")
nx = rv.get('next', {}) if rv else {}
if nx and not nx.get('pending'):
    for k in ('file', 'fileId', 'fileBytes'):
        if k not in nx:
            err(f"character.rive.next.{k} 없음(정식 v11 들어오면 채움)")
for x in riv_props:
    if x['rive'].get('pending') and x['status'] == 'mvp' and x['rive']['choice'] in ('petChoice', 'floatChoice'):
        warn(f"props {x['id']}: rive.pending(정령 v11 inputs.md로 확인됨 — 지울 것)")

for w in warns:
    print('경고:', w)
for e in errors:
    print('틀림:', e)
print(f"파일 사이 검사: 틀림 {len(errors)} · 경고 {len(warns)}")
sys.exit(1 if errors else 0)
