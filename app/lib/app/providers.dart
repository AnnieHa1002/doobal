import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/config_loader.dart';
import '../data/db/app_db.dart';
import '../data/landmark_loader.dart';
import '../data/step_source.dart';
import '../domain/landmark.dart';
import '../domain/rules.dart';
import 'sync_service.dart';

final rulesProvider = FutureProvider<Rules>((ref) => loadRules());

final landmarksProvider = FutureProvider<List<Landmark>>((ref) => loadLandmarks());

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb(driftDatabase(name: 'doobal'));
  ref.onDispose(db.close);
  return db;
});

final stepSourceProvider = Provider<StepSource>((ref) => HealthStepSource());

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final rules = await ref.watch(rulesProvider.future);
  final landmarks = await ref.watch(landmarksProvider.future);
  return SyncService(
    db: ref.watch(dbProvider),
    source: ref.watch(stepSourceProvider),
    rules: rules,
    allowedSources: Platform.isIOS ? rules.allowedSourcesIos : rules.allowedSourcesAndroid,
    landmarks: {for (final l in landmarks) l.id: l},
  );
});

/// 지금 상태. 동기화·여정 시작 뒤에 invalidate 한다
final snapshotProvider = FutureProvider<Snapshot>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.snapshot(DateTime.now().toUtc());
});
