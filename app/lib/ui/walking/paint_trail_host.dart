import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auto_sync.dart' show scaffoldMessengerKey;
import '../../app/paint_trail_controller.dart';
import '../../app/providers.dart' show appForegroundProvider;
import '../../domain/paint_trail.dart' show PaintTrailEnd;
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

  /// 맨 위가 쉼터(루트, 시트·다이얼로그 없이)인가
  bool get restOnTop => top.value?.isFirst ?? false;
}

final topRouteObserver = TopRouteObserver();

/// 물감 길이 시작돼도 걷는 중으로 넘어가지 않고 기다리게 하는 화면 수 (방명록 쓰기·꾸미기·도착).
/// 16장 11/16 ③부터는 쉼터가 맨 위일 때만 넘어가서 이 화면들도 저절로 기다린다 (남겨 둔 겹 막기)
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

/// 걷는 중 구석 쉼터 아이콘으로 쉼터에 온 물감 길 번호 (16장 11/16 ④): 그 물감 길 동안은 저절로 걷는 중으로
/// 되돌아가지 않는다 (쉼터에서 연 화면을 닫아도, 앱을 다시 열어도 쉼터. 11/17 ④가 ①보다 먼저). 새 물감 길이 열리면 비운다
class WalkingDismissed extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? trailId) => state = trailId;
}

final walkingDismissedProvider = NotifierProvider<WalkingDismissed, int?>(WalkingDismissed.new);

/// 걷는 중 화면을 쉼터 바로 위에 연다 (그 위 다른 화면은 닫는다. 쉼터 = 루트). 쉼터를 거치지 않고 바로 바뀐다
void openWalking(NavigatorState navigator) {
  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: walkingRouteName),
      builder: (_) => const WalkingScreen(),
    ),
    (r) => r.isFirst,
  );
}

/// 물감 길이 열려 있고 쉼터 아이콘으로 떠나지 않았으면 걷는 중으로 가야 한다 (16장 11/16 ③: 다른 화면을 닫으면 걷는 중)
bool walkingDue(WidgetRef ref) {
  final s = ref.read(paintTrailProvider);
  return s.active && ref.read(walkingDismissedProvider) != s.id;
}

/// 물감 길 화면 전환 (16장 11/16 ‘쉼터↔걷는 중 화면 흐름’ 6규칙, 8장 3번, 캔버스 2-2·3-1): 쉼터 위에 둔다 (StartGate).
/// 기준은 물감 길이 열려 있느냐다.
/// ① 앱을 다시 열 때(앞으로 올 때) 물감 길이 열려 있으면 걷는 중. 단 그 물감 길에서 쉼터 아이콘으로 떠났으면
///   쉼터 그대로다 (16장 11/17: ④가 ①보다 먼저). 앱을 새로 켜면 앞 실행의 물감 길은 닫혀 있어(AutoSync appEnded) 쉼터다.
/// ② 쉼터에서 걷기 시작하면 저절로 걷는 중.
/// ③ 다른 화면(지도·화집·꾸미기·상점·도착 등)이나 시트·다이얼로그가 떠 있으면 그대로 두고, 닫혀서 쉼터가 맨 위가
///   되면 걷는 중. 기다리는 사이 물감 길이 끝나면 넘어가지 않는다.
/// ④ 걷는 중 구석 쉼터 아이콘으로 쉼터에 오면 그 물감 길 동안은 저절로 되돌아가지 않는다 ([walkingDismissedProvider],
///   앱을 껐다 켜도 그대로. 새 물감 길이 열리면 잊는다).
///   쉼터 위 가운데 ‘걷는 중 · 물감 길 n km ›’를 누르면 걷는 중.
/// ⑤ 걸음이 멈춰 물감 길이 끝나면 걷는 중 화면이 맨 위일 때 쉼터로 돌아가고 토스트 `물감 길 n km를 그렸어요`
///   (다른 화면을 보고 있으면 화면은 그대로, 토스트만).
/// ⑥ 명소에 도착해 끝났으면(config paintTrail.endOnArrival) 아무것도 하지 않는다: 걷는 중이 도착 화면으로 바꾸고
///   (걷는 중이 아니면 AutoSync가 띄운다), 도착 화면을 닫으면 쉼터(그사이 새 물감 길이 열렸으면 바로 걷는 중). 토스트는 없다.
/// 걷는 중은 늘 쉼터 바로 위 한 겹이다 (쉼터를 그 위에 올리지 않는다: 걷는 중만 가로라서 닫히면 세로로 돌아온다).
/// 물감 길 판정 자체는 PaintTrailController가 한다 (이 위젯이 그 상태를 붙잡아 살려 둔다)
class PaintTrailHost extends ConsumerStatefulWidget {
  const PaintTrailHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PaintTrailHost> createState() => _PaintTrailHostState();
}

class _PaintTrailHostState extends ConsumerState<PaintTrailHost> {
  /// 열린 물감 길로 아직 넘어가지 않았다 (쉼터가 맨 위가 아니라서 기다리는 중)
  var _pendingOpen = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(paintTrailProvider, (prev, next) {
      if (next.active && next.id != prev?.id) {
        // 새 물감 길: 앞 물감 길에서 쉼터로 떠난 것은 잊는다
        ref.read(walkingDismissedProvider.notifier).set(null);
        _pendingOpen = true;
        _tryOpen();
      } else if (prev?.active == true && !next.active) {
        _pendingOpen = false;
        _onEnded(next);
      }
    });
    // ① 앱을 다시 열면 열린 물감 길로 (쉼터 아이콘으로 떠난 물감 길이면 walkingDue가 막는다: ④가 먼저)
    ref.listenManual(appForegroundProvider, (prev, next) {
      if (prev == false && next && ref.read(paintTrailProvider).active) {
        _pendingOpen = true;
        _tryOpen();
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

  /// 기다리던 물감 길이 있고 쉼터가 맨 위이면 걷는 중으로 넘어간다
  void _tryOpen() {
    if (!_pendingOpen || !mounted) return;
    if (!walkingDue(ref) || topRouteObserver.walkingOnTop) {
      _pendingOpen = false;
      return;
    }
    if (!topRouteObserver.restOnTop || ref.read(trailHoldProvider) > 0) return;
    _pendingOpen = false;
    // 화면을 짓거나 경로를 바꾸는 중일 수 있어서 이번 프레임이 끝난 뒤에
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !walkingDue(ref) || topRouteObserver.walkingOnTop) return;
      openWalking(Navigator.of(context));
    });
  }

  /// 물감 길이 끝났다: 걷는 중이 맨 위면 쉼터로, 토스트 한 줄. 도착으로 끝났으면 도착 화면이 맡는다
  void _onEnded(PaintTrailState s) {
    if (s.endedBy == PaintTrailEnd.arrived) return;
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
