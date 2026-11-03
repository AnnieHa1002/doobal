import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/backup_policy.dart';
import '../domain/focus_walk.dart';
import '../domain/prop.dart';
import '../ui/arrival/arrival_screen.dart';
import '../ui/common/toast.dart';
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
/// 어느 화면 위에서든 같은 Navigator에 올릴 수 있다.
/// 앱 걷기(본격 걷기 보너스의 창)를 위해 앱이 살아 있는 동안 config sync.aliveSaveSec마다와
/// 백그라운드로 갈 때 '살아 있던 시각'을 적는다. 앱을 켠 직후에는 앞 실행에서 끝나지 않은 앱 걷기를
/// 그 시각에서 닫고(동기화보다 먼저) 동기화한다. 닫은 창이 있으면(걷는 중에 앱이 끝났다) 첫 동기화 뒤에
/// 쉼터에 토스트를 한 번 띄운다: 창이 끝난 뒤 쌓인 걸음은 평소 걸음으로 더해졌다고 알린다.
/// 어느 화면의 동기화든 소품을 새로 얻으면(SyncService.newProps) 지금 화면 위에 한 줄 토스트를 띄운다
class AutoSync extends ConsumerStatefulWidget {
  const AutoSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends ConsumerState<AutoSync> {
  late final AppLifecycleListener _lifecycle;
  Timer? _aliveTimer;

  /// 돌고 있는 동기화 (겹쳐 돌지 않게 하고, 부른 쪽이 끝나길 기다릴 수 있게)
  Future<void>? _syncing;

  /// 이번 실행에서 도착 화면을 이미 띄운 여정 (같은 여정을 두 번 띄우지 않는다)
  final _arrivalsShown = <String>{};

  /// 새로 얻은 소품 듣기 (동기화 서비스가 새로 만들어지면 다시 듣는다)
  StreamSubscription<List<Prop>>? _propSub;

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
    ref.listenManual(syncServiceProvider, (_, next) {
      final svc = next.value;
      if (svc == null) return;
      _propSub?.cancel();
      _propSub = svc.newProps.listen(_showNewProps);
    }, fireImmediately: true);
    // 앱을 새로 켠 것도 연 것이다 (앞 실행이 백그라운드에서 끝났으면 예약된 N5가 남아 있다)
    _notice((svc, now) => svc.onOpen(now));
    _startUp();
  }

  @override
  void dispose() {
    _aliveTimer?.cancel();
    _propSub?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// 앱을 켠 직후: 앞 실행에서 끝나지 않은 앱 걷기를 닫고 지금 살아 있다고 적은 뒤 동기화한다
  /// (닫은 날의 하루 요약이 먼저 맞아야 동기화가 그 위에서 계산한다). 앞의 일이 실패해도 동기화는 한다.
  /// 닫은 창이 있었으면 동기화가 끝난 뒤 토스트를 띄운다
  Future<void> _startUp() async {
    DateTime? orphanEnd;
    await _service((svc, now) async {
      orphanEnd = await svc.closeOrphanAppWalksEnd(now);
      await svc.saveAlive(now);
    }, '앱 걷기 정리');
    await _startAliveTimer();
    await _sync();
    final end = orphanEnd;
    if (end != null) await _showOrphanToast(end);
  }

  /// 걷는 중에 앱이 끝나 닫은 창 [end] 뒤 지금까지 쌓인 걸음을 세어 `걷기가 멈췄어요` 토스트를 띄운다
  /// (걸음이 없으면 멈췄다는 말만). 첫 동기화가 건강 기록을 넣은 뒤라 그 걸음이 들어 있다.
  /// 같은 동기화가 띄운 `그동안 n km 걸었어요`는 지우고 이 토스트만 남긴다 (같은 걸음 이야기라서)
  Future<void> _showOrphanToast(DateTime end) async {
    var steps = 0;
    await _service((svc, now) async => steps = await svc.stepsFrom(end, now), '멈춘 걷기 걸음 세기');
    final messenger = scaffoldMessengerKey.currentState;
    if (!mounted || messenger == null) return;
    messenger.clearSnackBars();
    showToastOn(messenger, orphanWalkToast(steps));
  }

  /// 새로 얻은 소품 한 줄 토스트. 같은 동기화의 `그동안 n km 걸었어요`나 걷는 중 토스트를 지우지 않고
  /// 그 뒤에 이어서 띄운다
  void _showNewProps(List<Prop> props) {
    final messenger = scaffoldMessengerKey.currentState;
    if (!mounted || messenger == null) return;
    ref.invalidate(ownedPropIdsProvider);
    queueToastOn(messenger, newPropToast(props));
  }

  /// 앱이 살아 있는 동안 rules.aliveSaveSec마다 살아 있다고 적는다
  Future<void> _startAliveTimer() async {
    try {
      final rules = await ref.read(rulesProvider.future);
      if (!mounted) return;
      _aliveTimer = Timer.periodic(Duration(seconds: rules.aliveSaveSec), (_) => _saveAlive());
    } catch (e) {
      debugPrint('살아 있는 시각 저장 시작 실패: $e');
    }
  }

  void _saveAlive() => _service((svc, now) => svc.saveAlive(now), '살아 있는 시각 저장');

  /// 동기화 서비스에 지금 시각으로 일을 시킨다. 실패해도 앱 흐름은 그대로다
  Future<void> _service(
    Future<void> Function(SyncService svc, DateTime now) job,
    String what,
  ) async {
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await job(svc, ref.read(clockProvider)());
    } catch (e) {
      debugPrint('$what 실패: $e');
    }
  }

  /// 앞으로 나왔다: 화면 안 표시 모드로 바꾸고 N5 예약을 취소·초기화한 뒤 동기화한다
  void _onForeground() {
    ref.read(appForegroundProvider.notifier).set(true);
    _notice((svc, now) => svc.onOpen(now));
    _saveAlive();
    _sync();
  }

  /// 백그라운드로 갔다: 이제부터 동기화는 시스템 알림 대상이고, N5를 예약한다.
  /// 앱이 이대로 끝날 수 있어서 살아 있던 시각도 적는다
  void _onBackground() {
    ref.read(appForegroundProvider.notifier).set(false);
    _saveAlive();
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

  /// 겹쳐 돌지 않게 한다 (시작과 resumed가 연달아 올 수 있다): 이미 돌고 있으면 그 동기화를 기다리게 한다
  Future<void> _sync() => _syncing ??= _runSync().whenComplete(() => _syncing = null);

  Future<void> _runSync() async {
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
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
