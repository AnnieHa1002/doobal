import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/notice_page.dart';
import 'package:doobal/ui/debug/debug_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/settings/settings_screen.dart';
import 'package:doobal/ui/start/welcome_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import 'ui_env.dart';

/// 줄이 모두 만들어지도록 길게 잡은 높이
const _tall = 1400.0;

/// 묻다가 예외가 나는 걸음 출처 (건강 앱이 없는 기기)
class _ThrowingSource extends FakeStepSource {
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    throw StateError('건강 앱이 없다');
  }
}

Future<void> _open(WidgetTester tester, UiEnv e) =>
    openOnTop(tester, e, const SettingsScreen(),
        height: _tall, ready: () => find.text('권한 다시 열기').evaluate().isNotEmpty);

/// 모든 표의 행 수 합
Future<int> _rowCount(WidgetTester tester, AppDb db) async =>
    (await tester.runAsync(() async {
      var n = 0;
      for (final t in db.allTables) {
        n += (await db.select(t).get()).length;
      }
      return n;
    }))!;

GameButton _gameButton(WidgetTester tester, String label) =>
    tester.widget<GameButton>(find.widgetWithText(GameButton, label));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('줄 구성', () {
    testWidgets('제목과 뒤로, 계정 연결·알림은 비활성에 준비 중', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(find.text('설정'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      for (final t in ['계정 연결', '구글', '애플', '카카오', '알림']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // 구글·애플·카카오·알림 네 줄
      expect(find.text('준비 중'), findsNWidgets(4));

      // 눌러도 아무 일도 없다
      await tester.tap(find.text('구글'));
      await tester.tap(find.text('알림'));
      await transition(tester);
      expect(find.byType(NoticePage), findsNothing);
      expect(find.text('설정'), findsOneWidget);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('열기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('그림 출처·AI 사용 고지·이용약관·개인정보처리방침은 빈 문서 화면', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      for (final title in ['그림 출처', 'AI 사용 고지', '이용약관', '개인정보처리방침']) {
        await tester.tap(find.text(title));
        await transition(tester);
        expect(find.byType(NoticePage), findsOneWidget, reason: title);
        expect(find.text(title), findsOneWidget, reason: title);
        expect(find.text('문서를 준비하고 있어요'), findsOneWidget, reason: title);
        expect(find.text('설정'), findsNothing);

        await tester.tap(find.byTooltip('뒤로'));
        await transition(tester);
        expect(find.byType(NoticePage), findsNothing);
        expect(find.text('설정'), findsOneWidget);
      }
      await end(tester, e);
    });

    testWidgets('오픈소스 라이선스는 라이선스 화면을 연다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await tester.tap(find.text('오픈소스 라이선스'));
      await transition(tester);
      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('두발'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('개발자 화면은 그대로 디버그 화면으로 간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await tester.tap(find.text('개발자 화면'));
      await transition(tester);
      expect(find.byType(DebugScreen), findsOneWidget);
      expect(find.text('두발 디버그'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('걸음 데이터', () {
    testWidgets('마지막 동기화 시각을 한국 시간으로 보인다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 2026-11-18 01:05 UTC = 한국 10:05
        await e.svc.sync(t1.add(const Duration(minutes: 5)));
      });
      await _open(tester, e);

      expect(find.text('마지막 기록 11월 18일 10:05'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('아직 한 번도 가져오지 않았으면 안내', (tester) async {
      final e = UiEnv();
      // 동기화 없이 프로필만 (SyncState.lastFetchedUtc가 null)
      await tester.runAsync(() => completeOnboarding(e.db));
      await _open(tester, e);

      expect(find.textContaining('마지막 기록'), findsNothing);
      expect(find.text('아직 가져온 기록이 없어요'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('권한 다시 열기를 누르면 걸음 출처에 권한을 다시 묻는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(e.source.permissionRequests, 0);

      await tester.tap(find.text('권한 다시 열기'));
      await tester.pump();
      await settle(tester, () => e.source.permissionRequests > 0);
      await tester.pump();

      expect(e.source.permissionRequests, 1);
      expect(find.text('걸음 기록을 읽을 수 있어요'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('거부되거나 묻지 못해도 알려 주고 화면은 그대로다', (tester) async {
      final denied = UiEnv(source: FakeStepSource()..granted = false);
      await denied.seed(tester);
      await _open(tester, denied);
      await tester.tap(find.text('권한 다시 열기'));
      await settle(tester, () => denied.source.permissionRequests > 0);
      await tester.pump();
      expect(denied.source.permissionRequests, 1);
      expect(find.textContaining('걸음 권한을 열지 못했어요'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
      await end(tester, denied);

      final broken = UiEnv(source: _ThrowingSource());
      await broken.seed(tester);
      await _open(tester, broken);
      await tester.tap(find.text('권한 다시 열기'));
      await settle(tester, () => broken.source.permissionRequests > 0);
      await tester.pump();
      expect(broken.source.permissionRequests, 1);
      expect(find.textContaining('걸음 권한을 열지 못했어요'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
      await end(tester, broken);
    });
  });

  group('계정 삭제', () {
    /// 앱 전체를 띄워 쉼터에서 설정을 열고 `계정 삭제`를 누른 첫 확인 창까지
    Future<void> openFirstConfirm(WidgetTester tester, UiEnv e) async {
      await e.seed(tester, () async {
        await e.ownPaintings({'kr001': Frame.wood});
      });
      await pumpDoobal(tester, e, const DoobalApp(), height: _tall);
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.tap(find.byIcon(Icons.settings));
      await transition(tester);
      await tester.tap(find.text('계정 삭제'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('첫 확인에서 취소하면 그대로다', (tester) async {
      final e = UiEnv();
      await openFirstConfirm(tester, e);
      final before = await _rowCount(tester, e.db);
      expect(before, greaterThan(0));

      expect(find.text('계정을 삭제할까요?'), findsOneWidget);
      expect(find.text('이 기기의 기록이 모두 지워져요'), findsOneWidget);
      // 첫 확인은 두 버튼 모두 보조 버튼 (테라코타는 마지막 확인에만)
      expect(_gameButton(tester, '취소').kind, GameButtonKind.secondary);
      expect(_gameButton(tester, '계속').kind, GameButtonKind.secondary);

      await tester.tap(find.text('취소'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('계정을 삭제할까요?'), findsNothing);
      expect(find.text('정말 삭제할까요?'), findsNothing);
      expect(find.text('설정'), findsOneWidget);
      expect(await _rowCount(tester, e.db), before);
      await end(tester, e);
    });

    testWidgets('두 번째 확인에서 취소해도 그대로다 (마지막 버튼만 테라코타)', (tester) async {
      final e = UiEnv();
      await openFirstConfirm(tester, e);
      final before = await _rowCount(tester, e.db);

      await tester.tap(find.text('계속'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('정말 삭제할까요?'), findsOneWidget);
      expect(find.text('되돌릴 수 없어요'), findsOneWidget);
      expect(find.text('계정을 삭제할까요?'), findsNothing);
      expect(_gameButton(tester, '삭제').kind, GameButtonKind.primary);
      expect(_gameButton(tester, '취소').kind, GameButtonKind.secondary);

      await tester.tap(find.text('취소'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('정말 삭제할까요?'), findsNothing);
      expect(find.text('설정'), findsOneWidget);
      expect(await _rowCount(tester, e.db), before);
      await end(tester, e);
    });

    testWidgets('창 밖을 눌러 닫아도 지우지 않는다', (tester) async {
      final e = UiEnv();
      await openFirstConfirm(tester, e);
      final before = await _rowCount(tester, e.db);

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('계정을 삭제할까요?'), findsNothing);
      expect(await _rowCount(tester, e.db), before);
      await end(tester, e);
    });

    testWidgets('끝까지 가면 DB가 비고 설정·쉼터를 닫아 환영 화면이 나온다', (tester) async {
      final e = UiEnv();
      await openFirstConfirm(tester, e);
      expect(await _rowCount(tester, e.db), greaterThan(0));

      await tester.tap(find.text('계속'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('삭제'));
      await settle(tester, () => find.byType(WelcomeScreen).evaluate().isNotEmpty);
      await transition(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('만 14세 이상이에요'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(RestScreen), findsNothing);
      // 쉼터가 사라지기 전에 상태를 다시 읽어 SyncState·TravelFund 한 줄씩은 새로 생길 수 있다.
      // 그 둘은 처음 설치한 것과 같은 빈 값이고, 나머지 표는 모두 비어 있다
      for (final t in e.db.allTables) {
        if (t.actualTableName == 'sync_state' || t.actualTableName == 'travel_fund') continue;
        expect(await tester.runAsync(() => e.db.select(t).get()), isEmpty,
            reason: t.actualTableName);
      }
      final state = (await tester.runAsync(() => e.db.select(e.db.syncState).get()))!;
      expect(state.every((r) => r.lastFetchedUtc == null), isTrue);
      final fund = (await tester.runAsync(() => e.db.select(e.db.travelFund).get()))!;
      expect(fund.every((r) => r.km == 0), isTrue);
      await end(tester, e);
    });
  });
}
