import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 아래 탭 (16장 11/18 ①, config ui.tabs.items의 id)
enum HomeTab {
  rest('rest'),
  walk('walk'),
  me('me');

  const HomeTab(this.id);

  final String id;

  static HomeTab of(String id) => values.firstWhere((t) => t.id == id);
}

/// 지금 탭. 앱은 쉼터로 열린다 (config ui.tabs.openTo, 가안). 걸어도·물감 길이 끝나도 저절로 바뀌지 않는다
class CurrentTab extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.rest;

  void go(HomeTab tab) => state = tab;
}

final currentTabProvider = NotifierProvider<CurrentTab, HomeTab>(CurrentTab.new);

/// 탭마다의 Navigator (지도·화집·상점·꾸미기·도착 등은 그 탭 안에서 열려 탭 바가 남는다, M2~M6 AC).
/// 탭을 오가도 각 탭에 쌓인 화면은 그대로다 (config ui.tabs.keepState)
class TabNavigators {
  final _keys = {
    for (final t in HomeTab.values) t: GlobalKey<NavigatorState>(debugLabel: 'tab-${t.id}'),
  };

  /// 탭마다 쌓인 화면 수 (처음 화면 1). 걷기 탭이 처음 화면인지 볼 때 쓴다
  final depth = {for (final t in HomeTab.values) t: ValueNotifier(1)};

  /// 탭마다 쌓인 경로 (아래부터, 탭 뼈대의 관찰자가 채운다)
  final routes = {for (final t in HomeTab.values) t: <Route<dynamic>>[]};

  GlobalKey<NavigatorState> key(HomeTab tab) => _keys[tab]!;

  NavigatorState? of(HomeTab tab) => _keys[tab]!.currentState;

  /// [navigator]가 어느 탭의 것인가 (탭 밖이면 null)
  HomeTab? tabOf(NavigatorState navigator) {
    for (final t in HomeTab.values) {
      if (identical(of(t), navigator)) return t;
    }
    return null;
  }

  /// [tab]을 처음 화면만 남기고 애니메이션 없이 비운다. 떠나는 탭은 애니메이션이 멈추므로(TickerMode)
  /// 닫히는 애니메이션을 기다리지 않고 바로 지운다
  void clear(HomeTab tab) {
    final nav = of(tab);
    if (nav == null) return;
    for (final r in routes[tab]!.reversed.toList()) {
      if (!r.isFirst) nav.removeRoute(r);
    }
  }
}

/// 앱(ProviderScope)에 하나. 깊이 알림은 Navigator가 정리된 뒤에도 올 수 있어 따로 닫지 않는다
final tabNavigatorsProvider = Provider<TabNavigators>((ref) => TabNavigators());

/// 걷기 탭의 처음 화면(걷는 중)이 지금 보이는가: 걷기 탭이고 그 위에 다른 화면이 없다. 탭 뼈대가 정한다.
/// 걷는 중 화면은 이 동안만 가로로 돌 수 있고, 이정표 카드를 띄우고, 걸음 숫자를 따라 올린다
class WalkFront extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool front) => state = front;
}

final walkFrontProvider = NotifierProvider<WalkFront, bool>(WalkFront.new);

/// [tab]으로 바꾸고 그 탭 맨 위에 [page]를 연다 (알림으로 여는 방명록 쓰기·동행 이야기 등).
/// 탭 뼈대가 아직 없으면(시작 흐름 중) null
Future<T?>? openInTab<T>(WidgetRef ref, HomeTab tab, Widget page) {
  final nav = ref.read(tabNavigatorsProvider).of(tab);
  if (nav == null) return null;
  ref.read(currentTabProvider.notifier).go(tab);
  return nav.push(MaterialPageRoute<T>(builder: (_) => page));
}

/// 지금 탭 맨 위에 [page]를 연다 (도착). 탭 뼈대가 아직 없으면 null
Future<T?>? openInCurrentTab<T>(WidgetRef ref, Widget page) =>
    openInTab<T>(ref, ref.read(currentTabProvider), page);

/// [navigator]가 있는 탭을 처음 화면으로 되돌리고 쉼터 탭으로 간다 (지도 ‘출발하기’, 도착 → 걷기 기록 → 쉼터).
/// 다른 탭에서 왔으면 그 탭은 애니메이션 없이 비운다 (숨으면 애니메이션이 멈춰 화면이 남는다). 탭 밖이면 첫 화면까지 닫는다
void backToRest(WidgetRef ref, NavigatorState navigator) {
  final navs = ref.read(tabNavigatorsProvider);
  final tab = navs.tabOf(navigator);
  if (tab == null || tab == HomeTab.rest) {
    navigator.popUntil((r) => r.isFirst);
  } else {
    navs.clear(tab);
  }
  ref.read(currentTabProvider.notifier).go(HomeTab.rest);
}
