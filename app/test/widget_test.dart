import 'package:doobal/app/providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/main.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'domain/helpers.dart';

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
    // 에셋 읽기·DB 질의는 실제 비동기라 runAsync 안에서 기다린다.
    // 시작 동기화가 끝나면 상태를 다시 읽으니, 글이 뜰 때까지 몇 번 더 기다린다
    for (var i = 0; i < 10 && find.text('여정 없음').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(find.text('두발 디버그'), findsOneWidget);
    expect(find.text('여정 없음'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('켤 때 동기화하고 그동안 걸은 거리를 토스트로 알린다', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    final source = FakeStepSource();
    final now = DateTime.now().toUtc();
    // 3시간 전에 설치, 1시간 전부터 30분 × 100보(2.1km) 걸은 기록이 있는 상태에서 켠다
    final svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: const {},
    );
    await tester.runAsync(() => svc.sync(now.subtract(const Duration(hours: 3))));
    source.records.add(StepRecord(
      start: now.subtract(const Duration(hours: 1)),
      end: now.subtract(const Duration(minutes: 30)),
      steps: 3000,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // 두 번째 testWidgets부터는 rootBundle 에셋이 로드되지 않아(테스트 환경 한계) 직접 넣는다
        rulesProvider.overrideWith((ref) => rules),
        landmarksProvider.overrideWith((ref) => landmarks),
        dbProvider.overrideWithValue(db),
        stepSourceProvider.overrideWithValue(source),
      ],
      child: const DoobalApp(),
    ));
    for (var i = 0; i < 20 && find.text('그동안 2.1km 걸었어요').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(find.text('그동안 2.1km 걸었어요'), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
