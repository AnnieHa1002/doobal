import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/backup_service.dart';
import '../../app/providers.dart';

/// 서버가 없는 빌드에서 메모리 저장소에 쓰는 자리
const _debugUid = 'debug';

/// 백업 시험 (설정의 개발자 화면 옆, 디버그 빌드에서만 보인다): 지금 DB를 백업 문자열로 내보내 크기를
/// 보여 주고, 방금 내보낸 문자열을 저장소에서 꺼내 다시 들여온다. 실기기에서 크기를 확인하는 용도다.
/// 서버가 있으면 지금 로그인한 uid의 Firestore 백업(계정 연결 전이라도), 없으면 메모리 자리표시에 둔다
class BackupDebugScreen extends ConsumerStatefulWidget {
  const BackupDebugScreen({super.key});

  @override
  ConsumerState<BackupDebugScreen> createState() => _BackupDebugScreenState();
}

class _BackupDebugScreenState extends ConsumerState<BackupDebugScreen> {
  String? _message;
  var _busy = false;

  Future<void> _run(String label, Future<String> Function() job) async {
    setState(() => _busy = true);
    try {
      final done = await job();
      if (mounted) setState(() => _message = '$label: $done');
    } catch (e) {
      if (mounted) setState(() => _message = '$label 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 서버가 있으면 로그인한 uid (규칙상 본인 문서만 쓴다), 없으면 메모리 자리
  String _uid() => ref.read(serverBackendProvider)?.auth.current?.uid ?? _debugUid;

  Future<String> _export() async {
    final svc = await ref.read(backupServiceProvider.future);
    final text = await svc.exportBackup(ref.read(clockProvider)());
    await ref.read(backupStoreProvider).save(_uid(), text);
    final size = BackupService.measure(text);
    return '문자열 ${size.chars}자 (한도 ${svc.rules.backupMaxChars}자) · '
        '압축 ${size.gzipBytes}바이트 · 압축 전 ${size.jsonBytes}바이트';
  }

  Future<String> _restore() async {
    final text = await ref.read(backupStoreProvider).load(_uid());
    if (text == null) return '먼저 백업을 내보내 주세요';
    await (await ref.read(backupServiceProvider.future)).restoreBackup(text);
    // 걸음 분과 동기화 상태를 비웠으니 상태를 새로 읽는다
    ref.invalidate(snapshotProvider);
    ref.invalidate(onboardingStepProvider);
    return '되돌렸어요 (걸음 기록은 비웠고, 다음 동기화가 건강 앱에서 48시간을 다시 가져와요)';
  }

  String _where() {
    final server = ref.watch(serverBackendProvider);
    if (server == null) return '서버 대신 메모리에 두고 시험해요. 앱을 끄면 방금 낸 백업은 사라져요.';
    final state = ref.watch(accountStateProvider).value;
    final uid = state?.user?.uid;
    final linked = state?.linked;
    return '${server.label} · ${uid == null ? '로그인 전' : 'uid $uid'}'
        '${linked == null ? '' : ' · ${linked.name} 연결'}\n'
        'users/{uid}/backup/state에 두고 시험해요 (자동 백업은 계정을 연결해야 돌아요).';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('백업 시험')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_where(), key: const ValueKey('backup-where')),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _run('내보내기', _export),
                child: const Text('백업 내보내기'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('되돌리기', _restore),
                child: const Text('백업으로 되돌리기'),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, key: const ValueKey('backup-message')),
          ],
        ],
      ),
    );
  }
}
