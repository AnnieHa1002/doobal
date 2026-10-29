import 'package:health/health.dart' as hp;

import '../domain/bucket.dart';

/// 건강 앱에서 걸음 기록을 가져오는 곳. 테스트는 FakeStepSource를 쓴다
abstract class StepSource {
  Future<bool> requestPermission();

  Future<List<StepRecord>> fetch(DateTime fromUtc, DateTime toUtc);
}

/// HealthKit(iOS) / Health Connect(안드로이드). 걸음 읽기만 한다
class HealthStepSource implements StepSource {
  final _health = hp.Health();
  var _configured = false;

  static const _types = [hp.HealthDataType.STEPS];
  static const _read = [hp.HealthDataAccess.READ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _configure();
    final ok = await _health.requestAuthorization(_types, permissions: _read);
    // 안드로이드 백그라운드 동기화용. 거부해도 앱을 열 때는 동기화된다
    if (ok && await _health.isHealthDataInBackgroundAvailable()) {
      await _health.requestHealthDataInBackgroundAuthorization();
    }
    return ok;
  }

  @override
  Future<List<StepRecord>> fetch(DateTime fromUtc, DateTime toUtc) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: fromUtc,
      endTime: toUtc,
    );
    return [
      for (final p in points)
        if (p.value is hp.NumericHealthValue)
          StepRecord(
            start: p.dateFrom.toUtc(),
            end: p.dateTo.toUtc(),
            steps: (p.value as hp.NumericHealthValue).numericValue.round(),
            sourceId: p.sourceId,
            method: switch (p.recordingMethod) {
              hp.RecordingMethod.automatic => RecordingMethod.automatic,
              hp.RecordingMethod.active => RecordingMethod.active,
              hp.RecordingMethod.manual => RecordingMethod.manual,
              hp.RecordingMethod.unknown => RecordingMethod.unknown,
            },
          ),
    ];
  }
}

class FakeStepSource implements StepSource {
  FakeStepSource([List<StepRecord>? records]) : records = records ?? [];

  final List<StepRecord> records;

  @override
  Future<bool> requestPermission() async => true;

  /// 구간과 겹치는 기록을 돌려준다
  @override
  Future<List<StepRecord>> fetch(DateTime fromUtc, DateTime toUtc) async =>
      records.where((r) => r.end.isAfter(fromUtc) && r.start.isBefore(toUtc)).toList();
}
