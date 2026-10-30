import 'dart:convert';

import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/look.dart';
import 'package:drift/drift.dart' show Value;

import '../domain/helpers.dart';

/// 쉬는 자리를 [p]로 둔다. 그 자리에서 멈춘 여정 기록 하나를 DB에 직접 넣는다
/// ([at]이 더 늦은 기록이 있으면 그쪽이 쉬는 자리)
Future<void> placeAt(AppDb db, LatLng p, DateTime at) {
  final ms = at.toUtc().millisecondsSinceEpoch;
  return db.into(db.journeys).insert(JourneysCompanion.insert(
        id: 'place$ms',
        originLat: p.lat,
        originLng: p.lng,
        destId: 'kr001',
        startUtc: ms,
        fundKm: 0,
        totalEffectiveKm: 0,
        status: JourneyStatus.stopped,
        endLat: Value(p.lat),
        endLng: Value(p.lng),
        endedUtc: Value(ms),
      ));
}

/// 시작 흐름을 끝낸 프로필을 심는다 (관문을 지나 바로 쉼터가 뜬다). 닉네임·모습은 기본값.
/// [home]이 false면 출발 동네는 비워 둔다 (이미 넣은 출발 동네는 그대로)
Future<void> completeOnboarding(AppDb db, {bool home = true}) =>
    db.into(db.profile).insertOnConflictUpdate(ProfileCompanion(
      id: const Value(1),
      ageConfirmedAt: const Value(1),
      installId: Value('0' * 32),
      nickname: const Value('화가'),
      look: Value(jsonEncode(Look.initial.toJson())),
      onboardedAt: const Value(2),
      homeName: home ? const Value(testHomeName) : const Value.absent(),
      homeLat: home ? Value(testHome.lat) : const Value.absent(),
      homeLng: home ? Value(testHome.lng) : const Value.absent(),
    ));
