import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/domain/rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// M1 명세 v0.5 ⑧ (테스트 27~35 대체), v0.6 ①~③ (도착하면 끝·iOS 화면 꺼짐 메우기). 34 하루 카드는 T10 몫이라 여기 없다.
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

    test('data-v13 v21 값: 도착하면 끝·iOS 메우기·줍기 연출·지도 선·기본 물감', () {
      expect(rules.paintTrailEndOnArrival, isTrue);
      expect(rules.paintTrailIosBackfill, isTrue);
      final p = rules.paintPickup;
      expect((p.sizePt, p.pressedSec, p.splashSec, p.splashScaleFrom, p.splashScaleTo, p.gainFloatSec),
          (28, 0.12, 0.6, 0.6, 1.2, 1.2));
      expect(p.dropSprites, ['ui_paint_pickup_a_v01', 'ui_paint_pickup_b_v01']);
      expect((p.pressedSprite, p.splashSprite), ('ui_paint_pickup_c_v02', 'fx_paint_splash_v01'));
      final m = rules.mapTrail;
      expect((m.paintHeightPt, m.paintCapPt, m.pencilWidthPt, m.pencilColor), (10, 12, 2, 0xFF7A6A5C));
      expect((m.paintTile, m.paintCap, m.pencilTile),
          ('map_trail_drops_tile_v02', 'map_trail_drops_cap_v02', 'map_trail_pencil_tile_v01'));
      expect(rules.paintDefaultColor, 0xFFB5603A);
    });

    test('모르는 줍기·지도 규칙은 거부한다', () {
      Map<String, dynamic> pickup(Map<String, dynamic> j) =>
          (j['paintDrop'] as Map<String, dynamic>)['pickup'] as Map<String, dynamic>;
      expect(() => _rulesWith((j) => pickup(j)['reducedMotion'] = 'slow'), throwsFormatException);
      expect(() => _rulesWith((j) => pickup(j)['night'] = 'own'), throwsFormatException);
      expect(() => _rulesWith((j) => pickup(j)['splashScale'] = [1]), throwsFormatException);
      expect(() => _rulesWith((j) => (j['mapTrail'] as Map)['nonScaling'] = false),
          throwsFormatException);
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

    test('감지 걸음(16장 11/19): 0.5초마다 한 걸음이면 10번째 걸음(약 5초)에 첫 걸음의 분으로 연다', () {
      final tracker = PaintTrailTracker(rules);
      DateTime step(int k) => _at(0, 20).add(Duration(milliseconds: 500 * k));
      for (var k = 0; k < 9; k++) {
        expect(tracker.add(SensorGain(step(k), 1, detected: true)), isNull);
      }
      expect(tracker.add(SensorGain(step(9), 1, detected: true)), _at(0));
      expect(step(9).difference(step(0)), const Duration(milliseconds: 4500));
      expect(tracker.lastStartSteps, 10);
      expect(tracker.lastStartDetected, isTrue);
      expect(tracker.lastStartGains.map((g) => g.at), [for (var k = 0; k < 10; k++) step(k)]);
      // 열린 뒤 감지 걸음은 마지막 걸음을 옮긴다
      tracker.add(SensorGain(_at(3), 1, detected: true));
      expect(tracker.lastStep, _at(3));
    });

    test('감지 걸음과 카운터 걸음은 같은 걸음이라 더하지 않는다: 어느 한쪽이 10보를 넘어야 연다', () {
      final mixed = [
        for (var k = 0; k < 6; k++) SensorGain(_at(0, 10 + k), 1, detected: true),
        SensorGain(_at(0, 20), 6),
      ];
      expect(paintTrailWindows(mixed, now: _at(1), rules: rules), isEmpty);
      // 카운터가 몰아 보낸 10보로도 열린다 (감지 센서가 없는 기기·감지가 늦을 때)
      final counter = [...mixed, SensorGain(_at(0, 40), 4)];
      final tracker = PaintTrailTracker(rules);
      DateTime? opened;
      for (final g in counter) {
        opened ??= tracker.add(g);
      }
      expect(opened, _at(0));
      expect(tracker.lastStartDetected, isFalse);
      expect(tracker.lastStartSteps, 10);
    });

    test('숨었다 돌아오면 감지 걸음 창도 비운다', () {
      final tracker = PaintTrailTracker(rules);
      for (var k = 0; k < 9; k++) {
        tracker.add(SensorGain(_at(0, k), 1, detected: true));
      }
      tracker.add(SensorGain(_at(0, 10), 50, foreground: false));
      expect(tracker.add(SensorGain(_at(0, 11), 1, detected: true)), isNull);
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

  group('도착하면 물감 길이 끝난다 (M1 v0.6, 16장 11/14)', () {
    test('① 물감 길 중 도착 → 그 창의 끝 = 도착 시각(arrived), trailM은 도착까지', () {
      final walk = _gains(0, 10, 100);
      final w = paintTrailWindows(walk, arrivals: [_at(6, 45)], now: _at(30), rules: rules);
      // 도착 뒤 10:07:30의 100보로 새 창이 열리고, 걸음이 멈춰 10:10에 끝난다
      expect(w, [
        PaintTrailWindow(_at(0), _at(6, 45), PaintTrailEnd.arrived),
        PaintTrailWindow(_at(7), _at(10), PaintTrailEnd.idle),
      ]);
      // 분 시작이 도착 전인 10:00~10:06 7분 × 100보 × 0.7m
      expect(trailM(classifyGait(_walk(10, 100), rules), [w.first], now: _at(30), rules: rules),
          closeTo(490, 1e-9));
    });

    test('② 도착 뒤 60초에 9보 → 새 창 없음, 10보 → 새 창 (도착 직전 걸음은 세지 않는다)', () {
      final events = [
        ..._gains(0, 5, 100),
        // 도착 직전 5보 + 도착 뒤 4보: 합하면 9보 (도착 전 걸음은 새 창 판정에 안 든다)
        SensorGain(_at(4, 50), 5),
        SensorGain(_at(5, 20), 4),
        SensorGain(_at(5, 50), 5),
      ];
      final nine = paintTrailWindows(events, arrivals: [_at(5)], now: _at(6), rules: rules);
      expect(nine, [PaintTrailWindow(_at(0), _at(5), PaintTrailEnd.arrived)]);
      final ten = paintTrailWindows([...events, SensorGain(_at(6, 10), 1)],
          arrivals: [_at(5)], now: _at(7), rules: rules);
      expect(ten, [
        PaintTrailWindow(_at(0), _at(5), PaintTrailEnd.arrived),
        PaintTrailWindow(_at(5)),
      ]);
    });

    test('도착이 분 가운데면 새 창은 도착 시각부터 (창이 겹치지 않는다)', () {
      final events = [..._gains(0, 5, 100), SensorGain(_at(5, 40), 12)];
      expect(paintTrailWindows(events, arrivals: [_at(5, 10)], now: _at(6), rules: rules), [
        PaintTrailWindow(_at(0), _at(5, 10), PaintTrailEnd.arrived),
        PaintTrailWindow(_at(5, 10)),
      ]);
    });

    test('도착 전에 걸음이 멈춰 끝난 창은 idle 그대로, 열린 창이 없을 때 도착은 아무것도 안 한다', () {
      final walk = _gains(0, 3, 100);
      expect(paintTrailWindows(walk, arrivals: [_at(20)], now: _at(30), rules: rules),
          [PaintTrailWindow(_at(0), _at(3), PaintTrailEnd.idle)]);
      expect(paintTrailWindows(const [], arrivals: [_at(20)], now: _at(30), rules: rules), isEmpty);
    });
  });

  group('iOS 화면 꺼짐 메우기 (M1 v0.6, 16장 11/14)', () {
    /// 10:00~10:09 앞에서 걸어 연 판정기 (마지막 걸음 10:09:30), 10:10에 화면을 껐다
    PaintTrailTracker opened() {
      final t = PaintTrailTracker(rules);
      for (final g in _gains(0, 10, 100)) {
        t.add(g);
      }
      expect((t.start, t.lastStep), (_at(0), _at(9, 30)));
      return t;
    }

    test('③ 화면 끈 20분 1,500보 → 같은 물감 길에 1.05km 더해짐, 방울 10개분 10럭', () {
      final hidden = minutesFrom(_at(10), List.filled(20, 75));
      // 메우지 않으면 꺼지기 전 마지막 걸음 분 끝(10:10)에 끝난다
      expect(opened().idleEnd(_at(31)), _at(10));
      final t = opened();
      expect(t.backfill(hidden), _at(29));
      expect(t.idleEnd(_at(31)), isNull);
      expect(t.idleEnd(_at(35)), _at(30));

      final health = classifyGait([..._walk(10, 100), ...hidden], rules);
      double trail(DateTime end) => trailM(health, [PaintTrailWindow(_at(0), end, PaintTrailEnd.idle)],
          now: _at(40), rules: rules);
      final added = trail(_at(30)) - trail(_at(10));
      expect(added, closeTo(1050, 1e-9));
      expect(paintDrops(added, rules) * rules.paintDropCoinsPerDrop, 10);
      expect(trailCoins(actualM: 0, trailM: added, rules: rules), 10);
    });

    test('꺼진 동안 5분 넘게 빈 곳이 있으면 거기서 끝나고 그 뒤 걸음은 이 물감 길이 아니다', () {
      // 10:10~10:14 걷고 10:15~10:19 5분 비고 10:20~10:29 다시 걸음
      final hidden = [
        ...minutesFrom(_at(10), List.filled(5, 75)),
        ...minutesFrom(_at(20), List.filled(10, 75)),
      ];
      final t = opened();
      expect(t.backfill(hidden), _at(14));
      expect(t.idleEnd(_at(31)), _at(15));
    });

    test('4분만 비면 이어진다, 걸음 0인 분·이미 센 분은 보지 않는다', () {
      final hidden = [
        ...minutesFrom(_at(9), [500]),
        ...minutesFrom(_at(10), List.filled(5, 75)),
        ...minutesFrom(_at(15), List.filled(4, 0)),
        ...minutesFrom(_at(19), List.filled(11, 75)),
      ];
      expect(extendLastStep(_at(9, 30), hidden, rules), _at(29));
      expect(extendLastStep(_at(9, 30), minutesFrom(_at(10), [0, 0]), rules), _at(9, 30));
      // 첫 걸음 분이 이미 5분 넘게 떨어져 있으면 늘리지 않는다
      expect(extendLastStep(_at(9, 30), minutesFrom(_at(15), [80]), rules), _at(9, 30));
      expect(extendLastStep(_at(9, 30), minutesFrom(_at(14), [80]), rules), _at(14));
      expect(PaintTrailTracker(rules).backfill(hidden), isNull);
    });

    test('숨었다 돌아와 한꺼번에 들어온 걸음은 마지막 걸음을 옮기지 않는다', () {
      final t = opened()..add(SensorGain(_at(31), 1500, catchUp: true));
      expect(t.lastStep, _at(9, 30));
      expect(t.idleEnd(_at(31)), _at(10));
      t.add(SensorGain(_at(31, 20), 20));
      expect(t.lastStep, _at(31, 20));
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
