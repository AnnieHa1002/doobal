import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/notification_permission.dart';
import 'package:doobal/data/notifier.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:doobal/domain/rules.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/notice_page.dart';
import 'package:doobal/ui/debug/debug_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/settings/settings_screen.dart';
import 'package:doobal/ui/start/welcome_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

/// 알림 권한을 흉내 낸다. [state]는 isGranted가 돌려줄 값(null이면 모름),
/// [grantOnRequest]가 true면 권한을 물으면 허용된다
class _FakePermission implements NotificationPermission {
  _FakePermission(this.state, {this.grantOnRequest = false});

  bool? state;
  final bool grantOnRequest;
  var requests = 0;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grantOnRequest) state = true;
    return state ?? false;
  }

  @override
  Future<bool?> isGranted() async => state;
}

/// 알림 줄까지 읽혀서 그려질 때까지 기다린다
Future<void> _open(WidgetTester tester, UiEnv e, {List<Override> extra = const []}) =>
    openOnTop(tester, e, const SettingsScreen(),
        height: _tall,
        extra: extra,
        ready: () =>
            find.text('권한 다시 열기').evaluate().isNotEmpty &&
            find.text('알림 받기').evaluate().isNotEmpty);

/// 앱을 뒤로 보냈다가 앞으로 가져온다 (휴대폰 설정에 다녀오는 것과 같다)
void _leaveAndReturn(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

/// 알림 줄의 스위치: 0 전체, 1~5 방명록 기회·도착·이야기·거의 다 왔어·다시 부르기
bool _on(WidgetTester tester, int i) => tester.widget<Switch>(find.byType(Switch).at(i)).value;

/// 그 스위치 줄의 불투명도 (흐리면 0.4)
double _opacity(WidgetTester tester, int i) {
  final row = find.ancestor(of: find.byType(Switch).at(i), matching: find.byType(Opacity));
  return tester.widget<Opacity>(row.first).opacity;
}

/// config.json의 notifications 값을 바꾼 규칙
Rules _rulesWith(Map<String, Object> notifications) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  (j['notifications'] as Map<String, dynamic>).addAll(notifications);
  return Rules.fromJson(j);
}

Future<List<NotificationSettingsRow>> _settingsRows(WidgetTester tester, AppDb db) async =>
    (await tester.runAsync(() => db.select(db.notificationSettings).get()))!;

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
    testWidgets('제목과 뒤로, 계정 연결은 비활성에 준비 중', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(find.text('설정'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      for (final t in ['계정 연결', '구글', '애플', '카카오', '알림']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      // 구글·애플·카카오 세 줄
      expect(find.text('준비 중'), findsNWidgets(3));

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

  group('알림', () {
    const kinds = ['방명록 기회', '도착', '이야기', '거의 다 왔어(10km)', '다시 부르기(3일)'];

    testWidgets('전체 켜기 한 줄 + 종류별 다섯 줄이 모두 켜져 있고, 안내 글이 config 숫자다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(find.text('알림'), findsOneWidget);
      expect(find.text('알림 받기'), findsOneWidget);
      for (final t in kinds) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.byType(Switch), findsNWidgets(6));
      for (var i = 0; i < 6; i++) {
        expect(_on(tester, i), isTrue, reason: '$i');
        expect(_opacity(tester, i), 1, reason: '$i');
      }
      expect(find.text('하루 최대 2개, 밤 10시~아침 8시에는 보내지 않아요'), findsOneWidget);
      // 권한을 모르면(자리표시) 꺼진 것으로 보지 않는다: 경고 줄이 없다
      expect(find.text('휴대폰 설정에서 알림을 켜 주세요'), findsNothing);
      expect(find.text('설정 열기'), findsNothing);
      await end(tester, e);
    });

    testWidgets('안내 글과 줄 이름의 숫자는 config에서 읽는다', (tester) async {
      final e = UiEnv(
          appRules: _rulesWith({
        'dailyMax': 3,
        'quietFromHour': 23,
        'quietToHour': 7,
        'nearDestKm': 5,
        'inactiveHours': 48,
      }));
      await e.seed(tester);
      await _open(tester, e);

      expect(find.text('하루 최대 3개, 밤 11시~아침 7시에는 보내지 않아요'), findsOneWidget);
      expect(find.text('거의 다 왔어(5km)'), findsOneWidget);
      expect(find.text('다시 부르기(2일)'), findsOneWidget);
      await end(tester, e);

      // 소수 km·하루로 안 나눠지는 시간
      final e2 = UiEnv(appRules: _rulesWith({'nearDestKm': 7.5, 'inactiveHours': 36}));
      await e2.seed(tester);
      await _open(tester, e2);
      expect(find.text('거의 다 왔어(7.5km)'), findsOneWidget);
      expect(find.text('다시 부르기(36시간)'), findsOneWidget);
      await end(tester, e2);
    });

    testWidgets('종류 하나를 끄면 저장되고, 화면을 다시 열어도 그대로다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      expect(await _settingsRows(tester, e.db), isEmpty);

      await tester.tap(find.text('도착'));
      await tester.pump();
      await settle(tester, () => !_on(tester, 2));
      expect(_on(tester, 2), isFalse);
      // 다른 줄은 그대로다
      expect([for (var i = 0; i < 6; i++) _on(tester, i)], [true, true, false, true, true, true]);
      final row = (await _settingsRows(tester, e.db)).single;
      expect((row.allOn, row.n1On, row.n2On, row.n3On, row.n4On, row.n5On),
          (true, true, false, true, true, true));

      // 줄의 오른쪽 스위치 자리를 눌러도 바뀐다 (줄 어디나 눌린다)
      await tester.tap(find.byType(Switch).at(3), warnIfMissed: false);
      await settle(tester, () => !_on(tester, 3));
      expect(_on(tester, 3), isFalse);

      // 닫았다 다시 열면 저장한 대로 읽힌다
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await tester.tap(find.text('열기'));
      await transition(tester);
      await settle(tester, () => find.text('알림 받기').evaluate().isNotEmpty);
      await tester.pump();
      expect([for (var i = 0; i < 6; i++) _on(tester, i)], [true, true, false, false, true, true]);

      // 다시 켠다
      await tester.tap(find.text('도착'));
      await settle(tester, () => _on(tester, 2));
      expect(_on(tester, 2), isTrue);
      await end(tester, e);
    });

    testWidgets('전체를 끄면 종류별 다섯이 흐려져서 눌리지 않고, 다시 켜면 앞서 고른 대로다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      // 이야기만 먼저 끈다
      await tester.tap(find.text('이야기'));
      await settle(tester, () => !_on(tester, 3));

      await tester.tap(find.text('알림 받기'));
      await settle(tester, () => !_on(tester, 0));
      expect(_on(tester, 0), isFalse);
      // 전체는 그대로 눌린다 (흐리지 않다). 종류별은 값은 그대로 두고 흐려진다
      expect(_opacity(tester, 0), 1);
      for (var i = 1; i < 6; i++) {
        expect(_opacity(tester, i), closeTo(0.4, 1e-9), reason: '$i');
      }
      expect([for (var i = 1; i < 6; i++) _on(tester, i)], [true, true, false, true, true]);

      // 흐린 줄은 눌러도 바뀌지 않는다
      await tester.tap(find.text('도착'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(_on(tester, 2), isTrue);
      var row = (await _settingsRows(tester, e.db)).single;
      expect((row.allOn, row.n2On, row.n3On), (false, true, false));

      // 전체를 다시 켠다
      await tester.tap(find.text('알림 받기'));
      await settle(tester, () => _on(tester, 0));
      for (var i = 0; i < 6; i++) {
        expect(_opacity(tester, i), 1, reason: '$i');
      }
      expect([for (var i = 0; i < 6; i++) _on(tester, i)], [true, true, true, false, true, true]);
      row = (await _settingsRows(tester, e.db)).single;
      expect((row.allOn, row.n3On), (true, false));
      await end(tester, e);
    });

    testWidgets('휴대폰 권한이 꺼져 있으면 경고 줄과 설정 열기 버튼이 뜨고 토글이 흐려진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      final permission = _FakePermission(false, grantOnRequest: true);
      await _open(tester, e,
          extra: [notificationPermissionProvider.overrideWithValue(permission)]);
      await settle(tester, () => find.text('휴대폰 설정에서 알림을 켜 주세요').evaluate().isNotEmpty);
      await tester.pump();

      expect(find.text('휴대폰 설정에서 알림을 켜 주세요'), findsOneWidget);
      expect(_gameButton(tester, '설정 열기').kind, GameButtonKind.secondary);
      for (var i = 0; i < 6; i++) {
        expect(_opacity(tester, i), closeTo(0.4, 1e-9), reason: '$i');
      }
      // 흐려서 눌리지 않는다
      await tester.tap(find.text('도착'));
      await tester.tap(find.text('알림 받기'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect([for (var i = 0; i < 6; i++) _on(tester, i)], everyElement(isTrue));
      expect(await _settingsRows(tester, e.db), isEmpty);

      // 설정 열기: 이 앱의 알림 설정을 연다 (권한을 다시 묻지 않는다). 그대로 두면 경고가 남는다
      expect(e.appSettings.noticeOpens, 0);
      await tester.tap(find.text('설정 열기'));
      await tester.pump();
      expect(e.appSettings.noticeOpens, 1);
      expect(e.appSettings.appOpens, 0);
      expect(permission.requests, 0);
      expect(find.text('휴대폰 설정에서 알림을 켜 주세요'), findsOneWidget);

      // 설정에서 켜고 돌아오면 권한을 다시 읽어서 경고가 사라지고 토글이 켜진다
      permission.state = true;
      _leaveAndReturn(tester);
      await settle(tester, () => find.text('설정 열기').evaluate().isEmpty);
      await tester.pump();
      expect(e.appSettings.noticeOpens, 1);
      expect(permission.requests, 0);
      expect(find.text('휴대폰 설정에서 알림을 켜 주세요'), findsNothing);
      for (var i = 0; i < 6; i++) {
        expect(_opacity(tester, i), 1, reason: '$i');
      }
      await end(tester, e);
    });

    testWidgets('권한이 허용돼 있으면 경고가 없고, 돌아와도 거부면 경고가 남는다', (tester) async {
      final granted = UiEnv();
      await granted.seed(tester);
      await _open(tester, granted,
          extra: [notificationPermissionProvider.overrideWithValue(_FakePermission(true))]);
      await tester.pump();
      expect(find.text('휴대폰 설정에서 알림을 켜 주세요'), findsNothing);
      expect(_opacity(tester, 0), 1);
      await end(tester, granted);

      final denied = UiEnv();
      await denied.seed(tester);
      final permission = _FakePermission(false);
      await _open(tester, denied,
          extra: [notificationPermissionProvider.overrideWithValue(permission)]);
      await settle(tester, () => find.text('설정 열기').evaluate().isNotEmpty);
      await tester.pump();
      await tester.tap(find.text('설정 열기'));
      await tester.pump();
      expect(denied.appSettings.noticeOpens, 1);
      // 켜지 않고 돌아오면 여전히 꺼져 있다
      _leaveAndReturn(tester);
      await settle(tester, () => false, tries: 6);
      expect(permission.requests, 0);
      expect(find.text('휴대폰 설정에서 알림을 켜 주세요'), findsOneWidget);
      await end(tester, denied);
    });

    testWidgets('설정을 열지 못해도 화면은 그대로다', (tester) async {
      final e = UiEnv();
      e.appSettings.fail = true;
      await e.seed(tester);
      await _open(tester, e,
          extra: [notificationPermissionProvider.overrideWithValue(_FakePermission(false))]);
      await settle(tester, () => find.text('설정 열기').evaluate().isNotEmpty);
      await tester.pump();
      await tester.tap(find.text('설정 열기'));
      await tester.pump();
      expect(e.appSettings.noticeOpens, 1);
      expect(find.text('휴대폰 설정에서 알림을 켜 주세요'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
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
      expect(e.appSettings.appOpens, 0);
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
      // 거부돼도 앱 설정으로 보내지 않고 안내만 한다
      expect((denied.appSettings.appOpens, denied.appSettings.noticeOpens), (0, 0));
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
    Future<void> openFirstConfirm(
      WidgetTester tester,
      UiEnv e, {
      Future<void> Function()? more,
    }) async {
      await e.seed(tester, () async {
        await e.ownPaintings({'kr001': Frame.wood});
        await more?.call();
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

    testWidgets('끝까지 가면 예약해 둔 알림은 기록을 지우기 전에 취소한다', (tester) async {
      final e = UiEnv();
      await openFirstConfirm(tester, e, more: () async {
        // 사흘 뒤에 뜨기로 한 N5 예약과 이미 보낸 N2 기록
        await e.db.into(e.db.notificationLog).insert(NotificationLogCompanion.insert(
              kind: NoticeKind.n5,
              refKey: '',
              atUtc: t1.add(const Duration(hours: 72)).millisecondsSinceEpoch,
              status: NoticeStatus.scheduled,
            ));
        await e.db.into(e.db.notificationLog).insert(NotificationLogCompanion.insert(
              kind: NoticeKind.n2,
              refKey: 'j1',
              atUtc: t0.millisecondsSinceEpoch,
              status: NoticeStatus.sent,
            ));
      });

      await tester.tap(find.text('계속'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('삭제'));
      await settle(tester, () => find.byType(WelcomeScreen).evaluate().isNotEmpty);
      await transition(tester);

      // 예약(id 1)만 취소했다
      expect([for (final c in e.notifier.calls) (c.op, c.id)], [(NotifierOp.cancel, 1)]);
      expect(await tester.runAsync(() => e.db.select(e.db.notificationLog).get()), isEmpty);
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
