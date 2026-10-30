import 'package:doobal/app/providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/map_regions.dart';
import 'package:doobal/domain/route.dart';
import 'package:doobal/ui/common/format.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/map/landmark_card.dart';
import 'package:doobal/ui/map/map_geometry.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';

// 설치 KST 2026-11-18 09:00, 지도는 한 시간 뒤 (낮)
final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

// 경복궁에서 동쪽으로 약 1km
const _nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

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
  late final SyncService svc;
  DateTime now;

  List<Override> get overrides => [
        rulesProvider.overrideWith((ref) => rules),
        landmarksProvider.overrideWith((ref) => landmarks),
        propsProvider.overrideWith((ref) => props),
        milestonesProvider.overrideWith((ref) => milestones),
        campThemeProvider.overrideWith((ref) => campTheme),
        mapProjectionProvider.overrideWith((ref) => mapProjection),
        mapRegionsProvider.overrideWith((ref) => mapRegions),
        dbProvider.overrideWithValue(db),
        stepSourceProvider.overrideWithValue(source),
        clockProvider.overrideWithValue(() => now),
      ];

  /// 설치(= _t0)하고 출발 동네를 testHome으로 골라 둔다. [body]로 더 채울 수 있다
  Future<void> seed(WidgetTester tester, [Future<void> Function()? body]) =>
      tester.runAsync(() async {
        await svc.sync(_t0);
        await svc.setHome(testHomeName, testHome);
        await body?.call();
        // 여정 id가 시작 시각이라, 지도에서 출발하는 시각은 채워 둔 여정과 달라야 한다
        now = now.add(const Duration(minutes: 10));
      }) as Future<void>;

  /// 걷기 기록을 넣고 동기화해서 여행 경비를 [minutes]분 × 100보 만큼 쌓는다 (1분 0.07km)
  Future<void> fundBy(int minutes) async {
    source.records.add(_walk(_t1, minutes, 100));
    now = _t1.add(Duration(minutes: minutes + 30));
    await svc.sync(now);
  }

  Future<List<JourneyRow>> journeys(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.journeys).get()))!;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, bool Function() done, {int tries = 40}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
}

/// 화면 전환·지도 이동 애니메이션이 끝날 때까지
Future<void> _transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// 앱 첫 화면에서 지도를 연다 (지도가 쉼터 위에 쌓이는 것과 같다)
Future<void> _openMap(WidgetTester tester, _Env e, {bool walkAfterStart = false}) async {
  _phone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: e.overrides,
    child: MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: Palette.paper),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => MapScreen(walkAfterStart: walkAfterStart),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await _transition(tester);
  await _settle(tester, () => find.byType(InteractiveViewer).evaluate().isNotEmpty);
  // 카드의 거리 줄처럼 한 박자 늦게 오는 값까지
  await _settle(tester, () => false, tries: 6);
}

Future<void> _end(WidgetTester tester, _Env e) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.runAsync(e.db.close);
}

/// 검색해서 결과 줄을 눌러 명소를 고른다
Future<void> _searchAndPick(WidgetTester tester, String query, String id) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
  await tester.tap(find.byKey(ValueKey('result-$id')));
  await _transition(tester);
  await _settle(tester, () => false, tries: 6);
}

TransformationController _viewer(WidgetTester tester) =>
    tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!;

/// 캔버스 px → 화면 pt (폰 너비 390에 맞춘 지도와 지금 확대·이동 상태)
Offset _screenOf(WidgetTester tester, Offset canvasPx) =>
    MatrixUtils.transformPoint(_viewer(tester).value, canvasPx * (390 / 2048));

/// 검색 결과 줄들 (키가 result-로 시작하는 위젯)
Finder _results() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('result-');
    });

Finder _card(String text) =>
    find.descendant(of: find.byType(LandmarkCard), matching: find.text(text));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('칩', () {
    testWidgets('권역 7개가 `이름 다녀온 곳/전체`로 나오고, 도착하면 올라간다', (tester) async {
      final e = _Env();
      await e.seed(tester, () async {
        await placeAt(e.db, _nearGyeongbok, _t0);
        await e.svc.startJourney('kr001', _t1, useFund: false);
        e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 30, 100));
        e.now = _t1.add(const Duration(hours: 2));
        await e.svc.sync(e.now);
      });
      await _openMap(tester, e);

      expect(find.text('수도권 1/12'), findsOneWidget);
      for (final t in ['강원 0/17', '충청 0/17', '전라 0/21', '경상 0/31', '제주 0/2', '울릉 0/1']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await _end(tester, e);
    });

    testWidgets('칩을 누르면 그 권역으로 확대하고, 울릉은 최대 확대', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);

      // 처음은 확대 1배
      expect(_viewer(tester).value.getMaxScaleOnAxis(), 1);

      final gyeongsang = boundsOf(mapRegions.where((r) => r.region == 'gyeongsang'));
      await tester.ensureVisible(find.text('경상 0/31'));
      await tester.tap(find.text('경상 0/31'));
      await _transition(tester);
      final z = _viewer(tester).value.getMaxScaleOnAxis();
      expect(z, greaterThan(1));
      expect(z, lessThanOrEqualTo(6));
      // 권역 가운데가 화면 가운데 가까이 온다
      final c = _screenOf(tester, Offset(gyeongsang.center.x, gyeongsang.center.y));
      expect(c.dx, closeTo(195, 1));
      expect(c.dy, inInclusiveRange(150, 620));

      await tester.ensureVisible(find.text('울릉 0/1'));
      await tester.tap(find.text('울릉 0/1'));
      await _transition(tester);
      expect(_viewer(tester).value.getMaxScaleOnAxis(), closeTo(6, 1e-9));
      await _end(tester, e);
    });
  });

  group('이동·확대', () {
    testWidgets('두 손가락으로 벌리면 확대, 오므려도 1배 밑으로는 안 내려간다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);
      expect(_viewer(tester).value.getMaxScaleOnAxis(), 1);

      final a = await tester.startGesture(const Offset(170, 300));
      final b = await tester.startGesture(const Offset(220, 300));
      for (var i = 1; i <= 10; i++) {
        await a.moveTo(Offset(170 - i * 12, 300));
        await b.moveTo(Offset(220 + i * 12, 300));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await tester.pump();
      final zoomed = _viewer(tester).value.getMaxScaleOnAxis();
      expect(zoomed, greaterThan(1.5));
      expect(zoomed, lessThanOrEqualTo(6));

      final c = await tester.startGesture(const Offset(50, 300));
      final d = await tester.startGesture(const Offset(340, 300));
      for (var i = 1; i <= 10; i++) {
        await c.moveTo(Offset(50 + i * 13, 300));
        await d.moveTo(Offset(340 - i * 13, 300));
        await tester.pump();
      }
      await c.up();
      await d.up();
      await tester.pump();
      expect(_viewer(tester).value.getMaxScaleOnAxis(), greaterThanOrEqualTo(1));
      await _end(tester, e);
    });

    testWidgets('멀리 밀어도 지도가 화면 밖으로 사라지지 않는다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);

      const drags = [Offset(900, 0), Offset(-900, 0), Offset(0, 1500), Offset(0, -1500)];
      for (final delta in drags) {
        await tester.drag(find.byType(InteractiveViewer), delta);
        await tester.pump();
        // 캔버스(390 × 487.5pt)의 왼쪽 위·오른쪽 아래 모서리 중 적어도 절반은 화면 안에 남는다
        final topLeft = _screenOf(tester, Offset.zero);
        final bottomRight = _screenOf(tester, const Offset(2048, 2560));
        expect(topLeft.dx, lessThanOrEqualTo(195 + 1), reason: '$delta');
        expect(bottomRight.dx, greaterThanOrEqualTo(195 - 1), reason: '$delta');
        expect(topLeft.dy, lessThanOrEqualTo(422 + 1), reason: '$delta');
        expect(bottomRight.dy, greaterThanOrEqualTo(422 - 1), reason: '$delta');
      }
      await _end(tester, e);
    });
  });

  group('검색', () {
    testWidgets('이름에 글자가 들어간 명소를 최대 6곳 보여 주고, 고르면 카드와 확대', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);

      // 아무 것도 고르지 않았으면 카드가 없다
      expect(find.byType(LandmarkCard), findsNothing);

      // 두 글자 이상이 겹치는 흔한 글자로 6곳 제한을 본다
      const common = '산';
      final matches = landmarks.where((l) => l.name.contains(common)).length;
      expect(matches, greaterThan(6));
      await tester.enterText(find.byType(TextField), common);
      await tester.pump();
      expect(_results(), findsNWidgets(6));

      await tester.enterText(find.byType(TextField), '경복궁');
      await tester.pump();
      expect(_results(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('result-kr001')));
      await _transition(tester);

      // 결과 목록은 닫히고 카드가 뜬다
      expect(find.byKey(const ValueKey('result-kr001')), findsNothing);
      expect(_card('경복궁'), findsOneWidget);
      expect(_card('서울특별시 · 도시'), findsOneWidget);
      expect(find.text('여기로 가기'), findsOneWidget);
      // 그 명소 쪽으로 확대하고 화면 가운데 영역에 둔다
      expect(_viewer(tester).value.getMaxScaleOnAxis(), closeTo(4, 1e-9));
      final p = _screenOf(tester, toOffset(mapProjection.project(_byId['kr001']!.latLng)));
      expect(p.dx, closeTo(195, 1));
      expect(p.dy, inInclusiveRange(150, 620));
      await _end(tester, e);
    });

    testWidgets('없는 이름이면 결과가 없다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);
      await tester.enterText(find.byType(TextField), '없는이름없는이름');
      await tester.pump();
      expect(_results(), findsNothing);
      await _end(tester, e);
    });
  });

  group('지도 누르기', () {
    testWidgets('명소 표시 24pt 안을 누르면 그 명소, 빈 곳을 누르면 해제', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);

      final canvas = toOffset(mapProjection.project(_byId['kr003']!.latLng));
      final at = _screenOf(tester, canvas);
      await tester.tapAt(at + const Offset(12, 8));
      await tester.pump();
      expect(_card(_byId['kr003']!.name), findsOneWidget);

      // 바다 한가운데 (서해). 가까운 명소가 없다
      const sea = Offset(100, 1000);
      expect(
        nearestLandmark(sea * (390 / 2048), {
          for (final l in landmarks) l.id: toOffset(mapProjection.project(l.latLng)),
        }, base: 390 / 2048, zoom: 1),
        isNull,
      );
      await tester.tapAt(_screenOf(tester, sea));
      await tester.pump();
      expect(find.byType(LandmarkCard), findsNothing);
      await _end(tester, e);
    });
  });

  group('카드', () {
    testWidgets('안 가 본 곳: 이름·시도·지형, 그림 칸 3개가 모두 잠김, 액자 글자 없음', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      expect(find.byType(PaintingSlot), findsNWidgets(3));
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(3));
      expect(find.byIcon(Icons.landscape_outlined), findsNothing);
      expect(find.textContaining('액자'), findsNothing);
      // 지금 자리(서울시청)에서 가는 거리
      final km = buildRoute(testHome, _byId['kr001']!.latLng, rules).totalEffectiveKm;
      expect(_card('남은 거리 ${formatKm(km)} · 약 1일'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('다녀온 곳: 첫 칸이 액자 색, 나머지는 잠김, `금 액자`', (tester) async {
      final e = _Env();
      await e.seed(tester, () async {
        await e.db.into(e.db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
              landmarkId: 'kr001',
              visits: 3,
              frame: Frame.gold,
              bestKm: 60,
              firstArrivedUtc: _t0.millisecondsSinceEpoch,
              lastArrivedUtc: _t0.millisecondsSinceEpoch,
            ));
      });
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      expect(find.byIcon(Icons.landscape_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(_card('금 액자'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('여정이 있으면 목적지가 처음부터 골라져 있고 `여정 멈추기`뿐이다. 남은 거리·일수는 스냅숏과 같다',
        (tester) async {
      final e = _Env();
      await e.seed(tester, () async => e.svc.startJourney('kr003', _t1));
      await _openMap(tester, e);

      expect(_card(_byId['kr003']!.name), findsOneWidget);
      expect(find.text('여기로 가기'), findsNothing);
      expect(find.text('목적지 바꾸기'), findsNothing);
      expect(find.text('여정 멈추기'), findsOneWidget);
      final snap = (await tester.runAsync(() => e.svc.snapshot(e.now)))!;
      final days = snap.journey!.eta.difference(DateTime.utc(2026, 11, 18)).inDays;
      expect(_card('남은 거리 ${formatKm(snap.journey!.progress.remainingKm)} · 약 $days일'),
          findsOneWidget);
      await _end(tester, e);
    });
  });

  group('출발', () {
    testWidgets('여기로 가기: 경비가 0이면 시트 없이 바로 출발하고, 카드는 목적지로 바뀐다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('여기로 가기'));
      await _settle(tester, () => find.text('여기로 가기').evaluate().isEmpty);
      expect(find.text('더하기'), findsNothing);

      final rows = await e.journeys(tester);
      expect(rows.where((r) => r.status == JourneyStatus.active).single.destId, 'kr001');
      // 카드는 그대로 경복궁이고, 이제 현재 목적지라 `여정 멈추기`뿐이다
      expect(_card('경복궁'), findsOneWidget);
      expect(find.text('목적지 바꾸기'), findsNothing);
      expect(find.text('여정 멈추기'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('경비가 있으면 먼저 묻는다: 아껴 두기는 경비를 쓰지 않는다', (tester) async {
      final e = _Env();
      await e.seed(tester, () => e.fundBy(30));
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('여기로 가기'));
      await _transition(tester);
      expect(find.text('경비 2.1 km를 더할까요? (경비로 가는 구간에는 이벤트가 없어요)'), findsOneWidget);
      await tester.tap(find.text('아껴 두기'));
      await _settle(tester, () => find.text('여기로 가기').evaluate().isEmpty);

      final rows = await e.journeys(tester);
      final journey = rows.singleWhere((r) => r.status == JourneyStatus.active);
      expect(journey.fundKm, 0);
      final fund = await tester.runAsync(() => e.db.select(e.db.travelFund).getSingle());
      expect(fund!.km, closeTo(2.1, 1e-9));
      await _end(tester, e);
    });

    testWidgets('경비가 있으면 먼저 묻는다: 더하기는 경비를 모두 더한다', (tester) async {
      final e = _Env();
      await e.seed(tester, () => e.fundBy(30));
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('여기로 가기'));
      await _transition(tester);
      await tester.tap(find.text('더하기'));
      await _settle(tester, () => find.text('여기로 가기').evaluate().isEmpty);

      final rows = await e.journeys(tester);
      final journey = rows.singleWhere((r) => r.status == JourneyStatus.active);
      expect(journey.fundKm, closeTo(2.1, 1e-9));
      final fund = await tester.runAsync(() => e.db.select(e.db.travelFund).getSingle());
      expect(fund!.km, 0);
      await _end(tester, e);
    });

    testWidgets('경비 시트를 밖을 눌러 닫으면 출발하지 않는다', (tester) async {
      final e = _Env();
      await e.seed(tester, () => e.fundBy(30));
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('여기로 가기'));
      await _transition(tester);
      expect(find.text('더하기'), findsOneWidget);
      // 시트 위쪽 뒷배경
      await tester.tapAt(const Offset(195, 40));
      await _transition(tester);
      expect(find.text('더하기'), findsNothing);
      expect(find.text('여기로 가기'), findsOneWidget);
      expect((await e.journeys(tester)).where((r) => r.status == JourneyStatus.active), isEmpty);
      await _end(tester, e);
    });

    testWidgets('이미 있는 명소로는 못 가고 토스트로 알린다', (tester) async {
      final e = _Env();
      await e.seed(tester, () => placeAt(e.db, _byId['kr001']!.latLng, _t1));
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('여기로 가기'));
      await _settle(tester, () => find.text('이미 경복궁에 있어요').evaluate().isNotEmpty);
      expect(find.text('이미 경복궁에 있어요'), findsOneWidget);
      expect(find.text('여기로 가기'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('walkAfterStart: 출발하면 걷는 중으로 간다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e, walkAfterStart: true);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('여기로 가기'));
      await _settle(tester, () => find.byType(WalkingScreen).evaluate().isNotEmpty, tries: 80);
      await _transition(tester);
      expect(find.byType(WalkingScreen), findsOneWidget);
      expect(find.byType(MapScreen), findsNothing);
      expect(find.text('걷기 마치기'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('walkAfterStart라도 취소하면 지도에 남는다', (tester) async {
      final e = _Env();
      await e.seed(tester, () => e.fundBy(30));
      await _openMap(tester, e, walkAfterStart: true);
      await _searchAndPick(tester, '경복궁', 'kr001');
      await tester.tap(find.text('여기로 가기'));
      await _transition(tester);
      await tester.tapAt(const Offset(195, 40));
      await _transition(tester);
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(WalkingScreen), findsNothing);
      await _end(tester, e);
    });
  });

  group('목적지 바꾸기', () {
    testWidgets('다른 명소에는 `목적지 바꾸기`, 확인하면 지금 자리에서 새 목적지로 다시 출발', (tester) async {
      final e = _Env();
      await e.seed(tester, () async => e.svc.startJourney('kr003', _t1, useFund: false));
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      expect(find.text('여기로 가기'), findsNothing);
      await tester.tap(find.text('목적지 바꾸기'));
      await _transition(tester);
      expect(find.text('지금 자리에서 다시 출발해요. 액자 거리는 새로 세요.'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      await tester.tap(find.text('바꾸기'));
      await _settle(tester, () => find.text('목적지 바꾸기').evaluate().isEmpty);

      final rows = await e.journeys(tester);
      expect(rows.where((r) => r.status == JourneyStatus.active).single.destId, 'kr001');
      expect(rows.where((r) => r.destId == 'kr003').single.status, JourneyStatus.stopped);
      expect(_card('경복궁'), findsOneWidget);
      await _end(tester, e);
    });

    testWidgets('취소하면 그대로', (tester) async {
      final e = _Env();
      await e.seed(tester, () async => e.svc.startJourney('kr003', _t1, useFund: false));
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('목적지 바꾸기'));
      await _transition(tester);
      await tester.tap(find.text('취소'));
      await _transition(tester);

      expect(find.text('바꾸기'), findsNothing);
      expect(find.text('목적지 바꾸기'), findsOneWidget);
      final rows = await e.journeys(tester);
      expect(rows.where((r) => r.status == JourneyStatus.active).single.destId, 'kr003');
      await _end(tester, e);
    });

    testWidgets('경비가 있으면 확인 다음에 경비를 묻는다', (tester) async {
      final e = _Env();
      await e.seed(tester, () async {
        await e.fundBy(30);
        // 경비를 쓰지 않고 출발해서 경비가 남아 있다
        await e.svc.startJourney('kr003', e.now, useFund: false);
      });
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      await tester.tap(find.text('목적지 바꾸기'));
      await _transition(tester);
      await tester.tap(find.text('바꾸기'));
      await _transition(tester);
      expect(find.textContaining('를 더할까요?'), findsOneWidget);
      await tester.tap(find.text('더하기'));
      await _settle(tester, () => find.text('목적지 바꾸기').evaluate().isEmpty);

      final rows = await e.journeys(tester);
      final active = rows.singleWhere((r) => r.status == JourneyStatus.active);
      expect(active.destId, 'kr001');
      expect(active.fundKm, closeTo(2.1, 1e-9));
      await _end(tester, e);
    });
  });

  group('여정 멈추기', () {
    // config 상한 15km는 정수라 소수점 없이
    const stopText = '여기서 멈춰요. 다음 여정은 멈춘 자리에서 출발하고, '
        '그동안 걸은 거리는 여행 경비로 모아 둬요 (최대 15 km).';

    Future<JourneyRow> kr003(WidgetTester tester, _Env e) async =>
        (await e.journeys(tester)).singleWhere((r) => r.destId == 'kr003');

    testWidgets('진행 중인 여정의 목적지 카드에 보조 버튼 `여정 멈추기`, 다른 명소에는 없다', (tester) async {
      final e = _Env();
      await e.seed(tester, () async => e.svc.startJourney('kr003', _t1, useFund: false));
      await _openMap(tester, e);

      expect(_card(_byId['kr003']!.name), findsOneWidget);
      expect(find.text('여정 멈추기'), findsOneWidget);
      expect(tester.widget<GameButton>(find.widgetWithText(GameButton, '여정 멈추기')).kind,
          GameButtonKind.secondary);

      // 다른 명소는 `목적지 바꾸기` (primary)
      await _searchAndPick(tester, '경복궁', 'kr001');
      expect(_card('경복궁'), findsOneWidget);
      expect(find.text('여정 멈추기'), findsNothing);
      expect(tester.widget<GameButton>(find.widgetWithText(GameButton, '목적지 바꾸기')).kind,
          GameButtonKind.primary);
      await _end(tester, e);
    });

    testWidgets('여정이 없으면 `여정 멈추기`가 없다', (tester) async {
      final e = _Env();
      await e.seed(tester);
      await _openMap(tester, e);
      await _searchAndPick(tester, '경복궁', 'kr001');

      expect(find.text('여기로 가기'), findsOneWidget);
      expect(find.text('여정 멈추기'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('누르면 확인 시트가 뜨고, 멈추기를 고르면 여정이 멈추고 토스트, 카드는 `여기로 가기`',
        (tester) async {
      final e = _Env();
      await e.seed(tester, () async => e.svc.startJourney('kr003', _t1, useFund: false));
      await _openMap(tester, e);

      await tester.tap(find.text('여정 멈추기'));
      await _transition(tester);
      expect(find.text(stopText), findsOneWidget);
      expect(find.text('멈추기'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      // 확인하기 전에는 아무것도 바뀌지 않았다
      expect((await kr003(tester, e)).status, JourneyStatus.active);

      await tester.tap(find.text('멈추기'));
      await _settle(tester, () => find.text('여정 멈추기').evaluate().isEmpty);
      await _settle(tester, () => find.text('여정을 멈췄어요').evaluate().isNotEmpty);
      // 시트가 내려가는 애니메이션이 끝날 때까지 (토스트는 2.5초라 아직 떠 있다)
      await _transition(tester);

      final row = await kr003(tester, e);
      expect(row.status, JourneyStatus.stopped);
      expect(row.endedUtc, e.now.millisecondsSinceEpoch);
      final snap = (await tester.runAsync(() => e.svc.snapshot(e.now)))!;
      expect(snap.journey, isNull);
      expect(find.text('여정을 멈췄어요'), findsOneWidget);
      // 시트는 닫혔고, 같은 카드에서 멈춘 자리로부터 다시 출발할 수 있다
      expect(find.text(stopText), findsNothing);
      expect(_card(_byId['kr003']!.name), findsOneWidget);
      expect(find.text('여기로 가기'), findsOneWidget);
      expect(find.text('여정 멈추기'), findsNothing);
      await _end(tester, e);
    });

    testWidgets('멈춘 뒤 `여기로 가기`는 멈춘 자리에서 출발한다', (tester) async {
      final e = _Env();
      await e.seed(tester, () async {
        await e.svc.startJourney('kr003', _t1, useFund: false);
        e.source.records.add(_walk(_t1.add(const Duration(minutes: 5)), 20, 100));
      });
      await _openMap(tester, e);
      await tester.tap(find.text('여정 멈추기'));
      await _transition(tester);
      await tester.tap(find.text('멈추기'));
      await _settle(tester, () => find.text('여기로 가기').evaluate().isNotEmpty);

      final stopped = await kr003(tester, e);
      expect(stopped.status, JourneyStatus.stopped);
      await tester.tap(find.text('여기로 가기'));
      await _settle(tester, () => find.text('여정 멈추기').evaluate().isNotEmpty);
      final rows = await e.journeys(tester);
      final started = rows.singleWhere((r) => r.status == JourneyStatus.active);
      expect(started.destId, 'kr003');
      expect((started.originLat, started.originLng), (stopped.endLat, stopped.endLng));
      await _end(tester, e);
    });

    testWidgets('취소하면 그대로', (tester) async {
      final e = _Env();
      await e.seed(tester, () async => e.svc.startJourney('kr003', _t1, useFund: false));
      await _openMap(tester, e);

      await tester.tap(find.text('여정 멈추기'));
      await _transition(tester);
      await tester.tap(find.text('취소'));
      await _transition(tester);

      expect(find.text(stopText), findsNothing);
      expect(find.text('여정 멈추기'), findsOneWidget);
      expect(find.text('여정을 멈췄어요'), findsNothing);
      expect((await kr003(tester, e)).status, JourneyStatus.active);
      expect((await tester.runAsync(() => e.svc.snapshot(e.now)))!.journey, isNotNull);
      await _end(tester, e);
    });

    testWidgets('시트 밖을 눌러 닫아도 그대로, 다시 누를 수 있다', (tester) async {
      final e = _Env();
      await e.seed(tester, () async => e.svc.startJourney('kr003', _t1, useFund: false));
      await _openMap(tester, e);

      await tester.tap(find.text('여정 멈추기'));
      await _transition(tester);
      expect(find.text('멈추기'), findsOneWidget);
      // 시트 위쪽 뒷배경
      await tester.tapAt(const Offset(195, 40));
      await _transition(tester);

      expect(find.text('멈추기'), findsNothing);
      expect(find.text('여정을 멈췄어요'), findsNothing);
      expect((await kr003(tester, e)).status, JourneyStatus.active);
      // 겹침을 막는 잠금이 풀려 다시 열린다
      await tester.tap(find.text('여정 멈추기'));
      await _transition(tester);
      expect(find.text('멈추기'), findsOneWidget);
      await _end(tester, e);
    });
  });
}
