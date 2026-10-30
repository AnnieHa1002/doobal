import 'package:doobal/app/providers.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';

// 설치 KST 2026-11-18 09:00, 화면은 한 시간 뒤 (낮)
final t0 = DateTime.utc(2026, 11, 18, 0);
final t1 = t0.add(const Duration(hours: 1));

final byId = {for (final l in landmarks) l.id: l};

// 경복궁에서 동쪽으로 약 1km
const nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

StepRecord walkRecord(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

/// 메모리 DB + 가짜 걸음(원하면 [source]를 넣는다) + 바꿀 수 있는 시계. 에셋은 모두 직접 넣는다
/// (두 번째 testWidgets부터는 rootBundle 에셋이 로드되지 않는다)
class UiEnv {
  UiEnv({FakeStepSource? source})
      : db = AppDb(NativeDatabase.memory()),
        source = source ?? FakeStepSource(),
        now = t1 {
    svc = SyncService(
      db: db,
      source: this.source,
      rules: rules,
      allowedSources: const [],
      landmarks: byId,
      props: props,
      milestones: milestones,
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
        sigunguProvider.overrideWith((ref) => sigungu),
        hairSwatchesProvider.overrideWith((ref) => hairSwatches),
        dbProvider.overrideWithValue(db),
        stepSourceProvider.overrideWithValue(source),
        clockProvider.overrideWithValue(() => now),
      ];

  /// 설치(= t0)하고 출발 동네를 testHome으로 골라 둔다. 시작 흐름도 끝낸 것으로 둔다
  /// (그래야 DoobalApp이 시작 화면 대신 쉼터를 띄운다). [body]로 더 채울 수 있다
  Future<void> seed(WidgetTester tester, [Future<void> Function()? body]) =>
      tester.runAsync(() async {
        await svc.sync(t0);
        await svc.setHome(testHomeName, testHome);
        await completeOnboarding(db);
        await body?.call();
      }) as Future<void>;

  /// 경복궁 근처에서 출발해 경복궁에 도착한 상태로 만든다 (나무 액자, 도착 화면은 아직 안 봤다).
  /// 도착 시각은 t1 + 2시간(한국 11월 18일), 그날 걸음은 3,000보
  Future<void> arriveAtGyeongbok() async {
    await placeAt(db, nearGyeongbok, t0);
    await svc.startJourney('kr001', t1, useFund: false);
    source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), 30, 100));
    now = t1.add(const Duration(hours: 2));
    await svc.sync(now);
  }

  /// 첫 여정 '내 동네 스케치'를 정하고(t1 시작, 출발 동네 = testHome) 한 걸음도 안 걸은 채로 둔다.
  /// 시작 흐름을 끝낸 프로필(seed가 심는다)이 있어야 한다
  Future<void> startSketch() async {
    expect(await svc.startSketch(t1), isTrue);
  }

  /// 스케치 여정을 환산 거리 [km]인 가상 목적지로 직접 넣는다 (북동쪽). 말풍선 글처럼 거리가
  /// 정해진 값이 필요할 때 쓴다 (실제 목적지는 설치 번호로 정해져서 거리를 모른다)
  Future<void> insertSketchJourney(double km) {
    final dest = destinationPoint(testHome, 45, km, rules.earthRadiusKm);
    return db.into(db.journeys).insert(JourneysCompanion.insert(
          id: 'j${t1.millisecondsSinceEpoch}',
          originLat: testHome.lat,
          originLng: testHome.lng,
          destId: sketchId,
          startUtc: t1.millisecondsSinceEpoch,
          fundKm: 0,
          totalEffectiveKm: km,
          status: JourneyStatus.active,
          destLat: Value(dest.lat),
          destLng: Value(dest.lng),
        ));
  }

  /// 스케치 여정을 정하고 걸어서 도착한 상태로 만든다 (도착 화면은 아직 안 봤다).
  /// 도착 시각은 t1 + 2시간(한국 11월 18일 12시), 그날 걸음은 그 걷기의 걸음
  Future<void> arriveAtSketch() async {
    await startSketch();
    final km = (await svc.snapshot(t1)).journey!.totalKm;
    // 분당 100보(70m)로 모자라지 않게 한 분 더
    final minutes = (km * 1000 / (rules.walkStrideM * 100)).ceil() + 1;
    source.records.add(walkRecord(t1.add(const Duration(minutes: 5)), minutes, 100));
    now = t1.add(const Duration(hours: 2));
    await svc.sync(now);
  }

  /// 도착 화면 값까지 채운 도착한 여정과 그 그림 (직접 넣는다)
  Future<void> insertArrival(
    String id,
    String destId,
    DateTime at, {
    int visitNo = 1,
    Frame frame = Frame.wood,
    Frame? prevFrame,
    double km = 10,
  }) async {
    await db.into(db.journeys).insert(JourneysCompanion.insert(
          id: id,
          originLat: 38,
          originLng: 128,
          destId: destId,
          startUtc: at.millisecondsSinceEpoch - 1000,
          fundKm: 0,
          totalEffectiveKm: km,
          status: JourneyStatus.arrived,
          arrivedUtc: Value(at.millisecondsSinceEpoch),
          visitNo: Value(visitNo),
          prevFrame: Value(prevFrame),
          newFrame: Value(frame),
        ));
    await db.into(db.paintingsOwned).insertOnConflictUpdate(PaintingsOwnedCompanion.insert(
          landmarkId: destId,
          visits: visitNo,
          frame: frame,
          bestKm: km,
          firstArrivedUtc: at.millisecondsSinceEpoch,
          lastArrivedUtc: at.millisecondsSinceEpoch,
        ));
  }

  /// 얻은 그림만 넣는다 (도착 기록 없음). [seen]이 false면 새 그림 표시가 켜진 채로
  Future<void> ownPaintings(Map<String, Frame> frames, {bool seen = true}) =>
      db.batch((b) => b.insertAll(db.paintingsOwned, [
            for (final (i, e) in frames.entries.indexed)
              PaintingsOwnedCompanion.insert(
                landmarkId: e.key,
                visits: 1,
                frame: e.value,
                bestKm: 1,
                firstArrivedUtc: 1000 + i,
                lastArrivedUtc: 1000 + i,
                seen: Value(seen),
              ),
          ]));
}

void phone(WidgetTester tester, {double height = 844}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 실제 비동기(DB·에셋)가 끝나도록 기다리며 화면을 갱신한다
Future<void> settle(WidgetTester tester, bool Function() done, {int tries = 40}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
}

/// 화면 전환 애니메이션(플랫폼에 따라 최대 약 0.8초)이 끝날 때까지
Future<void> transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// 화면을 치우고 DB를 닫는다. 진행 중이던 비동기가 끝날 시간을 준다
Future<void> end(WidgetTester tester, UiEnv e) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.runAsync(e.db.close);
}

/// 앱 전체(DoobalApp = 시작 관문 → AutoSync + 쉼터)를 폰 크기로 띄운다
Future<void> pumpDoobal(WidgetTester tester, UiEnv e, Widget app, {double height = 844}) async {
  phone(tester, height: height);
  await tester.pumpWidget(ProviderScope(overrides: e.overrides, child: app));
}

/// '열기' 버튼 하나뿐인 첫 화면에서 [screen]을 연다 (앱 첫 화면 위에 쌓이는 것과 같다)
Future<void> openOnTop(
  WidgetTester tester,
  UiEnv e,
  Widget screen, {
  bool Function()? ready,
  double height = 844,
}) async {
  phone(tester, height: height);
  await tester.pumpWidget(ProviderScope(
    overrides: e.overrides,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await transition(tester);
  if (ready != null) await settle(tester, ready);
}
