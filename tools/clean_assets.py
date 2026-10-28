#!/usr/bin/env python3
"""두발 에셋 정리 스크립트 (dubal asset cleaner).

Codex 등에서 받은 원본 PNG를 에셋 요구서 규격에 맞게 다듬는다.

  캐릭터:  python clean_assets.py char  painter_idle_v01.png painter_walk_pose_v01.png ... -o out/
  하늘:    python clean_assets.py sky   bg_spring_day_01_sky_v01.png -o out/

캐릭터 처리
  1. 알파 1~24 → 0 (캔버스에 흩어진 희미한 점 제거)
  2. 본체와 떨어진 작은 덩어리(면적 < 0.2%) 제거
  3. 알파 240 이상 → 255 (몸 안쪽이 반투명이던 문제)
  4. 같은 묶음의 모든 포즈를 **같은 배율**로 1024×1280 캔버스에 넣고
     발바닥(가장 아래 불투명 픽셀)을 y=1216에, 머리 중심을 x=512에 맞춤
  5. C2PA 등 메타데이터 없이 저장 (PIL 기본 동작)

하늘 처리
  - 좌우 끝 256px을 서로 섞어 가로로 이어 붙여도 이음새가 보이지 않게 만든다.
  - 24시간 띠(8192×1800)로 늘리는 일은 하지 않는다. 다시 생성해야 한다.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

CANVAS_W, CANVAS_H = 1024, 1280
BASELINE_Y = 1216          # 발바닥 위치 (캔버스 높이의 95%)
MARGIN_TOP = 48            # 머리 위 최소 여백
ALPHA_FLOOR = 24           # 이 값 이하는 투명으로
ALPHA_SOLID = 240          # 이 값 이상은 완전 불투명으로
MIN_BLOB_RATIO = 0.002     # 본체 대비 이보다 작은 떨어진 덩어리는 삭제
SEAM = 256                 # 하늘 이음새 폭


def clean_alpha(rgba: np.ndarray) -> np.ndarray:
    a = rgba[..., 3].astype(np.int32)
    a[a <= ALPHA_FLOOR] = 0
    a[a >= ALPHA_SOLID] = 255

    mask = a > 0
    labels, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n > 1:
        sizes = ndimage.sum(mask, labels, range(1, n + 1))
        keep = sizes >= sizes.max() * MIN_BLOB_RATIO
        keep_ids = np.flatnonzero(keep) + 1
        a[~np.isin(labels, keep_ids)] = 0

    out = rgba.copy()
    out[..., 3] = a.astype(np.uint8)
    out[a == 0, :3] = 0      # 투명 픽셀의 색도 비워 두면 Rive/Flutter 가장자리 번짐이 줄어든다
    return out


def bbox(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha)
    return xs.min(), ys.min(), xs.max(), ys.max()


def head_center_x(alpha: np.ndarray, top: int, bottom: int) -> float:
    """윗부분 28%(머리)의 가로 중심. 포즈가 바뀌어도 머리가 흔들리지 않게 이 점을 기준으로 맞춘다."""
    cut = top + int((bottom - top) * 0.28)
    ys, xs = np.nonzero(alpha[top:cut])
    return float(xs.mean())


def place_characters(paths, out_dir):
    imgs = []
    for p in paths:
        arr = np.array(Image.open(p).convert("RGBA"))
        arr = clean_alpha(arr)
        imgs.append((p, arr, bbox(arr[..., 3])))

    # 같은 묶음은 한 배율: 가장 큰 포즈가 캔버스에 들어가도록
    max_h = max(b[3] - b[1] + 1 for _, _, b in imgs)
    max_w = max(b[2] - b[0] + 1 for _, _, b in imgs)
    scale = min((BASELINE_Y - MARGIN_TOP) / max_h, (CANVAS_W - 32) / max_w, 1.0)

    report = []
    for p, arr, (x0, y0, x1, y1) in imgs:
        crop = Image.fromarray(arr[y0:y1 + 1, x0:x1 + 1])
        w = round(crop.width * scale)
        h = round(crop.height * scale)
        crop = crop.resize((w, h), Image.LANCZOS)
        small = np.array(crop)
        small = clean_alpha(small)   # 리사이즈로 생긴 반투명 가장자리 다시 정리
        hx = head_center_x(small[..., 3], 0, h)

        canvas = np.zeros((CANVAS_H, CANVAS_W, 4), np.uint8)
        left = int(round(CANVAS_W / 2 - hx))
        top = BASELINE_Y - h + 1
        # 캔버스 밖으로 나가는 부분은 잘라 붙인다
        sx0, sy0 = max(0, -left), max(0, -top)
        dx0, dy0 = max(0, left), max(0, top)
        cw = min(w - sx0, CANVAS_W - dx0)
        ch = min(h - sy0, CANVAS_H - dy0)
        canvas[dy0:dy0 + ch, dx0:dx0 + cw] = small[sy0:sy0 + ch, sx0:sx0 + cw]

        name = os.path.splitext(os.path.basename(p))[0] + "_clean.png"
        Image.fromarray(canvas).save(os.path.join(out_dir, name), optimize=True)

        a = canvas[..., 3]
        bx0, by0, bx1, by1 = bbox(a)
        inner = a[a > 0]
        report.append(
            f"{name}: scale {scale:.4f}, bbox x{bx0}-{bx1} y{by0}-{by1}, "
            f"baseline {by1}, clipped={'yes' if (cw < w - sx0 or ch < h - sy0 or sx0 or sy0) else 'no'}, "
            f"opaque {np.mean(inner == 255) * 100:.1f}%, faint(1-24) {int(((a > 0) & (a <= 24)).sum())}"
        )
    return report


def clean_parts(paths, out_dir):
    lines = []
    for p in paths:
        im = Image.open(p).convert("RGBA")
        if im.size != (CANVAS_W, CANVAS_H):
            lines.append(f"{os.path.basename(p)}: 캔버스가 {im.size} — 파츠는 {CANVAS_W}x{CANVAS_H}이어야 합니다 (건너뜀)")
            continue
        arr = clean_alpha(np.array(im))
        name = os.path.splitext(os.path.basename(p))[0] + "_clean.png"
        Image.fromarray(arr).save(os.path.join(out_dir, name), optimize=True)
        lines.append(f"{name}: 위치 유지, 알파 정리")
    return lines


def make_sky_seamless(path, out_dir):
    img = np.array(Image.open(path).convert("RGB")).astype(np.float32)
    h, w, _ = img.shape
    if w <= SEAM * 2:
        sys.exit("하늘 이미지가 이음새 폭보다 너무 좁습니다")
    # 오른쪽 끝 SEAM px을 왼쪽 시작 부분과 섞고, 그만큼 잘라 낸다 → 너비 w-SEAM, 좌우가 이어진다
    t = np.linspace(0, 1, SEAM, dtype=np.float32)[None, :, None]
    left = img[:, :SEAM]
    right = img[:, w - SEAM:]
    blended = right * (1 - t) + left * t
    out = np.concatenate([img[:, SEAM:w - SEAM], blended], axis=1)
    out = np.clip(out, 0, 255).astype(np.uint8)
    name = os.path.splitext(os.path.basename(path))[0] + "_seamless.png"
    Image.fromarray(out).save(os.path.join(out_dir, name), optimize=True)

    # 확인용: 두 장을 이어 붙인 미리보기
    tile = np.concatenate([out, out], axis=1)
    prev = Image.fromarray(tile)
    prev.thumbnail((1600, 1600))
    prev.save(os.path.join(out_dir, os.path.splitext(name)[0] + "_tiled_preview.jpg"), quality=85)
    edge = np.abs(out[:, 0].astype(int) - out[:, -1].astype(int)).mean()
    return [f"{name}: {out.shape[1]}x{out.shape[0]}, 좌우 끝 평균 색 차이 {edge:.1f} (0에 가까울수록 이음새 없음)"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("kind", choices=["char", "sky"])
    ap.add_argument("files", nargs="+")
    ap.add_argument("-o", "--out", default="clean")
    ap.add_argument("--keep-position", action="store_true",
                    help="파츠용: 1024x1280 캔버스의 위치를 그대로 두고 알파만 정리")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    if args.kind == "char" and args.keep_position:
        lines = clean_parts(args.files, args.out)
    elif args.kind == "char":
        lines = place_characters(args.files, args.out)
    else:
        lines = []
        for f in args.files:
            lines += make_sky_seamless(f, args.out)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
