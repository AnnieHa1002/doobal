# 앱 크기(배경 WebP) T6c 인계

브랜치 `claude/t6c-app-size-adb187`, 시작 `05f13f6`(dev-batch) 위 커밋들(끝은 이 노트).
push·dev-batch·main 합치기·폰 설치는 하지 않았다. 새 패키지·DB 변경 없음. 화면 코드는 건드리지 않았다(`scene_art.dart`는 이름 맞추기 세 줄·주석 한 줄 + 작은 함수 하나).

**결론**: 배경 89장을 WebP로 바꿔 배경 폴더 98.3MB → 10.6MB. 릴리스 AAB 238.0MB → **150.8MB**, arm64 APK 198.4MB → **110.6MB**, 폰 한 대가 받는 크기 164.6MB → **77.4MB(추정)**. 전체 시험 2461 통과(건너뜀 14), `flutter analyze` 문제 없음, `check_data.py` 0.

## 한 것

| 일 | 커밋 | 내용 |
|---|---|---|
| 변환 도구 | `ceb6e17` | `tools/to_webp.py`(아래 ‘고른 품질’), `CLAUDE.md` 두 줄(아래 ‘통합 세션이 볼 것’) |
| 이름 맞추기 | `17289b5` | `scene_art.dart`: scene.json 조각 이름(납품 PNG)과 scene_art.json `file`(WebP)을 확장자 빼고 맞춤(`_artName`, 세 곳). `check_data.py`: 같은 규칙 + **scene_art.json `file`이 앱 폴더에 실제로 있는지** 새로 검사(옛 .png 이름이 남으면 1로 끝남). `scene_plan_test` 같은 규칙 |
| WebP 넣기 | `a1ad84b` | `assets/backgrounds/v11/` WebP 89장(PNG는 이 커밋까지 같이 있음) |
| 데이터 | `6a289e5` | **`scene_art.json`만**: `file` 89개 .png → .webp, `note`에 규칙 한 줄. 버전 12 그대로 |
| PNG 빼기 | `ff85868` | PNG 89장 삭제(원본은 Drive Assets), `scene_season_test`가 WebP 후경·별 점을 봄 |
| 노트 | (이 커밋) | 이 노트 |

- WebP로 안 바꾼 것: 쉼터 물건 `obj_rest_backpack·map·note`(PNG 3장, 332KB). `camp_wide.json`이 경로로 바로 읽어서 바꾸면 데이터 사본이 하나 더 바뀌는데 줄어드는 것은 약 0.2MB라 뒀다.
- 키는 그대로다: scene_art.json `assets` 키·`far`, 화면 코드의 그림 키(`'bg_path_v11_clean.png'` 등)는 납품 PNG 이름이 그대로 이름표다. 파일 경로만 `file`에 있다.
- 중간 커밋 `6a289e5` 하나만 꺼내면 `scene_season_test` 기대 6개가 틀린다(그때는 PNG·WebP가 다 있고 WebP를 읽음). 앱은 모든 커밋에서 그림을 찾는다. 끝 커밋에서 시험 모두 통과.

## 고른 품질과 이유

장마다 `tools/to_webp.py`가 골랐다(같은 설정으로 새 그림에도 씀).

1. 손실 WebP를 q95 → 92 → 90 → 88 → 85 → 82 → 80 차례로 만들고(`-m 6 -sharp_yuv -alpha_q 100`), 그림이 있는 상자(알파 > 0)만 잘라 원본과 비교한다.
2. **ssimulacra2 ≥ 85**(설명서: ‘1:1로 번갈아 봐도 구별 못 함’)와 **butteraugli 3-norm ≤ 0.75**(가장 나쁜 곳 위주, JPEG XL ‘시각 무손실’ 기본값 근처)를 둘 다 지키는 가장 낮은 품질. q80 밑으로는 안 내려간다.
3. 무손실 WebP가 더 작거나 어떤 품질도 안 맞으면 무손실, PNG보다 10% 넘게 안 줄면 PNG로 둔다(이번에는 없음).
4. 투명도는 무손실이고, 도구가 풀어서 원본 알파와 한 값도 다르지 않은지 장마다 확인했다.

butteraugli를 더한 까닭: 처음에는 ssimulacra2만 썼는데 `sky_wash`(매끈한 회색 결) q80이 86점으로 통과했지만 3배 확대·대비를 올려 보니 네모 블록이 보였고, `bg_lower_bank_grass` q80·q85도 ssimulacra2는 통과했지만 butteraugli 최대가 5.7·5.3이었다. 둘 다 butteraugli 3-norm에서 걸려 각각 q95·q90이 됐다.

결과: q95 22장, q92 21장, q90 13장, q88 10장, q85 5장, q82 4장, q80 8장, 무손실 6장. 큰 것은 대부분 q90~95다(후경 21장 모두 q92·q95). q80~85는 작은 하늘 그림(해·달·별·새·구름)과 종이 결이고, 해·달은 화면에 캔버스의 0.4배쯤으로 줄여 그린다(`sunSize` 140/339, `moonSize` 110/291).

눈으로 본 것(원본과 나란히, 회색·하늘색·밤색 바탕): 해 1배, 달 2배, 수도권 후경 2장째(q92, 기준선 0.75에 딱 걸친 장) 1배, 물(q92) 1배, `sky_wash` q80·90·95를 3배·대비 2.5배. q95 `sky_wash`·후경·물은 구별이 안 됐다. `sky_wash`는 하늘에 3.5%(`textureWash` 0.035)로만 얹힌다.

후경 세 장 이음새: 붙는 두 열의 평균 차이(0~255, 알파 곱한 값)가 원본 0.4~1.6 → WebP 0.7~2.0으로 0.3~0.7 늘었다. 한 장 안의 이웃 열 차이(0.3~1.7)와 비슷한 크기라 선으로 보이지는 않을 것으로 본다(추정, 폰에서 볼 것).

<details><summary>장마다 고른 품질 (PNG KB → WebP KB, ssimulacra2, butteraugli 3-norm)</summary>

| 파일 | PNG | 고름 | WebP | ssimu2 | BA3 |
|---|---:|---|---:|---:|---:|
| L2_jeju_basalt_patch_v11 | 526 | q90 | 48 | 88.1 | 0.67 |
| L2_mountain_shoulder_left_v11 | 842 | q95 | 118 | 89.9 | 0.50 |
| L2_mountain_shoulder_right_v11 | 703 | q92 | 68 | 89.9 | 0.55 |
| L2_river_shore_patch_v11 | 432 | q95 | 80 | 91.6 | 0.40 |
| L3_autumn_ginkgo_v11 | 1144 | q90 | 137 | 88.5 | 0.58 |
| L3_autumn_maple_v11 | 1142 | q95 | 157 | 90.3 | 0.52 |
| L3_autumn_rose_v11 | 1154 | q92 | 176 | 89.8 | 0.49 |
| L3_common_broadleaf_v10 | 1365 | q90 | 159 | 85.4 | 0.74 |
| L3_common_pine_cluster_v11 | 1181 | q92 | 138 | 88.9 | 0.55 |
| L3_spring_azalea_v11 | 1111 | q90 | 154 | 89.5 | 0.51 |
| L3_spring_cherry_v10 | 1362 | q88 | 134 | 85.6 | 0.70 |
| L3_spring_forsythia_v11 | 1104 | q92 | 195 | 90.0 | 0.44 |
| L3_spring_magnolia_v11 | 1099 | q92 | 167 | 89.5 | 0.46 |
| L3_spring_plum_v11 | 982 | q90 | 147 | 86.2 | 0.68 |
| L3_summer_trumpet_vine_v11 | 1298 | q92 | 174 | 89.2 | 0.50 |
| bg_back_meadow_autumn_v10_preview | 1554 | q90 | 210 | 86.0 | 0.71 |
| bg_back_meadow_spring_v10_preview | 1556 | q90 | 209 | 85.9 | 0.68 |
| bg_back_meadow_summer_v10_preview | 1569 | q95 | 264 | 87.5 | 0.73 |
| bg_back_meadow_winter_v10_preview | 1557 | q88 | 185 | 85.2 | 0.71 |
| bg_cluster_city_a_v10 | 1828 | q90 | 164 | 85.7 | 0.70 |
| bg_cluster_forest_a_v10 | 1555 | q95 | 183 | 87.9 | 0.60 |
| bg_cluster_forest_b_v10 | 1152 | q92 | 139 | 86.7 | 0.68 |
| bg_cluster_hill_a_v10 | 448 | q95 | 64 | 88.5 | 0.60 |
| bg_cluster_village_a_v10 | 1285 | q90 | 119 | 85.1 | 0.73 |
| bg_far_capital_wide_part1_v10 | 3072 | q95 | 274 | 87.4 | 0.63 |
| bg_far_capital_wide_part2_v10 | 3871 | q92 | 295 | 85.1 | 0.75 |
| bg_far_capital_wide_part3_v10 | 3063 | q95 | 293 | 87.5 | 0.62 |
| bg_far_chungcheong_wide_part1_v10 | 2491 | q95 | 203 | 87.3 | 0.62 |
| bg_far_chungcheong_wide_part2_v10 | 2635 | q95 | 215 | 87.9 | 0.61 |
| bg_far_chungcheong_wide_part3_v10 | 2571 | q92 | 147 | 85.2 | 0.74 |
| bg_far_gangwon_wide_part1_v10 | 2756 | q95 | 243 | 87.4 | 0.62 |
| bg_far_gangwon_wide_part2_v10 | 3448 | q92 | 253 | 85.9 | 0.72 |
| bg_far_gangwon_wide_part3_v10 | 2579 | q95 | 223 | 87.5 | 0.63 |
| bg_far_gyeongsang_wide_part1_v10 | 3204 | q92 | 210 | 85.9 | 0.74 |
| bg_far_gyeongsang_wide_part2_v10 | 3735 | q92 | 261 | 86.4 | 0.72 |
| bg_far_gyeongsang_wide_part3_v10 | 3334 | q92 | 221 | 86.1 | 0.74 |
| bg_far_jeju_wide_part1_v10 | 2064 | q95 | 188 | 88.2 | 0.62 |
| bg_far_jeju_wide_part2_v10 | 2776 | q92 | 222 | 85.8 | 0.74 |
| bg_far_jeju_wide_part3_v10 | 2219 | q95 | 199 | 88.3 | 0.61 |
| bg_far_jeolla_wide_part1_v10 | 2319 | q92 | 154 | 85.7 | 0.72 |
| bg_far_jeolla_wide_part2_v10 | 2559 | q92 | 194 | 86.2 | 0.68 |
| bg_far_jeolla_wide_part3_v10 | 2010 | q92 | 128 | 85.5 | 0.71 |
| bg_far_sea_wide_part1_v10 | 1838 | q95 | 144 | 86.5 | 0.64 |
| bg_far_sea_wide_part2_v10 | 2334 | q95 | 223 | 87.2 | 0.62 |
| bg_far_sea_wide_part3_v10 | 1929 | q95 | 162 | 86.7 | 0.63 |
| bg_front_autumn_v11 | 365 | q88 | 64 | 88.2 | 0.53 |
| bg_front_spring_v11 | 325 | q85 | 50 | 86.2 | 0.70 |
| bg_front_summer_v11 | 348 | q88 | 54 | 87.9 | 0.62 |
| bg_front_winter_v11 | 259 | q92 | 64 | 90.6 | 0.31 |
| bg_lower_bank_autumn_v11 | 282 | 무손실 | 186 | — | — |
| bg_lower_bank_base_v11 | 104 | q85 | 25 | 86.0 | 0.51 |
| bg_lower_bank_grass_v11 | 189 | q90 | 17 | 88.9 | 0.67 |
| bg_lower_bank_spring_v11 | 283 | 무손실 | 186 | — | — |
| bg_lower_bank_summer_v11 | 282 | 무손실 | 186 | — | — |
| bg_lower_bank_winter_v11 | 283 | q95 | 66 | 85.7 | 0.72 |
| bg_near_water_v11 | 1311 | q92 | 79 | 85.8 | 0.74 |
| bg_object_bush_a_v10 | 877 | q95 | 114 | 87.2 | 0.63 |
| bg_object_bush_b_v10 | 1207 | q92 | 142 | 85.9 | 0.71 |
| bg_object_utility_pole_a_v10 | 476 | q90 | 45 | 85.4 | 0.68 |
| bg_path_v11 | 312 | q95 | 55 | 88.1 | 0.71 |
| bg_rest_camp_back_grass_v11 | 131 | q88 | 34 | 89.5 | 0.59 |
| bg_rest_camp_back_landscape_v12 | 962 | q88 | 103 | 85.5 | 0.72 |
| bg_rest_camp_back_v11 | 998 | q90 | 88 | 85.7 | 0.73 |
| bg_rest_camp_front_grass_v11 | 32 | q88 | 10 | 91.6 | 0.67 |
| bg_rest_camp_front_v11 | 219 | q95 | 54 | 92.1 | 0.37 |
| fx_campfire_flame_01_v11 | 60 | q88 | 11 | 87.0 | 0.67 |
| fx_campfire_flame_02_v11 | 63 | q88 | 12 | 88.0 | 0.67 |
| fx_campfire_flame_03_v11 | 59 | q88 | 12 | 88.4 | 0.69 |
| paper_grain_v01 | 348 | q80 | 100 | 88.0 | 0.62 |
| prop_boat_01_v11 | 593 | q92 | 53 | 90.2 | 0.57 |
| sky_bird_v11 | 20 | q82 | 4 | 85.6 | 0.73 |
| sky_birds_flock_v11 | 43 | q80 | 10 | 86.0 | 0.68 |
| sky_cloud_01_v11 | 27 | q90 | 6 | 85.0 | 0.48 |
| sky_cloud_02_v11 | 63 | q85 | 8 | 87.2 | 0.75 |
| sky_cloud_03_v11 | 25 | 무손실 | 16 | — | — |
| sky_cloud_04_v11 | 55 | q85 | 8 | 88.0 | 0.68 |
| sky_moon_crescent_v11 | 27 | q82 | 5 | 86.7 | 0.71 |
| sky_moon_full_v11 | 59 | q85 | 6 | 86.7 | 0.73 |
| sky_star_dot_v01 | 5 | 무손실 | 3 | — | — |
| sky_star_dots_a_v01 | 8 | q80 | 2 | 88.8 | 0.39 |
| sky_star_dots_b_v01 | 8 | q80 | 3 | 89.2 | 0.35 |
| sky_star_five_v11 | 18 | q82 | 3 | 86.2 | 0.74 |
| sky_star_mix_v01 | 14 | q80 | 4 | 86.5 | 0.49 |
| sky_star_shooting_v11 | 17 | 무손실 | 11 | — | — |
| sky_star_spark_l_v01 | 23 | q80 | 4 | 85.1 | 0.72 |
| sky_star_spark_s_v01 | 10 | q82 | 2 | 85.2 | 0.69 |
| sky_stars_cluster_v11 | 15 | q80 | 5 | 89.0 | 0.46 |
| sky_sun_v11 | 53 | q80 | 9 | 86.4 | 0.61 |
| sky_wash_v01 | 91 | q95 | 8 | 92.1 | 0.74 |
| **합계 (KiB)** | **95705** | | **9974** | | |

(이름 끝 `_clean`은 뺐다. KB는 1024바이트)
</details>

## 전후 크기

MB = 10⁶바이트. 빌드는 이 맥에서 `flutter build appbundle --release`, `flutter build apk --release --target-platform android-arm64 --analyze-size`(전은 `05f13f6`을 꺼내 빌드, 후는 `ff85868`). `key.properties`가 없어 debug 키로 서명됨.

| | 전 `05f13f6` | 후 `ff85868` | 줄어듦 |
|---|---:|---:|---:|
| 배경 폴더 `assets/backgrounds` | 98.3 (PNG 92장) | 10.6 (WebP 89 + PNG 3) | −87.8 |
| 에셋 합계 `app/assets` | 154.7 | 66.9 | −87.8 |
| 릴리스 AAB | **238.0** | **150.8** | −87.2 |
| arm64 APK | **198.4** | **110.6** | −87.8 |
| 폰(arm64) 한 대가 받는 크기 (추정) | 164.6 | 77.4 | −87.2 |

- **폰 한 대 추정**: AAB `base/`의 압축 크기에서 armeabi-v7a·x86_64 라이브러리를 뺀 값. Play가 ABI별로 나눠 보내는 몫에 가깝지만 Play의 압축·분할은 다르므로 추정이다. 후 77.4 = 명소 그림 37.9 + 네이티브(arm64) 12.8 + 배경 10.4 + Rive 9.6 + 그 밖 6.7(소품 그림 2.4·dex 등).
- **AAB**의 47.6MB는 `BUNDLE-METADATA`(디버그 기호·난독화 표)라 기기로 안 간다.
- **arm64 APK가 추정보다 큰 까닭**: APK 안 `.so`는 압축 없이 들어가고(arm64 30.3MB), `rive_native`·`jni`·`datastore` 플러그인은 `--target-platform`을 안 따라 armeabi-v7a·x86_64 라이브러리(15.0MB)도 들어 있다. Play로 받으면 이 몫은 안 온다.
- `--analyze-size` 요약: `~/.flutter-devtools/apk-code-size-analysis_01.json`(전)·`_02.json`(후). Dart 코드(`libapp.so` 9.0MB)는 같다.
- 11/10 기록(AAB 230.5MB)보다 전 AAB가 7.5MB 큰 것은 그 뒤 들어온 정령 `spirit_v36.riv`(11.8MB) 등 때문이다. 11/10의 ‘폰 한 대 약 158MB’는 같은 셈법을 MiB로 하면 지금 전 값 157.0과 맞는다(단위 차이로 보임).
- Play 기본 모듈 한도(200MB·500MB, 9장 위험)보다 AAB·폰 몫 모두 넉넉히 작다.

## Annie가 폰에서 볼 것

걷는 중·쉼터·배 구간을 낮·해질녘·밤으로 한 번씩, 지역 두세 곳(수도권·제주·바다)과 계절 하나 이상.

1. **하늘·띠**: 해질녘·밤 하늘 그라데이션에 계단 같은 띠나 네모 블록이 없는지. 해·달·구름 안쪽이 얼룩지지 않았는지
2. **투명 가장자리**: 나무(L3)·덤불·전봇대·마을 묶음·후경 산 능선·배 둘레에 검은/흰 테두리나 번짐이 없는지(밤 색 입힘 때 특히)
3. **풀 색**: 아래 둑·쉼터 풀(회색조에 계절색을 입힘)의 색이 전과 같은지
4. **후경 이음새**: 후경 세 장이 붙는 두 곳에 세로 선이 생기지 않았는지(천천히 흐를 때)
5. **결**: 후경·나무의 종이 결·판화 선이 뭉개지지 않았는지, 모닥불 세 장이 바뀔 때 깜빡임이 늘지 않았는지
6. **처음 그리는 시간**: 쉼터·걷는 중 배경이 뜨는 데 전보다 느리지 않은지(WebP 풀기는 PNG와 비슷하거나 빠를 것으로 봄, 추정)

## 개발 기획에 넘길 것

- **`scene_art.json`**(`6a289e5`): `assets.*.file` 89개가 `assets/backgrounds/v11/*.webp`로 바뀜(쉼터 물건 `obj_rest_*` 3개만 .png). `note`에 규칙 한 줄을 더함. 원본에 같이 반영해 주세요. 버전은 12 그대로 두었다(올릴지는 개발 기획).
- 규칙: **scene.json·camp_wide.json은 납품 PNG 이름 그대로**(바꿀 것 없음), scene_art.json `file`만 앱에 넣은 실제 파일. 원본에서 scene_art.json을 다시 복사할 때 .png로 돌아가면 `check_data.py`가 ‘앱에 없음’으로 멈춘다.
- 앞으로 새 배경·조각은 PNG 이름으로 적어 주면 된다. 개발이 `tools/to_webp.py`로 바꾸고 scene_art.json `file`만 .webp로 적는다.

## 통합 세션이 볼 것

- **`CLAUDE.md`를 고쳤다**(`ceb6e17`, 두 줄): 리포 구조의 `tools/` 줄에 `to_webp.py (앱에 넣을 PNG → WebP)`를 더하고, ‘에셋’ 끝에 ‘앱에 넣는 그림은 WebP: `python3 tools/to_webp.py --write --remove-png <png...>`(장마다 품질을 재서 고름) 뒤 데이터의 파일 이름을 .webp로 고친다’를 더했다. 이유: 6장 ‘새 그림은 WebP부터’를 지킬 도구가 생겼는데 다음 세션이 찾을 곳이 CLAUDE.md라서. 빼도 도구 자체는 동작한다. `개발_계획.md` 6장 ‘새 그림’ 줄에도 도구 이름을 적을지는 통합 세션이 정해 주세요(이 트랙은 안 고침).
- `scene_art.dart`(T3 자리)는 `_artName` 함수와 세 줄(`_keyOfFile`·`load`의 `byFile`·`_displayRatios`의 `byFile`)만. T12 2단계와 겹치면 이 네 군데만 보면 된다.
- 도구가 쓰는 것: `cwebp`·`dwebp`(brew webp), `ssimulacra2`·`butteraugli_main`(brew jpeg-xl), numpy. 이 맥에는 다 있다. 89장 전부 6장씩 동시에 약 6분 반.
- 첫 시도 때 디스크가 4.3GB여서(규칙 6GB) arm64 APK 전 빌드를 멈췄다가, 다시 이어 받은 뒤(19GB) 쟀다. 다 잰 뒤 `app/build/app`은 지웠다.

## 더 줄일 여지 (고치지 않음)

| 대상 | 지금 | 여지 (재거나 계산함, 추정은 표시) | 누가·언제 |
|---|---:|---|---|
| 정령 `assets/rive/spirit_v36.riv` | 11.8MB (AAB 압축 뒤 Rive 전체 9.6) | 안에 PNG 738장 7.7MB가 들어 있다. 같은 그림을 WebP 무손실로 바꾸면 4.0MB(잼, −3.7MB). Rive 편집기가 내장 그림을 WebP로 내보낼 수 있는지·런타임이 읽는지는 확인 못 함. 나머지 약 4.1MB는 뼈대·애니메이션 | 정령 납품 쪽(Rive 편집기)에서 내보내기 설정 확인 |
| 옛 Rive `doobal_custom.riv`·`rive_test_v01.riv` | 1.5MB·0.17MB | 사람형(`scene_view.dart`가 아직 읽음)·개발 화면 시험용. 계획 4장 ‘옛 Rive 정령·사람형 코드 정리’ 때 빼면 −1.7MB | 그 정리 트랙 |
| 옛 사람형 조각 `assets/items/basic_v02` | 2.5MB (PNG) | 위 정리 때 같이 빼거나, 남기면 `to_webp.py`로(배경 비율이면 약 −2MB, 추정) | 같은 정리 트랙 |
| 명소 그림 `assets/paintings` | 37.9MB (WebP 102장, 1536×1152, 중앙값 353KB) | 가장 크다. 이미 WebP라 여기서 다시 손실 압축하면 두 번 깎인다. Drive 원본 PNG로 `to_webp.py`를 돌리면 줄 여지를 잴 수 있다(받기 허락 필요). 크게 보기 화면(16장 11/10)이 있어 해상도는 그대로 두는 쪽 | Annie 허락 뒤 개발 |
| 코드가 안 읽는 배경 | 0.8MB | `bg_rest_camp_back_landscape_v12`(0.11), 계절 아래 둑 4장(0.64, 회색조 둑이 있어 대체용으로만), 그리지 않는 하늘 그림 11장(0.06: 구름 3·4, 초승달, 새 한 마리, 별 무리 등). scene_art.json 목록에서도 빠져야 해서 개발 기획과 같이 | 개발 기획 + 개발 |
| `assets/ui/ui_note_paper_plain_9s60_v01_clean.png` | 0.41MB | `to_webp.py`로 약 −0.3MB(추정). 9-slice라 가장자리 확인 필요 | 아무 트랙 |
| 네이티브(arm64) | 12.8MB 압축 | `libflutter` 5.2·`libapp` 3.4·`librive_native` 2.7 등. 줄일 여지 작음 | — |
