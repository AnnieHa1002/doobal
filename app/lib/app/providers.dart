import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/config_loader.dart';
import '../data/db/app_db.dart';
import '../data/landmark_loader.dart';
import '../data/milestone_loader.dart';
import '../data/prop_loader.dart';
import '../data/step_source.dart';
import '../data/theme_loader.dart';
import '../domain/camp_theme.dart';
import '../domain/landmark.dart';
import '../domain/prop.dart';
import '../domain/rules.dart';
import 'sync_service.dart';

final rulesProvider = FutureProvider<Rules>((ref) => loadRules());

final landmarksProvider = FutureProvider<List<Landmark>>((ref) => loadLandmarks());

/// 소품 MVP 24개 (props.json)
final propsProvider = FutureProvider<List<Prop>>((ref) => loadProps());

/// 방명록 걸음 숫자 (milestones.json)
final milestonesProvider = FutureProvider<List<int>>((ref) => loadMilestones());

/// 쉼터 테마 (themes/camp.json)
final campThemeProvider = FutureProvider<CampTheme>((ref) => loadCampTheme());

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
