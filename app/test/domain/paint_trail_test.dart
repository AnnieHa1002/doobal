import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// M1 명세 v0.5 ⑧ (테스트 27~35 대체). 34 하루 카드는 T10 몫이라 여기 없다.
// 한국 시간 2026-11-18 10:00 = UTC 01:00. 보폭은 걷기 0.7m·뛰기 1.0m
final _t10 = DateTime.utc(2026, 11, 18, 1);
DateTime _at(int minutesAfter10, [int sec = 0]) =>
    _t10.add(Duration(minutes: minutesAfter10, seconds: sec));

/// config.json을 [edit]로 고친 규칙
Rules _rulesWith(void Function(Map<String, dynamic> config) edit) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  edit(j);
  return Rules.fromJson(j);
}

/// 10:00 + [startAfter]분부터 분당 [spm]보로 [minutes]분 걸은 분 목록
List<StepMinute> _walk(int minutes, int spm, {int startAfter = 0}) =>
    minutesFrom(_at(startAfter), List.filled(minutes, spm));

List<MinuteTravel> _split(
  List<StepMinute> minutes,
  List<PaintTrailWindow> windows, {
  DateTime? now,
}) =>
    splitTravel(
      minutes: classifyGait(minutes, rules),
      windows: windows,
      now: now ?? _at(600),
      rules: rules,
    );

/// 10:00 + [fromMin]분부터 [count]분 동안 분마다 [perMin]보씩 들어온 센서 걸음 (분 안 30초에)
List<SensorGain> _gains(int fromMin, int count, int perMin, {bool foreground = true}) => [
      for (var i = 0; i < count; i++)
        SensorGain(_at(fromMin + i, 30), perMin, foreground: foreground),
    ];

void main() {
  group('규칙 (config paintTrail·paintDrop·events)', () {
    test('data-v13 값 그대로: 60초 10보·5분·10럭/km·100m·방울 1럭·꺼진 동안 카드 1장', () {
      expect(rules.paintTrailStartSteps, 10);
      expect(rules.paintTrailStartWithinSec, 60);
      expect(rules.paintTrailIdleEndMin, 5);
      expect(rules.paintDropCoinsPerKm, 10);
      expect(rules.paintDropSpacingM, 100);
      expect(rules.paintDropCoinsPerDrop, 1);
      expect(rules.eventOffScreenCards, 1);
      expect(rules.coinsPerKm, 10);
      expect(rules.coinsDailyCap, 400);
    });

    test('모르는 거리 기준·0 이하 값은 거부한다', () {
      expect(() => _rulesWith((j) => (j['props'] as Map)['distanceBasis'] = 'walkTravel'),
          throwsFormatException);
      expect(() => _rulesWith((j) => (j['events'] as Map)['distanceBasis'] = 'appOn'),
          throwsFormatException);
      expect(
          () => _rulesWith(
              (j) => ((j['paintTrail'] as Map)['idleEndMin'] as Map)['min'] = 0),
          throwsFormatException);
      expect(
          () => _rulesWith(
              (j) => ((j['paintDrop'] as Map)['spacingM'] as Map)['m'] = 0),
          throwsFormatException);
    });
  });

  group('거리 1종 (①)', () {
    test('27 12분 × 100보 → actual 840m = travel 840m', () {
      final minutes = _walk(12, 100);
      final windows = [PaintTrailWindow(_at(0), _at(12), PaintTrailEnd.idle)];
      final t = sumTravel(_split(minutes, windows));
      expect(t.actualM, closeTo(840, 1e-9));
      expect(t.travelM, closeTo(840, 1e-9));
      expect(t.trailM, closeTo(840, 1e-9));
    });

    test('28 앱 밖 12분 × 100보 → 여정·소품 거리(actual) 840m, trail 0', () {
      final t = sumTravel(_split(_walk(12, 100), const []));
      expect(t.actualM, closeTo(840, 1e-9));
      expect(t.travelM, closeTo(840, 1e-9));
      expect(t.trailM, 0);
    });

    test('물감 길에 걸친 걷기는 분 시작이 창 안인 분만 trail', () {
      // 10:00~10:12 걷기, 물감 길 10:00~10:06 → 앞 6분(600보 × 0.7 = 420m)만
      final windows = [PaintTrailWindow(_at(0), _at(6), PaintTrailEnd.idle)];
      expect(trailM(classifyGait(_walk(12, 100), rules), windows, now: _at(60), rules: rules),
          closeTo(420, 1e-9));
    });

    test('열린 물감 길은 지금까지로 센다', () {
      final windows = [PaintTrailWindow(_at(0))];
      final minutes = classifyGait(_walk(12, 100), rules);
      expect(trailM(minutes, windows, now: _at(5), rules: rules), closeTo(350, 1e-9));
      expect(trailM(minutes, windows, now: _at(30), rules: rules), closeTo(840, 1e-9));
    });

    test('뛰기 분도 실제 거리: 걸음 × 1.0m', () {
      final t = sumTravel(_split(_walk(3, 150), [PaintTrailWindow(_at(0))]));
      expect(t.actualM, closeTo(450, 1e-9));
      expect(t.trailM, closeTo(450, 1e-9));
    });

    test('한국 날짜별 합: 자정을 넘으면 날이 나뉜다', () {
      // 한국 23:58 = UTC 14:58
      final start = DateTime.utc(2026, 11, 18, 14, 58);
      final minutes = minutesFrom(start, [100, 100, 100, 100]);
      final byDay = dailyTravel(splitTravel(
        minutes: classifyGait(minutes, rules),
        windows: [PaintTrailWindow(start)],
        now: start.add(const Duration(hours: 1)),
        rules: rules,
      ));
      expect(byDay['2026-11-18']!.actualM, closeTo(140, 1e-9));
      expect(byDay['2026-11-19']!.trailM, closeTo(140, 1e-9));
    });
  });

  group('액자 (①)', () {
    test('29 60km 여정을 모두 걸으면 실제 60km → 금', () {
      expect(frameFor(frameBasisKm(0, 60, 60), rules), Frame.gold);
      // 경비 10km + 50km도 같다. 넘친 걸음은 여정 거리에서 자른다
      expect(frameBasisKm(10, 55, 60), 60);
    });
  });

  group('럭 (③)', () {
    test('30 물감 길 밖 2km + 안 1km → 30 + 10 = 40', () {
      // 하루 실제 3km 중 물감 길 1km
      const day = TravelTotals(actualM: 3000, trailM: 1000);
      expect(dailyCoins(day, rules), 40);
      // 같은 합이면 몇 번을 다시 계산해도 같다
      expect(dailyCoins(day, rules), 40);
    });

    test('하루 상한 400: 50km(물감 길 0) → 400, 30km 중 20km 물감 길 → 300 + 200 → 400', () {
      expect(dailyCoins(const TravelTotals(actualM: 50000), rules), 400);
      expect(dailyCoins(const TravelTotals(actualM: 30000, trailM: 20000), rules), 400);
      expect(dailyCoins(const TravelTotals(actualM: 12000, trailM: 9000), rules), 210);
    });

    test('내림: 0.15km → 1 (1.5), 물감 길이면 3 (3.0)', () {
      expect(dailyCoins(const TravelTotals(actualM: 150), rules), 1);
      expect(dailyCoins(const TravelTotals(actualM: 150, trailM: 150), rules), 3);
    });

    test('coins.perKm가 null이면 0', () {
      final r = _rulesWith((j) => (j['coins'] as Map)['perKm'] = null);
      expect(trailCoins(actualM: 5000, trailM: 5000, rules: r), 0);
    });

    test('물감 방울 = 내림(물감 길 거리 ÷ 100m)', () {
      expect(paintDrops(0, rules), 0);
      expect(paintDrops(99.9, rules), 0);
      expect(paintDrops(100, rules), 1);
      expect(paintDrops(2460, rules), 24);
    });
  });

  group('물감 길 창 (②)', () {
    test('31 센서 60초에 9보 → 시작 안 함, 10보 → 시작 (첫 걸음의 분)', () {
      final nine = [SensorGain(_at(0, 10), 4), SensorGain(_at(0, 50), 5)];
      expect(paintTrailWindows(nine, now: _at(1), rules: rules), isEmpty);

      final ten = [SensorGain(_at(0, 10), 4), SensorGain(_at(1, 5), 6)];
      final w = paintTrailWindows(ten, now: _at(2), rules: rules);
      expect(w, [PaintTrailWindow(_at(0))]);
    });

    test('60초보다 오래 걸친 10보는 시작이 아니다', () {
      final slow = [SensorGain(_at(0, 0), 5), SensorGain(_at(1, 1), 5)];
      expect(paintTrailWindows(slow, now: _at(3), rules: rules), isEmpty);
      // 60초 딱 맞으면 안이다
      final edge = [SensorGain(_at(0, 0), 5), SensorGain(_at(1, 0), 5)];
      expect(paintTrailWindows(edge, now: _at(3), rules: rules), [PaintTrailWindow(_at(0))]);
    });

    test('앱이 뒤에 있을 때·숨었던 걸음이 한꺼번에 온 것으로는 시작하지 않는다', () {
      final back = _gains(0, 3, 100, foreground: false);
      expect(paintTrailWindows(back, now: _at(5), rules: rules), isEmpty);
      final caught = [SensorGain(_at(0, 10), 500, catchUp: true)];
      expect(paintTrailWindows(caught, now: _at(5), rules: rules), isEmpty);
    });

    test('32 10:00~10:10 걷고 멈춤 → 10:15에 끝 판정, endUtc 10:10 (idle)', () {
      final walk = _gains(0, 10, 100);
      expect(paintTrailWindows(walk, now: _at(14, 59), rules: rules), [PaintTrailWindow(_at(0))]);
      expect(paintTrailWindows(walk, now: _at(15), rules: rules),
          [PaintTrailWindow(_at(0), _at(10), PaintTrailEnd.idle)]);
    });

    test('4분 쉬고 다시 걸으면 하나로 이어진다, 6분 쉬면 둘로 나뉜다', () {
      final four = [..._gains(0, 5, 100), ..._gains(9, 5, 100)];
      expect(paintTrailWindows(four, now: _at(30), rules: rules),
          [PaintTrailWindow(_at(0), _at(14), PaintTrailEnd.idle)]);
      final six = [..._gains(0, 5, 100), ..._gains(11, 5, 100)];
      expect(paintTrailWindows(six, now: _at(30), rules: rules), [
        PaintTrailWindow(_at(0), _at(5), PaintTrailEnd.idle),
        PaintTrailWindow(_at(11), _at(16), PaintTrailEnd.idle),
      ]);
    });

    test('열린 동안은 숨어 있어도 걸음을 센다 (화면을 꺼도 이어진다)', () {
      final events = [..._gains(0, 3, 100), ..._gains(3, 10, 100, foreground: false)];
      expect(paintTrailWindows(events, now: _at(30), rules: rules),
          [PaintTrailWindow(_at(0), _at(13), PaintTrailEnd.idle)]);
    });

    test('33 끝나지 않은 창 + 앱이 10:20에 끝남 → 10:20(appEnded)', () {
      final walk = _gains(0, 20, 100);
      expect(paintTrailWindows(walk, aliveUtc: _at(20), now: _at(90), rules: rules),
          [PaintTrailWindow(_at(0), _at(20), PaintTrailEnd.appEnded)]);
      expect(orphanEnd(_at(0), _at(20)), _at(20));
      // 살아 있던 시각이 시작보다 앞이거나 없으면 시작에 닫는다 (길이 0)
      expect(orphanEnd(_at(5), _at(1)), _at(5));
      expect(orphanEnd(_at(5), null), _at(5));
    });

    test('앱이 끝나기 전에 걸음이 멈춰 있었으면 idle로 끝난 자리', () {
      final walk = _gains(0, 5, 100);
      expect(paintTrailWindows(walk, aliveUtc: _at(20), now: _at(90), rules: rules),
          [PaintTrailWindow(_at(0), _at(5), PaintTrailEnd.idle)]);
    });

    test('판정기: 이어 받은 창도 마지막 걸음부터 5분을 센다', () {
      final t = PaintTrailTracker(rules)..resume(_at(0), lastStep: _at(7, 20));
      expect(t.idleEnd(_at(12, 59)), isNull);
      expect(t.idleEnd(_at(13)), _at(8));
      expect(t.close(_at(8), PaintTrailEnd.idle),
          PaintTrailWindow(_at(0), _at(8), PaintTrailEnd.idle));
      expect(t.active, isFalse);
    });
  });

  group('지도 물감 길 (⑤)', () {
    test('35 앱 밖 3km → 앱 2km → [pencil 0~3, paint 3~5]', () {
      // 분마다 1km씩 (거리만 본다)
      final minutes = [
        for (var i = 0; i < 3; i++)
          MinuteTravel(minute: i, steps: 0, actualM: 1000, inTrail: false),
        for (var i = 3; i < 5; i++)
          MinuteTravel(minute: i, steps: 0, actualM: 1000, inTrail: true),
      ];
      expect(trailSegments(fundKm: 0, minutes: minutes), const [
        TrailSegment(0, 3, TrailKind.pencil),
        TrailSegment(3, 5, TrailKind.paint),
      ]);
    });

    test('실제 분으로: 물감 길 밖 걷기 → 물감 길 걷기', () {
      final minutes = [..._walk(10, 100), ..._walk(10, 100, startAfter: 10)];
      final windows = [PaintTrailWindow(_at(10), _at(20), PaintTrailEnd.idle)];
      final segs = trailSegments(fundKm: 0, minutes: _split(minutes, windows));
      expect(segs.length, 2);
      expect(segs[0].kind, TrailKind.pencil);
      expect(segs[0].toKm, closeTo(0.7, 1e-9));
      expect(segs[1].kind, TrailKind.paint);
      expect(segs[1].toKm, closeTo(1.4, 1e-9));
    });

    test('경비·상점 효과는 앞에 연필, 거리 배수는 곱하고, 여정 거리에서 자른다', () {
      final minutes = [
        const MinuteTravel(minute: 0, steps: 0, actualM: 1000, inTrail: true),
        const MinuteTravel(minute: 1, steps: 0, actualM: 1000, inTrail: true),
      ];
      expect(trailSegments(fundKm: 2, shopKm: 1, minutes: minutes, scale: 2, totalKm: 6), const [
        TrailSegment(0, 3, TrailKind.pencil),
        TrailSegment(3, 6, TrailKind.paint),
      ]);
    });

    test('걸음이 없으면 빈 목록', () {
      expect(trailSegments(fundKm: 0, minutes: const []), isEmpty);
    });
  });
}
