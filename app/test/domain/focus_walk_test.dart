import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/focus_walk.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/rules.dart';
import 'package:doobal/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 한국 시간 2026-11-18 10:00 = UTC 01:00. 보폭은 걷기 0.7m·뛰기 1.0m, 보너스 1.3배(보너스 0.3), 럭 2배
final _t10 = DateTime.utc(2026, 11, 18, 1);
DateTime _at(int minutesAfter10) => _t10.add(Duration(minutes: minutesAfter10));

/// config.json을 [edit]로 고친 규칙
Rules _rulesWith(void Function(Map<String, dynamic> config) edit) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  edit(j);
  return Rules.fromJson(j);
}

/// 10:00부터 분당 [spm]보로 [minutes]분 걸은 분 목록
List<StepMinute> _walk(int minutes, int spm, {int startAfter = 0}) =>
    minutesFrom(_at(startAfter), List.filled(minutes, spm));

/// 걷기/뛰기·걷기 구간·창으로 나눈 분별 나눔 (SyncService가 하는 것과 같은 순서)
List<MinuteTravel> _split(
  List<StepMinute> minutes,
  List<AppWalkWindow> windows, {
  Rules? r,
  DateTime? now,
}) {
  final rr = r ?? rules;
  return splitTravel(
    minutes: classifyGait(minutes, rr),
    sessions: detectSessions(minutes, rr),
    windows: windows,
    now: now ?? _at(600),
    rules: rr,
  );
}

void main() {
  group('규칙 (config bonus·coins)', () {
    test('config.json 값 그대로: 1.3배·럭 2배·럭 단가 미정(null)·30초마다 저장', () {
      expect(rules.bonusTravelMultiplier, 1.3);
      expect(rules.bonusCoinMultiplier, 2.0);
      expect(rules.coinsPerKm, isNull);
      expect(rules.aliveSaveSec, 30);
    });

    test('배수가 1 미만이면 거부한다 (1은 된다)', () {
      expect(() => _rulesWith((j) => (j['bonus'] as Map)['travelMultiplier'] = 0.99),
          throwsFormatException);
      expect(() => _rulesWith((j) => (j['bonus'] as Map)['coinMultiplier'] = 0.5),
          throwsFormatException);
      final one = _rulesWith((j) {
        (j['bonus'] as Map)['travelMultiplier'] = 1;
        (j['bonus'] as Map)['coinMultiplier'] = 1;
      });
      expect((one.bonusTravelMultiplier, one.bonusCoinMultiplier), (1.0, 1.0));
    });

    test('모르는 적용 범위·음수 럭 단가·0 이하 저장 간격은 거부한다, 럭 단가는 숫자도 된다', () {
      expect(() => _rulesWith((j) => (j['bonus'] as Map)['appliesTo'] = 'allWalks'),
          throwsFormatException);
      expect(() => _rulesWith((j) => (j['coins'] as Map)['perKm'] = -1), throwsFormatException);
      expect(() => _rulesWith((j) => (j['sync'] as Map)['aliveSaveSec'] = 0),
          throwsFormatException);
      expect(_rulesWith((j) => (j['coins'] as Map)['perKm'] = 10).coinsPerKm, 10.0);
    });
  });

  group('splitTravel: 명세 27~34', () {
    test('27: 창 안에서 12분 × 100보 → 실제 840m, 보너스 252m, 이동 1,092m', () {
      final split = _split(_walk(12, 100), [AppWalkWindow(_at(0), _at(12))]);
      final t = sumTravel(split);
      expect(t.actualM, closeTo(840, 1e-9));
      expect(t.bonusM, closeTo(252, 1e-9));
      expect(t.travelM, closeTo(1092, 1e-9));
      expect(t.shopM, 0);
      // 앱 걷기 이동 거리 = 실제 + 보너스 (상점 뺌)
      expect(t.walkTravelM, closeTo(1092, 1e-9));
    });

    test('28: 창 안 9분 × 150보는 걷기 1번이 아니라 보너스 0 (150보는 뛰기라 보폭 1.0m → 1,350m)', () {
      final minutes = _walk(9, 150);
      expect(detectSessions(minutes, rules).single.qualified, isFalse);
      final t = sumTravel(_split(minutes, [AppWalkWindow(_at(0), _at(9))]));
      // 150 ≥ runMinSpm(140)이라 뛰기: 9 × 150 × 1.0 = 1,350 (걷기 보폭으로 곱한 945가 아니다)
      expect(t.actualM, closeTo(1350, 1e-9));
      expect(t.bonusM, 0);
      expect(t.travelM, closeTo(1350, 1e-9));
      // 인정은 못 받았어도 창 안에서 걸은 거리라 앱 걷기 이동 거리에는 들어간다
      expect(t.walkTravelM, closeTo(1350, 1e-9));
    });

    test('29: 하루 4번째 인정 걷기(counted false)도 창 안이면 보너스를 받는다', () {
      // 10분 × 100보(1,000보) 걷기 4번, 사이는 5분씩 비어서 서로 다른 구간
      final minutes = [
        for (var i = 0; i < 4; i++) ..._walk(10, 100, startAfter: i * 15),
      ];
      final sessions = detectSessions(minutes, rules);
      expect(sessions.map((s) => s.qualified), [true, true, true, true]);
      expect(sessions.map((s) => s.counted), [true, true, true, false]);

      // 4번째 구간(10:45~10:55)만 창 안
      final fourth = _split(minutes, [AppWalkWindow(_at(45), _at(55))]);
      final t = sumTravel(fourth);
      expect(t.actualM, closeTo(4 * 700, 1e-9));
      // 10분 × 100보 × 0.7 × 0.3 = 210 (뒤의 보너스는 4번째 것뿐)
      expect(t.bonusM, closeTo(210, 1e-9));
      expect(sessionBonusM(sessions, fourth), [0, 0, 0, closeTo(210, 1e-9)]);
    });

    test('30: 60km 여정을 전부 본격 걷기로 걸으면 실제는 60 ÷ 1.3 = 46.15km → 은 액자 (보너스 없이는 금)', () {
      // 660분 × 100보 × 0.7m = 실제 46,200m, 이동 46,200 × 1.3 = 60,060m
      final t = sumTravel(_split(_walk(660, 100), [AppWalkWindow(_at(0), _at(660))]));
      expect(t.actualM, closeTo(46200, 1e-6));
      expect(t.travelM, closeTo(60060, 1e-6));
      expect(t.travelM / 1000, greaterThanOrEqualTo(60)); // 60km 여정에 도착

      // 액자는 실제 거리로: min(경비 0 + 46.2, 60) = 46.2 → 은
      final basis = frameBasisKm(0, t.actualM / 1000, 60);
      expect(basis, closeTo(46.2, 1e-9));
      expect(frameFor(basis, rules), Frame.silver);
      // 같은 60km를 앱 없이 걸어서 도착하면(실제 60km) 금
      expect(frameFor(frameBasisKm(0, 60, 60), rules), Frame.gold);
      // 이론값 60 ÷ 1.3
      expect(frameFor(frameBasisKm(0, 60 / 1.3, 60), rules), Frame.silver);
    });

    test('33: 창이 없으면 같은 12분 × 100보도 보너스 0, 앱 걷기 이동 거리 0', () {
      final t = sumTravel(_split(_walk(12, 100), const []));
      expect(t.actualM, closeTo(840, 1e-9));
      expect(t.bonusM, 0);
      expect(t.travelM, closeTo(840, 1e-9));
      expect(t.walkTravelM, 0);
    });

    test('34: 창 10:00~10:06이 10:00~10:12 인정 걷기에 걸치면 앞 6분(600보)만 보너스 126m', () {
      final minutes = _walk(12, 100);
      final split = _split(minutes, [AppWalkWindow(_at(0), _at(6))]);
      final t = sumTravel(split);
      // 600보 × 0.7 × 0.3 = 126. 인정은 12분 전체로 가렸다
      expect(t.bonusM, closeTo(126, 1e-9));
      expect(t.actualM, closeTo(840, 1e-9));
      // 앱 걷기 이동 거리는 창 안 6분의 실제 420 + 보너스 126
      expect(t.walkTravelM, closeTo(546, 1e-9));
      expect(split.where((m) => m.isBonus).map((m) => m.minute - epochMinute(_t10)),
          [0, 1, 2, 3, 4, 5]);
    });
  });

  group('창과 걷기 구간의 경계', () {
    test('창은 시작 시각 이상·끝 시각 미만의 분 (분 시작 시각으로 가린다)', () {
      final split = _split(_walk(12, 100), [AppWalkWindow(_at(3), _at(8))]);
      expect(split.where((m) => m.inWindow).map((m) => m.minute - epochMinute(_t10)),
          [3, 4, 5, 6, 7]);
    });

    test('창이 분 중간에 시작하면 그 분은 창 밖, 중간에 끝나면 그 분은 창 안', () {
      final start = _at(2).add(const Duration(seconds: 30));
      final end = _at(8).add(const Duration(seconds: 30));
      final split = _split(_walk(12, 100), [AppWalkWindow(start, end)]);
      expect(split.where((m) => m.inWindow).map((m) => m.minute - epochMinute(_t10)),
          [3, 4, 5, 6, 7, 8]);
    });

    test('열린 창은 지금까지: 지금(now) 전 분만 창 안', () {
      final split = _split(_walk(12, 100), [AppWalkWindow(_at(0))], now: _at(5));
      expect(split.where((m) => m.inWindow).length, 5);
      // 지금이 지난 뒤로는 다 창 안
      final later = _split(_walk(12, 100), [AppWalkWindow(_at(0))], now: _at(60));
      expect(later.every((m) => m.inWindow), isTrue);
    });

    test('길이 0인 창(앱이 끝나서 시작 시각에 닫음)과 거꾸로 된 창은 아무 분도 안 덮는다', () {
      final split = _split(_walk(12, 100), [
        AppWalkWindow(_at(2), _at(2)),
        AppWalkWindow(_at(8), _at(4)),
      ]);
      expect(split.any((m) => m.inWindow), isFalse);
    });

    test('겹치거나 맞닿은 창은 한 덩어리처럼, 같은 분을 두 번 세지 않는다', () {
      final split = _split(_walk(12, 100), [
        AppWalkWindow(_at(0), _at(5)),
        AppWalkWindow(_at(4), _at(9)),
        AppWalkWindow(_at(9), _at(10)),
      ]);
      expect(split.where((m) => m.inWindow).length, 10);
      expect(sumTravel(split).bonusM, closeTo(10 * 100 * 0.7 * 0.3, 1e-9));
    });

    test('창이 여럿이면 각 창 안의 분에만 붙는다', () {
      final split = _split(_walk(12, 100), [
        AppWalkWindow(_at(0), _at(2)),
        AppWalkWindow(_at(10), _at(12)),
      ]);
      expect(split.where((m) => m.isBonus).map((m) => m.minute - epochMinute(_t10)),
          [0, 1, 10, 11]);
    });

    test('소급: 인정 전(9분째)에는 보너스가 없다가 10분·1,000보를 채우는 순간 첫 분부터 붙는다', () {
      final windows = [AppWalkWindow(_at(0))];
      // 9분 × 111보 = 999보: 10분 미만·1,000보 미만
      expect(sumTravel(_split(_walk(9, 111), windows)).bonusM, 0);
      // 10분 × 100보 = 1,000보: 인정 → 첫 분부터 전부
      final ten = _split(_walk(10, 100), windows);
      expect(ten.first.isBonus, isTrue);
      expect(sumTravel(ten).bonusM, closeTo(1000 * 0.7 * 0.3, 1e-9));
      // 10분이어도 999보면 인정이 아니다 (걸음 기준)
      final short = minutesFrom(_at(0), [...List.filled(9, 100), 99]);
      expect(sumTravel(_split(short, windows)).bonusM, 0);
    });

    test('걷기 사이가 2분 넘게 비면 다른 구간: 인정 못 한 짧은 구간은 인정 구간 옆이어도 보너스 0', () {
      // 12분 걷고 5분 쉬고 4분 걷기. 뒤의 4분은 구간이 달라서 인정되지 않는다
      final minutes = [..._walk(12, 100), ..._walk(4, 100, startAfter: 17)];
      final split = _split(minutes, [AppWalkWindow(_at(0), _at(30))]);
      expect(split.where((m) => m.isBonus).length, 12);
    });

    test('창이 인정 걷기 안 일부만 겹쳐도 인정은 구간 전체로 본다 (창 밖 구간은 못 받는다)', () {
      // 인정된 걷기(10:00~10:12) 전체가 창 밖이면 보너스 없음
      final split = _split(_walk(12, 100), [AppWalkWindow(_at(20), _at(40))]);
      expect(sumTravel(split).bonusM, 0);
    });

    test('배수가 1이면 보너스 거리는 0이지만 보너스 분(럭 2배)은 그대로다', () {
      final r1 = _rulesWith((j) => (j['bonus'] as Map)['travelMultiplier'] = 1);
      final split = _split(_walk(12, 100), [AppWalkWindow(_at(0), _at(12))], r: r1);
      final t = sumTravel(split);
      expect(t.bonusM, 0);
      expect(t.bonusActualM, closeTo(840, 1e-9));
      expect(split.every((m) => m.isBonus), isTrue);
    });
  });

  group('travelFrom: 기준 분 앞에서 이어진 걷기', () {
    test('기준 분 앞쪽에서 시작한 걷기도 한 구간으로 인정하고, 기준 분 이후의 분만 나눈다', () {
      final context = _walk(12, 100);
      // 6분째부터 센다. 구간은 12분 전체라 인정, 앞 6분은 안 센다
      final from = epochMinute(_at(6));
      final split = travelFrom(
        context: context,
        fromMinute: from,
        windows: [AppWalkWindow(_at(0), _at(12))],
        now: _at(30),
        rules: rules,
      );
      expect(split.length, 6);
      expect(sumTravel(split).bonusM, closeTo(600 * 0.7 * 0.3, 1e-9));
    });

    test('창이 없으면 걷기 구간을 안 보고 실제 = 이동', () {
      final split = travelFrom(
        context: _walk(12, 100),
        fromMinute: epochMinute(_at(0)),
        windows: const [],
        now: _at(30),
        rules: rules,
      );
      final t = sumTravel(split);
      expect(t.actualM, closeTo(840, 1e-9));
      expect(t.bonusM, 0);
      expect(t.travelM, closeTo(840, 1e-9));
    });

    test('걷기/뛰기는 기준 분부터 이어서 판정한다 (앞 분의 상태를 가져오지 않는다)', () {
      // 135보는 경계 사이라 직전 상태를 따른다. 기준 분 앞 150보(뛰기)가 있어도 기준 분부터는 걷기에서 시작
      final context = minutesFrom(_at(0), [150, 135, 135]);
      final split = travelFrom(
        context: context,
        fromMinute: epochMinute(_at(1)),
        windows: const [],
        now: _at(30),
        rules: rules,
      );
      expect(sumTravel(split).actualM, closeTo(2 * 135 * 0.7, 1e-9));
    });
  });

  group('합계·하루·구간', () {
    test('dailyTravel: 한국 날짜 자정(UTC 15:00)에서 나뉜다', () {
      // KST 11/18 23:58·23:59, 11/19 00:00·00:01 (= UTC 14:58·14:59, 15:00·15:01)
      final minutes = minutesFrom(DateTime.utc(2026, 11, 18, 14, 58), [100, 100, 100, 100]);
      final split = _split(minutes, const []);
      final days = dailyTravel(split);
      expect(days.keys.toSet(), {'2026-11-18', '2026-11-19'});
      expect(days['2026-11-18']!.actualM, closeTo(140, 1e-9));
      expect(days['2026-11-19']!.actualM, closeTo(140, 1e-9));
    });

    test('sumTravel: 같은 분이 두 번(걷기/뛰기가 한 분에 바뀜) 와도 더한다', () {
      final m = [
        const GaitMinute(5, 50, Gait.walk),
        const GaitMinute(5, 100, Gait.run),
      ];
      final split = splitTravel(
        minutes: m,
        sessions: const [],
        windows: const [],
        now: _at(30),
        rules: rules,
      );
      expect(sumTravel(split).actualM, closeTo(50 * 0.7 + 100 * 1.0, 1e-9));
    });

    test('toStepMinutes: 같은 분을 더하고 시간순으로', () {
      expect(
        toStepMinutes(const [
          GaitMinute(7, 10, Gait.walk),
          GaitMinute(5, 20, Gait.run),
          GaitMinute(7, 5, Gait.run),
        ]),
        [const StepMinute(5, 20), const StepMinute(7, 15)],
      );
    });

    test('상점은 아직 0이고 이동 거리 = 실제 + 보너스 + 상점', () {
      const m = MinuteTravel(
        minute: 1,
        steps: 100,
        actualM: 70,
        bonusM: 21,
        shopM: 5,
        inWindow: true,
        isBonus: true,
      );
      expect(m.travelM, 96);
      // 앱 걷기 이동 거리에는 상점을 안 넣는다
      expect(m.walkTravelM, 91);
      expect(sumTravel([m]).travelM, 96);
    });
  });

  group('dailyCoins', () {
    final r10 = _rulesWith((j) => (j['coins'] as Map)['perKm'] = 10);

    test('31: 럭 단가 10 (시험값): 보너스 밖 실제 2km + 보너스 분 실제 1km → 20 + 20 = 40', () {
      // 200보/분은 뛰기(1.0m): 10분 = 2km는 창 밖, 5분 = 1km는 창 안. 15분 3,000보라 한 구간으로 인정
      final minutes = _walk(15, 200);
      final split = _split(minutes, [AppWalkWindow(_at(10), _at(15))], r: r10);
      final t = sumTravel(split);
      expect(t.actualM, closeTo(3000, 1e-9));
      expect(t.bonusActualM, closeTo(1000, 1e-9));
      expect(dailyCoins(t, r10), 40);
      // 같은 값으로 다시 계산해도 같다
      expect(dailyCoins(sumTravel(_split(minutes, [AppWalkWindow(_at(10), _at(15))], r: r10)), r10),
          40);
    });

    test('럭 단가가 null이면(기획 미정) 늘 0', () {
      final t = sumTravel(_split(_walk(15, 200), [AppWalkWindow(_at(0), _at(15))]));
      expect(dailyCoins(t, rules), 0);
    });

    test('보너스가 없는 날은 실제 km × 단가를 버림', () {
      // 1,234m × 10 = 12.34 → 12
      expect(dailyCoins(const TravelTotals(actualM: 1234), r10), 12);
      expect(dailyCoins(const TravelTotals(), r10), 0);
    });

    test('부동소수 오차로 한 개 모자라지 않는다 (0.7 × 보폭 합이 정수 경계일 때)', () {
      // 0.7m × 1,000보 = 700m(부동소수로 699.999…가 될 수 있다) × 단가 10 ÷ 1000 = 7
      final t = sumTravel(_split(_walk(10, 100), const [], r: r10));
      expect(dailyCoins(t, r10), 7);
    });
  });

  group('orphanEnd (35)', () {
    test('35: 열린 창 + 마지막으로 살아 있던 시각 10:20이면 10:20에서 닫는다', () {
      expect(orphanEnd(_at(0), _at(20)), _at(20));
    });

    test('마지막으로 살아 있던 시각이 시작보다 앞서거나 없으면 시작 시각 (길이 0)', () {
      expect(orphanEnd(_at(0), _at(-5)), _at(0));
      expect(orphanEnd(_at(0), null), _at(0));
      // 같으면 그 시각
      expect(orphanEnd(_at(0), _at(0)), _at(0));
    });
  });

  group('frameBasisKm', () {
    test('경비 + 실제로 걸은 거리, 여정 전체를 넘지 않는다', () {
      expect(frameBasisKm(3, 4, 60), 7);
      expect(frameBasisKm(15, 50, 60), 60);
      expect(frameBasisKm(0, 0, 60), 0);
    });
  });
}
