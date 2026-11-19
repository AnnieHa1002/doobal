import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/paint_color.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/domain/rules.dart';
import 'package:doobal/domain/scene.dart' show Season;
import 'package:doobal/domain/sky.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// M1 명세 v0.7 (물감 색·모으기) ④~⑨·v0.8 (계절·지역 색) ⑩~⑬의 순수 쪽. ⑦·⑧·⑨·⑬의 보관·DB 쪽은
// test/app/paint_service_test.dart

Map<String, dynamic> _config() =>
    jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;

Rules _rulesWith(void Function(Map<String, dynamic> config) edit) {
  final j = _config();
  edit(j);
  return Rules.fromJson(j);
}

PaintColorRules get _pc => rules.paintColor;

void main() {
  group('config paintColor 읽기', () {
    test('v24 값: 기본 #B5603A 무제한, 16색, 통 10%(rewards)·770~1,540m, 999통, 걷는 중에도 고름, 날씨 하루 한 번', () {
      expect(_pc.defaultId, 'basic');
      expect(_pc.defaultHex, 0xFFB5603A);
      expect(_pc.colorIds, hasLength(16));
      expect(_pc.colorIds.take(4), ['dawn', 'dawn_run', 'morning', 'morning_run']);
      expect(_pc.colorIds.skip(10), ['rain', 'rain_run', 'snow', 'snow_run', 'cloudy', 'cloudy_run']);
      expect(_pc.rewards, hasLength(1));
      final tube = _pc.rewards.single as TubeReward;
      expect(tube.chance, 0.1);
      expect((tube.minM, tube.maxM), (770, 1540));
      expect(_pc.maxTubesPerColor, 999);
      // 16장 11/16: 걷는 중에도 배낭에서 바로 바꾸고, 날씨는 한국 날짜마다 한 번 (askMin 1440)
      expect(_pc.chooseWhileWalking, isTrue);
      expect(_pc.weatherPerDay, isTrue);
      expect(_pc.weatherAskMin, 1440);
      // 계절 4 × 16색, 지역 7색·통의 15%, 배낭 묶음, 통 그림 이름
      expect(_pc.seasonHex.keys, Season.values);
      expect(_pc.seasonHex.values.map((t) => t.length), everyElement(8));
      expect(_pc.regions.keys,
          ['capital', 'gangwon', 'chungcheong', 'jeolla', 'gyeongsang', 'jeju', 'ulleung']);
      expect(_pc.regionChancePerTube, 0.15);
      expect(_pc.backpack.order, PaintGroup.values);
      expect(_pc.backpack.recentCount, 3);
      expect(_pc.backpack.collapsible, isTrue);
      // v30: 처음에 모두 펼침 (v24는 지금 계절만)
      expect(_pc.backpack.openOnStart, PaintOpenOnStart.all);
      expect((_pc.tubeRoadSprite, _pc.tubeIconSprite), ('ui_paint_tube_road_v01', 'ui_paint_tube_icon_v01'));
      // 지도 물감 길 테두리 (mapTrail.paint.border)
      expect((rules.mapTrail.borderColor, rules.mapTrail.borderAlpha, rules.mapTrail.borderExtraPt),
          (0xFF3E2C22, 0.25, 1.0));
    });

    test('색: 11/15 확정 {walk, run} 쌍 (intensity 없음), 계절이 붙으면 그 계절 hex', () {
      expect(_pc.hexOf('sunset'), 0xFFF79BB7);
      expect(_pc.hexOf('sunset_run'), 0xFFE07397);
      expect(_pc.hexOf('rain'), 0xFF85D5C5);
      expect(_pc.hexOf('snow_run'), 0xFF98C9D2);
      expect(_pc.hexOf('basic'), 0xFFB5603A);
      expect(_pc.hexOf('모르는색'), 0xFFB5603A);
      // 계절 키: 가을 노을 #F798A8 (캔버스 6-1·지도 첫 구간 색), 여름 진한 낮 #00A3D3
      expect(_pc.hexOf('autumn.sunset'), 0xFFF798A8);
      expect(_pc.hexOf('summer.day_run'), 0xFF00A3D3);
      // 지역 색 (계절·뛰기 변주 없음)
      expect(_pc.hexOf('region.kr.capital'), 0xFFEF937C);
      expect(_pc.hexOf('region.kr.jeju'), 0xFFFF8F65);
      expect(_pc.hexOf('region.kr.mars'), 0xFFB5603A);
    });

    test('이름 (config names): 기본·계절·진한·지역 색 이름', () {
      expect(_pc.nameOf('basic'), '기본');
      expect(_pc.nameOf('sunset'), '노을');
      expect(_pc.nameOf('autumn.sunset'), '가을 노을');
      expect(_pc.nameOf('autumn.sunset_run'), '가을 진한 노을');
      expect(_pc.nameOf('summer.rain'), '여름 비');
      expect(_pc.nameOf('winter.snow_run'), '겨울 진한 눈');
      expect(_pc.nameOf('region.kr.capital'), '수도권 단청 주홍');
      expect(_pc.nameOf('region.kr.ulleung'), '울릉 나리 초록');
    });

    test('아는 색 id: 기본·16색·계절 64색·지역 7색', () {
      final all = [
        'basic',
        ..._pc.colorIds,
        for (final s in Season.values) ..._pc.seasonIds(s),
        for (final r in _pc.regions.values) r.stockId,
      ];
      expect(all.toSet(), hasLength(1 + 16 + 64 + 7));
      expect(all.every(_pc.knows), isTrue);
      expect(_pc.seasonIds(Season.autumn).first, 'autumn.dawn');
      expect(_pc.knows('autumn.hail'), isFalse);
      expect(_pc.knows('monsoon.rain'), isFalse);
      expect(_pc.knows('region.kr.mars'), isFalse);
      expect(paintSeason('spring.dawn'), Season.spring);
      expect(paintSeason('dawn'), isNull);
      expect(paintSeason('region.kr.jeju'), isNull);
    });

    test('배낭 남은 거리 꼬리표는 0.1km 내림', () {
      expect(_pc.backpack.remainKm(1299), closeTo(1.2, 1e-9));
      expect(_pc.backpack.remainKm(1300), closeTo(1.3, 1e-9));
      expect(_pc.backpack.remainKm(99), 0);
    });

    test('v24 모르는 값 거부: 날씨 per, 다시 고르기, 계절 달 출처, 지역 기준, 통 그림 색, 묶음', () {
      expect(() => _rulesWith((j) => j['paintColor']['weatherSource']['per'] = 'hour'), throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['choose']['reselectOnRefill'] = true),
          throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['season']['monthsFrom'] = 'own'), throwsFormatException);
      expect(() => _rulesWith((j) => (j['paintColor']['season']['hex'] as Map).remove('winter')),
          throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['region']['by'] = 'gps'), throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['region']['colors']['jeju']['id'] = 'kr.capital'),
          throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['tube']['sprites']['tint'] = 'overlay'),
          throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['backpack']['order'] = ['recent', 'basic']),
          throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['backpack']['remainRound'] = 'round'),
          throwsFormatException);
    });

    test('뛰기 hex를 따로 주면 그 값 (11/15 디자인 기획 모양)', () {
      final r = _rulesWith((j) {
        (j['paintColor']['timePhase'] as Map<String, dynamic>)['sunset'] = {
          'walk': '#F79BB7',
          'run': '#E07397',
        };
      });
      expect(r.paintColor.hexOf('sunset'), 0xFFF79BB7);
      expect(r.paintColor.hexOf('sunset_run'), 0xFFE07397);
      // 옛 모양(문자열 하나 + intensity.run 계산식)도 읽는다: 뛰기는 더 어둡게
      final old = _rulesWith((j) {
        j['paintColor']['timePhase']['day'] = '#6FA8C9';
        j['paintColor']['intensity'] = {
          'run': {'darken': 0.18, 'saturate': 0.15},
        };
      });
      int luma(int c) => ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF);
      expect(old.paintColor.hexOf('day'), 0xFF6FA8C9);
      expect(luma(old.paintColor.hexOf('day_run')), lessThan(luma(0xFF6FA8C9)));
    });

    test('모든 색을 쌍으로 주면 intensity가 없어도 되고, 문자열 색이 하나라도 있으면 intensity.run이 있어야 한다', () {
      Map<String, String> pair(String w, String r) => {'walk': w, 'run': r};
      final r = _rulesWith((j) {
        final pc = j['paintColor'] as Map<String, dynamic>;
        pc.remove('intensity');
        for (final k in ['dawn', 'morning', 'day', 'sunset', 'night']) {
          pc['timePhase'][k] = pair('#C0ADE6', '#A18AD0');
        }
        for (final k in ['rain', 'snow', 'cloudy']) {
          pc['weather'][k] = pair('#CEE7EC', '#98C9D2');
        }
      });
      expect(r.paintColor.hexOf('snow_run'), 0xFF98C9D2);
      expect(() => _rulesWith((j) => j['paintColor']['timePhase']['day'] = '#6FA8C9'),
          throwsFormatException);
    });

    test('보상 표 목록(paintDrop.rewards)이 있으면 그것을 읽고, 모르는 kind·확률 합 1 초과는 거부', () {
      final r = _rulesWith((j) {
        j['paintDrop']['rewards'] = [
          {'kind': 'tube', 'chance': 0.25},
        ];
      });
      expect(r.paintColor.rewards.single.chance, 0.25);
      expect(
          () => _rulesWith((j) => j['paintDrop']['rewards'] = [
                {'kind': 'shortcut', 'chance': 0.01},
              ]),
          throwsFormatException);
      expect(
          () => _rulesWith((j) => j['paintDrop']['rewards'] = [
                {'kind': 'tube', 'chance': 0.7},
                {'kind': 'tube', 'chance': 0.4},
              ]),
          throwsFormatException);
    });

    test('틀린 값 거부: hex 모양, amountM 순서, 오프라인 규칙', () {
      expect(() => _rulesWith((j) => j['paintColor']['timePhase']['day'] = 'blue'), throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['tube']['amountM'] = [1540, 770]), throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['weatherSource']['offline'] = 'basic'),
          throwsFormatException);
      expect(() => _rulesWith((j) => j['paintColor']['default']['infinite'] = false), throwsFormatException);
    });
  });

  group('④ colorOf 표 16개 · ⑤ 날씨 null', () {
    test('날씨 비·눈·흐림이면 날씨 색, 맑음·모름이면 시간대 색, 뛰기면 _run', () {
      final seen = <String>{};
      for (final phase in SkyPhase.values) {
        for (final gait in Gait.values) {
          final suffix = gait == Gait.run ? '_run' : '';
          expect(colorOf(phase, PaintWeather.clear, gait), '${phase.name}$suffix');
          seen.add(colorOf(phase, PaintWeather.clear, gait));
          for (final w in [PaintWeather.rain, PaintWeather.snow, PaintWeather.cloudy]) {
            expect(colorOf(phase, w, gait), '${w.name}$suffix');
            seen.add(colorOf(phase, w, gait));
          }
        }
      }
      expect(seen, unorderedEquals(_pc.colorIds));
    });

    test('⑤ 날씨 null(오프라인·실패) = 시간대 색', () {
      expect(colorOf(SkyPhase.night, null, Gait.walk), 'night');
      expect(colorOf(SkyPhase.dawn, null, Gait.run), 'dawn_run');
      expect(paintWeatherOf('hail'), isNull);
      expect(paintWeatherOf('rain'), PaintWeather.rain);
    });

    test('그 순간 시간대: 서울 11/18 낮 12시는 낮, 밤 11시는 밤 (scene.sky 키 구간)', () {
      const seoul = LatLng(37.5665, 126.978);
      // KST 12:00 = UTC 03:00
      expect(paintPhaseAt(seoul, DateTime.utc(2026, 11, 18, 3), rules), SkyPhase.day);
      expect(paintPhaseAt(seoul, DateTime.utc(2026, 11, 18, 14), rules), SkyPhase.night);
      // 그날(11월 = 가을) 계절이 붙는다 (M1 v0.8: 방울 색도 그날 계절 hex)
      expect(momentColorAt(seoul, DateTime.utc(2026, 11, 18, 3), PaintWeather.snow, Gait.run, rules),
          'autumn.snow_run');
      expect(momentColorAt(seoul, DateTime.utc(2026, 11, 18, 3), null, Gait.walk, rules), 'autumn.day');
    });

    test('⑪ 3월 1일 00:00(한국)에 주운 통 = spring.*, 2월 28일 23:59 = winter.* (주운 날 한국 날짜의 계절)', () {
      const seoul = LatLng(37.5665, 126.978);
      // KST 2027-03-01 00:00 = UTC 2027-02-28 15:00
      expect(momentColorAt(seoul, DateTime.utc(2027, 2, 28, 15), null, Gait.walk, rules), startsWith('spring.'));
      expect(momentColorAt(seoul, DateTime.utc(2027, 2, 28, 14, 59), null, Gait.walk, rules),
          startsWith('winter.'));
      expect(momentColorAt(seoul, DateTime.utc(2027, 2, 28, 15), PaintWeather.rain, Gait.run, rules),
          'spring.rain_run');
    });

    test('⑫ 지역 = 가장 가까운 명소의 권역: 제주 명소 근처 → region.kr.jeju, 서울 → region.kr.capital', () {
      expect(regionPaintAt(const LatLng(33.4996, 126.5312), landmarks, rules)!.stockId, 'region.kr.jeju');
      expect(regionPaintAt(const LatLng(37.5665, 126.978), landmarks, rules)!.stockId, 'region.kr.capital');
      expect(regionPaintAt(const LatLng(37.4844, 130.9057), landmarks, rules)!.stockId, 'region.kr.ulleung');
      expect(regionPaintAt(const LatLng(37.5665, 126.978), const [], rules), isNull);
    });

    test('색 id 읽기: 계절이 붙어도 시간대·날씨·뛰기를 읽고, 기본·지역 색은 null', () {
      final b = paintBase('autumn.rain_run')!;
      expect((b.phase, b.weather, b.run), (null, PaintWeather.rain, true));
      expect(paintBase('sunset')!.phase, SkyPhase.sunset);
      expect(paintBase('basic'), isNull);
      expect(paintBase('region.kr.capital'), isNull);
    });
  });

  group('⑥ 방울 보상 (물감 길·방울 번호로 정하는 무작위)', () {
    test('난수를 고정하면 정한 대로: 0.05 → 통(양은 amount 수로), 0.1 이상 → 없음', () {
      double fixed(int trail, int drop, String slot) => switch (slot) {
            'reward' => drop.isEven ? 0.05 : 0.5,
            'amount' => 0.5,
            _ => 0.0,
          };
      var tubes = 0;
      for (var k = 1; k <= 100; k++) {
        final roll = rollDrop(7, k, _pc, random: fixed);
        if (!roll.tube) {
          expect(roll.reward, isNull);
          continue;
        }
        tubes++;
        // 770 + 내림(0.5 × 771)
        expect(roll.amountM, 770 + 385);
      }
      expect(tubes, 50);
      // 경계: 0.1은 통이 아니고, 0.0999…는 통. 양 끝은 770·1,540
      expect(rollDrop(1, 1, _pc, random: (_, _, s) => s == 'reward' ? 0.1 : 0).tube, isFalse);
      expect(rollDrop(1, 1, _pc, random: (_, _, s) => s == 'reward' ? 0.0999 : 0).amountM, 770);
      expect(rollDrop(1, 1, _pc, random: (_, _, s) => s == 'reward' ? 0 : 0.99999999).amountM, 1540);
    });

    test('지역 색은 통 확률과 따로 굴린다: region 수 < 0.15면 지역 색 통, 통이 아니면 지역도 아님', () {
      DropRoll roll(double reward, double region) =>
          rollDrop(1, 1, _pc, random: (_, _, s) => switch (s) {
                'reward' => reward,
                'region' => region,
                _ => 0.5,
              });
      expect(roll(0.05, 0.1).region, isTrue);
      expect(roll(0.05, 0.1499).region, isTrue);
      expect(roll(0.05, 0.15).region, isFalse);
      expect(roll(0.5, 0.0).region, isFalse);
      expect(roll(0.5, 0.0).tube, isFalse);
      // 지역 색이어도 양은 같은 규칙
      expect(roll(0.05, 0.1).amountM, 770 + 385);
    });

    test('⑩ 기본 무작위: 통 1만 개 중 지역 색 약 15%', () {
      var tubes = 0;
      var region = 0;
      for (var trail = 1; tubes < 10000; trail++) {
        for (var k = 1; k <= 100; k++) {
          final r = rollDrop(trail, k, _pc);
          if (!r.tube) continue;
          tubes++;
          if (r.region) region++;
        }
      }
      expect(region / tubes, closeTo(0.15, 0.015));
    });

    test('기본 무작위: 방울 100개에서 통 수·양이 범위 안, 다시 굴려도 같고, 1만 개면 약 10%', () {
      final first = [for (var k = 1; k <= 100; k++) rollDrop(3, k, _pc)];
      final again = [for (var k = 1; k <= 100; k++) rollDrop(3, k, _pc)];
      expect([for (final r in again) (r.tube, r.amountM)], [for (final r in first) (r.tube, r.amountM)]);
      final tubes = first.where((r) => r.tube).toList();
      expect(tubes.length, inInclusiveRange(1, 30));
      for (final t in tubes) {
        expect(t.amountM, inInclusiveRange(770, 1540));
      }
      var many = 0;
      final amounts = <int>[];
      for (var trail = 1; trail <= 100; trail++) {
        for (var k = 1; k <= 100; k++) {
          final r = rollDrop(trail, k, _pc);
          if (r.tube) {
            many++;
            amounts.add(r.amountM);
          }
        }
      }
      expect(many / 10000, closeTo(0.1, 0.015));
      final mean = amounts.fold(0, (a, b) => a + b) / amounts.length;
      expect(mean, closeTo((770 + 1540) / 2, 40));
      // 다른 물감 길은 다른 방울에 통이 나온다
      expect([for (var k = 1; k <= 100; k++) rollDrop(4, k, _pc).tube],
          isNot([for (final r in first) r.tube]));
    });
  });

  group('⑦ 칠하기 · ⑨ 럭', () {
    test('⑦ 남은 300m로 500m 칠하면 고른 색 300m + 기본 200m, 남은 0', () {
      final s = paintSplit(300, 500);
      expect((s.usedM, s.basicM, s.leftM, s.ranOut), (300.0, 200.0, 0.0, true));
      final more = paintSplit(800, 500);
      expect((more.usedM, more.basicM, more.leftM, more.ranOut), (500.0, 0.0, 300.0, false));
      expect(paintSplit(0, 100).ranOut, isFalse);
    });

    test('⑦ 지도 구간: 칠한 색이 바뀌면 물감 구간이 나뉜다 (고른 색 → 기본)', () {
      // 1분 100보(70m)씩 앱 밖 2분, 물감 길 6분(앞 4분 노을, 뒤 2분 기본)
      final minutes = [
        for (var i = 0; i < 8; i++)
          MinuteTravel(minute: 1000 + i, steps: 100, actualM: 70, inTrail: i >= 2),
      ];
      final segs = trailSegments(
        fundKm: 0,
        minutes: minutes,
        paintAt: (m) => m < 1006 ? 'sunset' : 'basic',
      );
      expect(segs, [
        const TrailSegment(0, 0.14, TrailKind.pencil),
        const TrailSegment(0.14, 0.42, TrailKind.paint, 'sunset'),
        const TrailSegment(0.42, 0.56, TrailKind.paint, 'basic'),
      ]);
      // 색을 안 주면 T9처럼 물감 한 구간
      expect(trailSegments(fundKm: 0, minutes: minutes).last,
          const TrailSegment(0.14, 0.56, TrailKind.paint));
    });

    test('그 분에 칠한 색: 그 시각 구간 색 (물감 길 하나에 구간 여럿), 물감 길 밖·색 없는 옛 물감 길은 기본', () {
      const trails = [
        TrailPaint(startMs: 100, endMs: 200, segments: [
          PaintSegment(100, 'autumn.sunset'),
          PaintSegment(130, 'region.kr.capital'),
          PaintSegment(150, 'basic'),
          PaintSegment(170, 'autumn.rain'),
        ]),
        TrailPaint(startMs: 300, endMs: 400),
        TrailPaint(startMs: 500, segments: [PaintSegment(500, 'rain')]),
      ];
      expect(paintedColorAt(trails, 50, 'basic'), 'basic');
      expect(paintedColorAt(trails, 100, 'basic'), 'autumn.sunset');
      expect(paintedColorAt(trails, 129, 'basic'), 'autumn.sunset');
      expect(paintedColorAt(trails, 130, 'basic'), 'region.kr.capital');
      expect(paintedColorAt(trails, 150, 'basic'), 'basic');
      expect(paintedColorAt(trails, 199, 'basic'), 'autumn.rain');
      expect(paintedColorAt(trails, 250, 'basic'), 'basic');
      expect(paintedColorAt(trails, 350, 'basic'), 'basic');
      // 열린 물감 길은 끝이 없다
      expect(paintedColorAt(trails, 99999, 'basic'), 'rain');
      expect(paintedColorAt(const [], 1, 'basic'), 'basic');
    });

    test('지도 구간: 걷는 중에 바꾼 색마다 물감 구간이 나뉜다 (노을 → 지역 → 기본)', () {
      final minutes = [
        for (var i = 0; i < 6; i++) MinuteTravel(minute: 2000 + i, steps: 100, actualM: 70, inTrail: true),
      ];
      final segs = trailSegments(
        fundKm: 0,
        minutes: minutes,
        paintAt: (m) => m < 2002 ? 'autumn.sunset' : (m < 2004 ? 'region.kr.capital' : 'basic'),
      );
      expect([for (final s in segs) s.colorId], ['autumn.sunset', 'region.kr.capital', 'basic']);
      expect(segs.map((s) => s.toKm - s.fromKm), everyElement(closeTo(0.14, 1e-9)));
    });

    test('가진 통 수 = 주운 차례로 쓴 뒤 다 안 쓴 통', () {
      expect(tubesLeft([800, 900, 1000], 0), 3);
      expect(tubesLeft([800, 900, 1000], 799), 3);
      expect(tubesLeft([800, 900, 1000], 800), 2);
      expect(tubesLeft([800, 900, 1000], 2700), 0);
    });

    test('⑨ 럭은 통과 상관없이 방울마다 +1 (물감 길 거리로 센다)', () {
      // 물감 길 1km = 방울 10개 = 10럭 (+ 모든 걸음 10럭), 통이 몇 개 나오든 같다
      expect(paintDrops(1000, rules), 10);
      expect(trailCoins(actualM: 1000, trailM: 1000, rules: rules), 20);
      expect(rules.paintDropCoinsPerDrop, 1);
    });
  });
}
