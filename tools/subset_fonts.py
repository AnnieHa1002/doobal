"""앱 글꼴(고운바탕·고운돋움)을 자주 쓰는 글자만 남겨 줄인다.

    python -m venv .venv && .venv/bin/pip install fonttools
    .venv/bin/python tools/subset_fonts.py <원본 폴더> app/assets/fonts

- 원본 TTF는 Drive Assets/05_UI_화면/fonts(GowunBatang-Regular·Bold, GowunDodum-Regular).
- 남기는 글자: 영문·숫자·기호, 자주 쓰는 한글 2,350자(KS X 1001), 한글 자모,
  그리고 앱 코드(app/lib)와 데이터(app/assets/data)에 실제로 쓰인 글자 전부.
  빠진 글자(드문 한글 등)는 휴대폰 기본 글꼴로 보인다.
- 문구·데이터에 새 글자가 생기면 다시 돌린다.
"""
import glob
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.normpath(os.path.join(HERE, '..', 'app'))
FONTS = ['GowunBatang-Regular.ttf', 'GowunBatang-Bold.ttf', 'GowunDodum-Regular.ttf']

# 영문·숫자·기호, 라틴-1 기호(· × 등), 일반 문장 부호(… ‘’ “” 등), 화살표, 한중일 기호(「」 등), 한글 자모
RANGES = [(0x20, 0x7E), (0xA0, 0xFF), (0x2010, 0x2027), (0x2030, 0x203B), (0x2190, 0x2199),
          (0x3000, 0x303F), (0x3131, 0x318E)]


def ks_hangul():
    """KS X 1001 완성형 한글 2,350자. 파이썬 euc-kr 코덱은 나머지 음절도 8바이트 자모열로
    바꿔 주므로, 2바이트로 바뀌는 음절만 고른다"""
    out = set()
    for cp in range(0xAC00, 0xD7A4):
        try:
            if len(chr(cp).encode('euc-kr')) == 2:
                out.add(cp)
        except UnicodeEncodeError:
            pass
    return out


def used_chars():
    """앱 코드와 데이터에 쓰인 글자 (문구·명소·시군구 이름 등)"""
    out = set()
    paths = glob.glob(os.path.join(APP, 'lib', '**', '*.dart'), recursive=True)
    paths += glob.glob(os.path.join(APP, 'assets', 'data', '**', '*.json'), recursive=True)
    for p in paths:
        with open(p, encoding='utf-8') as f:
            out.update(ord(c) for c in f.read() if ord(c) >= 0x20)
    return out


def main(src, dst):
    hangul = ks_hangul()
    assert len(hangul) == 2350, len(hangul)
    codepoints = hangul | used_chars()
    for lo, hi in RANGES:
        codepoints.update(range(lo, hi + 1))
    os.makedirs(dst, exist_ok=True)
    for name in FONTS:
        font = TTFont(os.path.join(src, name))
        have = set(font.getBestCmap())
        opts = subset.Options()
        opts.layout_features = ['*']
        opts.name_IDs = ['*']
        opts.hinting = False
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=sorted(codepoints & have))
        sub.subset(font)
        out = os.path.join(dst, name)
        font.save(out)
        missing = sorted(c for c in used_chars() if c not in have and c > 0x7F)
        print(f'{name}: {os.path.getsize(out):,} B, 글자 {len(codepoints & have):,}개, '
              f'코드·데이터에 쓰였지만 원본에 없는 글자 {len(missing)}개')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
