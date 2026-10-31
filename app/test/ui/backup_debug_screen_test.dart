import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/ui/debug/backup_debug_screen.dart';
import 'package:doobal/ui/settings/settings_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

final _message = find.byKey(const ValueKey('backup-message'));

String _text(WidgetTester tester) => tester.widget<Text>(_message).data!;

Future<List<DaySummaryRow>> _days(WidgetTester tester, UiEnv e) async =>
    (await tester.runAsync(() => e.db.select(e.db.daySummaries).get()))!;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('설정의 개발자 화면 옆에 백업 시험 줄이 있고 누르면 백업 시험 화면이 열린다', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await openOnTop(tester, e, const SettingsScreen(),
        height: 1400, ready: () => find.text('백업 시험').evaluate().isNotEmpty);
    expect(find.text('개발자 화면'), findsOneWidget);

    await tester.tap(find.text('백업 시험'));
    await transition(tester);
    expect(find.byType(BackupDebugScreen), findsOneWidget);
    expect(find.text('백업 내보내기'), findsOneWidget);
    expect(find.text('백업으로 되돌리기'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('내보내기는 크기를 보여 주고, 되돌리기는 방금 내보낸 백업으로 되돌린다', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await openOnTop(tester, e, const BackupDebugScreen());
    expect(_message, findsNothing);

    // 내보내기 전에는 되돌릴 게 없다
    await tester.tap(find.text('백업으로 되돌리기'));
    await settle(tester, () => _message.evaluate().isNotEmpty);
    expect(_text(tester), contains('먼저 백업을 내보내 주세요'));

    await tester.tap(find.text('백업 내보내기'));
    await settle(tester, () => _text(tester).startsWith('내보내기'));
    expect(_text(tester), matches(RegExp(r'^내보내기: 문자열 \d+자 \(한도 1000000자\) · 압축 \d+바이트 · 압축 전 \d+바이트$')));
    final before = await _days(tester, e);
    expect(before, isNotEmpty);

    // 내보낸 뒤에 바뀐 기록은 되돌리면 사라진다
    await tester.runAsync(() => e.db.into(e.db.daySummaries).insert(
        DaySummariesCompanion.insert(day: '2099-01-01', steps: 1, distanceM: 1, countedSessions: 0)));
    await tester.runAsync(() => e.db
        .into(e.db.stepMinutes)
        .insert(StepMinutesCompanion.insert(minuteUtc: const Value(7), steps: 7)));
    expect(await _days(tester, e), hasLength(before.length + 1));

    await tester.tap(find.text('백업으로 되돌리기'));
    await settle(tester, () => _text(tester).startsWith('되돌리기'));
    expect(_text(tester), startsWith('되돌리기: 되돌렸어요'));
    expect(await _days(tester, e), before);
    expect(await tester.runAsync(() => e.db.select(e.db.stepMinutes).get()), isEmpty);
    await end(tester, e);
  });
}
