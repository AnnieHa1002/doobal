import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../data/step_source.dart';
import '../domain/arrival.dart';
import '../domain/bucket.dart';
import '../domain/eta.dart';
import '../domain/gait.dart';
import '../domain/geo.dart';
import '../domain/guestbook.dart';
import '../domain/journey.dart';
import '../domain/landmark.dart';
import '../domain/prop.dart';
import '../domain/route.dart';
import '../domain/rules.dart';
import '../domain/scene.dart' show nearestLandmark;
import '../domain/session.dart';
import '../domain/sketch.dart';
import '../domain/time_kst.dart';
import '../domain/walk_record.dart';
import '../domain/wall.dart';

/// 한 번 가져온 결과. 출처별 걸음은 허용 목록을 정하는 실기기 확인용
class SyncReport {
  const SyncReport(this.records, this.dropped, this.stepsBySource, {this.advancedKm = 0});

  final int records;

  /// 수동 입력·허용 목록 밖이라 버린 기록 수
  final int dropped;
  final Map<String, int> stepsBySource;

  /// 이번 동기화로 인정된 거리(km). 진행 중 여정이 있었으면 그 진행 거리의 증가,
  /// 없었으면 여행 경비의 증가(상한에서 멈춤). 같은 기록으로 또 돌리면 0
  final double advancedKm;
}

/// 걷기 마치기 직후 걷기 기록 화면의 내용
class WalkRecord {
  const WalkRecord(this.summary, this.sessions, this.countedToday);

  final WalkSummary summary;

  /// 창과 겹치는 저장된 걷기 구간 (걷기 1번 인정 여부 포함)
  final List<WalkSession> sessions;

  /// 오늘(창이 끝나는 시각의 한국 날짜) 인정된 걷기 1번 수. 하루 최대는 rules.sessionMaxPerDay
  final int countedToday;
}

class JourneyView {
  const JourneyView(this.dest, this.totalKm, this.progress, this.eta);

  final Landmark dest;
  final double totalKm;
  final JourneyProgress progress;
  final DateTime eta;
}

/// 도착했는데 도착 화면을 아직 보여 주지 않은 여정 (앱 밖에서 도착했으면 다음 실행 때 먼저 보여 준다)
class PendingArrival {
  const PendingArrival({
    required this.journeyId,
    required this.dest,
    required this.visitNo,
    required this.prevFrame,
    required this.newFrame,
    required this.journeyKm,
    required this.arrivedAt,
  });

  final String journeyId;
  final Landmark dest;

  /// 몇 번째 방문인지. 1이면 새 그림
  final int visitNo;

  /// 도착 전 액자. 첫 방문이면 null
  final Frame? prevFrame;
  final Frame newFrame;

  /// 이 여정의 환산 거리(km). 액자 등급의 기준
  final double journeyKm;
  final DateTime arrivedAt;

  /// 재방문해서 액자가 올랐는가
  bool get frameUp => prevFrame != null && newFrame.index > prevFrame!.index;
}

/// 도착 화면에 보여 줄 값 (여정 하나)
class ArrivalView {
  const ArrivalView({
    required this.journeyId,
    required this.dest,
    required this.visitNo,
    required this.prevFrame,
    required this.newFrame,
    required this.journeyKm,
    required this.arrivedAt,
    required this.daySteps,
    required this.prevBestKm,
    required this.regionProp,
    this.isFirstPack = false,
  });

  final String journeyId;

  /// 도착지. 내 동네 스케치면 가짜 명소(id 'sketch')
  final Landmark dest;

  /// 몇 번째 방문인지. 1이면 새 그림
  final int visitNo;

  /// 도착 전 액자. 첫 방문이면 null
  final Frame? prevFrame;
  final Frame newFrame;

  /// 이 여정의 환산 거리(km)
  final double journeyKm;
  final DateTime arrivedAt;

  /// 도착한 날(한국 날짜)의 걸음. 하루 요약이 없으면 0
  final int daySteps;

  /// 먼저 도착한 여정 중 가장 먼 환산 거리(km). 첫 방문이면 null
  final double? prevBestKm;

  /// 이 도착이 그 권역을 채웠을 때 받는 권역 소품. 아니면 null
  final Prop? regionProp;

  /// 내 동네 스케치에 도착해서 받은 첫 그림(첫 여행 짐 꾸러미)이면 true, 명소면 false.
  /// 첫 그림은 액자 등급·몇 번째 방문·권역 완성이 없다 (newFrame은 늘 나무 액자)
  final bool isFirstPack;

  /// 재방문해서 액자가 올랐는가
  bool get frameUp => prevFrame != null && newFrame.index > prevFrame!.index;
}

/// 화집에서 보는 얻은 그림 하나
class OwnedPaintingView {
  const OwnedPaintingView({
    required this.landmark,
    required this.visits,
    required this.frame,
    required this.bestKm,
    required this.firstArrivedAt,
    required this.lastArrivedAt,
    this.isFirstPack = false,
  });

  /// 첫 그림이면 가짜 명소 [firstPackLandmark] (id 'sketch')
  final Landmark landmark;
  final int visits;

  /// 첫 그림은 늘 나무 액자 (화면의 나무 액자와 같고, 등급 계산에는 쓰지 않는다)
  final Frame frame;

  /// 가장 멀리서 걸어 온 환산 거리(km)
  final double bestKm;
  final DateTime firstArrivedAt;
  final DateTime lastArrivedAt;

  /// 내 동네 스케치에서 받은 첫 그림(첫 여행 짐 꾸러미)이면 true, 명소 그림이면 false
  final bool isFirstPack;
}

/// 그림 상세의 방문 한 줄
class VisitView {
  const VisitView({required this.visitNo, required this.km, required this.arrivedAt});

  final int visitNo;

  /// 그 여정의 환산 거리(km)
  final double km;
  final DateTime arrivedAt;
}

/// 사용자가 고른 출발 동네 (시·군·구 이름과 대표 좌표)
class Home {
  const Home(this.name, this.latLng);

  final String name;
  final LatLng latLng;
}

/// 방명록에 쓸 수 있는 열린 기회 하나 (쓰기 화면·쉼터 표지판)
class GuestbookTicket {
  const GuestbookTicket({
    required this.id,
    required this.kind,
    required this.scope,
    required this.placeName,
    required this.milestone,
    required this.stepsLeft,
    required this.openedAt,
  });

  final String id;
  final TicketKind kind;

  /// 어디서 쓰는 글인지: 명소 id, 첫 여정이면 'sketch', 걸음이면 'steps:<숫자>'
  final String scope;

  /// 도착 기회의 자리 이름: 명소 이름, 첫 여정이면 '내 동네 스케치'. 걸음 기회는 null
  final String? placeName;

  /// 걸음 숫자 기회의 숫자. 도착 기회는 null
  final int? milestone;

  /// 걸음 숫자 기회의 남은 걸음 (1 이상: 0이면 기회가 닫힌 것이라 이 값으로 나오지 않는다).
  /// 도착 기회는 null
  final int? stepsLeft;

  /// 기회가 열린 시각. 알림(M6)이 아직 없어서 기회를 발견한 동기화 시각이다
  final DateTime openedAt;
}

/// 내가 쓴 방명록 글 하나
class GuestbookPostView {
  const GuestbookPostView({
    required this.ticketId,
    required this.scope,
    required this.text,
    required this.createdAt,
    required this.status,
  });

  final String ticketId;

  /// 어디서 쓴 글인지 (기회의 scope)
  final String scope;
  final String text;
  final DateTime createdAt;

  /// 서버 전송 상태. 전송은 M5에서 붙여서 지금은 늘 pending
  final PostStatus status;
}

/// 화면에 보여 줄 지금 상태
class Snapshot {
  const Snapshot({
    required this.today,
    required this.todaySteps,
    required this.todayDistanceM,
    required this.countedSessions,
    required this.fundKm,
    required this.lastFetched,
    required this.journey,
    required this.totalSteps,
    required this.position,
    required this.home,
    required this.onSea,
    required this.pendingArrival,
    required this.unseenProps,
    required this.unseenPaintings,
    required this.paintingsCount,
    required this.totalKm,
    required this.guestbookTicket,
  });

  final String today;
  final int todaySteps;
  final double todayDistanceM;
  final int countedSessions;
  final double fundKm;
  final DateTime? lastFetched;
  final JourneyView? journey;

  /// 설치 이후 모든 하루 걸음의 합 (방명록 걸음 숫자 기준)
  final int totalSteps;

  /// 장면의 현재 위치. 여정 중이면 경로 위 지점, 아니면 가장 나중에 끝난 여정(도착·멈춤)의
  /// 끝 지점, 끝난 여정이 없으면 사용자가 고른 출발 동네.
  /// null은 출발 동네를 아직 안 골랐고 여행한 적도 없을 때뿐이다 (이때 onSea는 false)
  final LatLng? position;

  /// 사용자가 고른 출발 동네. 아직 안 골랐으면 null
  final Home? home;

  /// 배 구간 위인지 (여정 중일 때만 true가 될 수 있다)
  final bool onSea;

  /// 가장 최근에 도착했는데 도착 화면을 아직 안 본 여정
  final PendingArrival? pendingArrival;

  /// 배낭에 새 소품 표시를 띄울 개수 (아직 안 본 소품)
  final int unseenProps;

  /// 배낭에 새 그림 표시를 띄울 개수 (처음 얻고 화집에서 아직 안 본 그림)
  final int unseenPaintings;

  /// 얻은 그림 수
  final int paintingsCount;

  /// 설치 이후 실제로 걸은 거리(km). 하루 거리의 합이라 배 환산이 아니다 (소품 거리 기준)
  final double totalKm;

  /// 쉼터 표지판용 열린 방명록 기회 하나. 도착 기회가 먼저, 그다음 남은 걸음이 적은 걸음 숫자 기회.
  /// 없으면 null (표지판이 서지 않는다).
  /// TODO: 걷는 중 화면의 표지판과 "방명록 쓰기 · 남은 n보" 줄은 이 값으로 붙인다
  /// (lib/ui/walking은 다른 작업이 고치는 중이라 이번에는 안 한다)
  final GuestbookTicket? guestbookTicket;
}

/// 지도 화면에 쓸 값
class MapData {
  const MapData({
    required this.visited,
    required this.paths,
    required this.destId,
    required this.position,
    required this.fundKm,
    this.destPoint,
  });

  /// 그림을 얻은 명소 id → 지금 액자 (내 동네 스케치는 명소가 아니라 넣지 않는다)
  final Map<String, Frame> visited;

  /// 지금까지 지나온 길. 여정마다 한 줄이고, 배 구간은 항구를 거친다
  final List<List<LatLng>> paths;

  /// 진행 중인 여정의 목적지. 여정이 없으면 null (내 동네 스케치면 'sketch')
  final String? destId;

  /// 지금 있는 곳 (Snapshot.position과 같다)
  final LatLng? position;
  final double fundKm;

  /// 진행 중인 여정의 목적지가 명소가 아닌 가상 지점(내 동네 스케치)일 때 그 좌표. 명소 목적지면 null
  final LatLng? destPoint;
}

/// 지금 자리에서 어떤 명소로 가면 얼마나 걸리는지 (지도 카드용 미리 보기)
class JourneyPreview {
  const JourneyPreview(this.totalKm, this.etaDays);

  /// 환산 거리(km)
  final double totalKm;

  /// 오늘(한국 시간)부터 도착 예정일까지 며칠. 최소 1
  final int etaDays;
}

/// 수집 → 저장 → 계산 (M1 명세 6장). 같은 데이터로 여러 번 돌려도 결과가 같다
class SyncService {
  SyncService({
    required this.db,
    required this.source,
    required this.rules,
    required this.allowedSources,
    required this.landmarks,
    required this.props,
    this.milestones = const [],
    this.onLand = _anywhere,
  });

  final AppDb db;
  final StepSource source;
  final Rules rules;
  final List<String> allowedSources;
  final Map<String, Landmark> landmarks;

  /// [p]가 [island]의 땅 위인지 (내 동네 스케치 목적지가 바다에 떨어지지 않게).
  /// 앱은 지도 경계로 판정하는 함수를 넣고, 기본은 어디든 땅이다
  final bool Function(LatLng p, Island island) onLand;

  late final List<Landmark> _landmarkList = landmarks.values.toList();

  /// MVP 소품 (props.json의 mvp)
  final List<Prop> props;

  /// 방명록 걸음 숫자 (milestones.json의 stepMilestones, 오름차순).
  /// 비어 있으면 걸음 숫자 기회가 생기지 않는다
  final List<int> milestones;

  Future<SyncReport> sync(DateTime now) async {
    final state = await _ensureState(now);
    final install = _utc(state.installUtc);
    final last = state.lastFetchedUtc;
    final from = last == null
        ? install
        : _later(_utc(last).subtract(Duration(hours: rules.refetchHours)), install);
    final to = now.toUtc();

    final raw = await source.fetch(from, to);
    final kept = filterRecords(raw, allowedSources);
    final fromMin = epochMinute(from);
    final toMin = epochMinute(to);
    final minutes = toMinutes(kept)
        .where((m) => m.minute >= fromMin && m.minute <= toMin)
        .toList();

    var advancedKm = 0.0;
    await db.transaction(() async {
      final activeBefore = await _activeJourney();
      final before = await _creditedKm(activeBefore);
      await (db.delete(db.stepMinutes)
            ..where((t) => t.minuteUtc.isBetweenValues(fromMin, toMin)))
          .go();
      await db.batch((b) => b.insertAll(db.stepMinutes, [
            for (final m in minutes)
              StepMinutesCompanion.insert(minuteUtc: Value(m.minute), steps: m.steps),
          ]));
      await _recomputeDays(kstDayKey(from), kstDayKey(to));
      await _advanceJourney(to);
      await _unlockProps(to);
      await _updateGuestbookTickets(to);
      await (db.update(db.syncState)..where((t) => t.id.equals(1)))
          .write(SyncStateCompanion(lastFetchedUtc: Value(to.millisecondsSinceEpoch)));
      // 도착한 여정은 더 이상 active가 아니라서 id로 다시 읽는다
      final journeyAfter = activeBefore == null
          ? null
          : await (db.select(db.journeys)..where((t) => t.id.equals(activeBefore.id)))
              .getSingle();
      advancedKm = math.max(0.0, await _creditedKm(journeyAfter) - before);
    });
    return _report(raw, kept, advancedKm: advancedKm);
  }

  /// 저장하지 않고 출처만 본다 (허용 목록을 정할 때)
  Future<SyncReport> inspect(DateTime fromUtc, DateTime toUtc) async {
    final raw = await source.fetch(fromUtc, toUtc);
    return _report(raw, filterRecords(raw, allowedSources));
  }

  /// 그때까지의 거리를 경비로 넣은 뒤, 지금 자리에서 출발한다.
  /// 출발지는 진행 중인 여정이 있으면 그 여정의 지금 지점(그 여정은 멈춘다), 없으면 쉬는 자리.
  /// [useFund]가 true면 여행 경비를 모두 더한다 (더한 만큼 경비는 줄어든다)
  /// 진행 중인 여정도 쉬는 자리도 없으면(출발 동네를 안 골랐고 여행한 적도 없음) StateError를
  /// 던지고 아무것도 바꾸지 않는다 (동기화도 하지 않는다).
  /// 내 동네 스케치 여정 중에 부르면 그 여정은 멈춘다 (스케치는 다시 정하는 길이 없다)
  Future<void> startJourney(String destId, DateTime now, {bool useFund = true}) async {
    if (await _activeJourney() == null && await _restingPosition() == null) {
      throw StateError(_needHome);
    }
    await sync(now);
    final dest = landmarks[destId]!;
    await db.transaction(() async {
      final active = await _activeJourney();
      final origin = active == null ? await _restingPosition() : await _stop(active, now);
      // 위에서 걸렀으니 여기서 null일 수 없다 (동기화로 여정이 도착해도 도착지가 쉬는 자리다)
      if (origin == null) throw StateError(_needHome);
      final route = buildRoute(origin, dest.latLng, rules);
      // 지금 있는 명소로는 출발하지 않는다 (거리 0이라 바로 도착해 방문 수만 오른다). 멈춤도 되돌린다
      if (route.totalEffectiveKm == 0) throw StateError('이미 ${dest.name}에 있어요');
      await _insertJourney(origin, destId, route, now, useFund: useFund);
    });
  }

  /// 첫 여정 '내 동네 스케치'를 정한다: 출발 동네에서 config firstSketchKm 범위 안의 가상 지점으로
  /// 가는 여정. 지점은 설치 번호로 정해져서 같은 설치는 늘 같고, 출발 동네와 같은 섬의 땅으로 고른다.
  /// 여정 기록이 하나라도 있거나 스케치 그림이 이미 있으면, 설치 번호·출발 동네가 아직 없어도
  /// 아무것도 바꾸지 않고 false. 정했으면 true.
  /// 걸음 동기화는 하지 않는다 (경비도 쓰지 않는다. 방금 시작한 앱이라 앞선 걸음이 없다)
  Future<bool> startSketch(DateTime now) => db.transaction(() async {
        final anyJourney = await (db.select(db.journeys)..limit(1)).get();
        if (anyJourney.isNotEmpty || await _ownedRow(sketchId) != null) return false;
        final profile = await _profileRow();
        final installId = profile?.installId;
        final lat = profile?.homeLat;
        final lng = profile?.homeLng;
        if (installId == null || lat == null || lng == null) return false;

        await _ensureState(now);
        final home = LatLng(lat, lng);
        final island = islandOf(home, rules.islands);
        final dest = sketchDestination(
          home: home,
          installId: installId,
          minKm: rules.firstSketchMinKm,
          maxKm: rules.firstSketchMaxKm,
          earthRadiusKm: rules.earthRadiusKm,
          // 같은 섬이어야 배 구간이 끼지 않는다 (경로·섬 판정과 같은 경계 상자로 본다)
          ok: (p) => islandOf(p, rules.islands) == island && onLand(p, island),
        );
        await _insertJourney(home, sketchId, buildRoute(home, dest, rules), now,
            useFund: false, destPoint: dest);
        return true;
      });

  /// 새 여정 행을 넣고 경비를 줄인다 (경비를 쓰면 모두 더한다). [destPoint]는 가상 목적지의 좌표
  Future<void> _insertJourney(
    LatLng origin,
    String destId,
    TravelRoute route,
    DateTime now, {
    required bool useFund,
    LatLng? destPoint,
  }) async {
    final fund = await _fund();
    final used = useFund ? fund.km : 0.0;
    final at = now.toUtc().millisecondsSinceEpoch;
    // 도착 방명록은 다음 여정을 시작하기 전까지만 쓸 수 있다
    await _closeArrivalTickets(at);
    await db.into(db.journeys).insert(JourneysCompanion.insert(
          id: 'j$at',
          originLat: origin.lat,
          originLng: origin.lng,
          destId: destId,
          // 앞 여정을 멈춘 분은 그 여정의 걸음이라 새 여정은 다음 분부터 센다
          startUtc: math.max(at, fund.fundedUntilUtc),
          fundKm: used,
          totalEffectiveKm: route.totalEffectiveKm,
          status: JourneyStatus.active,
          destLat: Value(destPoint?.lat),
          destLng: Value(destPoint?.lng),
        ));
    await (db.update(db.travelFund)..where((t) => t.id.equals(1)))
        .write(TravelFundCompanion(km: Value(fund.km - used)));
  }

  /// 그때까지의 거리를 반영한 뒤, 진행 중인 여정을 지금 지점에서 멈춘다.
  /// 이후 걸음은 여행 경비로 간다. 멈췄으면 true. 진행 중인 여정이 없으면
  /// (그 동기화에서 도착한 경우도) 동기화만 하고 false
  Future<bool> stopJourney(DateTime now) async {
    await sync(now);
    return db.transaction(() async {
      final active = await _activeJourney();
      if (active == null) return false;
      await _stop(active, now);
      return true;
    });
  }

  /// 진행 중인 여정을 멈춘 것으로 닫고 멈춘 지점을 돌려준다. 방금 동기화한 상태여야 한다.
  /// 멈춘 분까지는 이 여정의 걸음(진행 거리에 이미 들어 있다)이라, 경비는 다음 분부터 센다
  Future<LatLng> _stop(JourneyRow active, DateTime now) async {
    final j = _toJourney(active);
    final p = progress(j, await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
    final at = positionAt(j.route, p.progressKm).latLng;
    await (db.update(db.journeys)..where((t) => t.id.equals(active.id))).write(JourneysCompanion(
      status: const Value(JourneyStatus.stopped),
      endLat: Value(at.lat),
      endLng: Value(at.lng),
      endedUtc: Value(now.toUtc().millisecondsSinceEpoch),
    ));
    await (db.update(db.travelFund)..where((t) => t.id.equals(1)))
        .write(TravelFundCompanion(fundedUntilUtc: Value(_nextMinuteMs(now))));
    return at;
  }

  /// 소장한 그림을 더하고 도착 화면에 쓸 값을 여정에 적는다 (도착 화면은 아직 안 보여 줌)
  Future<void> _arrive(JourneyRow active, DateTime to) async {
    final dest = _destOf(active);
    final at = to.toUtc().millisecondsSinceEpoch;
    if (dest.id == sketchId) return _arriveSketch(active, dest, at);
    final owned = await _ownedRow(dest.id);
    final out = paintingAfterArrival(
      owned == null ? null : OwnedPainting(owned.visits, owned.frame, owned.bestKm),
      _toJourney(active).route.totalEffectiveKm,
      rules,
    );
    final p = out.painting;
    // 새 그림 표시는 처음 얻을 때만 켠다. 재방문은 seen을 안 넣어서 충돌 갱신이 건드리지 않는다
    await db.into(db.paintingsOwned).insertOnConflictUpdate(PaintingsOwnedCompanion.insert(
          landmarkId: dest.id,
          visits: p.visits,
          frame: p.frame,
          bestKm: p.bestKm,
          firstArrivedUtc: owned?.firstArrivedUtc ?? at,
          lastArrivedUtc: at,
          seen: owned == null ? const Value(false) : const Value.absent(),
        ));
    await (db.update(db.journeys)..where((t) => t.id.equals(active.id))).write(JourneysCompanion(
      status: const Value(JourneyStatus.arrived),
      arrivedUtc: Value(at),
      endLat: Value(dest.latLng.lat),
      endLng: Value(dest.latLng.lng),
      visitNo: Value(p.visits),
      prevFrame: Value(out.prevFrame),
      newFrame: Value(p.frame),
    ));
    await _openArrivalTicket(active.id, dest.id, at);
  }

  /// 내 동네 스케치에 도착: 고정 그림 '첫 여행 짐 꾸러미'를 소장한다 (visits 1과 도착 시각만 남긴다).
  /// 액자 등급·권역은 건드리지 않는다
  Future<void> _arriveSketch(JourneyRow active, Landmark dest, int at) async {
    await db.into(db.paintingsOwned).insertOnConflictUpdate(PaintingsOwnedCompanion.insert(
          landmarkId: sketchId,
          visits: 1,
          // 액자 열은 필수라 wood를 넣는다. 화면의 나무 액자와 같고 등급 계산에는 쓰지 않는다
          frame: Frame.wood,
          bestKm: active.totalEffectiveKm,
          firstArrivedUtc: at,
          lastArrivedUtc: at,
          seen: const Value(false),
        ));
    await (db.update(db.journeys)..where((t) => t.id.equals(active.id))).write(JourneysCompanion(
      status: const Value(JourneyStatus.arrived),
      arrivedUtc: Value(at),
      endLat: Value(dest.latLng.lat),
      endLng: Value(dest.latLng.lng),
      visitNo: const Value(1),
      newFrame: const Value(Frame.wood),
    ));
    await _openArrivalTicket(active.id, sketchId, at);
  }

  /// 새로 얻은 소품을 더한다 (한 번 얻은 소품은 없어지지 않는다).
  /// 누적 거리·걸음은 하루 요약의 합, 권역은 그림을 얻은 명소로 센다
  Future<void> _unlockProps(DateTime now) async {
    final days = await db.select(db.daySummaries).get();
    final visited = await _visitedLandmarkIds();
    final earned = earnedPropIds(
      props,
      days.fold(0.0, (sum, d) => sum + d.distanceM) / 1000,
      days.fold(0, (sum, d) => sum + d.steps),
      completedRegions(visited, landmarks.values.toList()),
    );
    final owned = {for (final r in await db.select(db.propsOwned).get()) r.propId};
    final initial = {for (final p in props) if (p.kind == PropUnlockKind.initial) p.id};
    final at = now.toUtc().millisecondsSinceEpoch;
    // 기본 소품은 처음부터 가진 것이라 새 소품 표시를 켜지 않는다
    await db.batch((b) => b.insertAll(db.propsOwned, [
          for (final id in earned)
            if (!owned.contains(id))
              PropsOwnedCompanion.insert(
                  propId: id, unlockedUtc: at, seen: Value(initial.contains(id))),
        ]));
  }

  /// 도착한 여정의 방명록 기회를 연다. 열린 시각은 도착을 감지한 시각이다. 이미 있으면 그대로
  Future<void> _openArrivalTicket(String journeyId, String scope, int at) =>
      db.into(db.guestbookTickets).insert(
            GuestbookTicketsCompanion.insert(
              id: arrivalTicketId(journeyId),
              kind: TicketKind.arrival,
              scope: scope,
              openedUtc: at,
            ),
            mode: InsertMode.insertOrIgnore,
          );

  /// 새 여정을 시작하면 쓰지 않은 도착 기회는 닫힌다 (이월은 없다)
  Future<void> _closeArrivalTickets(int at) => (db.update(db.guestbookTickets)
        ..where((t) =>
            t.kind.equalsValue(TicketKind.arrival) & t.usedUtc.isNull() & t.closedUtc.isNull()))
      .write(GuestbookTicketsCompanion(closedUtc: Value(at)));

  Future<void> _closeTicket(String id, int at) => (db.update(db.guestbookTickets)
        ..where((t) => t.id.equals(id)))
      .write(GuestbookTicketsCompanion(closedUtc: Value(at)));

  /// 걸음 숫자 기회를 닫고 연다 (같은 기록으로 또 돌려도 결과가 같다).
  /// 닫기: 열린 뒤 [to]까지 저장된 걸음이 창(guestbook.milestoneWindowSteps) 이상이면 닫는다.
  /// 열기: 설치 이후 걸음(하루 요약의 합)이 넘은 걸음 숫자인데 기회가 없으면 만든다.
  /// 한 번에 여러 개를 넘으면 각각 만든다. 열린 시각은 이번 동기화 시각이다 (알림이 있으면
  /// 알림이 뜬 시각이지만 알림이 꺼진 경우와 같게 본다).
  /// TODO(M6): 알림이 뜬 시각을 열린 시각으로 쓴다
  Future<void> _updateGuestbookTickets(DateTime to) async {
    final at = to.toUtc().millisecondsSinceEpoch;
    final rows = await db.select(db.guestbookTickets).get();
    for (final r in rows) {
      if (r.kind != TicketKind.milestone || r.usedUtc != null || r.closedUtc != null) continue;
      if (stepsLeft(rules.guestbookWindowSteps, await _stepsAfter(r.openedUtc, to)) == 0) {
        await _closeTicket(r.id, at);
      }
    }
    final total = (await db.select(db.daySummaries).get()).fold(0, (sum, d) => sum + d.steps);
    final have = {for (final r in rows) r.id};
    await db.batch((b) => b.insertAll(db.guestbookTickets, [
          for (final m in milestonesReached(total, milestones))
            if (!have.contains(milestoneTicketId(m)))
              GuestbookTicketsCompanion.insert(
                id: milestoneTicketId(m),
                kind: TicketKind.milestone,
                scope: milestoneScope(m),
                openedUtc: at,
              ),
        ]));
  }

  /// [openedUtc] 다음 분부터 [upTo]가 속한 분까지 저장된 걸음의 합 (기회가 열린 분은 세지 않는다.
  /// 그 분의 걸음이 열리기 전인지 뒤인지 알 수 없어서 경비처럼 다음 분부터 센다)
  Future<int> _stepsAfter(int openedUtc, DateTime upTo) async {
    final minutes =
        await _minutesFrom(_minuteOf(openedUtc) + 1, beforeMinute: epochMinute(upTo) + 1);
    return minutes.fold<int>(0, (sum, m) => sum + m.steps);
  }

  Future<GuestbookTicketRow?> _ticketRow(String id) =>
      (db.select(db.guestbookTickets)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 열린 기회의 화면용 값. 이미 썼거나 닫혔거나, 걸음 숫자 기회의 남은 걸음이 0이면 null
  Future<GuestbookTicket?> _ticketOf(GuestbookTicketRow r, DateTime now) async {
    if (r.usedUtc != null || r.closedUtc != null) return null;
    final opened = _utc(r.openedUtc);
    if (r.kind == TicketKind.arrival) {
      return GuestbookTicket(
        id: r.id,
        kind: r.kind,
        scope: r.scope,
        placeName: r.scope == sketchId ? sketchName : landmarks[r.scope]?.name ?? r.scope,
        milestone: null,
        stepsLeft: null,
        openedAt: opened,
      );
    }
    final milestone = milestoneOfScope(r.scope);
    if (milestone == null) return null;
    final left = stepsLeft(rules.guestbookWindowSteps, await _stepsAfter(r.openedUtc, now));
    if (left == 0) return null;
    return GuestbookTicket(
      id: r.id,
      kind: r.kind,
      scope: r.scope,
      placeName: null,
      milestone: milestone,
      stepsLeft: left,
      openedAt: opened,
    );
  }

  /// 도착 화면을 보여 줬다고 적는다
  Future<void> markArrivalShown(String journeyId) =>
      (db.update(db.journeys)..where((t) => t.id.equals(journeyId)))
          .write(const JourneysCompanion(arrivalShown: Value(true)));

  /// 도착 화면에 쓸 값. 도착한 여정이 아니면 StateError.
  /// 날짜는 한국 날짜, 지난번 거리는 재방문(2번째부터)일 때만, 권역 소품은 첫 방문이 권역을 채웠을 때만
  Future<ArrivalView> arrivalView(String journeyId) async {
    final row = await (db.select(db.journeys)..where((t) => t.id.equals(journeyId)))
        .getSingleOrNull();
    if (row == null ||
        row.status != JourneyStatus.arrived ||
        row.arrivedUtc == null ||
        row.visitNo == null ||
        row.newFrame == null) {
      throw StateError('도착한 여정이 아니에요: $journeyId');
    }
    final dest = _destOf(row);
    final arrivedAt = _utc(row.arrivedUtc!);
    final visitNo = row.visitNo!;

    final day = await (db.select(db.daySummaries)
          ..where((t) => t.day.equals(kstDayKey(arrivedAt))))
        .getSingleOrNull();
    if (dest.id == sketchId) {
      if (await _ownedRow(sketchId) == null) throw StateError('첫 그림이 없어요: $journeyId');
      return ArrivalView(
        journeyId: row.id,
        dest: dest,
        visitNo: visitNo,
        prevFrame: null,
        newFrame: row.newFrame!,
        journeyKm: row.totalEffectiveKm,
        arrivedAt: arrivedAt,
        daySteps: day?.steps ?? 0,
        prevBestKm: null,
        regionProp: null,
        isFirstPack: true,
      );
    }
    // 그때까지 얻은 그림만 본다 (이 도착 뒤에 채운 권역을 이 도착의 일로 치지 않게)
    final visited = await _visitedLandmarkIds(until: row.arrivedUtc!);

    double? prevBestKm;
    if (visitNo > 1) {
      final trips = [
        for (final r in await _arrivedTo(dest.id))
          ArrivedTrip(_utc(r.arrivedUtc!), r.totalEffectiveKm),
      ];
      prevBestKm = previousBestKm(trips, arrivedAt);
    }

    return ArrivalView(
      journeyId: row.id,
      dest: dest,
      visitNo: visitNo,
      prevFrame: row.prevFrame,
      newFrame: row.newFrame!,
      journeyKm: row.totalEffectiveKm,
      arrivedAt: arrivedAt,
      daySteps: day?.steps ?? 0,
      prevBestKm: prevBestKm,
      regionProp: regionPropOnArrival(
        visitNo: visitNo,
        region: dest.region,
        visitedIds: visited,
        landmarks: landmarks.values.toList(),
        props: props,
      ),
    );
  }

  /// [landmarkId]에 도착한 여정을 도착 순서대로 (같은 시각이면 id 순)
  Future<List<JourneyRow>> _arrivedTo(String landmarkId) => (db.select(db.journeys)
        ..where((t) =>
            t.status.equalsValue(JourneyStatus.arrived) &
            t.destId.equals(landmarkId) &
            t.arrivedUtc.isNotNull())
        ..orderBy([
          (t) => OrderingTerm(expression: t.arrivedUtc),
          (t) => OrderingTerm(expression: t.id),
        ]))
      .get();

  /// 화집 벽: 늘 [wallSlots]칸. 안 건 칸은 null
  Future<List<String?>> wall() async => wallFromSlots({
        for (final r in await db.select(db.wallSlots).get()) r.slot: r.landmarkId,
      });

  /// [slot]에 얻은 그림 [landmarkId]를 건다. 같은 그림이 다른 칸에 있으면 그 칸은 비운다.
  /// 칸 번호가 범위 밖이면 RangeError, 얻지 않은 그림이면 StateError
  Future<void> setWall(int slot, String landmarkId) => db.transaction(() async {
        await _requireOwned(landmarkId);
        await _saveWall(placeOnWall(await wall(), slot, landmarkId));
      });

  /// 벽의 첫 빈 칸에 건다 (이미 걸려 있으면 그대로 두고 그 칸). 걸린 칸을 돌려주고,
  /// 벽이 가득 찼으면 null (아무것도 바꾸지 않는다)
  Future<int?> hangOnWall(String landmarkId) => db.transaction(() async {
        await _requireOwned(landmarkId);
        final current = await wall();
        final slot = slotToHang(current, landmarkId);
        if (slot == null) return null;
        await _saveWall(placeOnWall(current, slot, landmarkId));
        return slot;
      });

  Future<void> _requireOwned(String landmarkId) async {
    final owned = await (db.select(db.paintingsOwned)
          ..where((t) => t.landmarkId.equals(landmarkId)))
        .getSingleOrNull();
    if (owned == null) throw StateError('얻지 않은 그림이에요: $landmarkId');
  }

  Future<void> _saveWall(List<String?> wall) async {
    await db.delete(db.wallSlots).go();
    await db.batch((b) => b.insertAll(db.wallSlots, [
          for (var i = 0; i < wall.length; i++)
            if (wall[i] != null) WallSlotsCompanion.insert(slot: Value(i), landmarkId: wall[i]!),
        ]));
  }

  /// 얻은 그림 전부. 처음 얻은 순서 (같으면 명소 id 순)
  Future<List<OwnedPaintingView>> paintings() async {
    final rows = await (db.select(db.paintingsOwned)
          ..orderBy([
            (t) => OrderingTerm(expression: t.firstArrivedUtc),
            (t) => OrderingTerm(expression: t.landmarkId),
          ]))
        .get();
    return [for (final r in rows) ?_paintingOf(r)];
  }

  /// 그림 한 행을 화집에서 보는 값으로. 'sketch' 행은 첫 그림이라 가짜 명소 [firstPackLandmark]를 붙이고,
  /// 명소 목록에 없는 그림(옛 데이터)은 null
  OwnedPaintingView? _paintingOf(PaintingOwnedRow r) {
    final isFirstPack = r.landmarkId == sketchId;
    final landmark = isFirstPack ? firstPackLandmark : landmarks[r.landmarkId];
    if (landmark == null) return null;
    return OwnedPaintingView(
      landmark: landmark,
      visits: r.visits,
      frame: r.frame,
      bestKm: r.bestKm,
      firstArrivedAt: _utc(r.firstArrivedUtc),
      lastArrivedAt: _utc(r.lastArrivedUtc),
      isFirstPack: isFirstPack,
    );
  }

  /// 그 명소에 도착한 기록을 도착 순서대로. 몇 번째인지는 도착할 때 적어 둔 값
  /// (옛 기록처럼 없으면 순서)
  Future<List<VisitView>> visits(String landmarkId) async {
    final rows = await _arrivedTo(landmarkId);
    return [
      for (var i = 0; i < rows.length; i++)
        VisitView(
          visitNo: rows[i].visitNo ?? i + 1,
          km: rows[i].totalEffectiveKm,
          arrivedAt: _utc(rows[i].arrivedUtc!),
        ),
    ];
  }

  /// 얻은 소품 id (소품 탭)
  Future<Set<String>> ownedPropIds() async =>
      {for (final r in await db.select(db.propsOwned).get()) r.propId};

  /// 배낭의 새 소품 표시를 지운다
  Future<void> markPropsSeen() => (db.update(db.propsOwned)..where((t) => t.seen.equals(false)))
      .write(const PropsOwnedCompanion(seen: Value(true)));

  /// 아직 안 본 그림의 명소 id (화집 그림 탭의 새 그림 칸)
  Future<List<String>> unseenPaintingIds() async => [
        for (final r in await (db.select(db.paintingsOwned)..where((t) => t.seen.equals(false)))
            .get())
          r.landmarkId,
      ];

  /// 배낭의 새 그림 표시를 지운다
  Future<void> markPaintingsSeen() =>
      (db.update(db.paintingsOwned)..where((t) => t.seen.equals(false)))
          .write(const PaintingsOwnedCompanion(seen: Value(true)));

  /// 지금 쓸 수 있는 방명록 기회. 도착 기회가 먼저(나중에 도착한 것부터), 그다음 걸음 숫자 기회를
  /// 남은 걸음이 적은 순서로. 남은 걸음은 기회가 열린 뒤 [now]까지 저장된 걸음으로 센다
  /// (동기화는 하지 않는다. 부른 쪽이 먼저 sync 한다)
  Future<List<GuestbookTicket>> openTickets(DateTime now) async {
    final rows = await (db.select(db.guestbookTickets)
          ..where((t) => t.usedUtc.isNull() & t.closedUtc.isNull()))
        .get();
    final tickets = [for (final r in rows) ?await _ticketOf(r, now)];
    tickets.sort((a, b) {
      if (a.kind != b.kind) return a.kind == TicketKind.arrival ? -1 : 1;
      if (a.kind == TicketKind.arrival) return b.openedAt.compareTo(a.openedAt);
      final byLeft = a.stepsLeft!.compareTo(b.stepsLeft!);
      return byLeft != 0 ? byLeft : a.milestone!.compareTo(b.milestone!);
    });
    return tickets;
  }

  /// 기회 하나. 없거나 이미 썼거나 닫혔으면 null (쓰기 화면과 도착 화면 버튼이 읽는다)
  Future<GuestbookTicket?> guestbookTicket(String ticketId, DateTime now) async {
    final row = await _ticketRow(ticketId);
    return row == null ? null : _ticketOf(row, now);
  }

  /// 방명록 글을 쓴다: 글을 저장하고 기회를 쓴 것으로 바꾸고, 처음이면 동의 시각
  /// (Profile.guestbookConsentAt)을 적는다. 서버 전송은 M5에서 붙여서 글은 pending으로 남는다.
  /// StateError(메시지는 화면에 그대로 보여 줄 수 있다)를 던지고 아무것도 쓰지 않는 경우:
  /// 기회가 없다 · 이미 썼다 · 닫혔다 · 글이 비었거나 길다.
  /// 걸음 숫자 기회는 동기화가 닫기 전이라도 열린 뒤 [now]까지 저장된 걸음이 창을 채웠으면
  /// 닫힌 것으로 본다 (이때는 닫힘 시각만 적어 둔다).
  /// TODO(M5): 올리기 전에 금칙어를 검사한다 (config/moderation, korean_profanity_filter)
  Future<void> writeGuestbook(String ticketId, String text, DateTime now) async {
    final error = await db.transaction<String?>(() async {
      final row = await _ticketRow(ticketId);
      if (row == null) return '방명록을 남길 수 있는 때가 아니에요';
      if (row.usedUtc != null) return '이미 방명록을 남겼어요';
      final at = now.toUtc().millisecondsSinceEpoch;
      if (row.closedUtc != null || await _ticketOf(row, now) == null) {
        if (row.closedUtc == null) await _closeTicket(row.id, at);
        return '방명록을 남길 수 있는 때가 지났어요';
      }
      final body = cleanPost(text, rules.guestbookMaxChars);
      if (body == null) {
        return text.trim().isEmpty ? '글을 써 주세요' : '${rules.guestbookMaxChars}자까지 쓸 수 있어요';
      }
      await db.into(db.guestbookPosts).insert(GuestbookPostsCompanion.insert(
            ticketId: row.id,
            scope: row.scope,
            body: body,
            createdUtc: at,
            status: PostStatus.pending,
          ));
      await (db.update(db.guestbookTickets)..where((t) => t.id.equals(row.id)))
          .write(GuestbookTicketsCompanion(usedUtc: Value(at)));
      if (!await guestbookConsented()) {
        await db.into(db.profile).insertOnConflictUpdate(
            ProfileCompanion(id: const Value(1), guestbookConsentAt: Value(at)));
      }
      return null;
    });
    if (error != null) throw StateError(error);
  }

  /// 방명록 동의를 이미 했는가 (처음 쓸 때만 동의 줄을 보여 준다)
  Future<bool> guestbookConsented() async => (await _profileRow())?.guestbookConsentAt != null;

  /// 내가 쓴 방명록 글, 최근에 쓴 순서
  Future<List<GuestbookPostView>> myPosts() async {
    final rows = await (db.select(db.guestbookPosts)
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdUtc),
            (t) => OrderingTerm.desc(t.ticketId),
          ]))
        .get();
    return [
      for (final r in rows)
        GuestbookPostView(
          ticketId: r.ticketId,
          scope: r.scope,
          text: r.body,
          createdAt: _utc(r.createdUtc),
          status: r.status,
        ),
    ];
  }

  /// 걷기 기록: [fromUtc, toUtc)와 겹치는 분의 걸음·거리·걷기/달리기와 걷기 1번 인정 여부.
  /// 동기화는 하지 않는다. 부른 쪽이 먼저 sync 한다.
  /// 하루 계산(_recomputeDays)처럼 전날 0시부터 불러 걷기/뛰기 상태를 이어 판정한다
  Future<WalkRecord> walkRecord(DateTime fromUtc, DateTime toUtc) async {
    final fromMin = epochMinute(fromUtc);
    // 끝 시각이 걸친 분도 포함 (올림)
    final toMin = (toUtc.millisecondsSinceEpoch + Duration.millisecondsPerMinute - 1) ~/
        Duration.millisecondsPerMinute;
    final minutes = await _minutesFrom(
      epochMinute(kstDayStartUtc(addDays(kstDayKey(fromUtc), -1))),
      beforeMinute: toMin,
    );
    final summary = summarizeWalk(classifyGait(minutes, rules), fromMin, toMin, rules);

    final fromMs = fromMin * Duration.millisecondsPerMinute;
    final toMs = toMin * Duration.millisecondsPerMinute;
    final rows = await (db.select(db.walkSessions)
          ..where((t) => t.startUtc.isSmallerThanValue(toMs) & t.endUtc.isBiggerThanValue(fromMs))
          ..orderBy([(t) => OrderingTerm(expression: t.startUtc)]))
        .get();
    final today = await (db.select(db.daySummaries)
          ..where((t) => t.day.equals(kstDayKey(toUtc))))
        .getSingleOrNull();

    return WalkRecord(summary, [for (final r in rows) _sessionOf(r)], today?.countedSessions ?? 0);
  }

  Future<Snapshot> snapshot(DateTime now) async {
    final state = await _ensureState(now);
    final today = kstDayKey(now);
    final day = await (db.select(db.daySummaries)..where((t) => t.day.equals(today)))
        .getSingleOrNull();
    final fund = await _fund();

    final days = await db.select(db.daySummaries).get();
    final active = await _activeJourney();
    final here = await _whereNow(active);
    JourneyView? view;
    if (active != null) {
      final p = here.progress!;
      final eta = _etaOf(p.remainingKm, days, today, state);
      view = JourneyView(_destOf(active), here.journey!.route.totalEffectiveKm, p, eta);
    }

    return Snapshot(
      today: today,
      todaySteps: day?.steps ?? 0,
      todayDistanceM: day?.distanceM ?? 0,
      countedSessions: day?.countedSessions ?? 0,
      fundKm: fund.km,
      lastFetched: state.lastFetchedUtc == null ? null : _utc(state.lastFetchedUtc!),
      journey: view,
      totalSteps: days.fold(0, (sum, d) => sum + d.steps),
      position: here.position,
      home: await home(),
      onSea: here.onSea,
      pendingArrival: await _pendingArrival(),
      unseenProps: (await (db.select(db.propsOwned)..where((t) => t.seen.equals(false))).get())
          .length,
      unseenPaintings:
          (await (db.select(db.paintingsOwned)..where((t) => t.seen.equals(false))).get()).length,
      paintingsCount: (await db.select(db.paintingsOwned).get()).length,
      totalKm: days.fold(0.0, (sum, d) => sum + d.distanceM) / 1000,
      guestbookTicket: (await openTickets(now)).firstOrNull,
    );
  }

  /// 지도 화면용: 다녀온 명소와 액자, 지나온 길, 목적지, 지금 위치, 여행 경비.
  /// 길은 여정을 시작 순서대로 출발지 → 끝 지점이고, 끝 지점은 멈춘 지점·도착한 명소
  /// (끝이 안 적힌 옛 도착 여정은 목적지 명소)·진행 중 여정의 지금 위치다.
  /// 배 구간이 항구를 거치도록 buildRoute로 펴고, 길이가 0인 여정은 뺀다
  Future<MapData> mapData(DateTime now) async {
    await _ensureState(now);
    final active = await _activeJourney();
    final here = await _whereNow(active);
    final rows = await (db.select(db.journeys)
          ..orderBy([
            (t) => OrderingTerm(expression: t.startUtc),
            (t) => OrderingTerm(expression: t.id),
          ]))
        .get();

    final paths = <List<LatLng>>[];
    for (final r in rows) {
      // 진행 중인 여정은 자기 경로를 지금 지점에서 자른다 (배 위에 있어도 항구를 거친다)
      if (r.status == JourneyStatus.active) {
        final route = here.journey!.route;
        final at = positionAt(route, here.progress!.progressKm);
        final path = [route.start, for (final l in route.legs.take(at.legIndex)) l.to, at.latLng];
        if (here.progress!.progressKm > 0) paths.add(path);
        continue;
      }
      final LatLng? end;
      if (r.endLat != null && r.endLng != null) {
        end = LatLng(r.endLat!, r.endLng!);
      } else if (r.status == JourneyStatus.arrived) {
        end = _destOf(r).latLng;
      } else {
        end = null;
      }
      if (end == null) continue;
      final route = buildRoute(LatLng(r.originLat, r.originLng), end, rules);
      if (route.legs.isEmpty) continue;
      paths.add([route.start, for (final l in route.legs) l.to]);
    }

    return MapData(
      visited: {
        for (final p in await db.select(db.paintingsOwned).get())
          if (p.landmarkId != sketchId) p.landmarkId: p.frame,
      },
      paths: paths,
      destId: active?.destId,
      position: here.position,
      fundKm: (await _fund()).km,
      destPoint: active?.destId == sketchId ? _destOf(active!).latLng : null,
    );
  }

  /// [destId]로 지금 자리에서 가면 환산 거리와 며칠 걸리는지. 동기화·저장은 하지 않는다.
  /// 출발지는 진행 중인 여정의 지금 지점, 없으면 쉬는 자리. 둘 다 없으면 StateError(startJourney와 같다)
  Future<JourneyPreview> preview(String destId, DateTime now) async {
    final state = await _ensureState(now);
    final from = (await _whereNow(await _activeJourney())).position;
    if (from == null) throw StateError(_needHome);
    final totalKm = buildRoute(from, landmarks[destId]!.latLng, rules).totalEffectiveKm;
    final today = kstDayKey(now);
    final eta = _etaOf(totalKm, await db.select(db.daySummaries).get(), today, state);
    return JourneyPreview(totalKm, math.max(1, eta.difference(dayFromKey(today)).inDays));
  }

  Future<PendingArrival?> _pendingArrival() async {
    final row = await (db.select(db.journeys)
          ..where((t) =>
              t.status.equalsValue(JourneyStatus.arrived) &
              t.arrivalShown.equals(false) &
              t.visitNo.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.arrivedUtc)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return PendingArrival(
      journeyId: row.id,
      dest: _destOf(row),
      visitNo: row.visitNo!,
      prevFrame: row.prevFrame,
      newFrame: row.newFrame!,
      journeyKm: row.totalEffectiveKm,
      arrivedAt: _utc(row.arrivedUtc!),
    );
  }

  /// 사용자가 고른 출발 동네를 적는다 (이미 있으면 바꾼다). 이름은 시·군·구,
  /// 좌표는 그 행정구역의 대표 좌표. 이미 여행을 한 뒤에는 쉬는 자리에 영향이 없다
  Future<void> setHome(String name, LatLng latLng) =>
      db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
        id: const Value(1),
        homeName: Value(name),
        homeLat: Value(latLng.lat),
        homeLng: Value(latLng.lng),
      ));

  /// 사용자가 고른 출발 동네. 아직 안 골랐으면 null
  Future<Home?> home() async {
    final row = await _profileRow();
    if (row == null || row.homeName == null || row.homeLat == null || row.homeLng == null) {
      return null;
    }
    return Home(row.homeName!, LatLng(row.homeLat!, row.homeLng!));
  }

  /// 지금 있는 곳. 진행 중인 여정이 있으면 그 여정·진행·경로 위 지점·배 구간 여부,
  /// 없으면 쉬는 자리 (여정과 진행은 null)
  Future<_Here> _whereNow(JourneyRow? active) async {
    if (active == null) {
      return (journey: null, progress: null, position: await _restingPosition(), onSea: false);
    }
    final j = _toJourney(active);
    final p = progress(j, await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
    final at = positionAt(j.route, p.progressKm);
    return (journey: j, progress: p, position: at.latLng, onSea: at.onSea);
  }

  /// 남은 거리 [remainingKm]를 가는 도착 예정일 (하루 평균은 하루 요약에서)
  DateTime _etaOf(
    double remainingKm,
    List<DaySummaryRow> days,
    String today,
    SyncStateRow state,
  ) =>
      etaDate(remainingKm, {for (final d in days) d.day: d.distanceM / 1000}, today,
          state.firstRecordDay, rules);

  /// 여정이 없을 때 장면의 위치: 가장 나중에 끝난 여정(도착·멈춤)의 끝 지점, 없으면 출발 동네,
  /// 그것도 없으면 null. 끝 지점이 안 적힌 옛 도착 여정은 목적지 명소로 본다
  Future<LatLng?> _restingPosition() async {
    final row = await (db.select(db.journeys)
          ..where((t) =>
              t.endLat.isNotNull() | t.status.equalsValue(JourneyStatus.arrived))
          ..orderBy([
            (t) => OrderingTerm.desc(coalesce([t.arrivedUtc, t.endedUtc])),
            (t) => OrderingTerm.desc(t.startUtc),
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return (await home())?.latLng;
    return row.endLat == null ? _destOf(row).latLng : LatLng(row.endLat!, row.endLng!);
  }

  Future<SyncStateRow> _ensureState(DateTime now) async {
    final at = now.toUtc().millisecondsSinceEpoch;
    await db.into(db.syncState).insert(
          SyncStateCompanion.insert(
            id: const Value(1),
            firstRecordDay: kstDayKey(now),
            installUtc: at,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.travelFund).insert(
          TravelFundCompanion.insert(id: const Value(1), km: 0, fundedUntilUtc: at),
          mode: InsertMode.insertOrIgnore,
        );
    return (db.select(db.syncState)..where((t) => t.id.equals(1))).getSingle();
  }

  /// 영향받은 날의 하루 요약·걷기 1번을 다시 계산한다.
  /// 전날 0시부터 불러서 자정을 넘는 구간과 직전 걷기/뛰기 상태를 이어 본다
  Future<void> _recomputeDays(String firstDay, String lastDay) async {
    final days = <String>[];
    for (var d = firstDay; d.compareTo(lastDay) <= 0; d = addDays(d, 1)) {
      days.add(d);
    }
    final minutes =
        await _minutesFrom(epochMinute(kstDayStartUtc(addDays(firstDay, -1))));
    final gaits = classifyGait(minutes, rules);
    final sessions = detectSessions(minutes, rules)
        .where((s) => days.contains(kstDayKey(s.start)))
        .toList();

    final steps = {for (final d in days) d: 0};
    final dist = {for (final d in days) d: 0.0};
    for (final g in gaits) {
      final d = kstDayKey(StepMinute(g.minute, 0).startUtc);
      if (!steps.containsKey(d)) continue;
      steps[d] = steps[d]! + g.steps;
      dist[d] = dist[d]! + distanceM([g], rules);
    }

    final rangeFrom = kstDayStartUtc(firstDay).millisecondsSinceEpoch;
    final rangeTo = kstDayStartUtc(addDays(lastDay, 1)).millisecondsSinceEpoch;
    await (db.delete(db.walkSessions)
          ..where((t) =>
              t.startUtc.isBiggerOrEqualValue(rangeFrom) &
              t.startUtc.isSmallerThanValue(rangeTo)))
        .go();
    await db.batch((b) {
      for (final d in days) {
        b.insert(
          db.daySummaries,
          DaySummariesCompanion.insert(
            day: d,
            steps: steps[d]!,
            distanceM: dist[d]!,
            countedSessions: sessions.where((s) => s.counted && kstDayKey(s.start) == d).length,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      b.insertAll(db.walkSessions, [
        for (final s in sessions)
          WalkSessionsCompanion.insert(
            startUtc: Value(s.start.millisecondsSinceEpoch),
            endUtc: s.end.millisecondsSinceEpoch,
            steps: s.steps,
            distanceM: s.distanceM,
            runRatio: s.runRatio,
            qualified: s.qualified,
            counted: s.counted,
          ),
      ]);
    });
  }

  /// 여정이 있으면 진행·도착을 계산하고 넘친 거리를 경비로, 없으면 그동안 걸은 거리를 경비로 (상한 있음)
  Future<void> _advanceJourney(DateTime to) async {
    final fund = await _fund();
    final toMin = epochMinute(to);
    var km = fund.km;
    var fundedUntil = to.millisecondsSinceEpoch;

    final active = await _activeJourney();
    if (active != null) {
      final p = progress(_toJourney(active),
          await _distanceKmFrom(_minuteOf(active.startUtc)), rules);
      if (p.arrived) {
        await _arrive(active, to);
        km = addToFund(km, p.overflowKm, rules);
        // 도착한 분까지는 여정의 걸음(넘친 거리에 들어 있다)이라 경비는 다음 분부터
        fundedUntil = _nextMinuteMs(to);
      }
    } else {
      // 다 끝난 분만 센다. 지금 분은 다음 동기화 때 들어간다
      km = addToFund(
          km, await _distanceKmFrom(_minuteOf(fund.fundedUntilUtc), beforeMinute: toMin), rules);
    }
    // 멈춤으로 앞서 둔 다음 분 경계는 되돌리지 않는다 (같은 분 안에서 또 동기화해도 두 번 세지 않게)
    await (db.update(db.travelFund)..where((t) => t.id.equals(1))).write(TravelFundCompanion(
        km: Value(km), fundedUntilUtc: Value(math.max(fundedUntil, fund.fundedUntilUtc))));
  }

  Future<List<StepMinute>> _minutesFrom(int fromMinute, {int? beforeMinute}) async {
    final q = db.select(db.stepMinutes)
      ..where((t) => t.minuteUtc.isBiggerOrEqualValue(fromMinute))
      ..orderBy([(t) => OrderingTerm(expression: t.minuteUtc)]);
    if (beforeMinute != null) q.where((t) => t.minuteUtc.isSmallerThanValue(beforeMinute));
    return [for (final r in await q.get()) StepMinute(r.minuteUtc, r.steps)];
  }

  Future<double> _distanceKmFrom(int fromMinute, {int? beforeMinute}) async {
    final minutes = await _minutesFrom(fromMinute, beforeMinute: beforeMinute);
    return distanceM(classifyGait(minutes, rules), rules) / 1000;
  }

  /// 동기화 전후로 비교하는 값: 여정이 있으면 그 진행 거리(도착 뒤에도 넘친 만큼 포함),
  /// 없으면 여행 경비. 여정이 있는 동안 경비는 도착할 때 넘친 거리만 늘고 그건 진행 거리에
  /// 이미 들어 있으니, 둘을 더하면 두 번 세게 된다
  Future<double> _creditedKm(JourneyRow? journey) async {
    if (journey == null) return (await _fund()).km;
    final walked = await _distanceKmFrom(_minuteOf(journey.startUtc));
    return progress(_toJourney(journey), walked, rules).progressKm;
  }

  Future<TravelFundRow> _fund() =>
      (db.select(db.travelFund)..where((t) => t.id.equals(1))).getSingle();

  Future<JourneyRow?> _activeJourney() => (db.select(db.journeys)
        ..where((t) => t.status.equalsValue(JourneyStatus.active)))
      .getSingleOrNull();

  Journey _toJourney(JourneyRow r) {
    final origin = LatLng(r.originLat, r.originLng);
    return Journey(
      id: r.id,
      origin: origin,
      destId: r.destId,
      startAt: _utc(r.startUtc),
      fundKm: r.fundKm,
      route: buildRoute(origin, _destOf(r).latLng, rules),
    );
  }

  /// 여정의 목적지. 명소 id면 그 명소, 'sketch'면 저장한 가상 좌표와 가장 가까운 명소로 만든 가짜 명소
  Landmark _destOf(JourneyRow r) => r.destId == sketchId
      ? _sketchLandmarkAt(LatLng(r.destLat!, r.destLng!))
      : landmarks[r.destId]!;

  Landmark _sketchLandmarkAt(LatLng p) =>
      sketchLandmark(p, nearestLandmark(p, _landmarkList, rules.earthRadiusKm));

  Future<PaintingOwnedRow?> _ownedRow(String landmarkId) => (db.select(db.paintingsOwned)
        ..where((t) => t.landmarkId.equals(landmarkId)))
      .getSingleOrNull();

  /// 그림을 얻은 명소 id (내 동네 스케치는 명소가 아니라 뺀다). [until]이 있으면 그 시각(epoch ms)까지 얻은 것만
  Future<Set<String>> _visitedLandmarkIds({int? until}) async => {
        for (final r in await db.select(db.paintingsOwned).get())
          if (r.landmarkId != sketchId && (until == null || r.firstArrivedUtc <= until))
            r.landmarkId,
      };

  Future<ProfileRow?> _profileRow() =>
      (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();

  WalkSession _sessionOf(WalkSessionRow r) => WalkSession(
        start: _utc(r.startUtc),
        end: _utc(r.endUtc),
        steps: r.steps,
        distanceM: r.distanceM,
        runRatio: r.runRatio,
        qualified: r.qualified,
        counted: r.counted,
      );

  SyncReport _report(List<StepRecord> raw, List<StepRecord> kept, {double advancedKm = 0}) {
    final bySource = <String, int>{};
    for (final r in raw) {
      bySource[r.sourceId] = (bySource[r.sourceId] ?? 0) + r.steps;
    }
    return SyncReport(raw.length, raw.length - kept.length, bySource, advancedKm: advancedKm);
  }
}

const _needHome = '출발 동네를 먼저 골라 주세요';

bool _anywhere(LatLng p, Island island) => true;

typedef _Here = ({Journey? journey, JourneyProgress? progress, LatLng? position, bool onSea});

DateTime _utc(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

int _minuteOf(int ms) => ms ~/ Duration.millisecondsPerMinute;

/// [t]가 속한 분의 다음 분 시작 (epoch ms)
int _nextMinuteMs(DateTime t) => (epochMinute(t) + 1) * Duration.millisecondsPerMinute;

DateTime _later(DateTime a, DateTime b) =>
    _utc(math.max(a.millisecondsSinceEpoch, b.millisecondsSinceEpoch));
