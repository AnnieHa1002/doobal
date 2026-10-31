import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/laps.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// KST 10:00
final _t0 = DateTime.utc(2026, 11, 18, 1);
final _from = epochMinute(_t0);

/// 분 목록을 걷기/뛰기로 나눈다 (앱이 저장된 분을 읽을 때와 같다)
List<GaitMinute> _gaits(List<StepMinute> m) => classifyGait(m, rules);

/// 매 분 [steps]보를 [count]분 (시작은 [from] + [start]분)
List<StepMinute> _each(int count, int steps, {int start = 0}) =>
    [for (var i = 0; i < count; i++) StepMinute(_from + start + i, steps)];

/// 랩의 걸음 합 = 전체 걸음, 랩의 시간 합 = 마지막 끝 시각(초, 반올림)
void _expectTotals(List<Lap> laps, {required int steps, required int seconds}) {
  expect(laps.fold(0, (sum, l) => sum + l.steps), steps);
  expect(laps.fold(0, (sum, l) => sum + l.duration.inSeconds), seconds);
}

void main() {
  test('걸음이 없으면 빈 목록', () {
    expect(splitLaps(const [], _from, _from + 10, rules), isEmpty);
    // 걸음 0인 분만 있어도 비어 있다
    expect(splitLaps(_gaits(_each(5, 0)), _from, _from + 5, rules), isEmpty);
  });

  test('config의 랩 길이는 1km, 0 이하면 규칙을 읽지 못한다', () {
    expect(rules.lapKm, 1);
    expect(() => rulesWithLapKm(0), throwsFormatException);
    expect(() => rulesWithLapKm(-1), throwsFormatException);
  });

  group('걷기 (보폭 0.7m)', () {
    test('10분 × 100보는 1km를 못 채워 부분 랩 하나: 700m, 600초, 1,000보', () {
      // 거리 100 × 0.7 × 10 = 700m, 시간 10분 = 600초, 걸음 100 × 10
      final laps = splitLaps(_gaits(_each(10, 100)), _from, _from + 10, rules);
      expect(laps, hasLength(1));
      expect(laps[0].index, 1);
      expect(laps[0].distanceM, closeTo(700, 1e-9));
      expect(laps[0].duration, const Duration(seconds: 600));
      expect(laps[0].steps, 1000);
      expect(laps[0].partial, isTrue);
      // 페이스 = 600초 ÷ 0.7km = 857.14 → 857
      expect(laps[0].paceSecPerKm, 857);
    });

    test('15분 × 100보: 1km 랩(857초, 1,429보) + 부분 랩(50m, 43초, 71보)', () {
      // 분당 70m. 14분까지 980m, 14분째(14~15분)에 20m가 더 필요 = 그 분의 20/70.
      // 넘는 시각 = 14분 + 60초 × 20/70 = 840 + 17.142857 = 857.142857초 → 857
      // 그때까지 걸음 = 1,400 + 100 × 20/70 = 1,428.571 → 1,429
      // 부분 랩: 1,050 - 1,000 = 50m, 끝은 15분 = 900초 → 900 - 857 = 43초, 걸음 1,500 - 1,429 = 71
      final laps = splitLaps(_gaits(_each(15, 100)), _from, _from + 15, rules);
      expect(laps, hasLength(2));

      expect(laps[0].index, 1);
      expect(laps[0].distanceM, 1000);
      expect(laps[0].duration, const Duration(seconds: 857));
      expect(laps[0].steps, 1429);
      expect(laps[0].partial, isFalse);
      // 857초 ÷ 1km
      expect(laps[0].paceSecPerKm, 857);

      expect(laps[1].index, 2);
      expect(laps[1].distanceM, closeTo(50, 1e-9));
      expect(laps[1].duration, const Duration(seconds: 43));
      expect(laps[1].steps, 71);
      expect(laps[1].partial, isTrue);
      // 43초 ÷ 0.05km = 860
      expect(laps[1].paceSecPerKm, 860);

      _expectTotals(laps, steps: 1500, seconds: 900);
    });

    test('쉰 분이 랩 안에 끼면 그 시간도 랩 시간에 들어간다', () {
      // 0~4분(5분 × 100보 = 350m), 5·6·7분 쉼, 8~17분(10분 × 100보 = 700m). 모두 1,050m
      // 17분 시작까지 350 + 9 × 70 = 980m → 17분째에 20m 더 = 그 분의 2/7
      // 넘는 시각 = 17분 + 60초 × 2/7 = 1,020 + 17.142857 = 1,037.142857 → 1,037초
      // 걸음 = 500 + 900 + 100 × 2/7 = 1,428.571 → 1,429
      // 부분 랩: 50m, 끝은 18분 = 1,080초 → 1,080 - 1,037 = 43초, 걸음 1,500 - 1,429 = 71
      final m = [..._each(5, 100), ..._each(10, 100, start: 8)];
      final laps = splitLaps(_gaits(m), _from, _from + 18, rules);
      expect(laps, hasLength(2));
      expect(laps[0].duration, const Duration(seconds: 1037));
      expect(laps[0].steps, 1429);
      expect(laps[1].distanceM, closeTo(50, 1e-9));
      expect(laps[1].duration, const Duration(seconds: 43));
      expect(laps[1].steps, 71);
      _expectTotals(laps, steps: 1500, seconds: 1080);
    });

    test('시작 앞쪽의 쉰 분도 첫 랩 시간에 들어간다 (시간의 기준은 시작 분의 처음)', () {
      // 0~2분 쉼, 3~12분에 10분 × 100보 = 700m. 끝은 13분 = 780초
      final laps = splitLaps(_gaits(_each(10, 100, start: 3)), _from, _from + 13, rules);
      expect(laps, hasLength(1));
      expect(laps[0].distanceM, closeTo(700, 1e-9));
      expect(laps[0].duration, const Duration(seconds: 780));
      expect(laps[0].steps, 1000);
    });

    test('끝의 쉰 시간은 부분 랩에 넣지 않는다 (toMinute를 늘려도 같다)', () {
      // 15분 걸은 뒤 15분 더 쉰 창. 부분 랩은 걸음이 있던 마지막 분(15분 = 900초)에서 끝난다
      final g = _gaits([..._each(15, 100), ..._each(15, 0, start: 15)]);
      final laps = splitLaps(g, _from, _from + 30, rules);
      expect(laps, hasLength(2));
      expect(laps[1].duration, const Duration(seconds: 43));
      _expectTotals(laps, steps: 1500, seconds: 900);
    });

    test('랩 경계가 분 끝과 정확히 같으면 부분 랩이 생기지 않는다', () {
      // 랩 0.07km = 70m, 매 분 100보 = 70m. 2분이면 경계가 1분 끝·2분 끝이다
      // 랩 하나 = 70m, 60초, 100보
      final r = rulesWithLapKm(0.07);
      final laps = splitLaps(_gaits(_each(2, 100)), _from, _from + 2, r);
      expect(laps, hasLength(2));
      for (final l in laps) {
        expect(l.distanceM, closeTo(70, 1e-9));
        expect(l.duration, const Duration(seconds: 60));
        expect(l.steps, 100);
        expect(l.partial, isFalse);
      }
    });
  });

  group('달리기 (보폭 1.0m)', () {
    test('10분 × 150보: 1km 랩(400초, 1,000보) + 부분 랩(500m, 200초, 500보)', () {
      // 분당 150m. 6분까지 900m, 6분째(6~7분)에 100m 더 = 그 분의 100/150 = 2/3
      // 넘는 시각 = 6분 + 60초 × 2/3 = 360 + 40 = 400초, 걸음 = 900 + 150 × 2/3 = 1,000
      // 부분 랩: 1,500 - 1,000 = 500m, 끝은 10분 = 600초 → 200초, 걸음 1,500 - 1,000 = 500
      final g = _gaits(_each(10, 150));
      expect(g.every((m) => m.gait == Gait.run), isTrue);
      final laps = splitLaps(g, _from, _from + 10, rules);
      expect(laps, hasLength(2));
      expect(laps[0].distanceM, 1000);
      expect(laps[0].duration, const Duration(seconds: 400));
      expect(laps[0].steps, 1000);
      expect(laps[0].paceSecPerKm, 400);
      expect(laps[1].distanceM, closeTo(500, 1e-9));
      expect(laps[1].duration, const Duration(seconds: 200));
      expect(laps[1].steps, 500);
      // 200초 ÷ 0.5km
      expect(laps[1].paceSecPerKm, 400);
      _expectTotals(laps, steps: 1500, seconds: 600);
    });

    test('정확히 1km(5분 × 200보)면 랩 하나, 부분 랩 없음', () {
      // 분당 200m × 5분 = 1,000m, 끝은 5분 = 300초, 걸음 1,000
      final laps = splitLaps(_gaits(_each(5, 200)), _from, _from + 5, rules);
      expect(laps, hasLength(1));
      expect(laps[0].distanceM, 1000);
      expect(laps[0].duration, const Duration(seconds: 300));
      expect(laps[0].steps, 1000);
      expect(laps[0].partial, isFalse);
    });

    test('걷다 뛰면 분마다 보폭이 다르다: 5분 × 100보(걷기) + 5분 × 150보(뛰기)', () {
      // 걷기 5분 = 350m, 뛰기는 분당 150m. 뛰기 4분 더하면 950m (9분 시작),
      // 9분째에 50m 더 = 그 분의 50/150 = 1/3
      // 넘는 시각 = 9분 + 20초 = 560초, 걸음 = 500 + 600 + 150 × 1/3 = 1,150
      // 부분 랩: 1,100 - 1,000 = 100m, 끝은 10분 = 600초 → 40초, 걸음 1,250 - 1,150 = 100
      final m = [..._each(5, 100), ..._each(5, 150, start: 5)];
      final laps = splitLaps(_gaits(m), _from, _from + 10, rules);
      expect(laps, hasLength(2));
      expect(laps[0].duration, const Duration(seconds: 560));
      expect(laps[0].steps, 1150);
      expect(laps[1].distanceM, closeTo(100, 1e-9));
      expect(laps[1].duration, const Duration(seconds: 40));
      expect(laps[1].steps, 100);
      // 40초 ÷ 0.1km
      expect(laps[1].paceSecPerKm, 400);
      _expectTotals(laps, steps: 1250, seconds: 600);
    });
  });

  group('창 [from, to)', () {
    test('창 밖의 분은 쓰지 않는다. 시간의 기준은 창이 시작하는 분', () {
      // 0~24분(25분 × 100보)에서 5~19분만: 15분 × 100보이고 기준이 5분이라 15분 걸음과 같다
      final g = _gaits(_each(25, 100));
      final laps = splitLaps(g, _from + 5, _from + 20, rules);
      expect(laps, hasLength(2));
      expect(laps[0].duration, const Duration(seconds: 857));
      expect(laps[0].steps, 1429);
      expect(laps[1].distanceM, closeTo(50, 1e-9));
      expect(laps[1].duration, const Duration(seconds: 43));
      expect(laps[1].steps, 71);
      _expectTotals(laps, steps: 1500, seconds: 900);
    });

    test('끝 분은 포함하지 않는다 (반열린 구간)', () {
      final g = _gaits(_each(20, 100));
      final laps = splitLaps(g, _from, _from + 15, rules);
      _expectTotals(laps, steps: 1500, seconds: 900);
      expect(splitLaps(g, _from, _from, rules), isEmpty);
    });

    test('창 앞에서 이어진 뛰기 상태를 따른다 (135보는 직전 상태)', () {
      // 0분 150보(뛰기, 창 밖), 1·2분 135보(뛰기 이어짐) = 보폭 1.0m, 270m
      final m = [StepMinute(_from, 150), StepMinute(_from + 1, 135), StepMinute(_from + 2, 135)];
      final laps = splitLaps(_gaits(m), _from + 1, _from + 3, rules);
      expect(laps, hasLength(1));
      expect(laps[0].distanceM, closeTo(270, 1e-9));
      // 기준은 1분의 시작, 끝은 3분의 처음까지 2분 = 120초
      expect(laps[0].duration, const Duration(seconds: 120));
      expect(laps[0].steps, 270);
    });
  });

  group('한 분 안에 경계가 여러 개', () {
    test('20m 랩, 120보(84m) 한 분: 랩 넷 + 부분 랩(4m)', () {
      // 120보 × 0.7 = 84m 안의 경계 20·40·60·80m = 그 분의 5/21·10/21·15/21·20/21
      // 시각 = 60 × 5/21 = 14.29 → 14, 28.57 → 29, 42.86 → 43, 57.14 → 57
      // 걸음 = 120 × 5/21 = 28.57 → 29, 57.14 → 57, 85.71 → 86, 114.29 → 114
      // 랩 시간 = 14, 29-14 = 15, 43-29 = 14, 57-43 = 14, 부분 랩 60-57 = 3 (합 60)
      // 랩 걸음 = 29, 57-29 = 28, 86-57 = 29, 114-86 = 28, 120-114 = 6 (합 120)
      final r = rulesWithLapKm(0.02);
      final laps = splitLaps(_gaits(_each(1, 120)), _from, _from + 1, r);
      expect(laps.map((l) => l.index), [1, 2, 3, 4, 5]);
      expect(laps.map((l) => l.duration.inSeconds), [14, 15, 14, 14, 3]);
      expect(laps.map((l) => l.steps), [29, 28, 29, 28, 6]);
      expect(laps.map((l) => l.partial), [false, false, false, false, true]);
      for (final l in laps.take(4)) {
        expect(l.distanceM, 20);
      }
      expect(laps.last.distanceM, closeTo(4, 1e-9));
      _expectTotals(laps, steps: 120, seconds: 60);
    });

    test('한 분이 랩을 딱 맞게 채우면 부분 랩 없이 끝난다 (50m 랩, 달리기 200보 = 200m)', () {
      // 경계 50·100·150·200m = 그 분의 1/4·2/4·3/4·4/4 → 15·30·45·60초, 걸음 50·100·150·200
      final r = rulesWithLapKm(0.05);
      final laps = splitLaps(_gaits(_each(1, 200)), _from, _from + 1, r);
      expect(laps.map((l) => l.duration.inSeconds), [15, 15, 15, 15]);
      expect(laps.map((l) => l.steps), [50, 50, 50, 50]);
      expect(laps.any((l) => l.partial), isFalse);
    });

    test('경계가 여러 분에 흩어져 있다 (100m 랩, 분당 70m)', () {
      // 분 시작 누적 거리: 0·70·140·210·280m, 전체 350m
      // 100m: 1분째(70→140)의 30/70 = 3/7
      //   시각 60 + 60 × 3/7 = 85.71 → 86초, 걸음 100 + 100 × 3/7 = 142.86 → 143
      // 200m: 2분째(140→210)의 60/70 = 6/7
      //   시각 120 + 60 × 6/7 = 171.43 → 171초, 걸음 200 + 100 × 6/7 = 285.71 → 286
      // 300m: 4분째(280→350)의 20/70 = 2/7
      //   시각 240 + 60 × 2/7 = 257.14 → 257초, 걸음 400 + 100 × 2/7 = 428.57 → 429
      // 부분 랩: 50m, 끝은 5분 = 300초, 전체 걸음 500
      // 랩 시간 = 86, 171-86 = 85, 257-171 = 86, 300-257 = 43 (합 300)
      // 랩 걸음 = 143, 286-143 = 143, 429-286 = 143, 500-429 = 71 (합 500)
      final r = rulesWithLapKm(0.1);
      final laps = splitLaps(_gaits(_each(5, 100)), _from, _from + 5, r);
      expect(laps.map((l) => l.duration.inSeconds), [86, 85, 86, 43]);
      expect(laps.map((l) => l.steps), [143, 143, 143, 71]);
      expect(laps.last.distanceM, closeTo(50, 1e-9));
      _expectTotals(laps, steps: 500, seconds: 300);
    });
  });
}
