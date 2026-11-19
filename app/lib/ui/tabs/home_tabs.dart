import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/companion_providers.dart';
import '../../app/paint_trail_controller.dart';
import '../../app/providers.dart';
import '../../app/report_providers.dart';
import '../common/screen_orientation.dart';
import '../day_card/day_card_view.dart';
import '../profile/profile_screen.dart';
import '../rest/rest_screen.dart';
import '../walking/walking_screen.dart';
import 'home_tab.dart';
import 'tab_bar.dart';

export 'home_tab.dart';

/// 지금 보이는 아래 탭 바의 높이 (숨었으면 0). 쉼터·걷기 탭 장면은 이만큼에서 30pt 덜 올라간다
/// (캔버스 2-2·3-1: 장면 아래가 탭 바 위로 30pt 겹친다)
class TabBarSpace extends InheritedWidget {
  const TabBarSpace({super.key, required this.height, required super.child});

  final double height;

  /// 탭 뼈대 밖(시험에서 화면만 띄울 때)이면 0
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabBarSpace>()?.height ?? 0;

  /// 장면 아래를 탭 바 위로 얼마나 올리는가 (탭 바 높이 − 겹침 30pt)
  static double sceneBottom(BuildContext context) {
    final h = of(context);
    return h <= TabBarMetrics.sceneOverlap ? 0 : h - TabBarMetrics.sceneOverlap;
  }

  @override
  bool updateShouldNotify(TabBarSpace old) => old.height != height;
}

/// 앱 뼈대 = 아래 탭 3개 (16장 11/18 ①④⑤⑥·11/19, 캔버스 TabBar·2-2·3-1·9-1, M2~M6 AB·AC).
/// 탭마다 Navigator가 있어 지도·화집·상점·꾸미기·도착·동행 등은 그 탭 안에서 열리고 탭 바가 남는다.
/// 시작 흐름·그림 크게 보기·이야기 읽기·시트는 앱 Navigator 위로 떠서 탭 바를 덮는다 (config ui.tabs.hiddenOn).
/// 걷기 탭을 가로로 돌리면 탭 바를 숨긴다 (ui.tabs.landscapeHidesBar).
/// 탭은 처음 갈 때 짓고 그 뒤로는 살려 둔다 (keepState): 안 보이는 탭은 그리지 않고 애니메이션·정령도 멈춘다
/// (Offstage + TickerMode). 탭을 누르면 그 탭의 처음 화면 (캔버스 TabBar 메모), 시스템 뒤로는 그 탭 안에서
/// 한 단계, 처음 화면이면 쉼터 탭으로, 쉼터 처음 화면이면 앱을 닫는다.
/// 걸어도·물감 길이 끝나도 탭은 저절로 바뀌지 않는다 (11/16 쉼터↔걷는 중 6규칙을 대신함).
/// 걷는 중(물감 길이 열림)이면 걷기 아이콘의 발자국이 깜빡인다.
/// 가로 화면은 걷기 탭의 처음 화면(걷는 중)만 (config ui.orientation.landscape walking).
/// 새벽 5시 뒤 그날 처음 열면 하루 카드(캔버스 2-3)가 쉼터 처음 화면 위, 탭 바까지 덮어 뜬다
/// (캔버스 TabBar 메모 ‘하루 카드는 탭 바 위에’). 다른 탭이나 쉼터 위 다른 화면에 있으면 쉼터로 돌아올 때 보인다.
/// 시스템 뒤로는 카드를 닫는다
class HomeTabs extends ConsumerStatefulWidget {
  const HomeTabs({super.key});

  @override
  ConsumerState<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends ConsumerState<HomeTabs> {
  late final TabNavigators _navs;
  late final Map<HomeTab, _DepthObserver> _observers;

  /// 정리할 때는 ref를 못 쓰므로 처음에 잡아 둔다
  late final WalkFront _walkFront;

  /// 한 번이라도 연 탭 (처음 갈 때 짓는다)
  final _built = <HomeTab>{};

  /// 마지막으로 정한 방향 (가로 허용인가)
  bool? _landscapeOpen;

  @override
  void initState() {
    super.initState();
    _navs = ref.read(tabNavigatorsProvider);
    _walkFront = ref.read(walkFrontProvider.notifier);
    _observers = {for (final t in HomeTab.values) t: _DepthObserver(_navs.depth[t]!, _navs.routes[t]!)};
    _navs.depth[HomeTab.walk]!.addListener(_syncFront);
    final openTo = ref.read(rulesProvider).value?.screen.tabs.openTo;
    // 위젯을 짓는 중에는 provider를 못 바꾼다
    Future.microtask(() {
      if (mounted && openTo != null) ref.read(currentTabProvider.notifier).go(HomeTab.of(openTo));
    });
    ref.listenManual(currentTabProvider, (_, _) => _syncFront());
  }

  @override
  void dispose() {
    _navs.depth[HomeTab.walk]!.removeListener(_syncFront);
    if (_landscapeOpen ?? false) unawaited(SystemChrome.setPreferredOrientations(portraitOnly));
    final front = _walkFront;
    Future.microtask(() {
      try {
        front.set(false);
      } catch (_) {
        // 앱이 통째로 정리되는 중
      }
    });
    super.dispose();
  }

  /// 걷기 탭 처음 화면이 보이는지 알리고, 그때만 가로를 연다. 경로가 바뀌는 중일 수 있어 이번 그리기가 끝난 뒤에
  void _syncFront() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final front = ref.read(currentTabProvider) == HomeTab.walk && _navs.depth[HomeTab.walk]!.value <= 1;
      if (ref.read(walkFrontProvider) != front) ref.read(walkFrontProvider.notifier).set(front);
      final rules = ref.read(rulesProvider).value;
      if (rules == null) return;
      final open = front && rules.screen.landscapeScreens.contains('walking');
      if (open == _landscapeOpen) return;
      _landscapeOpen = open;
      unawaited(lockOrientation(rules.screen, open ? 'walking' : 'rest'));
    });
  }

  /// 탭을 눌렀다: 그 탭의 처음 화면으로 (같은 탭을 다시 눌러도)
  void _select(HomeTab tab) {
    _navs.of(tab)?.popUntil((r) => r.isFirst);
    ref.read(currentTabProvider.notifier).go(tab);
  }

  /// 하루 카드가 떠 있는가 (쉼터 탭 처음 화면에서만)
  bool _cardShown() =>
      ref.read(pendingDayCardProvider) != null &&
      ref.read(currentTabProvider) == HomeTab.rest &&
      _navs.depth[HomeTab.rest]!.value <= 1;

  /// 시스템 뒤로: 하루 카드 닫기 → 지금 탭 안에서 한 단계 → 쉼터 탭 → 앱 닫기
  Future<void> _back() async {
    if (_cardShown()) {
      ref.read(pendingDayCardProvider.notifier).dismiss();
      return;
    }
    final tab = ref.read(currentTabProvider);
    final nav = _navs.of(tab);
    if (nav != null && await nav.maybePop()) return;
    if (!mounted) return;
    if (tab != HomeTab.rest) {
      ref.read(currentTabProvider.notifier).go(HomeTab.rest);
      return;
    }
    await SystemNavigator.pop();
  }

  Widget _root(HomeTab tab) => switch (tab) {
        HomeTab.rest => const RestScreen(),
        HomeTab.walk => const WalkingScreen(),
        HomeTab.me => const ProfileScreen(),
      };

  Widget _tab(HomeTab tab, bool on) {
    if (on) _built.add(tab);
    if (!_built.contains(tab)) return const SizedBox.shrink();
    return Offstage(
      key: ValueKey('tab-body-${tab.id}'),
      offstage: !on,
      child: TickerMode(
        enabled: on,
        child: Navigator(
          key: _navs.key(tab),
          observers: [_observers[tab]!],
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => _root(tab),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value;
    final current = ref.watch(currentTabProvider);
    if (rules == null) return const Scaffold(body: SizedBox.expand());
    final tabs = rules.screen.tabs;
    final walking = ref.watch(paintTrailProvider.select((s) => s.active));
    final story = tabs.walkDots.contains('companionStory') &&
        rules.screen.dotOn('companion') &&
        ref.watch(unreadStoryProvider);
    final sign = tabs.walkDots.contains('guestbookSign') &&
        ref.watch(snapshotProvider.select((s) => s.value?.guestbookTicket != null));
    final mq = MediaQuery.of(context);
    final hideBar =
        current == HomeTab.walk && tabs.landscapeHidesBar && mq.orientation == Orientation.landscape;
    final barHeight = hideBar ? 0.0 : TabBarMetrics.height(mq.size, mq.viewPadding.bottom);
    final order = [for (final id in tabs.items) HomeTab.of(id)];
    final dayCard = ref.watch(pendingDayCardProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: TabBarSpace(
        height: barHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Scaffold(
          // 탭 안 화면은 탭 바 뒤까지 펼치고 MediaQuery 아래 여백으로 탭 바를 피한다 (장면은 30pt 겹친다)
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            children: [for (final t in order) _tab(t, t == current)],
          ),
          bottomNavigationBar: hideBar
              ? null
              : DoobalTabBar(
                  tabs: order,
                  labels: tabs.labels,
                  current: current,
                  walking: walking,
                  walkDot: story || sign,
                  onTap: _select,
                ),
              ),
            ),
            if (dayCard != null && current == HomeTab.rest)
              ValueListenableBuilder<int>(
                valueListenable: _navs.depth[HomeTab.rest]!,
                builder: (context, depth, _) => depth > 1
                    ? const SizedBox.shrink()
                    : Positioned.fill(
                        child: DayCardOverlay(
                          key: const ValueKey('rest-day-card'),
                          card: dayCard,
                          onClose: () => ref.read(pendingDayCardProvider.notifier).dismiss(),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 탭 Navigator에 쌓인 경로와 그 수를 센다 (처음 화면 1)
class _DepthObserver extends NavigatorObserver {
  _DepthObserver(this.depth, this.routes);

  final ValueNotifier<int> depth;
  final List<Route<dynamic>> routes;

  void _changed() {
    // 경로는 Navigator가 짓는 중에 바뀔 수 있어서 알림은 이번 프레임 뒤에
    WidgetsBinding.instance.addPostFrameCallback((_) => depth.value = routes.length);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      routes[i] = newRoute;
    } else if (newRoute != null) {
      routes.add(newRoute);
    }
    _changed();
  }
}
