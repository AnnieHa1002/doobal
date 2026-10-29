import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/main.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('디버그 화면이 뜬다', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        stepSourceProvider.overrideWithValue(FakeStepSource()),
      ],
      child: const DoobalApp(),
    ));
    // 에셋 읽기·DB 질의는 실제 비동기라 runAsync 안에서 기다린다
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('두발 디버그'), findsOneWidget);
    expect(find.text('여정 없음'), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
