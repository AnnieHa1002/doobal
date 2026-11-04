import 'package:doobal/domain/walk_arrival.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('previewReachesDest', () {
    test('남은 거리를 넘으면 true, 모자라면 false', () {
      expect(previewReachesDest(remainingKm: 0.5, extraM: 600), isTrue);
      expect(previewReachesDest(remainingKm: 0.5, extraM: 500), isTrue);
      expect(previewReachesDest(remainingKm: 0.5, extraM: 499), isFalse);
    });

    test('센서가 동기화 값보다 앞서지 않으면(0 이하) 늘 false', () {
      expect(previewReachesDest(remainingKm: 0, extraM: 0), isFalse);
      expect(previewReachesDest(remainingKm: 1, extraM: -50), isFalse);
    });
  });

  group('arrivalProbeDue', () {
    final t = DateTime.utc(2026, 11, 4, 1, 0, 0);
    test('처음이면 돌린다', () => expect(arrivalProbeDue(null, t, 5), isTrue));
    test('간격 안에서는 안 돌리고, 지나면 돌린다', () {
      expect(arrivalProbeDue(t, t.add(const Duration(seconds: 4)), 5), isFalse);
      expect(arrivalProbeDue(t, t.add(const Duration(seconds: 5)), 5), isTrue);
    });
  });
}
