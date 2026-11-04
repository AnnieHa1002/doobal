import 'dart:convert';
import 'dart:io';

import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/rules.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/profile/profile_screen.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:doobal/ui/walking/walking_hud.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

// 본격 걷기를 화면에 보이는 쪽: 걷는 중 걸음 알약 딱지·토스트·상시 알림, 걷기 기록의 거리 두 줄과 럭,
// 나의 정보의 본격 걷기 거리, 앱이 끝난 뒤 다시 켰을 때의 토스트.
// 설치 t0(KST 09:00), 걷기 시작 t1 = 한 시간 뒤. config: 걷기 1번 = 10분·1,000보, 여행 거리 1.3배·럭 2배

/// config.json을 [edit]로 고친 규칙 (럭 단가를 정하는 데 쓴다)
Rules _rulesWith(void Function(Map<String, dynamic> config) edit) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  edit(j);
  return Rules.fromJson(j);
}

/// 럭 단가가 정해진 규칙 (1km당 10럭)
final _coinRules = _rulesWith((j) => (j['coins'] as Map)['perKm'] = 10);

/// 럭 단가가 없는(null) 규칙. config v8부터 실제 값은 10이라, 럭 줄·토스트 럭 이야기가 없는 경우를 본다
final _noCoinRules = _rulesWith((j) => (j['coins'] as Map)['perKm'] = null);

int _ms(DateTime t) => t.millisecondsSinceEpoch;

DateTime _t(int minutesAfterT1) => t1.add(Duration(minutes: minutesAfterT1));

/// 걸음 알약 안의 글자
Finder _pill(String text) => find.descendant(of: find.byType(StepPill), matching: find.text(text));

/// 걸음 알약의 본격 걷기 딱지
Finder get _pillBadge =>
    find.descendant(of: find.byType(StepPill), matching: find.byKey(const Key('focus-badge')));

const _toast = '본격 걷기! 여행 거리 1.3배';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  /// 앱을 켜서 쉼터를 띄우고(여정 하나) 출발하기로 걷는 중까지 간다
  Future<void> openWalking(WidgetTester tester, UiEnv e) async {
    await e.seed(tester, () => e.svc.startJourney('kr003', t1));
    await pumpDoobal(tester, e, const DoobalApp());
    await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
    await tester.pump();
    await tester.tap(find.text('출발하기'));
    await transition(tester);
    await settle(tester, () => false, tries: 8);
    expect(find.byType(WalkingScreen), findsOneWidget);
  }

  /// 건강 기록 [minutes]분 × [spm]보가 [fromMin](t1 기준 분)부터 들어오고 시계가 그 끝까지 흘러
  /// 갱신 주기가 지난 상태. 알약의 걸음이 [total]이 될 때까지 가짜 시간을 0.1초씩 보낸다
  /// 건강 기록을 넣고 걸음 알약이 [total]까지 따라 오를 때까지 기다린다 (숫자는 3초에 걸쳐 오른다).
  /// [watch]를 주면 기다리는 동안 한 번이라도 보였는지 돌려준다 (그 사이 사라지는 토스트를 볼 때)
  Future<bool> healthWalk(
    WidgetTester tester,
    UiEnv e, {
    required int fromMin,
    required int minutes,
    required int spm,
    required int total,
    Finder? watch,
  }) async {
    e.source.records.add(walkRecord(_t(fromMin), minutes, spm));
    e.now = _t(fromMin + minutes);
    final done = _pill(formatInt(total));
    var seen = false;
    for (var i = 0; i < 600 && done.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      seen |= watch != null && watch.evaluate().isNotEmpty;
      if (i % 10 == 0) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      }
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return seen || (watch != null && watch.evaluate().isNotEmpty);
  }

  /// 시계가 [sec]초 흐른 뒤 센서가 누적 걸음 [total]을 준다
  Future<void> sensorTo(WidgetTester tester, UiEnv e, int sec, int total) async {
    e.now = e.now.add(Duration(seconds: sec));
    e.live.push(total);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // 걸음 알약 숫자는 3초에 걸쳐 따라 오른다 (CountFollower)
    await tester.pump(const Duration(milliseconds: 3100));
  }

  group('걷는 중: 걸음 알약 딱지·토스트·알림 (건강 기록으로 걷기 1번)', () {
    testWidgets('걷기 1번이 되기 전에는 딱지·토스트가 없고, 10분·1,000보가 되면 ×1.3과 토스트가 한 번 뜬다',
        (tester) async {
      final e = UiEnv(appRules: _noCoinRules);
      await openWalking(tester, e);
      expect(_pillBadge, findsNothing);

      // 5분 · 500보: 아직 걷기 1번이 아니다
      await healthWalk(tester, e, fromMin: 0, minutes: 5, spm: 100, total: 500);
      expect(_pill('500'), findsOneWidget);
      expect(_pillBadge, findsNothing);
      expect(find.textContaining('본격 걷기'), findsNothing);

      // 이어서 5분 · 500보: 10분 · 1,000보가 되어 걷기 1번으로 인정된다.
      // 토스트(2.5초)는 숫자가 1,000까지 따라 오르는(3초) 동안 떴다 사라진다
      final toastSeen = await healthWalk(tester, e,
          fromMin: 5, minutes: 5, spm: 100, total: 1000, watch: find.text(_toast));
      expect(_pill('1,000'), findsOneWidget);
      expect(_pillBadge, findsOneWidget);
      expect(find.descendant(of: _pillBadge, matching: find.text('×1.3')), findsOneWidget);
      expect(toastSeen, isTrue);
      // 럭 단가가 없으면(coins.perKm null) 토스트에 럭 이야기가 없다
      expect(find.textContaining('럭'), findsNothing);

      // 토스트는 2.5초 뒤 사라지고, 딱지는 마칠 때까지 남으며, 같은 걷기에서 다시 뜨지 않는다
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(_toast), findsNothing);
      await healthWalk(tester, e, fromMin: 10, minutes: 3, spm: 100, total: 1300);
      expect(_pillBadge, findsOneWidget);
      expect(find.text(_toast), findsNothing);
      await end(tester, e);
    });

    testWidgets('상시 알림: 본격 걷기가 되면 본문 끝에 ×1.3이 붙은 갱신이 한 번 나가고, 그 전엔 없다',
        (tester) async {
      final e = UiEnv();
      await openWalking(tester, e);
      expect(e.walkNotice.startFocus, [null]);

      await healthWalk(tester, e, fromMin: 0, minutes: 5, spm: 100, total: 500);
      expect([for (final u in e.walkNotice.updates) u.$1], [500]);
      expect(e.walkNotice.updateFocus, [null]);

      // 본격 걷기가 된 순간의 갱신: 새 걸음(1,000)과 표시(×1.3)가 한 번에 나간다
      await healthWalk(tester, e, fromMin: 5, minutes: 5, spm: 100, total: 1000);
      expect([for (final u in e.walkNotice.updates) u.$1], [500, 1000]);
      expect(e.walkNotice.updateFocus, [null, '×1.3']);
      await end(tester, e);
    });
  });

  group('걷는 중: 걸음 알약 딱지·토스트·알림 (기기 센서 분으로 걷기 1번)', () {
    testWidgets('센서가 센 10분 × 100보가 차는 순간 ×1.3과 토스트, 9분째까지는 없다', (tester) async {
      final e = UiEnv(appRules: _noCoinRules);
      await openWalking(tester, e);
      e.live.push(0); // 기준값

      // 60초마다 100보: 9번이면 9분 · 900보
      for (var i = 1; i <= 9; i++) {
        await sensorTo(tester, e, 60, i * 100);
      }
      expect(_pill('900'), findsOneWidget);
      expect(_pillBadge, findsNothing);
      expect(find.text(_toast), findsNothing);

      // 10번째: 10분 · 1,000보
      await sensorTo(tester, e, 60, 1000);
      expect(_pill('1,000'), findsOneWidget);
      expect(_pillBadge, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_toast), findsOneWidget);

      // 알림: 10번째 갱신에서 처음으로 ×1.3이 붙는다 (그 전 9번은 표시 없음)
      expect([for (final u in e.walkNotice.updates) u.$1],
          [for (var i = 1; i <= 10; i++) i * 100]);
      expect(e.walkNotice.updateFocus, [...List<String?>.filled(9, null), '×1.3']);
      await end(tester, e);
    });

    testWidgets('럭 단가가 정해져 있으면 토스트에 · 럭 2배가 붙는다', (tester) async {
      final e = UiEnv(appRules: _coinRules);
      await openWalking(tester, e);
      e.live.push(0);
      for (var i = 1; i <= 10; i++) {
        await sensorTo(tester, e, 60, i * 100);
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(_pillBadge, findsOneWidget);
      expect(find.text('$_toast · 럭 2배'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('빈 분이 길어서 두 구간으로 갈라지면(각 5분) 걸음이 합쳐 1,000보여도 딱지가 없다', (tester) async {
      final e = UiEnv();
      await openWalking(tester, e);
      e.live.push(0);
      // 1~5분 100보씩, 6~8분 쉬고(빈 분 3분 > config maxGapMin 2), 9~13분 100보씩
      var total = 0;
      for (var m = 1; m <= 13; m++) {
        if (m >= 6 && m <= 8) {
          await sensorTo(tester, e, 60, total);
          continue;
        }
        total += 100;
        await sensorTo(tester, e, 60, total);
      }
      expect(_pill('1,000'), findsOneWidget);
      expect(_pillBadge, findsNothing);
      expect(find.text(_toast), findsNothing);
      await end(tester, e);
    });
  });

  group('걷기 기록: 거리 두 줄과 럭', () {
    // 12분 × 100보 = 1,200보 · 실제 840m. 앱 걷기 창이 12분 전체를 덮으면 보너스 252m, 여행 1,092m
    Future<void> seedRecord(UiEnv e, {required bool focused}) async {
      e.source.records.add(walkRecord(t1, 12, 100));
      if (focused) {
        final id = await e.svc.startAppWalk(t1);
        await e.svc.finishAppWalk(id, _t(12));
      }
    }

    Future<void> openRecord(WidgetTester tester, UiEnv e) async {
      await openOnTop(
        tester,
        e,
        WalkRecordScreen(start: t1, end: _t(12), ratioBefore: null),
        ready: () => find.text('기록을 정리하는 중').evaluate().isEmpty,
      );
      await settle(tester, () => false, tries: 6);
    }

    testWidgets('본격 걷기: 실제 0.8km / 여행 1.1km (본격 걷기 ×1.3), 럭 단가가 없으면 럭 줄이 없다', (tester) async {
      final e = UiEnv(appRules: _noCoinRules);
      await e.seed(tester, () => seedRecord(e, focused: true));
      await openRecord(tester, e);

      expect(find.text('0.84 km'), findsOneWidget); // 큰 숫자는 실제 거리 그대로
      expect(find.text('실제 0.8km'), findsOneWidget);
      expect(find.text('여행 1.1km (본격 걷기 ×1.3)'), findsOneWidget);
      expect(find.textContaining('럭'), findsNothing);
      await end(tester, e);
    });

    testWidgets('본격 걷기가 아니면 실제 줄만 둔다 (여행 거리는 실제와 같아서)', (tester) async {
      final e = UiEnv(appRules: _noCoinRules);
      await e.seed(tester, () => seedRecord(e, focused: false));
      await openRecord(tester, e);

      expect(find.text('실제 0.8km'), findsOneWidget);
      expect(find.textContaining('여행'), findsNothing);
      expect(find.textContaining('본격 걷기'), findsNothing);
      expect(find.textContaining('럭'), findsNothing);
      await end(tester, e);
    });

    testWidgets('럭 단가가 있으면 +n 럭, 본격 걷기 분이 있으면 ×2 딱지: 840m 전부 보너스 → (0 + 0.84 × 2) × 10 = 16',
        (tester) async {
      final e = UiEnv(appRules: _coinRules);
      await e.seed(tester, () => seedRecord(e, focused: true));
      await openRecord(tester, e);

      expect(find.text('+16 럭'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('여행 1.1km (본격 걷기 ×1.3)'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('럭 단가가 있고 본격 걷기가 아니면 +8 럭 (0.84km × 10 내림)에 ×2 딱지는 없다', (tester) async {
      final e = UiEnv(appRules: _coinRules);
      await e.seed(tester, () => seedRecord(e, focused: false));
      await openRecord(tester, e);

      expect(find.text('+8 럭'), findsOneWidget);
      expect(find.text('×2'), findsNothing);
      await end(tester, e);
    });

    testWidgets('다시 보기(노트)에서도 같은 줄이 나온다 (저장된 창으로 그때 계산)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await seedRecord(e, focused: true);
        // 다시 보기는 동기화하지 않으니 저장돼 있어야 한다
        await e.svc.sync(_t(30));
      });
      await openOnTop(
        tester,
        e,
        WalkRecordScreen(start: t1, end: _t(12), ratioBefore: null, review: true),
        ready: () => find.text('기록을 정리하는 중').evaluate().isEmpty,
      );
      await settle(tester, () => false, tries: 6);
      expect(find.text('실제 0.8km'), findsOneWidget);
      expect(find.text('여행 1.1km (본격 걷기 ×1.3)'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('나의 정보: 본격 걷기 거리', () {
    Future<void> openProfile(WidgetTester tester, UiEnv e) => openOnTop(
          tester,
          e,
          const ProfileScreen(),
          height: 1000,
          ready: () => find.text('동행 도감').evaluate().isNotEmpty,
        );

    testWidgets('누적 거리 카드 아래에 `본격 걷기 12.3 km` (Snapshot.walkTravelKm, 한 자리)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.db.into(e.db.daySummaries).insertOnConflictUpdate(DaySummariesCompanion.insert(
              day: '2026-11-18',
              steps: 20000,
              distanceM: 14000,
              countedSessions: 0,
              travelM: const Value(15000),
              walkTravelM: const Value(12345),
            ));
      });
      await openProfile(tester, e);

      final line = find.byKey(const ValueKey('stat-focus-km'));
      expect(line, findsOneWidget);
      expect(find.text('본격 걷기 12.3 km'), findsOneWidget);
      // 누적 거리 카드(실제 14.0)와 별개의 줄이다
      expect(find.text('14.0 km'), findsOneWidget);
      // 카드 바로 아래, 오른쪽 열 (누적 거리 카드와 같은 쪽)
      final card = tester.getRect(find.byKey(const ValueKey('stat-km')));
      final text = tester.getRect(line);
      expect(text.top, greaterThanOrEqualTo(card.bottom));
      expect(text.top - card.bottom, lessThan(12));
      expect(text.left, greaterThanOrEqualTo(card.left));
      await end(tester, e);
    });

    testWidgets('본격 걷기를 안 했으면 0.0 km', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openProfile(tester, e);
      expect(find.text('본격 걷기 0.0 km'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('앱 종료 뒤: 걷기가 멈췄어요 토스트', () {
    /// 앞 실행에서 끝나지 않은 창을 t0에 열고 마지막으로 살아 있던 시각을 [alive]로 둔다.
    /// [records]는 앱을 켜는 첫 동기화에 들어온다
    Future<void> openApp(
      WidgetTester tester,
      UiEnv e, {
      required DateTime alive,
      List<StepRecordSpec> records = const [],
      Future<void> Function()? more,
    }) async {
      await e.seed(tester, () async {
        await more?.call();
        for (final r in records) {
          e.source.records.add(walkRecord(r.start, r.minutes, r.spm));
        }
        await e.db.into(e.db.appWalks).insert(AppWalksCompanion.insert(startUtc: _ms(t0)));
        await e.db
            .update(e.db.syncState)
            .write(SyncStateCompanion(lastAliveUtc: Value(_ms(alive))));
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 8);
      await tester.pump(const Duration(milliseconds: 300));
    }

    final alive = t0.add(const Duration(minutes: 20));

    testWidgets('창이 끝난 뒤 쌓인 걸음 n을 평소 걸음으로 더했다고 알린다 (창이 끝나기 전 걸음은 안 센다)', (tester) async {
      final e = UiEnv();
      await openApp(tester, e, alive: alive, records: [
        // 창이 끝나기 전(10~15분): 500보는 세지 않는다
        StepRecordSpec(t0.add(const Duration(minutes: 10)), 5, 100),
        // 창이 끝난 뒤(30~40분 · 25~28분): 1,000 + 300 = 1,300보
        StepRecordSpec(t0.add(const Duration(minutes: 30)), 10, 100),
        StepRecordSpec(t0.add(const Duration(minutes: 25)), 3, 100),
      ]);

      expect(find.text('걷기가 멈췄어요 · 그동안 1,300보는 평소 걸음으로 더했어요'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('끝난 뒤 걸음이 없으면 멈췄다는 말만', (tester) async {
      final e = UiEnv();
      await openApp(tester, e, alive: alive, records: [
        StepRecordSpec(t0.add(const Duration(minutes: 10)), 5, 100),
      ]);

      expect(find.text('걷기가 멈췄어요'), findsOneWidget);
      expect(find.textContaining('평소 걸음'), findsNothing);
      await end(tester, e);
    });

    testWidgets('한 번만: 토스트가 사라진 뒤 앞으로 돌아와 다시 동기화해도 또 뜨지 않는다', (tester) async {
      final e = UiEnv();
      await openApp(tester, e, alive: alive, records: [
        StepRecordSpec(t0.add(const Duration(minutes: 30)), 10, 100),
      ]);
      expect(find.textContaining('걷기가 멈췄어요'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('걷기가 멈췄어요'), findsNothing);

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
      await settle(tester, () => false, tries: 8);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('걷기가 멈췄어요'), findsNothing);
      await end(tester, e);
    });

    testWidgets('같은 동기화가 띄운 `그동안 n km 걸었어요`는 지우고 이 토스트만 남긴다', (tester) async {
      final e = UiEnv();
      await openApp(tester, e, alive: alive, more: () => e.svc.startJourney('kr003', t0), records: [
        StepRecordSpec(t0.add(const Duration(minutes: 30)), 10, 100),
      ]);
      // 창이 끝난 뒤 1,000보(0.7km)가 여정에 더해졌지만 km 토스트는 남지 않는다
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.journey!.progress.progressKm,
          closeTo(0.7, 1e-9));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('걷기가 멈췄어요 · 그동안 1,000보는 평소 걸음으로 더했어요'), findsOneWidget);
      expect(find.textContaining('km 걸었어요'), findsNothing);
      await end(tester, e);
    });

    testWidgets('끝나지 않은 창이 없으면 토스트가 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        e.source.records.add(walkRecord(t0.add(const Duration(minutes: 30)), 10, 100));
      });
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 8);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('걷기가 멈췄어요'), findsNothing);
      await end(tester, e);
    });
  });
}

/// 앞 실행이 끝난 뒤 건강 기록으로 들어오는 걷기 ([start]부터 [minutes]분 × 분당 [spm]보)
class StepRecordSpec {
  const StepRecordSpec(this.start, this.minutes, this.spm);

  final DateTime start;
  final int minutes;
  final int spm;
}
