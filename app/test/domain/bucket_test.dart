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
