import 'geo.dart';

/// 시간대 색 입히기 한 단계 (config scene.tint: bg·char). 곱하기로 입힌다
class TimeTint {
  const TimeTint(this.color, this.background, this.character);

  /// 불투명 ARGB (0xFFRRGGBB)
  final int color;

  /// 하늘을 뺀 배경 레이어에 입히는 세기와 캐릭터에 입히는 세기 (0~1)
  final double background;
  final double character;
}

/// 장면 레이어 이름 (config scene.layers). 그리는 순서는 painter가 정한다
enum SceneLayerId { sky, backdrop, ridge, grove, meadow, ground, foreground }

/// 레이어 하나의 규격 (config scene.layers). 좌표는 기준 화면(1170×2532) px.
/// sky는 그린 하늘이라 speed만 있고, 땅 이미지(ground)에는 띠가 없다
class SceneLayer {
  const SceneLayer({
    required this.speed,
    this.widthPx,
    this.heightPx,
    this.topY,
    this.bandTop,
    this.bandBottom,
  });

  /// 땅 속도에 대한 비율 (땅 1.0)
  final double speed;

  /// 이미지 크기와 위 가장자리 y. 이미지는 topY에서 topY + heightPx까지
  final double? widthPx;
  final double? heightPx;
  final double? topY;

  /// 윗선(실루엣의 위 가장자리)이 놓이는 y 범위
  final double? bandTop;
  final double? bandBottom;
}

/// 하늘 단계 하나의 색 (config scene.sky.keys). 색은 불투명 ARGB, glow는 빛무리
class SkyKeyColors {
  const SkyKeyColors({
    required this.top,
    required this.mid,
    required this.horizon,
    required this.glow,
    required this.glowStrength,
  });

  final int top;
  final int mid;
  final int horizon;
  final int glow;

  /// 빛무리 중심의 알파 (0~1)
  final double glowStrength;
}

/// 해·달이 지나는 호 (config scene.sky.arc)
class SkyArc {
  const SkyArc({
    required this.leftX,
    required this.rightX,
    required this.peakY,
    required this.glowRadiusPx,
  });

  /// 호의 왼쪽·오른쪽 끝 (화면 가로 비율)
  final double leftX;
  final double rightX;

  /// 호의 꼭대기 y와 빛무리 반지름 (기준 화면 px)
  final double peakY;
  final double glowRadiusPx;
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
    required this.firstSketchMinKm,
    required this.firstSketchMaxKm,
    required this.frameSilverKm,
    required this.frameGoldKm,
    required this.travelFundCapKm,
    required this.etaWindowDays,
    required this.etaDefaultDailySteps,
    required this.seasons,
    required this.groundWidthPx,
    required this.groundMeters,
    required this.screenHeightPx,
    required this.horizonY,
    required this.pathY,
    required this.characterHeightPx,
    required this.layers,
    required this.seaHiddenLayers,
    required this.sunZenithDeg,
    required this.skyMidStop,
    required this.skyNightEndMin,
    required this.skyDawnMin,
    required this.skyMorningMin,
    required this.skyDayStartMin,
    required this.skyDayEndMin,
    required this.skySunsetMin,
    required this.skyNightStartMin,
    required this.skyKeys,
    required this.skyStars,
    required this.skyArc,
    required this.timeTint,
    required this.nicknameMin,
    required this.nicknameMax,
    required this.notificationDailyMax,
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

  /// 첫 여정 '내 동네 스케치'의 목적지까지 거리 범위(km) (config journey.firstSketchKm)
  final double firstSketchMinKm;
  final double firstSketchMaxKm;

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

  /// 기준 화면 높이(px). 그리는 쪽이 실제 화면 높이 / 이 값으로 줄이거나 늘린다
  final double screenHeightPx;

  /// 지평선 y, 길 가운데 y (= 걷는 캐릭터의 발 높이), 캐릭터 키 (발에서 모자 끝까지). 기준 화면 px
  final double horizonY;
  final double pathY;
  final double characterHeightPx;

  /// 레이어별 규격. 모든 SceneLayerId가 들어 있다
  final Map<SceneLayerId, SceneLayer> layers;

  /// 배 구간(바다)에서 숨기는 레이어
  final Set<SceneLayerId> seaHiddenLayers;

  /// 일출·일몰 천정각(도). NOAA 기본 90.833
  final double sunZenithDeg;

  /// 하늘 세로 그라디언트(위·가운데·지평선)의 가운데 정지점 (지평선까지 높이의 비율)
  final double skyMidStop;

  /// 하늘 단계가 바뀌는 시각의 간격(분). 일출 기준: 밤 끝·새벽·아침·낮 시작,
  /// 일몰 기준: 낮 끝·노을·밤 시작. 음수는 앞
  final double skyNightEndMin;
  final double skyDawnMin;
  final double skyMorningMin;
  final double skyDayStartMin;
  final double skyDayEndMin;
  final double skySunsetMin;
  final double skyNightStartMin;

  /// 하늘 단계 이름(dawn·morning·day·sunset·night) → 색. 단계 사이는 시각에 따라 섞는다.
  /// SkyPhase 변환은 sky.dart (sky.dart가 rules.dart를 읽어서 여기서는 문자열 키)
  final Map<String, SkyKeyColors> skyKeys;

  /// 하늘 단계 이름 → 별 불투명도 (0~1). 없는 단계는 0. 잠정값(approx)
  final Map<String, double> skyStars;

  /// 해·달 호와 빛무리. 잠정값(approx)
  final SkyArc skyArc;

  /// 하늘 단계 이름(dawn·morning·sunset·night) → 색 입히기. 낮은 없다 = 입히지 않는다.
  /// SkyPhase 변환은 time_tint.dart (sky.dart가 rules.dart를 읽어서 여기서는 문자열 키)
  final Map<String, TimeTint> timeTint;

  /// 닉네임 길이(글자 수) 범위 (config profile)
  final int nicknameMin;
  final int nicknameMax;

  /// 알림은 하루 이만큼까지만 (config notifications.dailyMax). 시작 화면의 알림 권한 설명에도 쓴다
  final int notificationDailyMax;

  /// 비어 있으면 출처로 거르지 않는다 (M1 초기 수집용)
  final List<String> allowedSourcesIos;
  final List<String> allowedSourcesAndroid;

  /// 기록이 없을 때의 하루 거리 = 기본 걸음 × 걷기 보폭
  double get defaultDailyKm => etaDefaultDailySteps * walkStrideM / 1000;

  /// 거리 1m당 땅이 움직이는 px (40.96). 따로 저장하지 않는다
  double get groundPxPerM => groundWidthPx / groundMeters;

  factory Rules.fromJson(Map<String, dynamic> j) {
    final gait = j['gait'] as Map<String, dynamic>;
    final session = j['session'] as Map<String, dynamic>;
    final sync = j['sync'] as Map<String, dynamic>;
    final route = j['route'] as Map<String, dynamic>;
    final journey = j['journey'] as Map<String, dynamic>;
    final frame = journey['frame'] as Map<String, dynamic>;
    final eta = journey['eta'] as Map<String, dynamic>;
    final firstSketch = journey['firstSketchKm'] as Map<String, dynamic>;
    final scene = j['scene'] as Map<String, dynamic>;
    final sky = scene['sky'] as Map<String, dynamic>;
    final fromSunrise = sky['fromSunriseMin'] as Map<String, dynamic>;
    final fromSunset = sky['fromSunsetMin'] as Map<String, dynamic>;
    final arc = sky['arc'] as Map<String, dynamic>;
    final profile = j['profile'] as Map<String, dynamic>;
    final notifications = j['notifications'] as Map<String, dynamic>;
    final sources = j['allowedSources'] as Map<String, dynamic>;

    LatLng latLng(dynamic v) => LatLng(_d(v['lat']), _d(v['lng']));
    Bounds bounds(dynamic v) =>
        Bounds(_d(v['latMin']), _d(v['latMax']), _d(v['lngMin']), _d(v['lngMax']));
    final islandJson = route['islands'] as Map<String, dynamic>;

    SceneLayerId layerId(String name) =>
        SceneLayerId.values.asNameMap()[name] ?? (throw FormatException('모르는 레이어: $name'));
    final layers = {
      for (final e in (scene['layers'] as Map<String, dynamic>).entries)
        layerId(e.key): SceneLayer(
          speed: _d(e.value['speed']),
          widthPx: _dn(e.value['widthPx']),
          heightPx: _dn(e.value['heightPx']),
          topY: _dn(e.value['topY']),
          bandTop: _dn(e.value['bandTop']),
          bandBottom: _dn(e.value['bandBottom']),
        ),
    };
    for (final id in SceneLayerId.values) {
      if (!layers.containsKey(id)) throw FormatException('레이어 규격이 없다: ${id.name}');
    }

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
      firstSketchMinKm: _d(firstSketch['min']),
      firstSketchMaxKm: _d(firstSketch['max']),
      frameSilverKm: _d(frame['silverKm']),
      frameGoldKm: _d(frame['goldKm']),
      travelFundCapKm: _d(journey['travelFundCapKm']),
      etaWindowDays: eta['windowDays'] as int,
      etaDefaultDailySteps: eta['defaultDailySteps'] as int,
      seasons: (j['seasons'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as List).cast<int>())),
      groundWidthPx: _d(scene['groundWidthPx']),
      groundMeters: _d(scene['groundMeters']),
      screenHeightPx: _d(scene['screenHeightPx']),
      horizonY: _d(scene['horizonY']),
      pathY: _d(scene['pathY']),
      characterHeightPx: _d(scene['characterHeightPx']),
      layers: layers,
      seaHiddenLayers: {for (final n in scene['seaHiddenLayers'] as List) layerId(n as String)},
      sunZenithDeg: _d(scene['sunZenithDeg']),
      skyMidStop: _d(sky['midStop']),
      skyNightEndMin: _d(fromSunrise['nightEnd']),
      skyDawnMin: _d(fromSunrise['dawn']),
      skyMorningMin: _d(fromSunrise['morning']),
      skyDayStartMin: _d(fromSunrise['dayStart']),
      skyDayEndMin: _d(fromSunset['dayEnd']),
      skySunsetMin: _d(fromSunset['sunset']),
      skyNightStartMin: _d(fromSunset['nightStart']),
      skyKeys: (sky['keys'] as Map<String, dynamic>).map((k, v) => MapEntry(
          k,
          SkyKeyColors(
            top: _hex(v['top'] as String),
            mid: _hex(v['mid'] as String),
            horizon: _hex(v['horizon'] as String),
            glow: _hex(v['glow'] as String),
            glowStrength: _d(v['glowStrength']),
          ))),
      // approx 같은 표시는 숫자가 아니라 건너뛴다
      skyStars: {
        for (final e in (sky['stars'] as Map<String, dynamic>).entries)
          if (e.value is num) e.key: _d(e.value),
      },
      skyArc: SkyArc(
        leftX: _d(arc['leftX']),
        rightX: _d(arc['rightX']),
        peakY: _d(arc['peakY']),
        glowRadiusPx: _d(arc['glowRadiusPx']),
      ),
      timeTint: (scene['tint'] as Map<String, dynamic>).map((k, v) => MapEntry(
          k, TimeTint(_hex(v['color'] as String), _d(v['bg']), _d(v['char'])))),
      nicknameMin: profile['nicknameMin'] as int,
      nicknameMax: profile['nicknameMax'] as int,
      notificationDailyMax: notifications['dailyMax'] as int,
      allowedSourcesIos: (sources['ios'] as List).cast<String>(),
      allowedSourcesAndroid: (sources['android'] as List).cast<String>(),
    );
  }
}

double _d(dynamic v) => (v as num).toDouble();

double? _dn(dynamic v) => v == null ? null : _d(v);

/// "#RRGGBB" → 불투명 ARGB
int _hex(String s) => 0xFF000000 | int.parse(s.substring(1), radix: 16);
