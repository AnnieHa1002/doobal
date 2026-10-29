import 'geo.dart';

/// config.json의 규칙 숫자. 엔진은 숫자를 코드에 두지 않고 여기서 읽는다
class Rules {
  const Rules({
    required this.walkMaxSpm,
    required this.runMinSpm,
    required this.walkStrideM,
    required this.runStrideM,
    required this.sessionMaxGapMin,
    required this.sessionMinMin,
    required this.sessionMinSteps,
    required this.sessionMaxPerDay,
    required this.refetchHours,
    required this.seaFactor,
    required this.earthRadiusKm,
    required this.ports,
    required this.islands,
    required this.fallbackOrigin,
    required this.frameSilverKm,
    required this.frameGoldKm,
    required this.travelFundCapKm,
    required this.sketchSteps,
    required this.etaWindowDays,
    required this.etaDefaultDailySteps,
    required this.allowedSourcesIos,
    required this.allowedSourcesAndroid,
  });

  final int walkMaxSpm;
  final int runMinSpm;
  final double walkStrideM;
  final double runStrideM;

  final int sessionMaxGapMin;
  final int sessionMinMin;
  final int sessionMinSteps;
  final int sessionMaxPerDay;

  final int refetchHours;

  final double seaFactor;
  final double earthRadiusKm;

  /// wando·jeju·pohang·dodong
  final Map<String, LatLng> ports;
  final Map<Island, Bounds> islands;

  /// 위치를 거부했을 때의 출발지 (국토 정중앙, 양구)
  final LatLng fallbackOrigin;

  final double frameSilverKm;
  final double frameGoldKm;
  final double travelFundCapKm;
  final List<double> sketchSteps;
  final int etaWindowDays;
  final int etaDefaultDailySteps;

  /// 비어 있으면 출처로 거르지 않는다 (M1 초기 수집용)
  final List<String> allowedSourcesIos;
  final List<String> allowedSourcesAndroid;

  /// 기록이 없을 때의 하루 거리 = 기본 걸음 × 걷기 보폭
  double get defaultDailyKm => etaDefaultDailySteps * walkStrideM / 1000;

  factory Rules.fromJson(Map<String, dynamic> j) {
    final gait = j['gait'] as Map<String, dynamic>;
    final session = j['session'] as Map<String, dynamic>;
    final route = j['route'] as Map<String, dynamic>;
    final journey = j['journey'] as Map<String, dynamic>;
    final frame = journey['frame'] as Map<String, dynamic>;
    final eta = journey['eta'] as Map<String, dynamic>;
    final sources = j['allowedSources'] as Map<String, dynamic>;

    LatLng latLng(dynamic v) => LatLng(_d(v['lat']), _d(v['lng']));
    Bounds bounds(dynamic v) =>
        Bounds(_d(v['latMin']), _d(v['latMax']), _d(v['lngMin']), _d(v['lngMax']));
    final islandJson = route['islands'] as Map<String, dynamic>;

    return Rules(
      walkMaxSpm: gait['walkMaxSpm'] as int,
      runMinSpm: gait['runMinSpm'] as int,
      walkStrideM: _d(gait['walkStrideM']),
      runStrideM: _d(gait['runStrideM']),
      sessionMaxGapMin: session['maxGapMin'] as int,
      sessionMinMin: session['minMin'] as int,
      sessionMinSteps: session['minSteps'] as int,
      sessionMaxPerDay: session['maxPerDay'] as int,
      refetchHours: (j['sync'] as Map<String, dynamic>)['refetchHours'] as int,
      seaFactor: _d(route['seaFactor']),
      earthRadiusKm: _d(route['earthRadiusKm']),
      ports: (route['ports'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, latLng(v))),
      islands: {
        Island.jeju: bounds(islandJson['jeju']),
        Island.ulleung: bounds(islandJson['ulleung']),
      },
      fallbackOrigin: latLng(route['fallbackOrigin']),
      frameSilverKm: _d(frame['silverKm']),
      frameGoldKm: _d(frame['goldKm']),
      travelFundCapKm: _d(journey['travelFundCapKm']),
      sketchSteps: (journey['sketchSteps'] as List).map(_d).toList(),
      etaWindowDays: eta['windowDays'] as int,
      etaDefaultDailySteps: eta['defaultDailySteps'] as int,
      allowedSourcesIos: (sources['ios'] as List).cast<String>(),
      allowedSourcesAndroid: (sources['android'] as List).cast<String>(),
    );
  }
}

double _d(dynamic v) => (v as num).toDouble();
