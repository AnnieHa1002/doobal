import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/config_loader.dart';
import '../data/db/app_db.dart';
import '../data/landmark_loader.dart';
import '../data/map_loader.dart';
import '../data/milestone_loader.dart';
import '../data/prop_loader.dart';
import '../data/step_source.dart';
import '../data/theme_loader.dart';
import '../domain/camp_theme.dart';
import '../domain/landmark.dart';
import '../domain/map_projection.dart';
import '../domain/map_regions.dart';
import '../domain/prop.dart';
import '../domain/rules.dart';
import 'sync_service.dart';

final rulesProvider = FutureProvider<Rules>((ref) => loadRules());

final landmarksProvider = FutureProvider<List<Landmark>>((ref) => loadLandmarks());

/// 소품 MVP 27개 (props.json)
final propsProvider = FutureProvider<List<Prop>>((ref) => loadProps());

/// 방명록 걸음 숫자 (milestones.json)
final milestonesProvider = FutureProvider<List<int>>((ref) => loadMilestones());

/// 쉼터 테마 (themes/camp.json)
final campThemeProvider = FutureProvider<CampTheme>((ref) => loadCampTheme());

/// 지도 위경도 → 캔버스 px (assets/map/ui_map_projection_v01.json)
final mapProjectionProvider = FutureProvider<MapProjection>((ref) => loadMapProjection());

/// 지도 시도 경계 (assets/map/ui_map_regions_v01.svg)
final mapRegionsProvider = FutureProvider<List<MapRegion>>((ref) => loadMapRegions());

/// 지금 시각(UTC). 화면과 서비스는 DateTime.now()를 직접 부르지 않고 이걸 쓴다. 테스트에서 바꾼다
final clockProvider = Provider<DateTime Function()>((ref) => () => DateTime.now().toUtc());

/// 1분마다 새로 나오는 지금 시각. 쉼터처럼 가만히 있는 화면의 하늘이 시간을 따라가게 한다
final minuteClockProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream<DateTime>.periodic(const Duration(minutes: 1), (_) => clock());
});

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb(driftDatabase(name: 'doobal'));
  ref.onDispose(db.close);
  return db;
});

final stepSourceProvider = Provider<StepSource>((ref) => HealthStepSource());

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final rules = await ref.watch(rulesProvider.future);
  final landmarks = await ref.watch(landmarksProvider.future);
  final props = await ref.watch(propsProvider.future);
  return SyncService(
    db: ref.watch(dbProvider),
    source: ref.watch(stepSourceProvider),
    rules: rules,
    allowedSources: Platform.isIOS ? rules.allowedSourcesIos : rules.allowedSourcesAndroid,
    landmarks: {for (final l in landmarks) l.id: l},
    props: props,
  );
});

/// 지금 상태. 동기화·여정 시작 뒤에 invalidate 한다
final snapshotProvider = FutureProvider<Snapshot>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.snapshot(ref.read(clockProvider)());
});

/// 지도 화면의 값 (다녀온 명소·지나온 길·위치). 상태가 바뀌면 snapshotProvider와 함께 새로 읽는다
final mapDataProvider = FutureProvider<MapData>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.mapData(ref.read(clockProvider)());
});

/// 지금 자리에서 그 명소까지의 거리와 일수 (지도 카드)
final journeyPreviewProvider =
    FutureProvider.autoDispose.family<JourneyPreview, String>((ref, destId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.preview(destId, ref.read(clockProvider)());
});

/// 도착 화면의 값 (여정 하나). 한 번 읽으면 그대로라 상태가 바뀌어도 다시 읽지 않는다
final arrivalViewProvider =
    FutureProvider.autoDispose.family<ArrivalView, String>((ref, journeyId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.arrivalView(journeyId);
});

/// 화집 벽 4칸. 건 뒤에는 invalidate 한다
final wallProvider = FutureProvider.autoDispose<List<String?>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.wall();
});

/// 얻은 그림 전부 (화집·그림 상세). 도착해서 상태가 바뀌면 새로 읽는다
final paintingsProvider = FutureProvider.autoDispose<List<OwnedPaintingView>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.paintings();
});

/// 얻은 소품 id (화집 소품 탭)
final ownedPropIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.ownedPropIds();
});

/// 그림 하나의 방문 기록 (그림 상세)
final visitsProvider =
    FutureProvider.autoDispose.family<List<VisitView>, String>((ref, landmarkId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.visits(landmarkId);
});
