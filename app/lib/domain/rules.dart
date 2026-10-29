import 'geo.dart';

/// 시간대 색 입히기 한 단계 (config scene.timeTint). 곱하기로 입힌다
class TimeTint {
  const TimeTint(this.color, this.background, this.character);

  /// 불투명 ARGB (0xFFRRGGBB)
  final int color;

  /// 하늘을 뺀 배경 레이어에 입히는 세기와 캐릭터에 입히는 세기 (0~1)
  final double background;
  final double character;
}

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
    required this.walkingRefreshSec,
    required this.seaFactor,
    required this.earthRadiusKm,
    required this.ports,
    required this.islands,
    required this.fallbackOrigin,
    required this.frameSilverKm,
    required this.frameGoldKm,
    required this.travelFundCapKm,
    required this.etaWindowDays,
    required this.etaDefaultDailySteps,
    required this.seasons,
    required this.groundWidthPx,
    required this.groundMeters,
    required this.parallaxBackdrop,
    required this.parallaxGround,
    required this.parallaxForeground,
    required this.skyBandWidthPx,
    required this.skyTileWidthPx,
    required this.groundTileWidthPx,
    required this.sunZenithDeg,
    required this.skyDawnHour,
    required this.skyMorningHour,
    required this.skyDayHour,
    required this.skySunsetHour,
    required this.skyNightHour,
    required this.timeTint,
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

  /// 걷는 중 화면이 동기화하는 간격(초)
  final int walkingRefreshSec;

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
  final int etaWindowDays;
  final int etaDefaultDailySteps;

  /// 계절 이름(spring·summer·autumn·winter) → 달. Season 변환은 scene.dart
  final Map<String, List<int>> seasons;

  /// 땅 이미지 한 장의 가로(px)와 그게 나타내는 거리(m)
  final double groundWidthPx;
  final double groundMeters;

  /// 레이어별 스크롤 배율 (후경 0.3, 땅 1.0, 전경 1.3)
  final double parallaxBackdrop;
  final double parallaxGround;
  final double parallaxForeground;

  /// 하늘 띠 전체 가로와 조각 가로, 땅 조각 가로 (px)
  final double skyBandWidthPx;
  final double skyTileWidthPx;
  final double groundTileWidthPx;

  /// 일출·일몰 천정각(도). NOAA 기본 90.833
  final double sunZenithDeg;

  /// 하늘 5단계가 시작하는 기준 시각(h). 밤은 [night, 24)과 [0, dawn). 잠정값(approx)
  final double skyDawnHour;
  final double skyMorningHour;
  final double skyDayHour;
  final double skySunsetHour;
  final double skyNightHour;

  /// 하늘 단계 이름(dawn·morning·sunset·night) → 색 입히기. 낮은 없다 = 입히지 않는다.
  /// SkyPhase 변환은 time_tint.dart (sky.dart가 rules.dart를 읽어서 여기서는 문자열 키)
  final Map<String, TimeTint> timeTint;

  /// 비어 있으면 출처로 거르지 않는다 (M1 초기 수집용)
  final List<String> allowedSourcesIos;
  final List<String> allowedSourcesAndroid;

  /// 기록이 없을 때의 하루 거리 = 기본 걸음 × 걷기 보폭
  double get defaultDailyKm => etaDefaultDailySteps * walkStrideM / 1000;

  /// 거리 1m당 땅이 움직이는 px (20.48). 따로 저장하지 않는다
  double get groundPxPerM => groundWidthPx / groundMeters;

  factory Rules.fromJson(Map<String, dynamic> j) {
    final gait = j['gait'] as Map<String, dynamic>;
    final session = j['session'] as Map<String, dynamic>;
    final sync = j['sync'] as Map<String, dynamic>;
    final route = j['route'] as Map<String, dynamic>;
    final journey = j['journey'] as Map<String, dynamic>;
    final frame = journey['frame'] as Map<String, dynamic>;
    final eta = journey['eta'] as Map<String, dynamic>;
    final scene = j['scene'] as Map<String, dynamic>;
    final parallax = scene['parallax'] as Map<String, dynamic>;
    final phases = scene['skyPhases'] as Map<String, dynamic>;
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
      refetchHours: sync['refetchHours'] as int,
      walkingRefreshSec: sync['walkingRefreshSec'] as int,
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
      etaWindowDays: eta['windowDays'] as int,
      etaDefaultDailySteps: eta['defaultDailySteps'] as int,
      seasons: (j['seasons'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as List).cast<int>())),
      groundWidthPx: _d(scene['groundWidthPx']),
      groundMeters: _d(scene['groundMeters']),
      parallaxBackdrop: _d(parallax['backdrop']),
      parallaxGround: _d(parallax['ground']),
      parallaxForeground: _d(parallax['foreground']),
      skyBandWidthPx: _d(scene['skyBandWidthPx']),
      skyTileWidthPx: _d(scene['skyTileWidthPx']),
      groundTileWidthPx: _d(scene['groundTileWidthPx']),
      sunZenithDeg: _d(scene['sunZenithDeg']),
      skyDawnHour: _d(phases['dawn']),
      skyMorningHour: _d(phases['morning']),
      skyDayHour: _d(phases['day']),
      skySunsetHour: _d(phases['sunset']),
      skyNightHour: _d(phases['night']),
      timeTint: (scene['timeTint'] as Map<String, dynamic>).map((k, v) => MapEntry(
          k, TimeTint(_hex(v['color'] as String), _d(v['background']), _d(v['character'])))),
      allowedSourcesIos: (sources['ios'] as List).cast<String>(),
      allowedSourcesAndroid: (sources['android'] as List).cast<String>(),
    );
  }
}

double _d(dynamic v) => (v as num).toDouble();

/// "#RRGGBB" → 불투명 ARGB
int _hex(String s) => 0xFF000000 | int.parse(s.substring(1), radix: 16);
