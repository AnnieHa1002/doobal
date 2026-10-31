import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/providers.dart';
import 'package:doobal/data/backup_store.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import 'ui_env.dart';

/// 올라간 백업(uid, 문자열)을 모으는 가짜 저장소
class _Store implements BackupStore {
  final saved = <(String, String)>[];

  @override
  Future<void> save(String uid, String text) async => saved.add((uid, text));

  @override
  Future<String?> load(String uid) async => null;
}

int _createdUtc(String text) =>
    (jsonDecode(utf8.decode(gzip.decode(base64.decode(text)))) as Map<String, dynamic>)['createdUtc']
        as int;

void _toBackground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void _toForeground(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// 계정을 연결한 사용자([uid])로 앱을 띄운다. [uid]가 null이면 기본 그대로 (연결 없음)
  Future<ProviderContainer> openApp(
    WidgetTester tester,
    UiEnv e,
    _Store store, {
    String? uid,
    Future<void> Function()? seed,
  }) async {
    await e.seed(tester, seed);
    phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...e.overrides,
        backupStoreProvider.overrideWithValue(store),
        if (uid != null) backupUidProvider.overrideWithValue(uid),
      ],
      child: const DoobalApp(),
    ));
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(RestScreen)));
  }

  testWidgets('계정 연결이 없으면(지금은 늘 그렇다) 켜기·백그라운드에서도 백업하지 않는다', (tester) async {
    final e = UiEnv();
    final store = _Store();
    final container = await openApp(tester, e, store);
    expect(container.read(backupUidProvider), isNull);

    _toBackground(tester);
    await settle(tester, () => false, tries: 8);
    _toForeground(tester);
    await settle(tester, () => false, tries: 8);
    e.now = e.now.add(const Duration(days: 1));
    _toBackground(tester);
    await settle(tester, () => false, tries: 8);
    expect(store.saved, isEmpty);
    await end(tester, e);
  });

  testWidgets('연결했으면: 켠 뒤 첫 동기화에 한 번, 10분 안 백그라운드는 건너뛰고 지나면 올린다', (tester) async {
    final e = UiEnv();
    final store = _Store();
    await openApp(tester, e, store, uid: 'u1');

    // 첫 동기화 = 날짜가 바뀐 뒤 첫 동기화 (백업한 적이 없다)
    await settle(tester, () => store.saved.isNotEmpty);
    expect(store.saved, hasLength(1));
    expect(store.saved.single.$1, 'u1');
    expect(_createdUtc(store.saved.single.$2), t1.millisecondsSinceEpoch);

    // 5분 뒤 백그라운드: 건너뛴다 (돌아와도 같은 날이라 동기화 뒤 백업은 없다)
    e.now = t1.add(const Duration(minutes: 5));
    _toBackground(tester);
    await settle(tester, () => false, tries: 8);
    expect(store.saved, hasLength(1));
    _toForeground(tester);
    await settle(tester, () => false, tries: 8);
    expect(store.saved, hasLength(1));

    // 11분 뒤 백그라운드: 올린다
    e.now = t1.add(const Duration(minutes: 11));
    _toBackground(tester);
    await settle(tester, () => store.saved.length == 2);
    expect(store.saved, hasLength(2));
    expect(_createdUtc(store.saved.last.$2), e.now.millisecondsSinceEpoch);
    await end(tester, e);
  });

  testWidgets('연결했으면: 한국 날짜가 바뀐 뒤 첫 동기화(앞으로 돌아올 때)에 올린다', (tester) async {
    final e = UiEnv();
    final store = _Store();
    await openApp(tester, e, store, uid: 'u1');
    await settle(tester, () => store.saved.isNotEmpty);
    expect(store.saved, hasLength(1));

    // 다음 날 낮에 앱으로 돌아온다 (백그라운드로는 안 갔다고 치고 resumed만)
    e.now = t1.add(const Duration(days: 1));
    _toForeground(tester);
    await settle(tester, () => store.saved.length == 2);
    expect(store.saved, hasLength(2));
    expect(_createdUtc(store.saved.last.$2), e.now.millisecondsSinceEpoch);
    await end(tester, e);
  });

  testWidgets('연결했으면: 도착을 알면 올린다 (10분이 지났을 때)', (tester) async {
    final e = UiEnv();
    final store = _Store();
    final container = await openApp(tester, e, store, uid: 'u1', seed: () async {
      await placeAt(e.db, nearGyeongbok, t0);
      await e.svc.startJourney('kr001', t1, useFund: false);
    });
    await settle(tester, () => store.saved.isNotEmpty);
    expect(store.saved, hasLength(1));

    // 30분 걸어서 경복궁에 도착한 기록이 들어오고, 상태를 새로 읽는다
    final svc = (await tester.runAsync(() => container.read(syncServiceProvider.future)))!;
    e.source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), 30, 100));
    e.now = t1.add(const Duration(hours: 2));
    var done = false;
    final run = svc.sync(e.now).whenComplete(() => done = true);
    await settle(tester, () => done, tries: 80);
    await run;
    container.invalidate(snapshotProvider);
    await settle(tester, () => store.saved.length == 2);
    expect(store.saved, hasLength(2));
    expect(_createdUtc(store.saved.last.$2), e.now.millisecondsSinceEpoch);

    // 도착 화면은 백업과 상관없이 그대로 올라온다
    await settle(tester, () => find.byType(ArrivalScreen).evaluate().isNotEmpty);
    await transition(tester);
    expect(find.byType(ArrivalScreen), findsOneWidget);
    await end(tester, e);
  });
}
