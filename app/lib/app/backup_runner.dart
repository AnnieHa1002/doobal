import '../data/backup_store.dart';
import '../domain/backup_policy.dart';
import '../domain/rules.dart';
import 'backup_service.dart';

/// 자동 백업: 정책(shouldBackup)이 허락하면 지금 DB를 내보내 저장소에 올린다.
/// 마지막 백업 시각은 메모리에만 둔다 (DB 스키마를 늘리지 않으려고). 앱을 다시 켜면 비어서 첫 동기화에
/// 한 번 백업한다.
/// TODO(M5): 마지막 백업 시각을 서버 문서의 갱신 시각에서 읽어 앱을 켠 직후의 불필요한 백업을 줄인다
class BackupRunner {
  BackupRunner({
    required this.service,
    required this.store,
    required this.rules,
    required this.uid,
  });

  final BackupService service;
  final BackupStore store;
  final Rules rules;

  /// 계정을 연결한 사용자의 uid. 연결하지 않았으면 null이라 백업하지 않는다.
  /// 부를 때마다 읽는다 (연결·해제가 바로 반영되게)
  final String? Function() uid;

  DateTime? _lastBackupUtc;
  var _running = false;

  /// 마지막으로 백업을 올린 시각 (이번 실행에서). 없으면 null
  DateTime? get lastBackupUtc => _lastBackupUtc;

  /// [reason]으로 백업을 시도한다. 올렸으면 true, 정책이 막았거나 이미 올리는 중이면 false.
  /// 내보내기·저장이 실패하면 그대로 던진다 (마지막 백업 시각은 안 바뀐다)
  Future<bool> run(BackupReason reason, DateTime now) async {
    final id = uid();
    if (_running ||
        !shouldBackup(
          reason: reason,
          lastBackupUtc: _lastBackupUtc,
          now: now,
          linked: id != null,
          rules: rules,
        )) {
      return false;
    }
    _running = true;
    try {
      await store.save(id!, await service.exportBackup(now));
      _lastBackupUtc = now.toUtc();
      return true;
    } finally {
      _running = false;
    }
  }

  /// 동기화가 끝난 뒤: 마지막 백업과 한국 날짜가 다르면(날짜가 바뀐 뒤 첫 동기화) 백업을 시도한다
  Future<bool> afterSync(DateTime now) async =>
      dayChangedSince(_lastBackupUtc, now) && await run(BackupReason.dayChanged, now);
}
