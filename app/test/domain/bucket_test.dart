import 'package:doobal/domain/bucket.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int h, int m, [int s = 0]) => DateTime.utc(2026, 11, 18, h, m, s);

StepRecord _rec(DateTime start, DateTime end, int steps,
        {String source = 'iphone', RecordingMethod method = RecordingMethod.automatic}) =>
    StepRecord(start: start, end: end, steps: steps, sourceId: source, method: method);

List<int> _steps(List<StepMinute> m) => m.map((x) => x.steps).toList();

void main() {
  test('#10 분 나누기: 10:00:30~10:02:30, 240보', () {
    final m = toMinutes([_rec(_at(10, 0, 30), _at(10, 2, 30), 240)]);
    expect(m.map((x) => x.startUtc).toList(), [_at(10, 0), _at(10, 1), _at(10, 2)]);
    expect(_steps(m), [60, 120, 60]);
  });

  test('#11 나머지: 10:00~10:03, 100보 → 34, 33, 33', () {
    final m = toMinutes([_rec(_at(10, 0), _at(10, 3), 100)]);
    expect(_steps(m), [34, 33, 33]);
    expect(_steps(m).reduce((a, b) => a + b), 100);
  });

  test('#12 같은 분에 출처가 둘이면 최댓값', () {
    final m = toMinutes([
      _rec(_at(10, 0), _at(10, 1), 80, source: 'iphone'),
      _rec(_at(10, 0), _at(10, 1), 95, source: 'watch'),
    ]);
    expect(m, [StepMinute(epochMinute(_at(10, 0)), 95)]);
  });

  group('splitSteps: 걸음 수와 시각 구간으로 분 나누기 (기록 없이)', () {
    final m10 = epochMinute(_at(10, 0));

    test('10:00:30~10:02:30, 240보 → 60, 120, 60 (겹친 시간 비율)', () {
      expect(splitSteps(240, _at(10, 0, 30), _at(10, 2, 30)), {
        m10: 60,
        m10 + 1: 120,
        m10 + 2: 60,
      });
    });

    test('나머지는 큰 분부터 1씩, 같으면 이른 분 먼저: 10:00~10:03, 100보 → 34, 33, 33', () {
      // 분마다 100 × 60000 ÷ 180000 = 33 나머지 60000으로 같아서 이른 분이 1을 받는다
      expect(splitSteps(100, _at(10, 0), _at(10, 3)), {m10: 34, m10 + 1: 33, m10 + 2: 33});
    });

    test('10분에 600보 → 분마다 60보 (딱 떨어진다)', () {
      final m = splitSteps(600, _at(12, 2), _at(12, 12));
      final first = epochMinute(_at(12, 2));
      expect(m, {for (var i = 0; i < 10; i++) first + i: 60});
    });

    test('끝이 분 경계에서 끝나면 그 다음 분은 만들지 않는다: 10:00:30~10:01:00, 30보', () {
      expect(splitSteps(30, _at(10, 0, 30), _at(10, 1)), {m10: 30});
    });

    test('구간이 없거나(끝이 시작보다 늦지 않다) 걸음이 0이면: 시작 분에 전부 / 비어 있다', () {
      expect(splitSteps(7, _at(10, 5, 20), _at(10, 5, 20)), {m10 + 5: 7});
      expect(splitSteps(7, _at(10, 5, 20), _at(10, 4)), {m10 + 5: 7});
      expect(splitSteps(0, _at(10, 0), _at(10, 3)), isEmpty);
      expect(splitSteps(-3, _at(10, 0), _at(10, 3)), isEmpty);
    });

    test('splitRecord는 같은 결과다', () {
      final r = _rec(_at(10, 0, 30), _at(10, 2, 30), 241);
      expect(splitRecord(r), splitSteps(241, r.start, r.end));
    });
  });

  test('같은 출처의 기록이 한 분에 둘이면 더한다', () {
    final m = toMinutes([
      _rec(_at(10, 0), _at(10, 0, 30), 40),
      _rec(_at(10, 0, 30), _at(10, 1), 50),
    ]);
    expect(_steps(m), [90]);
  });

  test('#13 수동 입력은 버린다', () {
    final kept = filterRecords(
        [_rec(_at(10, 0), _at(10, 5), 500, method: RecordingMethod.manual)], const []);
    expect(toMinutes(kept), isEmpty);
  });

  test('허용 목록이 있으면 목록 밖 출처를 버린다', () {
    final recs = [
      _rec(_at(10, 0), _at(10, 1), 80, source: 'iphone'),
      _rec(_at(10, 0), _at(10, 1), 95, source: 'other.app'),
    ];
    expect(filterRecords(recs, const ['iphone']).map((r) => r.sourceId), ['iphone']);
    expect(filterRecords(recs, const []), hasLength(2));
  });
}
