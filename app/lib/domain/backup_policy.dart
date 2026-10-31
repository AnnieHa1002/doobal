import 'rules.dart';
import 'time_kst.dart';

/// 백업을 시도하는 때 (M5 명세): 날짜가 바뀐 뒤 첫 동기화, 도착, 앱이 백그라운드로 갈 때
enum BackupReason { dayChanged, arrived, background }

/// 지금 백업을 올릴까. 계정을 연결하지 않았으면 안 한다 (익명 uid는 앱을 지우면 다시 찾을 수 없다).
/// 마지막 백업 뒤 config backup.minIntervalMin 이내면 건너뛰고, 정확히 그 시간이면 한다.
/// 시계가 뒤로 가서 마지막 백업이 미래면 간격을 믿을 수 없으니 한다.
/// 이유는 셋 다 같게 다룬다 (이유마다 다르게 할 일이 생기면 여기서 가른다)
bool shouldBackup({
  required BackupReason reason,
  DateTime? lastBackupUtc,
  required DateTime now,
  required bool linked,
  required Rules rules,
}) {
  if (!linked) return false;
  switch (reason) {
    case BackupReason.dayChanged:
    case BackupReason.arrived:
    case BackupReason.background:
      break;
  }
  if (lastBackupUtc == null) return true;
  final since = now.difference(lastBackupUtc);
  return since.isNegative || since >= Duration(minutes: rules.backupMinIntervalMin);
}

/// 마지막 백업 뒤 처음 맞는 한국 날짜인가 (날짜가 바뀐 뒤 첫 동기화). 백업한 적이 없으면 true
bool dayChangedSince(DateTime? lastBackupUtc, DateTime now) =>
    lastBackupUtc == null || kstDayKey(lastBackupUtc) != kstDayKey(now);
