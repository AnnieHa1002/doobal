#!/usr/bin/env python3
"""앱에 넣을 PNG를 WebP로 바꾼다 (T6c 앱 크기, 11/16).

  python3 tools/to_webp.py app/assets/backgrounds/v11/*.png            # 고르기만 하고 표를 보인다
  python3 tools/to_webp.py --write 새그림_clean.png ...                # .webp를 PNG 옆에 쓴다
  python3 tools/to_webp.py --write --remove-png 새그림_clean.png ...   # WebP로 바꾼 PNG는 지운다

clean_assets.py로 다듬은 `_clean` PNG를 앱에 넣기 직전에 쓴다(다듬기·자르기는 하지 않는다).
바꾼 뒤 그 그림을 적은 데이터(scene_art.json `file` 등)를 .webp로 고친다. 원본 PNG는 Drive Assets 폴더에 있다.

고르는 법 (장마다)
  1. 손실 WebP를 품질 Q_LADDER 순서(높은 것부터)로 만들어 원본과 두 가지로 비교한다.
     투명 여백이 점수를 부풀리지 않게 그림이 있는 상자(알파 > 0)만 잘라 잰다.
     - ssimulacra2 ≥ MIN_SCORE(85): 설명서의 '1:1로 번갈아 봐도 구별 못 함'. 전체 인상(결 뭉개짐 등)
     - butteraugli 3-norm ≤ MAX_BUTTERAUGLI(0.75, 회색 128 위에 얹어 잼): 가장 나쁜 곳 위주.
       매끈한 그라데이션의 띠·네모 블록은 ssimulacra2가 놓쳐서 이것으로 막는다(11/16 sky_wash q80·
       bg_lower_bank_grass q85가 ssimulacra2는 통과, 여기서 걸림. 확대해 보면 블록이 보였다)
     둘 다 맞는 것 중 가장 낮은 품질을 고른다(하나라도 틀리면 그 아래는 보지 않는다).
  2. 무손실 WebP가 그보다 작거나, 어떤 품질도 맞지 않으면 무손실을 쓴다.
  3. 원본 PNG보다 KEEP_RATIO 넘게 줄지 않으면 PNG로 둔다.
  투명도는 늘 무손실(-alpha_q 100, 풀어서 원본과 같은지 확인)이고, 색 변환은 -sharp_yuv(가장자리 색 번짐을 줄임)로 한다.

필요한 것: cwebp·dwebp(brew webp), ssimulacra2·butteraugli_main(brew jpeg-xl), numpy. PIL은 쓰지 않는다.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

import numpy as np

Q_LADDER = [95, 92, 90, 88, 85, 82, 80]
MIN_SCORE = 85.0
MAX_BUTTERAUGLI = 0.75  # 3-norm
KEEP_RATIO = 0.9   # WebP가 PNG의 90%보다 크면 PNG로 둔다
LOSSY = ['-m', '6', '-sharp_yuv', '-alpha_q', '100', '-metadata', 'none']
LOSSLESS = ['-lossless', '-z', '9', '-metadata', 'none']


def need(tool):
    path = shutil.which(tool)
    if not path:
        sys.exit(f'{tool}이 없다 (brew install webp jpeg-xl)')
    return path


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def encode(src, dst, args):
    run(need('cwebp'), '-quiet', *args, src, '-o', dst)
    return os.path.getsize(dst)


def read_rgba(webp, tmp):
    """WebP를 풀어 높이×너비×4 배열로"""
    pam = os.path.join(tmp, 'read.pam')
    run(need('dwebp'), '-quiet', '-pam', webp, '-o', pam)
    data = open(pam, 'rb').read()
    end = data.index(b'ENDHDR\n') + 7
    head = dict(line.split(b' ', 1) for line in data[:end].split(b'\n')[1:-2])
    return np.frombuffer(data[end:], np.uint8).reshape(int(head[b'HEIGHT']), int(head[b'WIDTH']), 4)


def write_ppm(path, rgba, bg=128):
    """회색 바탕에 얹은 RGB (butteraugli는 투명도를 보지 않는다)"""
    a = rgba[..., 3:].astype(np.float32) / 255
    rgb = (rgba[..., :3] * a + bg * (1 - a)).round().astype(np.uint8)
    h, w, _ = rgb.shape
    with open(path, 'wb') as f:
        f.write(f'P6\n{w} {h}\n255\n'.encode() + np.ascontiguousarray(rgb).tobytes())


def write_pam(path, rgba):
    h, w, _ = rgba.shape
    head = f'P7\nWIDTH {w}\nHEIGHT {h}\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n'
    with open(path, 'wb') as f:
        f.write(head.encode() + np.ascontiguousarray(rgba).tobytes())


class Original:
    """원본 픽셀과 그림이 있는 상자. 잘라 둔 원본을 PAM으로 써 둔다"""

    def __init__(self, src, tmp):
        exact = os.path.join(tmp, 'exact.webp')
        encode(src, exact, ['-lossless', '-exact', '-z', '0'])
        self.rgba = read_rgba(exact, tmp)
        ys, xs = np.nonzero(self.rgba[..., 3])
        if len(ys) == 0:
            sys.exit(f'완전히 투명한 그림: {src}')
        self.box = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
        self.pam = os.path.join(tmp, 'orig.pam')
        self.ppm = os.path.join(tmp, 'orig.ppm')
        write_pam(self.pam, self.rgba[self.box])
        write_ppm(self.ppm, self.rgba[self.box])
        self.tmp = tmp

    def check_alpha(self, webp):
        out = read_rgba(webp, self.tmp)
        if out.shape != self.rgba.shape or not np.array_equal(out[..., 3], self.rgba[..., 3]):
            sys.exit(f'투명도가 바뀜: {webp}')
        return out

    def score(self, webp):
        """(ssimulacra2, butteraugli 3-norm)"""
        out = self.check_alpha(webp)[self.box]
        pam = os.path.join(self.tmp, 'out.pam')
        ppm = os.path.join(self.tmp, 'out.ppm')
        write_pam(pam, out)
        write_ppm(ppm, out)
        ssim = float(run(need('ssimulacra2'), self.pam, pam).strip().splitlines()[-1])
        # 출력: '<max>\n3-norm: <값>'
        ba = float(run(need('butteraugli_main'), self.ppm, ppm).split('3-norm:')[1].split()[0])
        return ssim, ba


def choose(src, tmp):
    """(방식, WebP 경로 또는 None, 크기, ssimulacra2, butteraugli). 방식은 'q90'·'lossless'·'png'"""
    png_size = os.path.getsize(src)
    orig = Original(src, tmp)
    best = None
    for q in Q_LADDER:
        out = os.path.join(tmp, f'q{q}.webp')
        size = encode(src, out, ['-q', str(q), *LOSSY])
        ssim, ba = orig.score(out)
        if ssim < MIN_SCORE or ba > MAX_BUTTERAUGLI:
            break
        best = (f'q{q}', out, size, ssim, ba)
    ll = os.path.join(tmp, 'lossless.webp')
    ll_size = encode(src, ll, LOSSLESS)
    if best is None or ll_size <= best[2]:
        orig.check_alpha(ll)
        best = ('lossless', ll, ll_size, 100.0, 0.0)
    if best[2] > png_size * KEEP_RATIO:
        return ('png', None, png_size, 100.0, 0.0)
    return best


def convert(src, write, remove_png):
    with tempfile.TemporaryDirectory() as tmp:
        kind, webp, size, ssim, ba = choose(src, tmp)
        png_size = os.path.getsize(src)
        if write and webp:
            shutil.copyfile(webp, src[:-4] + '.webp')
            if remove_png:
                os.remove(src)
    return os.path.basename(src), png_size, kind, size, ssim, ba


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('png', nargs='+')
    p.add_argument('--write', action='store_true', help='고른 .webp를 PNG 옆에 쓴다')
    p.add_argument('--remove-png', action='store_true', help='WebP로 바꾼 PNG를 지운다 (--write와 같이)')
    p.add_argument('-j', type=int, default=max(1, (os.cpu_count() or 2) // 2), help='동시에 바꿀 장 수')
    a = p.parse_args()
    if a.remove_png and not a.write:
        sys.exit('--remove-png는 --write와 같이 쓴다')
    files = [f for f in a.png if f.endswith('.png')]
    for f in sorted(set(a.png) - set(files)):
        print(f'건너뜀(PNG 아님): {f}', file=sys.stderr)

    with ThreadPoolExecutor(a.j) as pool:
        rows = list(pool.map(lambda f: convert(f, a.write, a.remove_png), files))
    print(f"{'파일':56} {'PNG KB':>8} {'고름':>9} {'결과 KB':>8} {'ssimu2':>7} {'BA3':>5}")
    for name, png_size, kind, size, ssim, ba in rows:
        print(f'{name:56} {png_size / 1024:8.0f} {kind:>9} {size / 1024:8.0f} {ssim:7.1f} {ba:5.2f}')
    total_png = sum(r[1] for r in rows)
    total_out = sum(r[3] for r in rows)
    print(f"{'합계':56} {total_png / 1024:8.0f} {'':>9} {total_out / 1024:8.0f}")


if __name__ == '__main__':
    main()
