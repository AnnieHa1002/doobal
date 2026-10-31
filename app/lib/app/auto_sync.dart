import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/backup_policy.dart';
import '../ui/arrival/arrival_screen.dart';
import 'backup_runner.dart';
import 'notification_service.dart';
import 'providers.dart';
import 'sync_service.dart';

/// MaterialApp에 달아 두면 어느 화면에서도 토스트를 띄울 수 있다
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 이 거리(km) 이상 늘었을 때만 "그동안 n km 걸었어요"를 보여 준다
const _toastMinKm = 0.1;

/// 앱을 켤 때와 백그라운드에서 돌아올 때 한 번씩 동기화하고 상태를 새로 읽는다.
/// 권한이 없는 등 실패는 조용히 넘어간다.
/// 앱이 앞에 있는지도 알려 준다 (알림 판단이 앞이면 화면 안 표시만 한다). 앱을 열 때는 예약해 둔
/// '다시 부르기' 알림(N5)을 취소하고, 백그라운드로 갈 때는 다시 예약한다.
/// 자동 백업도 여기서 시도한다 (계정을 연결한 사용자만, 10분 안 반복은 건너뛴다): 날짜가 바뀐 뒤 첫
/// 동기화, 도착을 알았을 때, 백그라운드로 갈 때.
/// 도착했는데 도착 화면을 아직 안 봤으면(앱을 켜기 전에 도착했거나, 걷는 중 화면이 새로 읽다가
/// 도착을 알게 됐을 때) 열려 있는 화면 위에 도착 화면을 띄운다. 이 위젯이 home이라
/// 어느 화면 위에서든 같은 Navigator에 올릴 수 있다
class AutoSync extends ConsumerStatefulWidget {
  const AutoSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends ConsumerState<AutoSync> {
  late final AppLifecycleListener _lifecycle;
  var _running = false;

  /// 이번 실행에서 도착 화면을 이미 띄운 여정 (같은 여정을 두 번 띄우지 않는다)
  final _arrivalsShown = <String>{};

  @override
  void initState() {
    super.initState();
    // 숨김과 일시정지가 연달아 와도 N5는 한 번만 예약된다 (이미 예약돼 있으면 그대로 둔다)
    _lifecycle = AppLifecycleListener(
      onResume: _onForeground,
      onHide: _onBackground,
      onPause: _onBackground,
    );
    ref.listenManual(snapshotProvider, (_, next) => _checkArrival(next.value),
        fireImmediately: true);
    // 앱을 새로 켠 것도 연 것이다 (앞 실행이 백그라운드에서 끝났으면 예약된 N5가 남아 있다)
    _notice((svc, now) => svc.onOpen(now));
    _sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 앞으로 나왔다: 화면 안 표시 모드로 바꾸고 N5 예약을 취소·초기화한 뒤 동기화한다
  void _onForeground() {
    ref.read(appForegroundProvider.notifier).set(true);
    _notice((svc, now) => svc.onOpen(now));
    _sync();
  }

  /// 백그라운드로 갔다: 이제부터 동기화는 시스템 알림 대상이고, N5를 예약한다
  void _onBackground() {
    ref.read(appForegroundProvider.notifier).set(false);
    _notice((svc, now) => svc.onBackground(now));
    _backup((runner, now) => runner.run(BackupReason.background, now));
  }

  /// 알림 판단에 지금 시각으로 일을 시킨다. 실패해도 앱 흐름은 그대로다
  Future<void> _notice(Future<void> Function(NotificationService svc, DateTime now) job) async {
    try {
      final svc = await ref.read(notificationServiceProvider.future);
      await job(svc, ref.read(clockProvider)());
    } catch (e) {
      debugPrint('알림 상태 갱신 실패: $e');
    }
  }

  /// 백업을 시도한다. 계정을 연결하지 않았거나 정책이 막으면 아무 일도 없고, 실패해도 앱 흐름은 그대로다
  Future<void> _backup(Future<bool> Function(BackupRunner runner, DateTime now) job) async {
    try {
      final runner = await ref.read(backupRunnerProvider.future);
      await job(runner, ref.read(clockProvider)());
    } catch (e) {
      debugPrint('자동 백업 실패: $e');
    }
  }

  void _checkArrival(Snapshot? snap) {
    final id = snap?.pendingArrival?.journeyId;
    if (id == null || !_arrivalsShown.add(id)) return;
    // 도착을 알았다: 새 그림이 들어간 상태를 백업한다 (도착 화면이 닫히길 기다리지 않는다)
    _backup((runner, now) => runner.run(BackupReason.arrived, now));
    // 그리는 중에 화면을 올리지 않도록 이번 그리기가 끝난 뒤에
    Future.microtask(() {
      if (mounted) _showArrival(id);
    });
  }

  /// 도착 화면을 올리고, 닫히면 본 것으로 적은 뒤 상태를 새로 읽는다
  Future<void> _showArrival(String journeyId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ArrivalScreen(journeyId: journeyId)),
    );
    if (!mounted) return;
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.markArrivalShown(journeyId);
    } catch (e) {
      debugPrint('도착 화면 확인 기록 실패: $e');
    }
    if (mounted) ref.invalidate(snapshotProvider);
  }

  Future<void> _sync() async {
    // 겹쳐 돌지 않게 한다 (시작과 resumed가 연달아 올 수 있다)
    if (_running) return;
    _running = true;
    try {
      final svc = await ref.read(syncServiceProvider.future);
      final report = await svc.sync(ref.read(clockProvider)());
      if (!mounted) return;
      ref.invalidate(snapshotProvider);
      if (report.advancedKm >= _toastMinKm) {
        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text('그동안 ${report.advancedKm.toStringAsFixed(1)}km 걸었어요'),
        ));
      }
      _backup((runner, now) => runner.afterSync(now));
    } catch (e) {
      debugPrint('자동 동기화 실패: $e');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
