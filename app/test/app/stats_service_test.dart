import 'package:doobal/app/stats_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

// 설치 KST 2026-11-18 09:00
final _t0 = DateTime.utc(2026, 11, 18, 0);

StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDb db;
  late FakeStepSource source;
  late SyncService sync;
  late StatsService stats;

  setUp(() {
    db = AppDb(NativeDatabase.memory());
    source = FakeStepSource();
    sync = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: const {},
      props: props,
    );
    stats = StatsService(db);
  });
  tearDown(() => db.close());

  group('recentDays', () {
    test('기록이 없으면 14일 모두 0', () async {
      final bars = await stats.recentDays('2026-11-18');
      expect(bars, hasLength(14));
      expect(bars.every((b) => b.steps == 0), isTrue);
    });

    test('하루 요약의 걸음을 날짜에 맞추고 빈 날은 0, 14일보다 앞은 넣지 않는다', () async {
      // 오늘(11/18) 15분 × 100보, 어제(11/17) 10분 × 100보
      source.records.addAll([
        _walk(_t0.add(const Duration(hours: 1)), 15, 100),
        _walk(_t0.subtract(const Duration(hours: 20)), 10, 100),
      ]);
      await sync.sync(_t0.subtract(const Duration(days: 20)));
      await sync.sync(_t0.add(const Duration(hours: 3)));
      // 14일보다 앞 날짜(11/04)는 막대에 나오지 않는다
      await db.into(db.daySummaries).insertOnConflictUpdate(DaySummariesCompanion.insert(
          day: '2026-11-04', steps: 777, distanceM: 0, countedSessions: 0));

      final bars = await stats.recentDays('2026-11-18');
      expect(bars, hasLength(14));
      expect(bars.first.day, '2026-11-05');
      expect(bars.last.day, '2026-11-18');
      expect(bars.last.steps, 1500);
      expect(bars[12].steps, 1000);
      expect(bars.where((b) => b.steps > 0), hasLength(2));
    });
  });

  group('walkSessions / countedNth', () {
    setUp(() async {
      // 같은 날 15분 걷기 4번 (30분 간격): 앞 셋은 인정, 넷째는 하루 최대(3)를 채워 인정 안 됨.
      // 이튿날 한 번 더
      for (var i = 0; i < 4; i++) {
        source.records.add(_walk(_t0.add(Duration(hours: 1, minutes: 30 * i)), 15, 100));
      }
      source.records.add(_walk(_t0.add(const Duration(days: 1, hours: 1)), 15, 100));
      // 첫 동기화가 설치 시각이라 그 앞의 기록은 가져오지 않는다
      await sync.sync(_t0);
      await sync.sync(_t0.add(const Duration(days: 1, hours: 3)));
    });

    test('감지된 걷기를 최신순으로 돌려준다', () async {
      final sessions = await stats.walkSessions();
      expect(sessions, hasLength(5));
      expect(sessions.first.start, _t0.add(const Duration(days: 1, hours: 1)));
      expect(sessions.last.start, _t0.add(const Duration(hours: 1)));
      for (var i = 1; i < sessions.length; i++) {
        expect(sessions[i].start.isBefore(sessions[i - 1].start), isTrue);
      }
      expect(sessions.first.steps, 1500);
      expect(sessions.first.distanceM, closeTo(1050, 1e-6));
      expect(sessions.first.end.difference(sessions.first.start), const Duration(minutes: 15));
      expect(sessions.map((s) => s.counted), [true, false, true, true, true]);
    });

    test('countedNth: 그날 인정된 걷기 중 몇 번째', () async {
      final starts = [for (final s in (await stats.walkSessions()).reversed) s.start];
      expect(await stats.countedNth(starts[0]), 1);
      expect(await stats.countedNth(starts[1]), 2);
      expect(await stats.countedNth(starts[2]), 3);
      // 인정 안 된 넷째는 앞의 3번까지 센다
      expect(await stats.countedNth(starts[3]), 3);
      // 이튿날은 다시 1번째
      expect(await stats.countedNth(starts[4]), 1);
    });
  });

  test('걷기가 없으면 빈 목록', () async {
    expect(await stats.walkSessions(), isEmpty);
  });
}
