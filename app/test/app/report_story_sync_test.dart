import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/day_card.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/route.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'helpers.dart' show placeAt;

// 하루 카드 엽서의 이야기 (T10b, 16장 11/19): 카드 끝날의 여정 진행·도착, 칠한 물감 구간.
// 설치 KST 2026-11-18 09:00, 걷기는 그날 10:00(= _t1)부터. 보폭 걷기 0.7m (12분 × 100보 = 840m)

final _landmarks = {for (final l in landmarks) l.id: l};

final _t0 = DateTime.utc(2026, 11, 18, 0);
final _t1 = _t0.add(const Duration(hours: 1));

DateTime _at(int minutesAfter10) => _t1.add(Duration(minutes: minutesAfter10));

/// 한국 시각 → UTC
DateTime _kst(int m, int d, [int h = 0, int min = 0]) =>
    DateTime.utc(2026, m, d, h, min).subtract(const Duration(hours: 9));

int _ms(DateTime t) => t.millisecondsSinceEpoch;

StepRecord _walk(DateTime start, int minutes, int spm) => StepRecord(
      start: start,
      end: start.add(Duration(minutes: minutes)),
      steps: minutes * spm,
      sourceId: 'iphone',
      method: RecordingMethod.automatic,
    );

double _routeKm(LatLng from, String destId) =>
    buildRoute(from, _landmarks[destId]!.latLng, rules).totalEffectiveKm;

/// 가는 거리가 60km를 넘는 육지 명소: 몇 km를 걸어서는 도착하지 않는다
final _farDest = landmarks
    .firstWhere((l) => l.island == Island.mainland && _routeKm(testHome, l.id) > 60)
    .id;

/// 경복궁(kr001) 바로 옆 (ui_env와 같은 자리, 30분 걸으면 닿는다)
const _nearGyeongbok = LatLng(37.57761, 126.9769 + 0.0113);

const _d18 = DayRange.single('2026-11-18');
const _d19 = DayRange.single('2026-11-19');

class _Env {
  _Env()
      : db = AppDb(NativeDatabase.memory()),
        source = FakeStepSource() {
    svc = SyncService(
      db: db,
      source: source,
      rules: rules,
      allowedSources: const [],
      landmarks: _landmarks,
      props: props,
      milestones: milestones,
      distanceScale: 1,
      eventCatalog: eventCatalog,
    );
  }

  final AppDb db;
  final FakeStepSource source;
  late final SyncService svc;

  /// [from]에 물감 길을 열고 [minutes]분 동안 분당 [spm]보를 걷고 [syncAt]에 동기화한 뒤 [to]에 닫는다
  Future<int> trailWalk(DateTime from, int minutes, int spm, DateTime syncAt, DateTime to) async {
    final id = await svc.startPaintTrail(from, from);
    source.records.add(_walk(from, minutes, spm));
    await svc.sync(syncAt);
    await svc.endPaintTrail(id, to, syncAt);
    return id;
  }
}

Future<_Env> _env() async {
  final e = _Env();
  addTearDown(e.db.close);
  await e.svc.sync(_t0);
  await e.svc.setHome(testHomeName, testHome);
  return e;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('여정 없이 걸었으면 여정·자리 없음, 물감 길은 기본 물감 한 구간', () async {
    final e = await _env();
    await e.trailWalk(_at(0), 12, 100, _at(20), _at(12));
    final s = await e.svc.cardStory(_d18, _kst(11, 19, 7));
    expect(s.journey, isNull);
    expect(s.position, isNull);
    expect(s.strokes, [const PaintStroke('basic', 840)]);
  });

  test('여정을 그날 시작했으면 시작 때(경비)부터 그날 24시까지 진행, 다음 날 카드는 그 진행부터', () async {
    final e = await _env();
    await e.svc.startJourney(_farDest, _t1, useFund: false);
    // 물감 길 12분(0.84km) + 앱 밖 12분(0.84km)
    await e.trailWalk(_at(0), 12, 100, _at(15), _at(12));
    e.source.records.add(_walk(_at(30), 12, 100));
    await e.svc.sync(_at(50));
    final total = _routeKm(testHome, _farDest);

    var s = await e.svc.cardStory(_d18, _kst(11, 19, 7));
    var j = s.journey!;
    expect(j.destId, _farDest);
    expect(j.destName, _landmarks[_farDest]!.name);
    expect(j.arrived, isFalse);
    expect(j.totalKm, closeTo(total, 1e-9));
    expect(j.beforeKm, closeTo(0, 1e-9));
    expect(j.endKm, closeTo(1.68, 1e-9));
    expect(j.deltaKm, closeTo(1.68, 1e-9));
    expect(j.remainingKm, closeTo(total - 1.68, 1e-9));
    // 물감 길 안의 걸음만 (앱 밖 12분은 연필)
    expect(s.strokes, [const PaintStroke('basic', 840)]);
    final route = buildRoute(testHome, _landmarks[_farDest]!.latLng, rules);
    expect(s.position!.lat, closeTo(positionAt(route, 1.68).latLng.lat, 1e-9));

    // 다음 날 20분(1.4km) 걷기 → 19일 카드: 1.68 → 3.08km
    e.source.records.add(_walk(_kst(11, 19, 8), 20, 100));
    await e.svc.sync(_kst(11, 19, 9));
    s = await e.svc.cardStory(_d19, _kst(11, 20, 7));
    j = s.journey!;
    expect(j.beforeKm, closeTo(1.68, 1e-9));
    expect(j.endKm, closeTo(3.08, 1e-9));
    expect(s.strokes, isEmpty);
    // 18일 카드를 나중에 다시 봐도 그날 24시까지의 진행 그대로 (노트 다시 보기)
    expect((await e.svc.cardStory(_d18, _kst(11, 20, 7))).journey!.endKm, closeTo(1.68, 1e-9));
  });

  test('쉬어 간 날은 진행이 그대로 (전 = 끝)', () async {
    final e = await _env();
    await e.svc.startJourney(_farDest, _t1, useFund: false);
    e.source.records.add(_walk(_at(0), 12, 100));
    await e.svc.sync(_at(20));
    final j = (await e.svc.cardStory(_d19, _kst(11, 20, 7))).journey!;
    expect(j.beforeKm, closeTo(0.84, 1e-9));
    expect(j.endKm, closeTo(0.84, 1e-9));
    expect(j.deltaKm, 0);
  });

  test('상점 효과는 쓴 날의 진행에 든다 (그날 24시 진행에는 들고, 그날 0시 진행에는 안 든다)', () async {
    final e = await _env();
    await e.svc.startJourney(_farDest, _t0, useFund: false);
    final id = (await e.db.select(e.db.journeys).getSingle()).id;
    e.source.records.add(_walk(_at(0), 12, 100));
    await e.svc.sync(_at(20));
    await e.db.into(e.db.shopUses).insert(ShopUsesCompanion.insert(
        itemId: 'shortcut', day: '2026-11-19', journeyId: id, km: const Value(1.0)));
    final j = (await e.svc.cardStory(_d19, _kst(11, 20, 7))).journey!;
    expect(j.beforeKm, closeTo(0.84, 1e-9));
    expect(j.endKm, closeTo(1.84, 1e-9));
  });

  test('구간 색: 노을 → 기본으로 바꾼 물감 길은 걸은 차례로 두 구간', () async {
    final e = await _env();
    final id = await e.trailWalk(_at(0), 20, 100, _at(25), _at(20));
    await e.db.batch((b) => b.insertAll(e.db.paintTrailColors, [
          PaintTrailColorsCompanion.insert(trailId: id, fromUtc: _ms(_at(0)), colorId: 'autumn.sunset'),
          PaintTrailColorsCompanion.insert(trailId: id, fromUtc: _ms(_at(10)), colorId: 'basic'),
        ]));
    final s = await e.svc.cardStory(_d18, _kst(11, 19, 7));
    expect(s.strokes, [const PaintStroke('autumn.sunset', 700), const PaintStroke('basic', 700)]);
  });

  test('카드 날 안에 도착하면 그 여정: 도착·받은 액자·방문, 끝 진행 = 전체', () async {
    final e = await _env();
    await placeAt(e.db, _nearGyeongbok, _t0);
    await e.svc.startJourney('kr001', _t1, useFund: false);
    e.source.records.add(_walk(_at(5), 30, 100));
    await e.svc.sync(_at(120));
    final journey =
        (await e.db.select(e.db.journeys).get()).singleWhere((r) => r.status == JourneyStatus.arrived);
    expect(journey.status, JourneyStatus.arrived);

    final j = (await e.svc.cardStory(_d18, _kst(11, 19, 7))).journey!;
    expect(j.destId, 'kr001');
    expect(j.arrived, isTrue);
    expect(j.frame, journey.newFrame);
    expect(j.visitNo, 1);
    expect(j.endKm, closeTo(j.totalKm, 1e-9));
    expect(j.beforeKm, 0);
    // 다음 날 카드에는 이 여정이 없다 (끝난 여정)
    expect((await e.svc.cardStory(_d19, _kst(11, 20, 7))).journey, isNull);
  });
}
