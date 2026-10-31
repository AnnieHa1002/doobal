import 'package:doobal/app/auto_sync.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/live_steps.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/scene/scene_view.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';

// 설치 KST 2026-11-18 09:00, 걷기 시작은 한 시간 뒤 (낮)
final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

final _byId = {for (final l in landmarks) l.id: l};

StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

/// 메모리 DB + 가짜 걸음 + 바꿀 수 있는 시계. 에셋은 모두 직접 넣는다
/// (두 번째 testWidgets부터는 rootBundle 에셋이 로드되지 않는다)
class _Env {
  _Env() : db = AppDb(NativeDatabase.memory()), source = FakeStepSource(), now = _t1 {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _byId,
      props: props,
    );
  }

  final AppDb db;
  final FakeStepSource source;

  /// 기기 걸음 센서 (테스트가 값을 밀어 넣는다). 권한은 처음부터 있다
  final live = FakeLiveSteps();
  late final SyncService svc;
  DateTime now;

  List<Override> get overrides => [
        rulesProvider.overrideWith((ref) => rules),
        landmarksProvider.overrideWith((ref) => landmarks),
        propsProvider.overrideWith((ref) => props),
        milestonesProvider.overrideWith((ref) => milestones),
        noticeCatalogProvider.overrideWith((ref) => noticeCatalog),
        campThemeProvider.overrideWith((ref) => campTheme),
        mapProjectionProvider.overrideWith((ref) => mapProjection),
        mapRegionsProvider.overrideWith((ref) => mapRegions),
        hairSwatchesProvider.overrideWith((ref) => hairSwatches),
        lookPaletteProvider.overrideWith((ref) => lookPalette),
        dbProvider.overrideWithValue(db),
        stepSourceProvider.overrideWithValue(source),
        liveStepsProvider.overrideWithValue(live),
        clockProvider.overrideWithValue(() => now),
      ];

  /// 설치(= _t0)하고 출발 동네를 testHome으로 골라 둔다([home]이 false면 안 고른 채로).
  /// 시작 흐름도 끝낸 것으로 둔다(DoobalApp이 쉼터를 바로 띄운다).
  /// 원하면 kr003으로 여정을 시작해 둔다
  Future<void> seed(WidgetTester tester, {String? dest, LatLng? origin, bool home = true}) =>
      tester.runAsync(() async {
        await svc.sync(_t0);
        if (home) await svc.setHome(testHomeName, testHome);
        await completeOnboarding(db, home: home);
        if (origin != null) await placeAt(db, origin, _t0);
        if (dest != null) await svc.startJourney(dest, _t1);
      }) as Future<void>;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 실제 비동기(DB·에셋)가 끝나도록 기다리며 화면을 갱신한다
Future<void> _settle(WidgetTester tester, bool Function() done, {int tries = 40}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
}

/// 조건 없이 비동기가 흘러가게 두기
Future<void> _wait(WidgetTester tester, [int times = 8]) => _settle(tester, () => false, tries: times);

/// 화면 전환 애니메이션(플랫폼에 따라 최대 약 0.8초)이 끝날 때까지
Future<void> _transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pumpApp(WidgetTester tester, _Env e) async {
  _phone(tester);
  await tester.pumpWidget(ProviderScope(overrides: e.overrides, child: const DoobalApp()));
  await _settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
}

/// 걸어서 마친 화면을 치우고 DB를 닫는다. 진행 중이던 비동기가 끝날 시간을 준다
Future<void> _end(WidgetTester tester, _Env e) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.runAsync(e.db.close);
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await _transition(tester);
}

double _totalKm(String destId, [LatLng? origin]) =>
    buildRoute(origin ?? testHome, _byId[destId]!.latLng, rules).totalEffectiveKm;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('쉼터', () {
    testWidgets('여정이 없으면 목적지를 고르라는 알약, 출발하기는 지도로 간다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _pumpApp(tester, e);

      expect(find.text('쉬는 중 · 목적지를 골라 보세요'), findsOneWidget);
      expect(find.text('출발하기'), findsOneWidget);
      expect(find.text('지도'), findsOneWidget);
      expect(find.text('배낭'), findsOneWidget);
      expect(find.text('노트'), findsOneWidget);

      await _tapIcon(tester, Icons.directions_walk);
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.text('명소 이름 검색'), findsOneWidget);
      expect(find.text('걷기 마치기'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('출발 동네를 안 골랐으면 고르라는 카드만 나오고, 임시 화면에서 고르면 쉼터가 된다', (tester) async {
      final e = _Env();
      await e.seed(tester, home: false);
      _phone(tester);
      // 시작 관문은 출발 동네가 없으면 ③ 단계를 띄우니, 쉼터의 임시 카드는 관문 없이 직접 띄운다
      await tester.pumpWidget(ProviderScope(
        overrides: e.overrides,
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          home: const AutoSync(child: RestScreen()),
        ),
      ));
      await _settle(tester, () => find.text('출발 동네를 골라 주세요').evaluate().isNotEmpty);

      expect(find.text('출발 동네를 골라 주세요'), findsOneWidget);
      expect(find.text('고르기'), findsOneWidget);
      // 장면·상태 알약·출발하기·모서리 물건은 없고, 설정 버튼은 남는다
      expect(find.textContaining('쉬는 중'), findsNothing);
      expect(find.text('출발하기'), findsNothing);
      expect(find.byType(SceneView), findsNothing);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      await tester.tap(find.text('고르기'));
      await _transition(tester);
      expect(find.text('출발 동네 (임시)'), findsOneWidget);
      expect(find.text('출발 동네 없음'), findsOneWidget);

      // 대전 유성구를 고른다
      await tester.tap(find.text('출발 동네'), warnIfMissed: false);
      await _transition(tester);
      await tester.tap(find.text('대전광역시 유성구').last);
      await _transition(tester);
      await tester.tap(find.text('출발 동네로 정하기'));
      await _settle(tester, () => find.text('출발 동네 유성구').evaluate().isNotEmpty);
      expect(find.text('출발 동네 유성구'), findsOneWidget);
      await tester.pageBack();
      await _transition(tester);
      await _settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);

      expect(find.text('쉬는 중 · 목적지를 골라 보세요'), findsOneWidget);
      expect(find.text('출발 동네를 골라 주세요'), findsNothing);
      final snap = (await tester.runAsync(() => e.svc.snapshot(e.now)))!;
      expect(snap.position, _byId['kr003']!.latLng);
      await _end(tester, e);
    });

    testWidgets('출발 동네를 골라 둔 쉼터는 상태 알약과 장면이 나온다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _pumpApp(tester, e);

      expect(find.text('쉬는 중 · 목적지를 골라 보세요'), findsOneWidget);
      expect(find.text('출발 동네를 골라 주세요'), findsNothing);
      expect(find.byType(SceneView), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('여정이 있으면 목적지까지 남은 거리, 출발하기는 걷는 중으로 간다', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      await _pumpApp(tester, e);

      expect(find.text('쉬는 중 · 목적지까지 ${formatKm(_totalKm('kr003'))}'), findsOneWidget);

      await tester.tap(find.text('출발하기'));
      await _transition(tester);
      expect(find.text('걷기 마치기'), findsOneWidget);
      expect(find.text('걷는 중'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('지도·배낭·노트를 누르면 각 화면이 열린다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _pumpApp(tester, e);

      await tester.tap(find.text('지도'));
      await _transition(tester);
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.text('명소 이름 검색'), findsOneWidget);
      // 지도는 앱바가 없어서 자기 뒤로 가기 버튼을 쓴다
      await _tapIcon(tester, Icons.arrow_back);
      expect(find.byType(MapScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.backpack_outlined));
      await _transition(tester);
      expect(find.byType(AlbumScreen), findsOneWidget);
      expect(find.text('화집'), findsOneWidget);
      expect(find.text('준비 중'), findsNothing);
      await _tapIcon(tester, Icons.arrow_back);
      expect(find.byType(AlbumScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await _transition(tester);
      expect(find.text('노트'), findsOneWidget);
      expect(find.text('내 방명록'), findsOneWidget);
      expect(find.text('걷기 기록'), findsOneWidget);
      await _tapIcon(tester, Icons.arrow_back);

      expect(find.byType(RestScreen), findsOneWidget);
      expect(find.text('쉬는 중 · 목적지를 골라 보세요'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('나의 정보·설정, 설정의 개발자 화면은 디버그 화면', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _pumpApp(tester, e);

      await _tapIcon(tester, Icons.person);
      expect(find.text('나의 정보'), findsOneWidget);
      await _settle(tester, () => find.text('동행 도감').evaluate().isNotEmpty);
      expect(find.text('동행 도감'), findsOneWidget);
      await _tapIcon(tester, Icons.arrow_back);

      await _tapIcon(tester, Icons.settings);
      expect(find.text('설정'), findsOneWidget);
      // 알림 줄이 늘어서 개발자 화면 줄은 스크롤해야 보인다
      await tester.scrollUntilVisible(find.text('개발자 화면'), 300);
      await tester.tap(find.text('개발자 화면'));
      await _transition(tester);
      expect(find.text('두발 디버그'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('목적지를 지도에서 고르면 쉼터 알약이 바뀐다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _pumpApp(tester, e);

      await tester.tap(find.text('지도'));
      await _transition(tester);
      await _settle(tester, () => find.byType(InteractiveViewer).evaluate().isNotEmpty);
      await tester.enterText(find.byType(TextField), '엑스포');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('result-kr003')));
      await _transition(tester);
      await tester.tap(find.text('여기로 가기'));
      await _settle(tester, () => find.text('여기로 가기').evaluate().isEmpty);
      await _tapIcon(tester, Icons.arrow_back);
      await _settle(tester, () => find.textContaining('목적지까지').evaluate().isNotEmpty);

      expect(find.text('쉬는 중 · 목적지까지 ${formatKm(_totalKm('kr003'))}'), findsOneWidget);
      await _end(tester, e);
    });
  });

  group('걷는 중', () {
    /// 쉼터에서 출발하기를 눌러 걷는 중까지 가고, 첫 동기화가 끝나길 기다린다
    Future<void> openWalking(WidgetTester tester, _Env e) async {
      await _pumpApp(tester, e);
      await tester.tap(find.text('출발하기'));
      await _transition(tester);
      await _wait(tester);
    }

    /// 걷기를 시작한 뒤 [minutes]분 × [spm]보 걸은 기록이 들어오고 갱신 주기가 지난 상태.
    /// 가짜 시간을 0.1초씩 보내며 프레임을 그려서, 갱신 직후에 거리가 한꺼번에 뛰지 않는지도 볼 수 있다
    Future<void> walkAndRefresh(WidgetTester tester, _Env e, int minutes, int spm) async {
      e.source.records.add(_walk(_t1, minutes, spm));
      e.now = _t1.add(Duration(minutes: minutes));
      final done = find.text('${formatInt(minutes * spm)}보');
      for (var i = 0; i < 600 && done.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i % 10 == 0) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        }
      }
    }

    testWidgets('갱신 주기가 지나면 가짜 기록의 걸음이 뜨고, 패널을 누르면 자세한 숫자와 혼자 걷는 중', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      await openWalking(tester, e);
      expect(find.text('0보'), findsOneWidget);
      expect(find.text('혼자 걷는 중'), findsNothing);

      await walkAndRefresh(tester, e, 10, 100);
      expect(find.text('1,000보'), findsOneWidget);
      expect(find.text('걷는 중'), findsOneWidget);
      // 여정 막대와 남은 거리
      final remaining = _totalKm('kr003') - 0.7;
      expect(find.text('${_byId['kr003']!.name}까지 ${formatKm(remaining)}'), findsOneWidget);

      await tester.tap(find.text('걷는 중'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('혼자 걷는 중'), findsOneWidget);
      expect(find.text('분당 걸음'), findsOneWidget);
      expect(find.text('100보'), findsOneWidget);
      expect(find.text('4.2 km/h'), findsOneWidget);
      // 3600 ÷ 4.2 = 857.14 → 857초 = 14분 17초
      expect(find.text('페이스'), findsOneWidget);
      expect(find.text('14\'17"/km'), findsOneWidget);
      expect(find.text('0.70 m'), findsOneWidget);
      expect(find.text('오늘 걸음'), findsOneWidget);
      // 걸음 숫자와 오늘 걸음 둘
      expect(find.text('1,000보'), findsNWidgets(2));
      final eta = (await tester.runAsync(() => e.svc.snapshot(e.now)))!.journey!.eta;
      expect(find.text(formatMonthDay(eta)), findsOneWidget);
      // 누적 1,000보 → 다음 방명록 5,000까지 4,000보
      expect(find.text('다음 방명록 지점까지 4,000보'), findsOneWidget);

      await tester.tap(find.text('걷는 중'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('혼자 걷는 중'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('분당 140보 이상이면 달리는 중', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      await openWalking(tester, e);
      expect(find.text('걷는 중'), findsOneWidget);

      await walkAndRefresh(tester, e, 10, 150);
      expect(find.text('달리는 중'), findsOneWidget);
      expect(find.text('걷는 중'), findsNothing);
      await tester.tap(find.text('달리는 중'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('9.0 km/h'), findsOneWidget);
      expect(find.text('1.00 m'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('보이는 거리는 한 주기 안에 목표(0.70km)에 닿고 넘지 않는다', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      await openWalking(tester, e);
      await walkAndRefresh(tester, e, 10, 100);

      // 갱신이 끝난 직후엔 아직 0km 근처에서 출발한다 (한꺼번에 뛰지 않는다)
      double shown() {
        final t = tester.widgetList<Text>(find.byWidgetPredicate(
            (w) => w is Text && RegExp(r'^\d+\.\d\d km$').hasMatch(w.data ?? '')));
        return double.parse(t.single.data!.split(' ').first);
      }

      expect(shown(), lessThan(0.1));
      var prev = shown();
      // 0.5초씩 45초: 줄지 않고 목표(0.70)를 넘지 않으며, 한 주기(30초)쯤 지나면 거의 다 따라왔다
      for (var i = 1; i <= rules.walkingRefreshSec * 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(shown(), greaterThanOrEqualTo(prev));
        expect(shown(), lessThanOrEqualTo(0.70));
        prev = shown();
        if (i == rules.walkingRefreshSec * 2 - 4) expect(shown(), greaterThanOrEqualTo(0.65));
      }
      expect(find.text('0.70 km'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('걷는 시간은 시계를 따라 흐른다', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      await openWalking(tester, e);
      expect(find.text('0:00'), findsOneWidget);

      e.now = _t1.add(const Duration(minutes: 3, seconds: 7));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('3:07'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('배 구간에 들어서면 토스트를 한 번만 띄운다', (tester) async {
      final e = _Env();
      final jeju = landmarks.firstWhere((l) => l.island == Island.jeju);
      await e.seed(tester, dest: jeju.id, origin: rules.ports['wando']);
      await openWalking(tester, e);
      expect(find.text('배를 타고 건너요 (3배 빠르게)'), findsOneWidget);

      // 토스트가 사라진 뒤 갱신되어도 같은 배 구간이니 다시 뜨지 않는다
      // 토스트는 2.5초 뒤 사라진다
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('배를 타고 건너요 (3배 빠르게)'), findsNothing);
      await walkAndRefresh(tester, e, 10, 100);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1,000보'), findsOneWidget);
      expect(find.text('배를 타고 건너요 (3배 빠르게)'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('땅 위에서는 토스트가 없다', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      await openWalking(tester, e);
      expect(find.textContaining('배를 타고'), findsNothing);
      await _end(tester, e);
    });

    group('기기 걸음 센서', () {
      /// 시계가 [sec]초 흐른 뒤 센서가 누적 걸음 [total]을 준다
      Future<void> sensorTo(WidgetTester tester, _Env e, int sec, int total) async {
        e.now = e.now.add(Duration(seconds: sec));
        e.live.push(total);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }

      testWidgets('센서 값을 밀어 넣으면 이번 걸음이 바로 오르고 (health 기록이 없어도), 거리가 따라 흐른다',
          (tester) async {
        final e = _Env();
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);
        expect(find.text('0보'), findsOneWidget);
        expect(e.live.listeners, 1);

        // 첫 값은 기준값이라 세지 않는다
        e.live.push(50000);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('0보'), findsOneWidget);

        // 6초마다 10보 (분당 100보) 6번 = 60보 = 42m
        for (var i = 1; i <= 6; i++) {
          await sensorTo(tester, e, 6, 50000 + i * 10);
          expect(find.text('${i * 10}보'), findsOneWidget);
        }
        expect(find.text('걷는 중'), findsOneWidget);
        // 한 주기 안에 센서 거리(60 × 0.7 = 42m)까지 따라온다
        for (var i = 0; i < 70; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(find.text('0.04 km'), findsOneWidget);
        await _end(tester, e);
      });

      testWidgets('health 값이 더 크면 health 값, 센서가 더 늘면 다시 센서 값 (큰 쪽)', (tester) async {
        final e = _Env();
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);
        e.live.push(0);
        await sensorTo(tester, e, 5, 30);
        expect(find.text('30보'), findsOneWidget);

        await walkAndRefresh(tester, e, 10, 100);
        expect(find.text('1,000보'), findsOneWidget);
        expect(find.text('30보'), findsNothing);

        await sensorTo(tester, e, 5, 1530);
        expect(find.text('1,530보'), findsOneWidget);
        expect(find.text('1,000보'), findsNothing);
        await _end(tester, e);
      });

      testWidgets('센서가 있으면 달리는 중 라벨과 분당 걸음·속도·보폭은 센서 기준', (tester) async {
        final e = _Env();
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);
        expect(find.text('걷는 중'), findsOneWidget);

        e.live.push(0);
        // 30초 창에 70보 → 분당 140보 → 뛰기 (health 기록은 없다)
        await sensorTo(tester, e, 5, 70);
        expect(find.text('달리는 중'), findsOneWidget);
        expect(find.text('걷는 중'), findsNothing);
        await tester.tap(find.text('달리는 중'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('140보'), findsOneWidget);
        expect(find.text('8.4 km/h'), findsOneWidget);
        // 3600 ÷ 8.4 = 428.57 → 429초 = 7분 9초
        expect(find.text('7\'09"/km'), findsOneWidget);
        expect(find.text('1.00 m'), findsOneWidget);

        // 가만히 서면 창이 비어 분당 걸음이 0이 되고 달리는 중이 아니게 된다
        e.now = e.now.add(const Duration(minutes: 1));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('걷는 중'), findsOneWidget);
        expect(find.text('0.0 km/h'), findsOneWidget);
        // 속도가 0이면 페이스를 못 낸다
        expect(find.text('-'), findsOneWidget);
        await _end(tester, e);
      });

      testWidgets('센서가 없는 기기(오류)면 health 값만 쓴다', (tester) async {
        final e = _Env();
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);
        e.live.pushError();
        await tester.pump();
        expect(e.live.listeners, 0);

        await walkAndRefresh(tester, e, 10, 150);
        expect(find.text('1,500보'), findsOneWidget);
        expect(find.text('달리는 중'), findsOneWidget);
        await _end(tester, e);
      });

      testWidgets('걷기 마치기로 나가면 센서 읽기를 멈춘다', (tester) async {
        final e = _Env();
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);
        expect(e.live.listeners, 1);

        await tester.tap(find.text('걷기 마치기'));
        await _transition(tester);
        expect(e.live.listeners, 0);
        await _end(tester, e);
      });

      testWidgets('앱이 뒤로 갔다 오면 새 기준값부터 센다 (꺼져 있던 동안의 걸음은 화면에 안 들어간다)',
          (tester) async {
        final e = _Env();
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);
        e.live.push(1000);
        await sensorTo(tester, e, 5, 1010);
        expect(find.text('10보'), findsOneWidget);

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
        expect(e.live.subscriptions, 2);

        e.live.push(5000);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('10보'), findsOneWidget);
        await sensorTo(tester, e, 5, 5005);
        expect(find.text('15보'), findsOneWidget);
        await _end(tester, e);
      });

      testWidgets('권한이 없으면 처음 들어올 때 한 번 묻고, 허용되면 센서를 읽는다', (tester) async {
        final e = _Env();
        e.live.permitted = false;
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);

        expect(e.live.permissionRequests, 1);
        expect(e.live.listeners, 1);
        await _end(tester, e);
      });

      testWidgets('거부하면 health 값만 쓰고, 이 앱이 켜져 있는 동안 다시 들어와도 다시 묻지 않는다', (tester) async {
        final e = _Env();
        e.live
          ..permitted = false
          ..grantOnRequest = false;
        await e.seed(tester, dest: 'kr003');
        await openWalking(tester, e);
        expect(e.live.permissionRequests, 1);
        expect(e.live.listeners, 0);

        await walkAndRefresh(tester, e, 10, 100);
        expect(find.text('1,000보'), findsOneWidget);
        expect(find.text('걷는 중'), findsOneWidget);

        // 걷기 마치기 → 쉼터로 → 출발하기로 다시 들어온다
        await tester.tap(find.text('걷기 마치기'));
        await _transition(tester);
        await _settle(tester, () => find.text('쉼터로').evaluate().isNotEmpty);
        await tester.tap(find.text('쉼터로'));
        await _transition(tester);
        await tester.tap(find.text('출발하기'));
        await _transition(tester);
        await _wait(tester);
        expect(find.text('걷기 마치기'), findsOneWidget);

        expect(e.live.permissionRequests, 1);
        expect(e.live.listeners, 0);
        await _end(tester, e);
      });
    });
  });

  group('걷기 마치기 → 걷기 기록 → 쉼터로', () {
    testWidgets('걷기 기록의 숫자와 걷기 1번 줄, 쉼터로 돌아온다', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      await _pumpApp(tester, e);
      await tester.tap(find.text('출발하기'));
      await _transition(tester);
      await _wait(tester);

      // 15분 × 100보 = 1,500보, 1.05km
      e.source.records.add(_walk(_t1, 15, 100));
      e.now = _t1.add(const Duration(minutes: 15));
      for (var i = 0; i < 600 && find.text('1,500보').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (i % 10 == 0) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        }
      }

      await tester.tap(find.text('걷기 마치기'));
      await _transition(tester);
      await _settle(tester, () => find.text('1,500').evaluate().isNotEmpty);

      expect(find.text('걷기 기록'), findsOneWidget);
      expect(find.text('1,500'), findsOneWidget);
      // 큰 거리 숫자와 1km 기록의 남은 구간 줄
      expect(find.text('1.05 km'), findsNWidgets(2));
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('걸음'), findsOneWidget);
      expect(find.text('거리'), findsOneWidget);
      expect(find.text('시간'), findsOneWidget);
      expect(find.text('걷기 100% · 달리기 0%'), findsOneWidget);
      expect(find.text('오늘 1/3번째 함께 걷기'), findsOneWidget);
      expect(find.text('다음 방명록 지점까지 3,500보'), findsOneWidget);

      // 진행 막대: 걷기 전 0%에서 지금 %까지
      final name = _byId['kr003']!.name;
      final after = (1.05 / _totalKm('kr003') * 100).round();
      expect(find.text('$name까지 0% 왔어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('$name까지 $after% 왔어요'), findsOneWidget);

      await tester.tap(find.text('쉼터로'));
      await _transition(tester);
      expect(find.text('걷기 기록'), findsNothing);
      expect(find.text('걷기 마치기'), findsNothing);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(find.text('쉬는 중 · 목적지까지 ${formatKm(_totalKm('kr003') - 1.05)}'), findsOneWidget);
      expect(Navigator.of(tester.element(find.byType(RestScreen))).canPop(), isFalse);
      await _end(tester, e);
    });
  });

  group('걷기 기록 화면 (직접 열기)', () {
    Future<void> openRecord(
      WidgetTester tester,
      _Env e, {
      required DateTime start,
      required DateTime end,
      double? ratioBefore,
      bool review = false,
    }) async {
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: e.overrides,
        child: MaterialApp(
          home: WalkRecordScreen(start: start, end: end, ratioBefore: ratioBefore, review: review),
        ),
      ));
      await _settle(tester, () => find.text('기록을 정리하는 중').evaluate().isEmpty);
    }

    testWidgets('기준을 못 채운 걷기는 1번으로 치는 기준을 알려 주고, 여정이 없으면 진행 막대가 없다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      // 5분 × 100보: 10분·1,000보 기준 미달
      e.source.records.add(_walk(_t1, 5, 100));
      await openRecord(tester, e, start: _t1, end: _t1.add(const Duration(minutes: 5)));

      expect(find.text('500'), findsOneWidget);
      expect(find.text('0.35 km'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('10분 이상, 1,000보 이상 이어 걸으면 1번으로 쳐요'), findsOneWidget);
      expect(find.textContaining('왔어요'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('인정된 걷기는 오늘 n/3번째 함께 걷기 (그날 둘째 걷기면 2/3)', (tester) async {
      final e = _Env();
      await e.seed(tester);
      // 15분 × 100보를 15분 비우고 두 번: 둘 다 기준(10분·1,000보) 이상
      e.source.records
          .addAll([_walk(_t1, 15, 100), _walk(_t1.add(const Duration(minutes: 30)), 15, 100)]);
      final start = _t1.add(const Duration(minutes: 30));
      await openRecord(tester, e, start: start, end: start.add(const Duration(minutes: 15)));

      expect(find.text('오늘 2/3번째 함께 걷기'), findsOneWidget);
      expect(find.textContaining('이어 걸으면'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('큰 숫자 40·라벨 12, 쉼터로 버튼이 있다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      e.source.records.add(_walk(_t1, 15, 100));
      await openRecord(tester, e, start: _t1, end: _t1.add(const Duration(minutes: 15)));

      expect(tester.widget<Text>(find.text('1,500')).textSpan!.style!.fontSize, 40);
      // 큰 숫자가 먼저, 그 뒤가 1km 기록의 남은 구간 줄
      expect(tester.widget<Text>(find.text('1.05 km').first).textSpan!.style!.fontSize, 40);
      expect(tester.widget<Text>(find.text('15:00')).textSpan!.style!.fontSize, 40);
      expect(tester.widget<Text>(find.text('걸음')).style!.fontSize, 12);
      expect(tester.widget<Text>(find.text('걷기 기록')).style!.fontSize, 22);
      expect(find.text('쉼터로'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('다시 보기(review)는 진행 막대 연출과 쉼터로 없이 뒤로 가기만 있다', (tester) async {
      final e = _Env();
      await e.seed(tester, dest: 'kr003');
      e.source.records.add(_walk(_t1, 15, 100));
      // 다시 보기는 동기화하지 않으니 저장돼 있어야 한다
      await tester.runAsync(() => e.svc.sync(_t1.add(const Duration(minutes: 30))));
      // 걷기 전 비율을 넘겨도 다시 볼 때는 막대를 그리지 않는다
      await openRecord(
        tester,
        e,
        start: _t1,
        end: _t1.add(const Duration(minutes: 15)),
        ratioBefore: 0,
        review: true,
      );

      expect(find.text('1,500'), findsOneWidget);
      expect(find.textContaining('왔어요'), findsNothing);
      expect(find.text('쉼터로'), findsNothing);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('뛴 비율이 막대 아래 글자로 나온다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      // 100보 10분 → 150보 5분 (뛴 걸음 750 / 1,750)
      e.source.records.addAll([_walk(_t1, 10, 100), _walk(_t1.add(const Duration(minutes: 10)), 5, 150)]);
      await openRecord(tester, e, start: _t1, end: _t1.add(const Duration(minutes: 15)));

      expect(find.text('1,750'), findsOneWidget);
      expect(find.text('걷기 57% · 달리기 43%'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('1km 이상 걸으면 평균 줄과 1km 기록이 나온다 (1km 랩 + 남은 부분 랩)', (tester) async {
      final e = _Env();
      await e.seed(tester);
      // 15분 × 100보: 1.05km, 1,500보
      // 평균 페이스 900초 ÷ 1.05km = 857.14 → 857 = 14'17", 평균 분당 걸음 1,500 ÷ 15 = 100
      // 1km 랩은 857초 → 14'17", 남은 50m는 43초 ÷ 0.05km = 860 → 14'20"
      e.source.records.add(_walk(_t1, 15, 100));
      await openRecord(tester, e, start: _t1, end: _t1.add(const Duration(minutes: 15)));

      expect(find.text('평균 페이스 14\'17"/km · 평균 분당 걸음 100보'), findsOneWidget);
      expect(find.text('1km 기록'), findsOneWidget);
      expect(find.text('1 km'), findsOneWidget);
      expect(find.text('14\'17"/km'), findsOneWidget);
      // 남은 부분 랩은 거기까지의 거리 1.05 km (큰 거리 숫자와 같은 글자라 둘)
      expect(find.text('1.05 km'), findsNWidgets(2));
      expect(find.text('14\'20"/km'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('1km를 못 채우면 평균 줄만 있고 1km 기록은 없다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      // 5분 × 100보: 0.35km. 300초 ÷ 0.35km = 857.14 → 14'17"
      e.source.records.add(_walk(_t1, 5, 100));
      await openRecord(tester, e, start: _t1, end: _t1.add(const Duration(minutes: 5)));

      expect(find.text('평균 페이스 14\'17"/km · 평균 분당 걸음 100보'), findsOneWidget);
      expect(find.text('1km 기록'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('걸음이 없으면 평균 줄도 1km 기록도 없다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await openRecord(tester, e, start: _t1, end: _t1.add(const Duration(minutes: 5)));

      expect(find.text('걸음'), findsOneWidget);
      expect(find.textContaining('평균'), findsNothing);
      expect(find.text('1km 기록'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('하루 최대(3번)를 채운 뒤의 걷기는 n/n번을 다 채웠어요', (tester) async {
      final e = _Env();
      await e.seed(tester);
      // 15분씩 4번, 사이는 15분 비움 → 앞 셋만 인정되고 넷째는 기준만 넘음
      for (var i = 0; i < 4; i++) {
        e.source.records.add(_walk(_t1.add(Duration(minutes: 30 * i)), 15, 100));
      }
      final start = _t1.add(const Duration(minutes: 90));
      await openRecord(tester, e, start: start, end: start.add(const Duration(minutes: 15)));

      expect(find.text('오늘은 3/3번을 다 채웠어요'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('마지막 방명록 걸음 숫자를 넘으면 다음 방명록 줄이 없다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      // 설치 전 날짜로 큰 걸음을 직접 넣어 둔다 (동기화가 다시 계산하는 범위 밖)
      await tester.runAsync(() => e.db.into(e.db.daySummaries).insert(
          DaySummariesCompanion.insert(
              day: '2026-11-10', steps: 1234567, distanceM: 0, countedSessions: 0)));
      e.source.records.add(_walk(_t1, 15, 100));
      await openRecord(tester, e, start: _t1, end: _t1.add(const Duration(minutes: 15)));

      expect(find.text('1,500'), findsOneWidget);
      expect(find.textContaining('다음 방명록'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('쉼터로는 첫 화면까지 돌아간다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      _phone(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: e.overrides,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => WalkRecordScreen(start: _t1, end: _t1, ratioBefore: null),
                )),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await _transition(tester);
      expect(find.text('걷기 기록'), findsOneWidget);
      await tester.tap(find.text('쉼터로'));
      await _transition(tester);
      expect(find.text('열기'), findsOneWidget);
      expect(find.text('걷기 기록'), findsNothing);
      await _end(tester, e);
    });
  });
}
