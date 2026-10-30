import 'package:doobal/app/providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app/helpers.dart';
import 'domain/helpers.dart';

void main() {
  testWidgets('첫 화면은 쉼터다 (출발 동네를 골라 둔 뒤)', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    // 시작 흐름을 끝낸 프로필(출발 동네 포함)이 있어야 시작 화면 대신 쉼터가 나온다
    await tester.runAsync(() => completeOnboarding(db));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // 에셋은 직접 넣는다 (테스트 환경에서 rootBundle이 불안정하다)
        rulesProvider.overrideWith((ref) => rules),
        landmarksProvider.overrideWith((ref) => landmarks),
        propsProvider.overrideWith((ref) => props),
        milestonesProvider.overrideWith((ref) => milestones),
        campThemeProvider.overrideWith((ref) => campTheme),
        // 동기화 서비스가 지도 경계로 땅을 판정해서 지도도 필요하다
        mapProjectionProvider.overrideWith((ref) => mapProjection),
        mapRegionsProvider.overrideWith((ref) => mapRegions),
        dbProvider.overrideWithValue(db),
        stepSourceProvider.overrideWithValue(FakeStepSource()),
      ],
      child: const DoobalApp(),
    ));
    // DB 질의는 실제 비동기라 runAsync 안에서 기다린다.
    // 시작 동기화가 끝나면 상태를 다시 읽으니, 글이 뜰 때까지 몇 번 더 기다린다
    for (var i = 0; i < 20 && find.textContaining('쉬는 중').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }

    expect(find.byType(RestScreen), findsOneWidget);
    expect(find.text('쉬는 중 · 목적지를 골라 보세요'), findsOneWidget);
    expect(find.text('출발하기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
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
      props: props,
    );
    await tester.runAsync(() async {
      await svc.sync(now.subtract(const Duration(hours: 3)));
      await completeOnboarding(db);
    });
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
        propsProvider.overrideWith((ref) => props),
        milestonesProvider.overrideWith((ref) => milestones),
        campThemeProvider.overrideWith((ref) => campTheme),
        // 동기화 서비스가 지도 경계로 땅을 판정해서 지도도 필요하다
        mapProjectionProvider.overrideWith((ref) => mapProjection),
        mapRegionsProvider.overrideWith((ref) => mapRegions),
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
