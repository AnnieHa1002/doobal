import 'package:doobal/domain/backup_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final _last = DateTime.utc(2026, 11, 18, 3);

bool _should({
  BackupReason reason = BackupReason.background,
  DateTime? last,
  required DateTime now,
  bool linked = true,
}) =>
    shouldBackup(reason: reason, lastBackupUtc: last, now: now, linked: linked, rules: rules);

void main() {
  test('config의 간격은 10분', () => expect(rules.backupMinIntervalMin, 10));

  group('shouldBackup', () {
    test('계정을 연결하지 않았으면 어떤 이유로도 하지 않는다', () {
      for (final reason in BackupReason.values) {
        expect(_should(reason: reason, now: _last, linked: false), isFalse, reason: '$reason');
        expect(
          _should(
              reason: reason,
              last: _last,
              now: _last.add(const Duration(days: 3)),
              linked: false),
          isFalse,
          reason: '$reason (오래전 백업)',
        );
      }
    });

    test('연결했고 백업한 적이 없으면 한다', () {
      for (final reason in BackupReason.values) {
        expect(_should(reason: reason, now: _last), isTrue, reason: '$reason');
      }
    });

    test('마지막 백업 뒤 10분 이내면 건너뛴다: 9분 59초는 건너뛰고 10분은 한다', () {
      expect(_should(last: _last, now: _last), isFalse);
      expect(_should(last: _last, now: _last.add(const Duration(minutes: 9, seconds: 59))),
          isFalse);
      expect(_should(last: _last, now: _last.add(const Duration(minutes: 10))), isTrue);
      expect(_should(last: _last, now: _last.add(const Duration(minutes: 10, seconds: 1))),
          isTrue);
    });

    test('이유 셋 모두 같은 간격 규칙을 따른다', () {
      for (final reason in BackupReason.values) {
        final near = _last.add(const Duration(minutes: 9, seconds: 59));
        final far = _last.add(const Duration(minutes: 10));
        expect(_should(reason: reason, last: _last, now: near), isFalse, reason: '$reason 9:59');
        expect(_should(reason: reason, last: _last, now: far), isTrue, reason: '$reason 10:00');
      }
    });

    test('날짜가 바뀌었어도 10분 이내면 건너뛴다 (한국 자정 직전·직후)', () {
      final beforeMidnight = DateTime.utc(2026, 11, 18, 14, 55); // KST 23:55
      final afterMidnight = DateTime.utc(2026, 11, 18, 15, 1); // KST 00:01
      expect(
          _should(reason: BackupReason.dayChanged, last: beforeMidnight, now: afterMidnight),
          isFalse);
    });

    test('시계가 뒤로 가서 마지막 백업이 미래면 한다', () {
      expect(_should(last: _last, now: _last.subtract(const Duration(minutes: 1))), isTrue);
    });

    test('시각을 로컬로 넘겨도 같다', () {
      final now = _last.add(const Duration(minutes: 10)).toLocal();
      expect(_should(last: _last.toLocal(), now: now), isTrue);
      expect(_should(last: _last.toLocal(), now: now.subtract(const Duration(seconds: 1))),
          isFalse);
    });
  });

  group('dayChangedSince', () {
    test('백업한 적이 없으면 날짜가 바뀐 것으로 본다', () {
      expect(dayChangedSince(null, _last), isTrue);
    });

    test('같은 한국 날짜면 아니고, 다음 한국 날짜면 맞다', () {
      final last = DateTime.utc(2026, 11, 18, 14, 59); // KST 11/18 23:59
      expect(dayChangedSince(last, DateTime.utc(2026, 11, 18, 14, 59, 59)), isFalse);
      expect(dayChangedSince(last, DateTime.utc(2026, 11, 18, 15)), isTrue); // KST 11/19 00:00
    });

    test('UTC 날짜가 아니라 한국 날짜로 센다', () {
      // UTC로는 11/18과 11/19지만 한국으로는 둘 다 11/19
      final last = DateTime.utc(2026, 11, 18, 15, 30);
      expect(dayChangedSince(last, DateTime.utc(2026, 11, 19, 10)), isFalse);
    });
  });
}
