enum RecordingMethod { automatic, active, manual, unknown }

/// 건강 앱에서 가져온 걸음 기록 하나 (시각은 UTC)
class StepRecord {
  const StepRecord({
    required this.start,
    required this.end,
    required this.steps,
    required this.sourceId,
    this.method = RecordingMethod.unknown,
  });

  final DateTime start;
  final DateTime end;
  final int steps;
  final String sourceId;
  final RecordingMethod method;
}

/// 분 단위 걸음. minute = UTC epoch 분
class StepMinute {
  const StepMinute(this.minute, this.steps);

  final int minute;
  final int steps;

  DateTime get startUtc =>
      DateTime.fromMillisecondsSinceEpoch(minute * _msPerMin, isUtc: true);

  @override
  bool operator ==(Object other) =>
      other is StepMinute && other.minute == minute && other.steps == steps;

  @override
  int get hashCode => Object.hash(minute, steps);

  @override
  String toString() => 'StepMinute($startUtc, $steps)';
}

const _msPerMin = 60000;

int epochMinute(DateTime t) => t.millisecondsSinceEpoch ~/ _msPerMin;

/// 수동 입력과 허용 목록 밖 출처를 버린다. 목록이 비어 있으면 출처로는 거르지 않는다
List<StepRecord> filterRecords(List<StepRecord> records, List<String> allowedSources) =>
    records
        .where((r) => r.method != RecordingMethod.manual)
        .where((r) => allowedSources.isEmpty || allowedSources.contains(r.sourceId))
        .toList();

/// 기록 하나를 각 분과 겹친 시간 비율로 나눈다 (분 → 걸음).
/// 정수로 맞출 때는 최대 나머지 방식: 나머지가 큰 분부터 1씩, 같으면 이른 분 먼저. 합은 원래 걸음과 같다
Map<int, int> splitRecord(StepRecord r) {
  if (r.steps <= 0) return {};
  final s = r.start.millisecondsSinceEpoch;
  final e = r.end.millisecondsSinceEpoch;
  if (e <= s) return {s ~/ _msPerMin: r.steps};

  final total = e - s;
  final first = s ~/ _msPerMin;
  final last = (e - 1) ~/ _msPerMin;
  final base = <int, int>{};
  final rem = <int, int>{};
  for (var m = first; m <= last; m++) {
    final overlap = _min(e, (m + 1) * _msPerMin) - _max(s, m * _msPerMin);
    base[m] = r.steps * overlap ~/ total;
    rem[m] = r.steps * overlap % total;
  }

  var left = r.steps - base.values.fold(0, (a, b) => a + b);
  final order = rem.keys.toList()
    ..sort((a, b) => rem[a] != rem[b] ? rem[b]!.compareTo(rem[a]!) : a.compareTo(b));
  for (final m in order) {
    if (left == 0) break;
    base[m] = base[m]! + 1;
    left--;
  }
  return base..removeWhere((_, v) => v == 0);
}

/// 같은 출처 안에서는 더하고, 같은 분에 출처가 여럿이면 합이 아니라 최댓값을 쓴다
/// (아이폰+워치처럼 같은 걸음을 두 번 세지 않게). 분 순서로 돌려준다
List<StepMinute> toMinutes(List<StepRecord> records) {
  final bySource = <String, Map<int, int>>{};
  for (final r in records) {
    final src = bySource.putIfAbsent(r.sourceId, () => {});
    splitRecord(r).forEach((m, n) => src[m] = (src[m] ?? 0) + n);
  }
  final merged = <int, int>{};
  for (final src in bySource.values) {
    src.forEach((m, n) => merged[m] = _max(merged[m] ?? 0, n));
  }
  final keys = merged.keys.toList()..sort();
  return [for (final m in keys) StepMinute(m, merged[m]!)];
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
