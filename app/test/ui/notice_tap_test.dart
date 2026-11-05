import 'dart:async';

import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/local_notifications.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/companion/companion_screen.dart';
import 'package:doobal/ui/guestbook/guestbook_write_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart' show Key;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 누른 알림을 흉내 낸다: [tap]으로 앱이 켜진 채 누르고, [launch]는 알림을 눌러 켜진 경우
class _FakeNotifications extends LocalNotifications {
  _FakeNotifications({this.launch});

  final String? launch;
  final _taps = StreamController<String>.broadcast();

  void tap(String payload) => _taps.add(payload);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> launchPayload() async => launch;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// 걸음 숫자 3,000보 방명록 기회가 열린 상태로 앱(쉼터)을 띄운다
  Future<void> openApp(WidgetTester tester, UiEnv e, _FakeNotifications notices) async {
    await e.seed(
        tester,
        () => e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
              id: milestoneTicketId(3000),
              kind: TicketKind.milestone,
              scope: '3000',
              openedUtc: t1.millisecondsSinceEpoch,
            )));
    phone(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [...e.overrides, localNotificationsProvider.overrideWithValue(notices)],
      child: const DoobalApp(),
    ));
    await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
  }

  testWidgets('N1(방명록 걸음 숫자)을 누르면 그 기회의 방명록 쓰기가 열린다', (tester) async {
    final e = UiEnv();
    final notices = _FakeNotifications();
    await openApp(tester, e, notices);
    expect(find.byType(GuestbookWriteScreen), findsNothing);

    notices.tap('N1:m:3000');
    await settle(tester, () => find.byType(GuestbookWriteScreen).evaluate().isNotEmpty);
    expect(tester.widget<GuestbookWriteScreen>(find.byType(GuestbookWriteScreen)).ticketId,
        'm:3000');
    await end(tester, e);
  });

  testWidgets('N1을 눌러 앱이 켜졌으면 쉼터 위에 방명록 쓰기가 열린다', (tester) async {
    final e = UiEnv();
    await openApp(tester, e, _FakeNotifications(launch: 'N1:m:3000'));
    await settle(tester, () => find.byType(GuestbookWriteScreen).evaluate().isNotEmpty);
    expect(tester.widget<GuestbookWriteScreen>(find.byType(GuestbookWriteScreen)).ticketId,
        'm:3000');
    await end(tester, e);
  });

  group('N3(이야기 새 장)', () {
    final sheet = find.byKey(const Key('story-sheet'));
    String title(String id, int no) => companionCatalog.byId(id)!.chapters[no].title;

    /// 동행 둘을 만나 둔 앱을 띄운다 (퐁이 2장까지 열림, 휴 1장까지 열림, 지금은 휴와 걷는 중)
    Future<void> openWithStories(WidgetTester tester, UiEnv e, _FakeNotifications notices) async {
      await e.seed(tester, () async {
        await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
            companionId: 'bright', metUtc: 1, chapter: const Value(2)));
        await e.db.into(e.db.companions).insert(CompanionsCompanion.insert(
            companionId: 'rest', metUtc: 2, chapter: const Value(1)));
        await e.db.into(e.db.companionStints).insert(CompanionStintsCompanion.insert(
            startUtc: const Value(1), companionId: const Value('rest')));
      });
      phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [...e.overrides, localNotificationsProvider.overrideWithValue(notices)],
        child: const DoobalApp(),
      ));
      await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
    }

    testWidgets('누르면 그 동행의 그 장이 열리고 읽은 것으로 남는다', (tester) async {
      final e = UiEnv();
      final notices = _FakeNotifications();
      await openWithStories(tester, e, notices);

      notices.tap('N3:bright:2');
      await settle(tester, () => sheet.evaluate().isNotEmpty);
      expect(find.byType(CompanionScreen), findsOneWidget);
      expect(find.textContaining(title('bright', 2)), findsWidgets);
      final row = (await tester.runAsync(() => (e.db.select(e.db.companions)
            ..where((t) => t.companionId.equals('bright')))
          .getSingle()))!;
      expect(row.readChapter, 2);
      await end(tester, e);
    });

    testWidgets('알림으로 앱이 켜져도 그 장이 열린다', (tester) async {
      final e = UiEnv();
      await openWithStories(tester, e, _FakeNotifications(launch: 'N3:rest:1'));
      await settle(tester, () => sheet.evaluate().isNotEmpty);
      expect(find.textContaining(title('rest', 1)), findsWidgets);
      await end(tester, e);
    });

    testWidgets('안 열린 장·안 만난 동행이면 시트 없이 동행 화면만 연다', (tester) async {
      final e = UiEnv();
      final notices = _FakeNotifications();
      await openWithStories(tester, e, notices);

      notices.tap('N3:bright:5');
      await settle(tester, () => find.byKey(const Key('companion-now')).evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 3);
      expect(sheet, findsNothing);

      notices.tap('N3:doctor:1');
      await settle(tester, () => false, tries: 3);
      expect(sheet, findsNothing);
      await end(tester, e);
    });

    testWidgets('key 모양이 다르면 쉼터 그대로', (tester) async {
      final e = UiEnv();
      final notices = _FakeNotifications();
      await openWithStories(tester, e, notices);
      notices.tap('N3:bright');
      notices.tap('N3:');
      await settle(tester, () => false, tries: 3);
      expect(find.byType(CompanionScreen), findsNothing);
      await end(tester, e);
    });
  });

  testWidgets('N4·N5·모르는 알림은 쉼터 그대로 (따로 여는 화면이 없다)', (tester) async {
    final e = UiEnv();
    final notices = _FakeNotifications();
    await openApp(tester, e, notices);
    for (final payload in ['N4:j-1', 'N5:', 'walk']) {
      notices.tap(payload);
      await settle(tester, () => false, tries: 3);
    }
    expect(find.byType(GuestbookWriteScreen), findsNothing);
    expect(find.byType(RestScreen), findsOneWidget);
    await end(tester, e);
  });
}
