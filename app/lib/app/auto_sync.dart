import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/arrival/arrival_screen.dart';
import 'providers.dart';
import 'sync_service.dart';

/// MaterialApp에 달아 두면 어느 화면에서도 토스트를 띄울 수 있다
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 이 거리(km) 이상 늘었을 때만 "그동안 n km 걸었어요"를 보여 준다
const _toastMinKm = 0.1;

/// 앱을 켤 때와 백그라운드에서 돌아올 때 한 번씩 동기화하고 상태를 새로 읽는다.
/// 권한이 없는 등 실패는 조용히 넘어간다.
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
    _lifecycle = AppLifecycleListener(onResume: _sync);
    ref.listenManual(snapshotProvider, (_, next) => _checkArrival(next.value),
        fireImmediately: true);
    _sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _checkArrival(Snapshot? snap) {
    final id = snap?.pendingArrival?.journeyId;
    if (id == null || !_arrivalsShown.add(id)) return;
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
    } catch (e) {
      debugPrint('자동 동기화 실패: $e');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
