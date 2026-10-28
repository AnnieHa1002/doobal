#!/usr/bin/env python3
"""두발 명소 좌표 재추출 (카카오 로컬 API 키워드 검색).

사용법 (내 컴퓨터에서, 추가 설치 없음):
    export KAKAO_REST_KEY=발급받은_REST_API_키      # Windows PowerShell: $env:KAKAO_REST_KEY="..."
    python geocode_landmarks.py 명소_한국101.csv

결과
    명소_한국101_new.csv   위도·경도를 새 값으로 바꾸고, 가장 가까운 명소·거리km를 다시 계산
    geocode_report.txt     명소마다 카카오가 찾은 장소 이름·주소와 이동 거리.
                           [확인] 표시 줄은 사람이 지도에서 봐야 함
                           (검색 결과 없음 / 1km 넘게 이동 / 장소 이름이 명소 이름과 안 맞음)

규칙
    - 검색어는 "시군구 명소이름". '·'로 묶인 명소는 앞부분만 쓴다(예: 인천 차이나타운·월미도 → 중구 인천 차이나타운).
    - 결과가 없으면 명소 이름만으로 한 번 더 찾는다. 그래도 없으면 기존 좌표를 둔다.
    - 키는 파일에 적지 않고 환경 변수로만 받는다.
"""
import csv
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

API = "https://dapi.kakao.com/v2/local/search/keyword.json"
SHIFT_WARN_KM = 1.0


def haversine(lat1, lng1, lat2, lng2):
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def search(key, query):
    url = API + "?" + urllib.parse.urlencode({"query": query, "size": 5})
    req = urllib.request.Request(url, headers={"Authorization": f"KakaoAK {key}"})
    with urllib.request.urlopen(req, timeout=10) as res:
        return json.load(res).get("documents", [])


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    key = os.environ.get("KAKAO_REST_KEY")
    if not key:
        sys.exit("환경 변수 KAKAO_REST_KEY 가 없습니다")

    src = sys.argv[1]
    with open(src, encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
        fields = list(rows[0].keys())

    report = []
    for r in rows:
        name = r["명소"]
        short = name.split("·")[0].strip()
        old = (float(r["위도"]), float(r["경도"]))
        docs = search(key, f'{r["시군구"]} {short}') or search(key, short)
        time.sleep(0.1)
        if not docs:
            report.append(f'[확인] {r["id"]} {name}: 검색 결과 없음, 기존 좌표 유지')
            continue
        d = docs[0]
        new = (round(float(d["y"]), 5), round(float(d["x"]), 5))
        shift = haversine(*old, *new)
        words = [w for w in short.split() if len(w) >= 2]
        name_ok = any(w in d["place_name"] for w in words)
        flag = "[확인] " if (shift > SHIFT_WARN_KM or not name_ok) else ""
        report.append(
            f'{flag}{r["id"]} {name}: {old[0]},{old[1]} → {new[0]},{new[1]} '
            f'({shift:.2f}km 이동) / 카카오: {d["place_name"]}, {d.get("road_address_name") or d["address_name"]}'
        )
        r["위도"], r["경도"] = new

    # 가장 가까운 명소 다시 계산
    for r in rows:
        best = min(
            (o for o in rows if o is not r),
            key=lambda o: haversine(float(r["위도"]), float(r["경도"]), float(o["위도"]), float(o["경도"])),
        )
        r["가장 가까운 명소"] = best["명소"]
        r["거리km"] = f'{haversine(float(r["위도"]), float(r["경도"]), float(best["위도"]), float(best["경도"])):.1f}'

    base = os.path.splitext(src)[0]
    with open(base + "_new.csv", "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    with open("geocode_report.txt", "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")

    flagged = sum(1 for line in report if line.startswith("[확인]"))
    print(f"완료: {len(rows)}곳, 확인 필요 {flagged}곳 → {base}_new.csv, geocode_report.txt")


if __name__ == "__main__":
    main()
