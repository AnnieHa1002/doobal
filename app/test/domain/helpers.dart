import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/badge.dart';
import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/camp_theme.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/domain/moderation.dart';
import 'package:doobal/domain/map_projection.dart';
import 'package:doobal/domain/map_regions.dart';
import 'package:doobal/domain/notification_policy.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/road_event.dart';
import 'package:doobal/domain/rules.dart';
import 'package:doobal/domain/sigungu.dart';
import 'package:doobal/domain/spirit_palette.dart';
import 'package:doobal/domain/companion.dart';
import 'package:doobal/domain/shop.dart';

/// 테스트도 실제 config.json 값으로 돈다 (flutter test는 app/에서 실행)
final Rules rules = Rules.fromJson(
  jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 랩 길이(record.lapKm)만 바꾼 규칙. 한 분 안에 경계가 여러 개인 경우를 작은 값으로 본다
Rules rulesWithLapKm(double lapKm) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  (j['record'] as Map<String, dynamic>)['lapKm'] = lapKm;
  return Rules.fromJson(j);
}

/// 실제 landmarks.json의 명소 101곳
final List<Landmark> landmarks = [
  for (final l in (jsonDecode(File('assets/data/landmarks.json').readAsStringSync())
          as Map<String, dynamic>)['landmarks'] as List)
    Landmark.fromJson(l as Map<String, dynamic>),
];

/// 실제 props.json의 MVP 소품 27개
final List<Prop> props = parseProps(
  jsonDecode(File('assets/data/props.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 milestones.json의 방명록 걸음 숫자 23개
final List<int> milestones = ((jsonDecode(File('assets/data/milestones.json').readAsStringSync())
        as Map<String, dynamic>)['stepMilestones'] as List)
    .cast<int>();

/// 실제 events.json (길 위 이벤트 풍경·칭찬 문구)
final EventCatalog eventCatalog = EventCatalog.fromJson(
  jsonDecode(File('assets/data/events.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 badges.json (도장 20개와 하늘 구간)
final ShopCatalog shopCatalog = parseShop(
  jsonDecode(File('assets/data/shop.json').readAsStringSync()) as Map<String, dynamic>,
);

final BoatCatalog boatCatalog = parseBoats(
  jsonDecode(File('assets/data/boats.json').readAsStringSync()) as Map<String, dynamic>,
);

final CompanionCatalog companionCatalog = parseCompanions(
  jsonDecode(File('assets/data/companions.json').readAsStringSync()) as Map<String, dynamic>,
);

final BadgeCatalog badgeCatalog = BadgeCatalog.fromJson(
  jsonDecode(File('assets/data/badges.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 themes/camp.json
final CampTheme campTheme = CampTheme.fromJson(
  jsonDecode(File('assets/data/themes/camp.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 지도 투영 (assets/map/ui_map_projection_v01.json)
final MapProjection mapProjection = MapProjection.fromJson(
  jsonDecode(File('assets/map/ui_map_projection_v01.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// 실제 지도 경계 (assets/map/ui_map_regions_v01.svg의 18개)
final List<MapRegion> mapRegions =
    parseMapRegions(File('assets/map/ui_map_regions_v01.svg').readAsStringSync());

/// 실제 sigungu.json의 시·군·구
final List<Sigungu> sigungu = parseSigungu(
  jsonDecode(File('assets/data/sigungu.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 palette.json의 정령 부분 (몸 색 견본, 얼굴 파츠 이름, 소품 색 규칙)
final SpiritPalette spiritPalette = SpiritPalette.fromJson(
  jsonDecode(File('assets/data/palette.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 moderation.json의 금칙어 규칙
final Moderation moderation = Moderation.fromJson(
  jsonDecode(File('assets/data/moderation.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 실제 notifications.json의 알림 종류별 우선순위와 문구
final NoticeCatalog noticeCatalog = NoticeCatalog.fromJson(
  jsonDecode(File('assets/data/notifications.json').readAsStringSync()) as Map<String, dynamic>,
);

/// 테스트용 출발 동네: 서울시청 (서울특별시 중구). 실제 출발 동네는 사용자가 고른다
const testHome = LatLng(37.5665, 126.9780);
const testHomeName = '중구';

/// start부터 1분 간격으로 걸음을 채운 분 목록 (0도 그대로 넣는다)
List<StepMinute> minutesFrom(DateTime startUtc, List<int> steps) {
  final first = epochMinute(startUtc);
  return [for (var i = 0; i < steps.length; i++) StepMinute(first + i, steps[i])];
}
