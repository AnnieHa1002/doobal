import 'package:doobal/domain/restore_floor.dart';
import 'package:flutter_test/flutter_test.dart';

/// 복원한 값 (걸음 6,000 · 4.2km · 인정 2번)
const _restored = DayTotals(6000, 4200, 2);

void main() {
  group('isRestoredDay', () {
    test('복원한 마지막 날 이하만 복원한 날이다', () {
      expect(isRestoredDay('2026-11-19', '2026-11-20'), isTrue);
      expect(isRestoredDay('2026-11-20', '2026-11-20'), isTrue);
      expect(isRestoredDay('2026-11-21', '2026-11-20'), isFalse);
      // 달·해가 바뀌어도 날짜 순서대로
      expect(isRestoredDay('2026-10-31', '2026-11-01'), isTrue);
      expect(isRestoredDay('2027-01-01', '2026-12-31'), isFalse);
    });

    test('복원한 적이 없으면(null) 어느 날도 아니다', () {
      expect(isRestoredDay('2026-11-20', null), isFalse);
    });
  });

  group('guardRestoredDay', () {
    test('다시 계산한 값이 0이면 복원값 그대로, 걷기 구간도 복원한 것을 둔다', () {
      final out = guardRestoredDay(_restored, const DayTotals(0, 0, 0));
      expect((out.totals.steps, out.totals.distanceM, out.totals.countedSessions), (6000, 4200, 2));
      expect(out.useRecomputedSessions, isFalse);
    });

    test('다시 계산한 값이 작으면 복원값을 지킨다 (인정된 걷기 수는 줄지 않는다)', () {
      final out = guardRestoredDay(_restored, const DayTotals(1000, 700, 1));
      expect((out.totals.steps, out.totals.distanceM, out.totals.countedSessions), (6000, 4200, 2));
      expect(out.useRecomputedSessions, isFalse);
    });

    test('같은 값이면 다시 계산한 것을 쓴다 (같은 건강 기록으로 다시 계산한 경우)', () {
      final out = guardRestoredDay(_restored, _restored);
      expect((out.totals.steps, out.totals.distanceM, out.totals.countedSessions), (6000, 4200, 2));
      expect(out.useRecomputedSessions, isTrue);
    });

    test('걸음이 더 들어오면 더 큰 값으로 바뀌고 걷기 구간도 다시 계산한 것이다', () {
      final out = guardRestoredDay(_restored, const DayTotals(9000, 6300, 3));
      expect((out.totals.steps, out.totals.distanceM, out.totals.countedSessions), (9000, 6300, 3));
      expect(out.useRecomputedSessions, isTrue);
    });

    test('걸음이 늘어도 인정된 걷기가 복원값보다 적으면 인정 수와 걷기 구간은 복원값을 둔다', () {
      // 8,000보지만 길이·걸음 기준을 넘는 걷기가 1번뿐 (복원값은 2번)
      final out = guardRestoredDay(_restored, const DayTotals(8000, 5600, 1));
      expect(out.totals.steps, 8000);
      expect(out.totals.distanceM, 5600);
      expect(out.totals.countedSessions, 2);
      expect(out.useRecomputedSessions, isFalse);
    });

    test('인정된 걷기가 늘어도 걸음이 복원값보다 적으면 복원값을 지킨다', () {
      final out = guardRestoredDay(_restored, const DayTotals(5000, 3500, 3));
      expect((out.totals.steps, out.totals.distanceM, out.totals.countedSessions), (6000, 4200, 2));
      expect(out.useRecomputedSessions, isFalse);
    });

    test('걸음·거리는 따로 큰 쪽을 쓴다', () {
      // 걸음은 늘었는데 거리는 짧다 (걷기로만 센 경우)
      final out = guardRestoredDay(_restored, const DayTotals(7000, 4000, 2));
      expect(out.totals.steps, 7000);
      expect(out.totals.distanceM, 4200);
      expect(out.useRecomputedSessions, isTrue);
    });

    test('복원값이 0인 날은 다시 계산한 값이 된다', () {
      final out = guardRestoredDay(const DayTotals(0, 0, 0), const DayTotals(300, 210, 0));
      expect((out.totals.steps, out.totals.distanceM, out.totals.countedSessions), (300, 210, 0));
      expect(out.useRecomputedSessions, isTrue);
    });

    group('본격 걷기 열 (보너스·상점·이동 거리·앱 걷기 이동 거리·럭)', () {
      // 실제 4.2km + 보너스 1.26km + 상점 0.1km = 이동 5.56km, 앱 걷기 이동 5.46km, 럭 84
      const restored = DayTotals(6000, 4200, 2,
          bonusM: 1260, shopM: 100, travelM: 5560, walkTravelM: 5460, coins: 84);

      test('다시 계산한 값이 0이면 새 열도 복원값 그대로다', () {
        final out = guardRestoredDay(restored, const DayTotals(0, 0, 0));
        final t = out.totals;
        expect((t.bonusM, t.shopM, t.travelM, t.walkTravelM, t.coins),
            (1260, 100, 5560, 5460, 84));
        expect(out.useRecomputedSessions, isFalse);
      });

      test('열마다 큰 쪽을 쓴다 (줄어들지 않는다)', () {
        // 보너스·럭은 줄고(창이 짧아짐), 이동 거리·앱 걷기 이동 거리는 늘었다
        final out = guardRestoredDay(
          restored,
          const DayTotals(6000, 4200, 2,
              bonusM: 300, shopM: 200, travelM: 6000, walkTravelM: 5000, coins: 90),
        );
        final t = out.totals;
        expect((t.bonusM, t.shopM, t.travelM, t.walkTravelM, t.coins),
            (1260, 200, 6000, 5460, 90));
        expect(out.useRecomputedSessions, isTrue);
      });

      test('새 열을 안 적으면 0이라 옛 값은 그대로 지킨다 (열이 생기기 전 값과 같은 모양)', () {
        final out = guardRestoredDay(_restored, const DayTotals(6000, 4200, 2));
        final t = out.totals;
        expect((t.bonusM, t.shopM, t.travelM, t.walkTravelM, t.coins), (0, 0, 0, 0, 0));
      });
    });
  });
}
