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

/// 쉼터 넓히기·확대 규칙 (config rest.drag·rest.zoom)
class RestRules {
  const RestRules({
    required this.zoomMin,
    required this.zoomMax,
    required this.snapEdgesWhenZoomed,
    required this.snapToEnds,
    required this.farParallax,
    required this.snapSec,
  });

  final double zoomMin;
  final double zoomMax;

  /// 확대 중에도 손을 떼면 끝에 붙는가
  final bool snapEdgesWhenZoomed;

  /// 손을 떼면 처음·끝으로 붙는가
  final bool snapToEnds;

  /// 하늘·후경이 캠프 판의 몇 배로 움직이나
  final double farParallax;

  /// 끝에 붙는 시간
  final double snapSec;
}

/// 장면 레이어 이름 (config scene.layers, 6역할 + 하늘). 그리는 순서는 painter가 정한다
enum SceneLayerId { sky, backdrop, grove, roadside, meadow, ground, foreground }

/// 계절 보정 (config scene.seasonTint). [layers]에만 입힌다
class SeasonTint {
  const SeasonTint({
    required this.layers,
    required this.multiply,
    required this.strength,
    this.saturation = 0,
    this.brightness = 0,
  });

  final Set<SceneLayerId> layers;

  /// 곱하기 색 (불투명 ARGB)과 세기
  final int multiply;
  final double strength;
  final double saturation;
  final double brightness;
}

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

/// 정령을 누르는 반응 (config character.tapReaction): 창([angryWindowSec]) 안에 [angryTaps]번이면 화남
/// ([angryHoldSec] 동안), 그보다 적으면 행복
class TapReaction {
  const TapReaction({
    required this.happyMaxTaps,
    required this.angryWindowSec,
    required this.angryTaps,
    required this.angryHoldSec,
  });

  /// 행복 반응으로 세는 연타 수 (참고값: 화남 조건 전까지는 모두 행복)
  final int happyMaxTaps;
  final double angryWindowSec;
  final int angryTaps;
  final double angryHoldSec;
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
    required this.aliveSaveSec,
    required this.backgroundSyncMin,
    required this.liveCadenceWindowSec,
    required this.liveNoticeUpdateSec,
    required this.lapKm,
    required this.bonusTravelMultiplier,
    required this.bonusCoinMultiplier,
    required this.paintTrailStartSteps,
    required this.paintTrailStartWithinSec,
    required this.paintTrailIdleEndMin,
    required this.paintDropCoinsPerKm,
    required this.paintDropSpacingM,
    required this.paintDropCoinsPerDrop,
    required this.coinsPerKm,
    required this.coinsDailyCap,
    required this.coinsWelcomeGift,
    required this.coinAmountFormat,
    required this.coinBuyQuestion,
    required this.coinBuyButton,
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
    required this.characterCanvasHeightPx,
    required this.characterHeightLandscapePx,
    required this.rest,
    required this.seasonTint,
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
    required this.notificationQuietFromHour,
    required this.notificationQuietToHour,
    required this.notificationNearDestKm,
    required this.notificationInactiveHours,
    required this.notificationInactiveDeferHour,
    required this.guestbookMaxChars,
    required this.guestbookWindowSteps,
    required this.eventEveryKm,
    required this.eventFlushSec,
    required this.eventOffScreenCards,
    required this.eventCardSec,
    required this.stampLineSec,
    required this.arrivalProbeSec,
    required this.mapFirstViewMinLandmarks,
    required this.mapFirstViewMargin,
    required this.bigViewMaxZoom,
    required this.bigViewSavedToastSec,
    required this.backupMinIntervalMin,
    required this.backupMaxChars,
    required this.allowedSourcesIos,
    required this.allowedSourcesAndroid,
    required this.tapReaction,
    required this.companionGuaranteeDays,
    required this.companionWalksPerChapter,
    required this.companionChapters,
    required this.companionMeetChanceMatch,
    required this.companionMeetChanceOther,
    required this.companionAheadEverySec,
    required this.companionAheadAwaySec,
    required this.companionWalkMps,
    required this.companionLagCatchUpMps,
    required this.companionLateArrivalMaxSec,
    required this.shopDailyEffectCapKm,
    required this.shopMaxHoldPerItem,
    required this.adsRewardedPerDay,
    required this.adsMaxRewardCoins,
  });

  /// 설치 뒤 며칠까지 둘째·셋째 동행을 꼭 만나는지 (config companions.guaranteeByDay)
  final List<int> companionGuaranteeDays;

  /// 함께 인정된 걷기 1번 몇 번마다 이야기 한 장 (config companions.walksPerChapter)
  final int companionWalksPerChapter;

  /// 이야기 마지막 장 번호 (config companions.chapters, 이 장이 완결)
  final int companionChapters;

  /// 둘째·셋째 동행을 칸마다 만날 확률: 안 만난 동행의 지형이 맞는 칸, 그 밖의 칸
  /// (config companions.meetChance, 가안)
  final double companionMeetChanceMatch;
  final double companionMeetChanceOther;

  /// 걷는 중 연출 (config companions.pace, 저장하지 않는다)
  final double companionAheadEverySec;
  final double companionAheadAwaySec;

  /// 동행의 걷기 속도(m/s): 뒤처지는 속도와 쉼터 늦은 도착을 잰다 (config companions.pace.walkMps, 가안)
  final double companionWalkMps;
  final double companionLagCatchUpMps;
  final double companionLateArrivalMaxSec;

  /// 여행 효과로 하루에 더할 수 있는 거리 (config shop.dailyEffectCapKm)
  final double shopDailyEffectCapKm;

  /// 여행 효과를 종류마다 몇 개까지 보관하는지 (config shop.maxHoldPerItem)
  final int shopMaxHoldPerItem;

  /// 보상형 광고 하루 횟수와 한 번에 받는 럭 상한 (config ads)
  final int adsRewardedPerDay;
  final int adsMaxRewardCoins;

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

  /// 앱이 살아 있는 동안 '마지막으로 살아 있던 시각'을 적는 간격(초) (config sync.aliveSaveSec).
  /// 앱이 갑자기 끝났을 때 열려 있던 앱 걷기를 이 시각에서 닫는다
  final int aliveSaveSec;

  /// 앱이 닫혀 있을 때 걸음을 가져와 동기화하는 간격(분) (config sync.backgroundMin, 안드로이드 WorkManager).
  /// 안드로이드가 정하는 최소는 15분이고, 실제로 도는 때는 안드로이드가 배터리에 맞춰 늦출 수 있다
  final int backgroundSyncMin;

  /// 걸음 센서로 분당 걸음을 낼 때 보는 최근 시간(초) (config live.cadenceWindowSec)
  final int liveCadenceWindowSec;

  /// 걷는 중 상시 알림(안드로이드)의 걸음·거리를 새로 쓰는 가장 짧은 간격(초) (config live.noticeUpdateSec)
  final int liveNoticeUpdateSec;

  /// 걷기 기록의 랩 길이(km) (config record.lapKm)
  final double lapKm;

  /// 본격 걷기 보너스 (config bonus, 16장 11/13에 없앰). 다음 커밋에서 읽지 않는다
  final double bonusTravelMultiplier;
  final double bonusCoinMultiplier;

  /// 물감 길 시작 (config paintTrail.startMinSteps): 앱이 앞에 있을 때 [paintTrailStartWithinSec]초 안에
  /// 센서 걸음이 [paintTrailStartSteps]보 늘면 시작한다 (가안 60초 10보)
  final int paintTrailStartSteps;
  final int paintTrailStartWithinSec;

  /// 걸음이 이만큼(분) 멈추면 물감 길이 끝난다 (config paintTrail.idleEndMin, 가안 5분)
  final int paintTrailIdleEndMin;

  /// 물감 길 실제 1km당 덤 럭 (config paintDrop.coinsPerKm). 하루 상한 coins.dailyCap에 같이 든다
  final double paintDropCoinsPerKm;

  /// 물감 방울 사이 거리(m, config paintDrop.spacingM, 가안 100)와 방울 하나에 머리 위로 뜨는 럭
  /// (config paintDrop.coinsPerDrop, 연출 숫자)
  final double paintDropSpacingM;
  final int paintDropCoinsPerDrop;

  /// 실제 1km당 하루 럭 (config coins.perKm). 기획이 아직 안 정해서 null이면 럭은 늘 0이다
  final double? coinsPerKm;

  /// 걸어서 버는 럭의 하루 상한 (config coins.dailyCap). 광고·첫 선물은 따로다
  final int coinsDailyCap;

  /// 첫 그림(내 동네 스케치) 도착 때 한 번 주는 첫 선물 (config coins.welcomeGift)
  final int coinsWelcomeGift;

  /// 럭 값 표기 '{n} 럭' (config coins.format.amount)
  final String coinAmountFormat;

  /// 구매 질문 '{item}을(를) {n} 럭에 구매할까요?' (config coins.format.buyQuestion, 조사는 앱이 고른다)
  final String coinBuyQuestion;

  /// 구매 버튼 글 (config coins.format.buyButton)
  final String coinBuyButton;

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

  /// 정령·동행 캔버스에서 머리~발 높이 (config character.canvas.heightPx). 배 판 그림과 같은 잣대다
  final double characterCanvasHeightPx;

  /// 가로 화면의 캐릭터 키 (기준 1170px, config character.canvas.screenHeightPx.landscape)
  final double characterHeightLandscapePx;

  /// 쉼터 밀기·확대 (config rest)
  final RestRules rest;

  /// 계절 이름 → 계절 보정 (봄·여름은 없음)
  final Map<String, SeasonTint> seasonTint;

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

  /// 알림을 안 보내는 조용한 시간 (한국 시간, quietFromHour시 정각부터 quietToHour시 정각 전까지),
  /// '거의 다 왔어' 알림의 남은 거리(km), '다시 부르기' 알림까지 안 연 시간, '다시 부르기'를
  /// 조용한 시간이나 아침에 맞췄을 때 미루는 한국 시간(시)
  /// (config notifications.quietFromHour·quietToHour·nearDestKm·inactiveHours·inactiveDeferHour)
  final int notificationQuietFromHour;
  final int notificationQuietToHour;
  final double notificationNearDestKm;
  final int notificationInactiveHours;
  final int notificationInactiveDeferHour;

  /// 방명록 글 길이 상한(글자 수)과, 걸음 숫자 기회가 열린 뒤 쓸 수 있는 걸음 수
  /// (config guestbook.maxChars·milestoneWindowSteps)
  final int guestbookMaxChars;
  final int guestbookWindowSteps;

  /// 길 위 이벤트가 한 칸 열리는 앱이 켜진 동안의 거리(km) (config events.everyKm)
  final double eventEveryKm;

  /// 걷는 중 화면이 센서로 센 거리를 이벤트 계산에 넘기는 간격(초) (config events.flushSec)
  final int eventFlushSec;

  /// 화면이 꺼진 동안 넘은 칸 중 다시 켜질 때 보여 줄 카드 수 (config events.offScreenCards, 11/13 1장).
  /// 넘은 칸은 모두 줄로 남는다
  final int eventOffScreenCards;

  /// 걷는 중 화면에 이정표 카드(config hud.eventCardSec)·새 도장 줄(config hud.stampLineSec)이
  /// 떠 있는 시간(초). 지나면 저절로 사라진다
  final double eventCardSec;
  final double stampLineSec;

  /// 센서 미리보기가 남은 거리를 넘었을 때 도착 확인 동기화를 다시 돌리는 최소 간격(초)
  /// (config walk.arrivalProbeSec)
  final int arrivalProbeSec;

  /// 지도를 처음 열 때 현재 위치 둘레에 최소 몇 곳의 명소가 보이게 할지(config map.firstView.minLandmarks)와
  /// 보이는 범위 가장자리 여백 비율(config map.firstView.margin)
  final int mapFirstViewMinLandmarks;
  final double mapFirstViewMargin;

  /// 그림 크게 보기(16장 11/10): 두 손가락 확대 상한 배율(config ui.bigView.maxZoom, 가안 2)과
  /// 저장 뒤 ‘저장했어요’가 떠 있는 시간(초, ui.bigView.savedToastSec)
  final double bigViewMaxZoom;
  final double bigViewSavedToastSec;

  /// 자동 백업은 마지막 백업 뒤 이 시간(분) 안에는 다시 하지 않는다 (config backup.minIntervalMin).
  /// 백업 문자열(base64)의 글자 수 상한은 서버 문서 한도(1MiB)에서 필드 이름 같은 여유를 뺀 값이다
  /// (config backup.maxChars)
  final int backupMinIntervalMin;
  final int backupMaxChars;

  /// 비어 있으면 출처로 거르지 않는다 (M1 초기 수집용)
  final List<String> allowedSourcesIos;
  final List<String> allowedSourcesAndroid;

  /// 쉼터·꾸미기에서 정령을 누르는 반응 (config character.tapReaction)
  final TapReaction tapReaction;

  /// 기록이 없을 때의 하루 거리 = 기본 걸음 × 걷기 보폭
  double get defaultDailyKm => etaDefaultDailySteps * walkStrideM / 1000;

  /// 거리 1m당 땅이 움직이는 px (40.96). 따로 저장하지 않는다
  double get groundPxPerM => groundWidthPx / groundMeters;

  factory Rules.fromJson(Map<String, dynamic> j) {
    final gait = j['gait'] as Map<String, dynamic>;
    final session = j['session'] as Map<String, dynamic>;
    final sync = j['sync'] as Map<String, dynamic>;
    final live = j['live'] as Map<String, dynamic>;
    final record = j['record'] as Map<String, dynamic>;
    final bonus = j['bonus'] as Map<String, dynamic>;
    final paintTrail = j['paintTrail'] as Map<String, dynamic>;
    final trailStart = paintTrail['startMinSteps'] as Map<String, dynamic>;
    final paintDrop = j['paintDrop'] as Map<String, dynamic>;
    final coins = j['coins'] as Map<String, dynamic>;
    final route = j['route'] as Map<String, dynamic>;
    final journey = j['journey'] as Map<String, dynamic>;
    final frame = journey['frame'] as Map<String, dynamic>;
    final eta = journey['eta'] as Map<String, dynamic>;
    final firstSketch = journey['firstSketchKm'] as Map<String, dynamic>;
    final scene = j['scene'] as Map<String, dynamic>;
    final restZoom = (j['rest'] as Map<String, dynamic>)['zoom'] as Map<String, dynamic>;
    final restDrag = (j['rest'] as Map<String, dynamic>)['drag'] as Map<String, dynamic>;
    final sky = scene['sky'] as Map<String, dynamic>;
    final fromSunrise = sky['fromSunriseMin'] as Map<String, dynamic>;
    final fromSunset = sky['fromSunsetMin'] as Map<String, dynamic>;
    final arc = sky['arc'] as Map<String, dynamic>;
    final profile = j['profile'] as Map<String, dynamic>;
    final notifications = j['notifications'] as Map<String, dynamic>;
    final guestbook = j['guestbook'] as Map<String, dynamic>;
    final backup = j['backup'] as Map<String, dynamic>;
    final events = j['events'] as Map<String, dynamic>;
    final firstView = (j['map'] as Map<String, dynamic>)['firstView'] as Map<String, dynamic>;
    final hud = j['hud'] as Map<String, dynamic>;
    final bigView = (j['ui'] as Map<String, dynamic>)['bigView'] as Map<String, dynamic>;
    final walk = j['walk'] as Map<String, dynamic>;
    final sources = j['allowedSources'] as Map<String, dynamic>;
    final companions = j['companions'] as Map<String, dynamic>;
    final companionPace = companions['pace'] as Map<String, dynamic>;
    final shop = j['shop'] as Map<String, dynamic>;
    final ads = j['ads'] as Map<String, dynamic>;
    final tap = (j['character'] as Map<String, dynamic>)['tapReaction'] as Map<String, dynamic>;
    final tapAngry = tap['angry'] as Map<String, dynamic>;
    final tapReaction = TapReaction(
      happyMaxTaps: tap['happyMaxTaps'] as int,
      angryWindowSec: _d(tapAngry['windowSec']),
      angryTaps: tapAngry['taps'] as int,
      angryHoldSec: _d(tapAngry['holdSec']),
    );
    if (tapReaction.angryTaps < 2 || tapReaction.angryWindowSec <= 0) {
      throw const FormatException('character.tapReaction.angry는 2번 이상, 창 0초 초과여야 한다');
    }

    LatLng latLng(dynamic v) => LatLng(_d(v['lat']), _d(v['lng']));
    Bounds bounds(dynamic v) =>
        Bounds(_d(v['latMin']), _d(v['latMax']), _d(v['lngMin']), _d(v['lngMax']));
    final islandJson = route['islands'] as Map<String, dynamic>;

    SceneLayerId layerId(String name) =>
        SceneLayerId.values.asNameMap()[name] ?? (throw FormatException('모르는 레이어: $name'));
    // speed가 없는 항목은 레이어가 아니라 조각 묶음이다 (people: 11/4 쓰지 않음)
    final layers = {
      for (final e in (scene['layers'] as Map<String, dynamic>).entries)
        if (e.value['speed'] != null) layerId(e.key): SceneLayer(
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

    // 랩 길이가 0 이하면 랩을 끊을 수 없다
    if (_d(record['lapKm']) <= 0) throw const FormatException('record.lapKm는 0보다 커야 한다');

    // 보너스는 늘려 주는 것이라 1배 미만이면 거리·럭이 줄어든다. 구현한 적용 범위는 하나뿐이다
    if (bonus['appliesTo'] != 'qualifiedSession') {
      throw FormatException('bonus.appliesTo를 모른다: ${bonus['appliesTo']}');
    }
    if (_d(bonus['travelMultiplier']) < 1) {
      throw const FormatException('bonus.travelMultiplier는 1 이상이어야 한다');
    }
    if (_d(bonus['coinMultiplier']) < 1) {
      throw const FormatException('bonus.coinMultiplier는 1 이상이어야 한다');
    }
    if (_dn(coins['perKm']) case final perKm? when perKm < 0) {
      throw const FormatException('coins.perKm는 0 이상이거나 null이어야 한다');
    }
    if ((coins['dailyCap'] as int) <= 0) {
      throw const FormatException('coins.dailyCap은 0보다 커야 한다');
    }
    if ((trailStart['steps'] as int) <= 0 || (trailStart['withinSec'] as int) <= 0) {
      throw const FormatException('paintTrail.startMinSteps의 걸음·초는 0보다 커야 한다');
    }
    if (((paintTrail['idleEndMin'] as Map)['min'] as int) <= 0) {
      throw const FormatException('paintTrail.idleEndMin.min은 0보다 커야 한다');
    }
    if (_d((paintDrop['spacingM'] as Map)['m']) <= 0) {
      throw const FormatException('paintDrop.spacingM.m은 0보다 커야 한다');
    }
    // 구현한 거리 기준은 하나씩이다 (M1 명세 v0.5 ①·④)
    if ((j['props'] as Map)['distanceBasis'] != 'actualAll') {
      throw FormatException('props.distanceBasis를 모른다: ${(j['props'] as Map)['distanceBasis']}');
    }
    if (events['distanceBasis'] != 'paintTrailActual') {
      throw FormatException('events.distanceBasis를 모른다: ${events['distanceBasis']}');
    }
    if ((coins['welcomeGift'] as int) < 0) {
      throw const FormatException('coins.welcomeGift는 0 이상이어야 한다');
    }
    if ((sync['aliveSaveSec'] as int) <= 0) {
      throw const FormatException('sync.aliveSaveSec는 0보다 커야 한다');
    }
    if ((sync['backgroundMin'] as int) < 15) {
      throw const FormatException('sync.backgroundMin은 15(안드로이드 최소) 이상이어야 한다');
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
      aliveSaveSec: sync['aliveSaveSec'] as int,
      backgroundSyncMin: sync['backgroundMin'] as int,
      liveCadenceWindowSec: live['cadenceWindowSec'] as int,
      liveNoticeUpdateSec: live['noticeUpdateSec'] as int,
      lapKm: _d(record['lapKm']),
      bonusTravelMultiplier: _d(bonus['travelMultiplier']),
      bonusCoinMultiplier: _d(bonus['coinMultiplier']),
      paintTrailStartSteps: trailStart['steps'] as int,
      paintTrailStartWithinSec: trailStart['withinSec'] as int,
      paintTrailIdleEndMin: (paintTrail['idleEndMin'] as Map)['min'] as int,
      paintDropCoinsPerKm: _d(paintDrop['coinsPerKm']),
      paintDropSpacingM: _d((paintDrop['spacingM'] as Map)['m']),
      paintDropCoinsPerDrop: paintDrop['coinsPerDrop'] as int,
      coinsPerKm: _dn(coins['perKm']),
      coinsDailyCap: coins['dailyCap'] as int,
      coinsWelcomeGift: coins['welcomeGift'] as int,
      coinAmountFormat: (coins['format'] as Map)['amount'] as String,
      coinBuyQuestion: (coins['format'] as Map)['buyQuestion'] as String,
      coinBuyButton: (coins['format'] as Map)['buyButton'] as String,
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
      characterCanvasHeightPx:
          _d(((j['character'] as Map<String, dynamic>)['canvas'] as Map<String, dynamic>)['heightPx']),
      characterHeightLandscapePx: _d(((j['character'] as Map<String, dynamic>)['canvas']
          as Map<String, dynamic>)['screenHeightPx']['landscape']),
      rest: RestRules(
        zoomMin: _d(restZoom['min']),
        zoomMax: _d(restZoom['max']),
        snapEdgesWhenZoomed: restZoom['snapEdgesWhenZoomed'] as bool,
        snapToEnds: restDrag['snapToEnds'] as bool,
        farParallax: _d(restDrag['farParallax']),
        snapSec: _d(restDrag['snapSec']),
      ),
      seasonTint: {
        for (final e in (scene['seasonTint'] as Map<String, dynamic>).entries)
          if (e.value is Map)
            e.key: SeasonTint(
              layers: {for (final n in (e.value as Map)['layers'] as List) layerId(n as String)},
              multiply: _hex((e.value as Map)['multiply'] as String),
              strength: _d((e.value as Map)['strength']),
              saturation: _dn((e.value as Map)['saturation']) ?? 0,
              brightness: _dn((e.value as Map)['brightness']) ?? 0,
            ),
      },
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
      notificationQuietFromHour: notifications['quietFromHour'] as int,
      notificationQuietToHour: notifications['quietToHour'] as int,
      notificationNearDestKm: _d(notifications['nearDestKm']),
      notificationInactiveHours: notifications['inactiveHours'] as int,
      notificationInactiveDeferHour: notifications['inactiveDeferHour'] as int,
      guestbookMaxChars: guestbook['maxChars'] as int,
      guestbookWindowSteps: guestbook['milestoneWindowSteps'] as int,
      eventEveryKm: _d(events['everyKm']),
      eventFlushSec: events['flushSec'] as int,
      eventOffScreenCards: events['offScreenCards'] as int,
      eventCardSec: _d(hud['eventCardSec']),
      stampLineSec: _d(hud['stampLineSec']),
      arrivalProbeSec: walk['arrivalProbeSec'] as int,
      mapFirstViewMinLandmarks: firstView['minLandmarks'] as int,
      mapFirstViewMargin: _d(firstView['margin']),
      bigViewMaxZoom: _d(bigView['maxZoom']),
      bigViewSavedToastSec: _d(bigView['savedToastSec']),
      backupMinIntervalMin: backup['minIntervalMin'] as int,
      backupMaxChars: backup['maxChars'] as int,
      allowedSourcesIos: (sources['ios'] as List).cast<String>(),
      allowedSourcesAndroid: (sources['android'] as List).cast<String>(),
      tapReaction: tapReaction,
      companionGuaranteeDays: (companions['guaranteeByDay'] as List).cast<int>(),
      companionWalksPerChapter: companions['walksPerChapter'] as int,
      companionChapters: companions['chapters'] as int,
      companionMeetChanceMatch: _d((companions['meetChance'] as Map)['terrainMatch']),
      companionMeetChanceOther: _d((companions['meetChance'] as Map)['other']),
      companionAheadEverySec: _d(companionPace['aheadEverySec']),
      companionAheadAwaySec: _d(companionPace['aheadAwaySec']),
      companionWalkMps: _d(companionPace['walkMps']),
      companionLagCatchUpMps: _d(companionPace['lagCatchUpMps']),
      companionLateArrivalMaxSec: _d(companionPace['lateArrivalMaxSec']),
      shopDailyEffectCapKm: _d(shop['dailyEffectCapKm']),
      shopMaxHoldPerItem: shop['maxHoldPerItem'] as int,
      adsRewardedPerDay: ads['rewardedPerDay'] as int,
      adsMaxRewardCoins: ads['maxRewardCoins'] as int,
    );
  }
}

double _d(dynamic v) => (v as num).toDouble();

double? _dn(dynamic v) => v == null ? null : _d(v);

/// "#RRGGBB" → 불투명 ARGB
int _hex(String s) => 0xFF000000 | int.parse(s.substring(1), radix: 16);
