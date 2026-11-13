import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auto_sync.dart' show scaffoldMessengerKey;
import '../../app/paint_trail_controller.dart';
import '../common/toast.dart';
import 'walking_screen.dart';

/// 걷는 중 화면의 경로 이름 (지금 맨 위가 걷는 중인지 알아보려고)
const walkingRouteName = 'walking';

/// 지금 맨 위 경로를 지켜본다 (MaterialApp.navigatorObservers). 시트·다이얼로그(PopupRoute)가 떠 있는지,
/// 걷는 중 화면이 맨 위인지 물감 길 화면 전환이 본다. 앱에 하나다
class TopRouteObserver extends NavigatorObserver {
  final top = ValueNotifier<Route<dynamic>?>(null);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => top.value = route;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => top.value = previousRoute;

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (top.value == route) top.value = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (top.value == oldRoute) top.value = newRoute;
  }

  /// 맨 위가 시트·다이얼로그인가
  bool get popupOnTop => top.value is PopupRoute;

  /// 맨 위가 걷는 중 화면인가
  bool get walkingOnTop => top.value?.settings.name == walkingRouteName;
}

final topRouteObserver = TopRouteObserver();

/// 물감 길이 시작돼도 걷는 중으로 넘어가지 않고 기다리게 하는 화면 수 (방명록 쓰기·꾸미기·도착, 가안).
/// 닫히면 0이 되고 그때 넘어간다
class TrailHold extends Notifier<int> {
  @override
  int build() => 0;

  void enter() => state = state + 1;

  void leave() => state = state > 0 ? state - 1 : 0;
}

final trailHoldProvider = NotifierProvider<TrailHold, int>(TrailHold.new);

/// [TrailHold]를 쓰는 화면이 섞는다: 떠 있는 동안 물감 길 화면 전환을 기다리게 한다
mixin HoldsPaintTrail<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final TrailHold _hold;

  @override
  void initState() {
    super.initState();
    _hold = ref.read(trailHoldProvider.notifier);
    // 위젯을 짓는 중에는 provider를 못 바꾼다
    Future.microtask(() {
      try {
        _hold.enter();
      } catch (_) {
        // 앱이 통째로 정리되는 중
      }
    });
  }

  @override
  void dispose() {
    Future.microtask(() {
      try {
        _hold.leave();
      } catch (_) {
        // 앱이 통째로 정리되는 중
      }
    });
    super.dispose();
  }
}

/// 걷는 중 화면을 쉼터 바로 위에 연다 (다른 화면은 닫는다. 쉼터 = 루트)
void openWalking(NavigatorState navigator) {
  navigator.popUntil((r) => r.isFirst);
  navigator.push(MaterialPageRoute<void>(
    settings: const RouteSettings(name: walkingRouteName),
    builder: (_) => const WalkingScreen(),
  ));
}

/// 물감 길 화면 전환 (M2~M6 명세 v0.17 T①, 캔버스 2-2·3-1): 쉼터 위에 둔다 (StartGate).
/// - 물감 길이 열리면 어느 화면에서든 걷는 중으로 넘어간다. 시트·다이얼로그·방명록 쓰기·꾸미기·도착 화면이
///   떠 있으면 닫힐 때까지 기다린다 (가안). 기다리는 사이 물감 길이 끝나면 넘어가지 않는다.
/// - 걸음이 멈춰 물감 길이 끝나면 걷는 중 화면이 맨 위일 때 쉼터로 돌아가고, 토스트
///   `물감 길 n km를 그렸어요`를 띄운다 (다른 화면을 보고 있으면 토스트만).
/// 물감 길 판정 자체는 PaintTrailController가 한다 (이 위젯이 그 상태를 붙잡아 살려 둔다)
class PaintTrailHost extends ConsumerStatefulWidget {
  const PaintTrailHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PaintTrailHost> createState() => _PaintTrailHostState();
}

class _PaintTrailHostState extends ConsumerState<PaintTrailHost> {
  /// 열린 물감 길로 아직 넘어가지 않았다 (막혀서 기다리는 중)
  var _pendingOpen = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(paintTrailProvider, (prev, next) {
      if (prev?.active != true && next.active) {
        _pendingOpen = true;
        _tryOpen();
      } else if (prev?.active == true && !next.active) {
        _pendingOpen = false;
        _onEnded(next);
      }
    });
    ref.listenManual(trailHoldProvider, (_, _) => _tryOpen());
    topRouteObserver.top.addListener(_tryOpen);
  }

  @override
  void dispose() {
    topRouteObserver.top.removeListener(_tryOpen);
    super.dispose();
  }

  /// 기다리던 물감 길이 있고 막는 화면이 없으면 걷는 중으로 넘어간다
  void _tryOpen() {
    if (!_pendingOpen || !mounted) return;
    if (!ref.read(paintTrailProvider).active) {
      _pendingOpen = false;
      return;
    }
    if (topRouteObserver.popupOnTop || ref.read(trailHoldProvider) > 0) return;
    if (topRouteObserver.walkingOnTop) {
      _pendingOpen = false;
      return;
    }
    _pendingOpen = false;
    // 화면을 짓거나 경로를 바꾸는 중일 수 있어서 이번 프레임이 끝난 뒤에
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(paintTrailProvider).active) return;
      openWalking(Navigator.of(context));
    });
  }

  /// 물감 길이 끝났다: 걷는 중이 맨 위면 쉼터로, 토스트 한 줄
  void _onEnded(PaintTrailState s) {
    if (topRouteObserver.walkingOnTop) Navigator.of(context).popUntil((r) => r.isFirst);
    final km = s.endedKm;
    final messenger = scaffoldMessengerKey.currentState;
    if (km == null || messenger == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queueToastOn(messenger, paintTrailEndedToast(km));
    });
  }

  @override
  Widget build(BuildContext context) {
    // 물감 길 판정을 앱이 쉼터에 있는 동안 살려 둔다
    ref.watch(paintTrailProvider.select((s) => s.active));
    return widget.child;
  }
}

/// 물감 길이 끝나 쉼터로 돌아왔을 때의 토스트 (캔버스 2-2): `물감 길 2.0km를 그렸어요`
String paintTrailEndedToast(double km) => '물감 길 ${km.toStringAsFixed(1)}km를 그렸어요';
