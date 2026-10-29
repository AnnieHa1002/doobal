import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/geo.dart';
import 'package:drift/drift.dart' show Value;

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
