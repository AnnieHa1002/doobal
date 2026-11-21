import 'dart:math';

/// 화면 세부 (16장 11/13 ‘화면 세부 4건’, config ui.newDot·ui.orientation·character.rive.customizePreview)와
/// 정령 화면별 자세·방향 (16장 11/11 앉기·11/13 v32, config character.rive.poses·screens·restSwap·flipSideOn)
class ScreenRules {
  const ScreenRules({
    required this.newDots,
    required this.cartDotWhen,
    required this.landscapeScreens,
    required this.spirit,
    this.tabs = TabRules.fallback,
  });

  /// [config]는 config.json 전체
  factory ScreenRules.fromJson(Map<String, dynamic> config) {
    final ui = config['ui'] as Map<String, dynamic>;
    final dot = ui['newDot'] as Map<String, dynamic>;
    final orientation = ui['orientation'] as Map<String, dynamic>;
    if (orientation['others'] != 'portrait') {
      throw FormatException('ui.orientation.others는 portrait만 안다: ${orientation['others']}');
    }
    final on = {for (final s in dot['on'] as List) s as String};
    final unknown = on.difference(newDotPlaces);
    if (unknown.isNotEmpty) throw FormatException('ui.newDot.on에 모르는 자리: $unknown');
    final rive = (config['character'] as Map<String, dynamic>)['rive'] as Map<String, dynamic>;
    return ScreenRules(
      newDots: on,
      cartDotWhen: dot['cartWhen'] as String?,
      landscapeScreens: {for (final s in orientation['landscape'] as List) s as String},
      spirit: SpiritStageRules.fromJson(rive),
      tabs: TabRules.fromJson(config),
    );
  }

  /// 아래 탭 바·쉼터 옆 버튼·걷기 탭 표지판 (16장 11/18·11/19)
  final TabRules tabs;

  /// 새 소식 점이 붙는 자리 (ui.newDot.on: backpack·companion·cart). 노트에는 없다
  final Set<String> newDots;

  /// 수레 점의 조건 (ui.newDot.cartWhen, 지금 newShopItem 하나)
  final String? cartDotWhen;

  /// 가로로 돌릴 수 있는 화면 (ui.orientation.landscape). 나머지는 세로 고정
  final Set<String> landscapeScreens;

  final SpiritStageRules spirit;

  bool dotOn(String place) => newDots.contains(place);

  /// 수레 점: 상점에 새 상품이 들어왔을 때만
  bool get cartDotOnNewItem => dotOn('cart') && cartDotWhen == 'newShopItem';
}

/// ui.newDot.on에 올 수 있는 자리
const newDotPlaces = {'backpack', 'companion', 'cart'};

/// 아래 탭 (config ui.tabs.items). 순서가 탭 바의 왼쪽부터다
const tabIds = {'rest', 'walk', 'me'};

/// 쉼터 옆 세로 버튼 (config rest.sideButtons.items)
const sideButtonIds = {'map', 'backpack', 'shop', 'decorate'};

/// 걷기 탭 아이콘에 점을 붙이는 일 (config ui.tabs.dots.walk)
const walkDotKinds = {'companionStory', 'guestbookSign'};

/// 화면 3탭 (16장 11/18 ①④⑤⑥·11/19, config ui.tabs·rest.sideButtons·guestbook.sign, M2~M6 AB·AC).
/// 걸어도 탭은 저절로 바뀌지 않는다 (ui.tabs.autoSwitch false만 안다)
class TabRules {
  const TabRules({
    required this.items,
    required this.labels,
    required this.openTo,
    required this.landscapeHidesBar,
    required this.walkDots,
    required this.sideButtons,
    required this.signScreenX,
    required this.spiritLongPressCustomize,
  });

  /// [config]는 config.json 전체
  factory TabRules.fromJson(Map<String, dynamic> config) {
    final tabs = (config['ui'] as Map<String, dynamic>)['tabs'] as Map<String, dynamic>;
    final items = [for (final t in tabs['items'] as List) t as String];
    if (items.toSet().length != items.length || !tabIds.containsAll(items) || items.length != tabIds.length) {
      throw FormatException('ui.tabs.items는 rest·walk·me 한 번씩: $items');
    }
    if (tabs['autoSwitch'] != false) {
      throw const FormatException('ui.tabs.autoSwitch는 false만 안다 (16장 11/18 ⑤)');
    }
    final labels = {
      for (final e in (tabs['labels'] as Map<String, dynamic>).entries) e.key: e.value as String,
    };
    if (!labels.keys.toSet().containsAll(items)) throw FormatException('ui.tabs.labels가 모자라다: $labels');
    final openTo = (tabs['openTo'] as Map<String, dynamic>)['value'] as String;
    if (!items.contains(openTo)) throw FormatException('ui.tabs.openTo가 탭이 아니다: $openTo');
    final dots = tabs['dots'] as Map<String, dynamic>? ?? const {};
    final walkDots = {for (final d in dots['walk'] as List? ?? const []) d as String};
    if (!walkDotKinds.containsAll(walkDots)) throw FormatException('ui.tabs.dots.walk에 모르는 점: $walkDots');
    final side = (config['rest'] as Map<String, dynamic>)['sideButtons'] as Map<String, dynamic>;
    final buttons = [for (final b in side['items'] as List) b as String];
    if (!sideButtonIds.containsAll(buttons)) throw FormatException('rest.sideButtons.items에 모르는 버튼: $buttons');
    final sign = (config['guestbook'] as Map<String, dynamic>?)?['sign'] as Map<String, dynamic>?;
    final signX = (sign?['screenX'] as num?)?.toDouble() ?? fallback.signScreenX;
    if (signX <= 0 || signX >= 1) throw FormatException('guestbook.sign.screenX는 0~1 사이: $signX');
    final tap = (config['character'] as Map<String, dynamic>)['tapReaction'] as Map<String, dynamic>;
    final long = tap['longPress'] as Map<String, dynamic>?;
    return TabRules(
      items: items,
      labels: labels,
      openTo: openTo,
      landscapeHidesBar: tabs['landscapeHidesBar'] as bool? ?? true,
      walkDots: walkDots,
      sideButtons: buttons,
      signScreenX: signX,
      spiritLongPressCustomize: long?['screen'] == 'rest' && long?['opens'] == 'customize',
    );
  }

  /// config v30 값 (시험·옛 데이터에서 ScreenRules를 직접 만들 때)
  static const fallback = TabRules(
    items: ['rest', 'walk', 'me'],
    labels: {'rest': '쉼터', 'walk': '걷기', 'me': '나'},
    openTo: 'rest',
    landscapeHidesBar: true,
    walkDots: {'companionStory', 'guestbookSign'},
    sideButtons: ['map', 'backpack', 'shop', 'decorate'],
    signScreenX: 0.78,
    spiritLongPressCustomize: true,
  );

  /// 탭 순서 (rest·walk·me)
  final List<String> items;

  /// 탭 이름 (쉼터·걷기·나)
  final Map<String, String> labels;

  /// 앱을 열 때의 탭 (가안 rest)
  final String openTo;

  /// 걷기 탭을 가로로 돌리면 탭 바를 숨긴다
  final bool landscapeHidesBar;

  /// 걷기 탭 아이콘에 점을 붙이는 일 (안 읽은 이야기·방명록 쓸 기회)
  final Set<String> walkDots;

  /// 쉼터 옆 세로 버튼 (위에서부터)
  final List<String> sideButtons;

  /// 걷기 탭 방명록 표지판의 왼쪽 끝 (화면 폭 비율, 캔버스 3-1 왼쪽 298/390)
  final double signScreenX;

  /// 쉼터에서 정령을 길게 누르면 정령 꾸미기 (config character.tapReaction.longPress, 16장 11/19 ③)
  final bool spiritLongPressCustomize;
}

/// 정령 자세 번호와 화면별 자세 (config character.rive, 정령 계약 3장)
class SpiritStageRules {
  const SpiritStageRules({
    required this.poses,
    required this.screens,
    required this.restSwap,
    required this.sideFacesLeft,
    required this.flipSideOn,
    required this.customizeSwipe,
    required this.customizeExprButton,
    required this.walkPlayback,
  });

  /// [rive]는 config character.rive
  factory SpiritStageRules.fromJson(Map<String, dynamic> rive) {
    final poses = {
      for (final e in (rive['poses'] as Map<String, dynamic>).entries) e.key: e.value as int,
    };
    int pose(String name, String where) =>
        poses[name] ?? (throw FormatException('character.rive.$where: 모르는 자세 $name'));
    final screens = {
      for (final e in (rive['screens'] as Map<String, dynamic>).entries) e.key: e.value as String,
    };
    for (final e in screens.entries) {
      if (e.value != restSwapName) pose(e.value, 'screens.${e.key}');
    }
    final swap = rive['restSwap'] as Map<String, dynamic>;
    final swapPoses = [for (final p in swap['poses'] as List) pose(p as String, 'restSwap.poses')];
    final minSec = (swap['minSec'] as num).toDouble();
    final maxSec = (swap['maxSec'] as num).toDouble();
    if (swapPoses.isEmpty || minSec <= 0 || maxSec < minSec) {
      throw const FormatException('character.rive.restSwap: 자세가 하나 이상, 0 < minSec ≤ maxSec');
    }
    final preview = rive['customizePreview'] as Map<String, dynamic>;
    final swipe = [
      for (final p in preview['swipe'] as List) pose(p as String, 'customizePreview.swipe'),
    ];
    if (swipe.isEmpty) throw const FormatException('character.rive.customizePreview.swipe가 비었다');
    final playback = rive['walkPlayback'] as Map<String, dynamic>;
    return SpiritStageRules(
      poses: poses,
      screens: screens,
      restSwap: RestSwapRules(
        poses: swapPoses,
        minSec: minSec,
        maxSec: maxSec,
        noRepeat: swap['noRepeat'] as bool? ?? true,
        night: pose(swap['night'] as String, 'restSwap.night'),
      ),
      sideFacesLeft: rive['sideFacesLeft'] as bool? ?? true,
      flipSideOn: {for (final s in rive['flipSideOn'] as List? ?? const []) s as String},
      customizeSwipe: swipe,
      customizeExprButton: preview['exprButton'] as bool? ?? false,
      walkPlayback: WalkPlaybackRules.fromJson(playback),
    );
  }

  /// 자세 이름 → poseChoice (floatFront 0 …)
  final Map<String, int> poses;

  /// 화면 → 자세 이름 (쉼터는 [restSwapName])
  final Map<String, String> screens;
  final RestSwapRules restSwap;

  /// riv의 옆모습(1·3·6)이 왼쪽을 보는가
  final bool sideFacesLeft;

  /// 옆모습을 좌우로 뒤집어 오른쪽을 보게 하는 화면 (걷는 중)
  final Set<String> flipSideOn;

  /// 꾸미기 미리보기를 밀 때 도는 자세 차례 (정면 → 옆 → 뒤)
  final List<int> customizeSwipe;

  /// 꾸미기 표정 미리보기 단추 (16장 11/13: 없음)
  final bool customizeExprButton;

  /// 걷는 중 걷기·뛰기 동작의 재생 빠르기 (16장 11/19)
  final WalkPlaybackRules walkPlayback;

  /// [screen] 화면의 자세 번호. 쉼터(restSwap)는 바꾸기 첫 자세
  int poseOf(String screen) {
    final name = screens[screen];
    if (name == null) throw ArgumentError.value(screen, 'screen', 'character.rive.screens에 없는 화면');
    return name == restSwapName ? restSwap.poses.first : poses[name]!;
  }

  /// [screen]에서 정령 그림을 좌우로 뒤집는가: 오른쪽을 봐야 하는 화면([flipSideOn])인데 riv 옆모습이 왼쪽을 볼 때
  bool flips(String screen) => sideFacesLeft && flipSideOn.contains(screen);
}

/// config screens에서 쉼터 자세 바꾸기를 뜻하는 이름
const restSwapName = 'restSwap';

/// 쉼터 정령 떠 있기↔앉기 무작위 (config character.rive.restSwap, 16장 11/11 가안 20~40초)
class RestSwapRules {
  const RestSwapRules({
    required this.poses,
    required this.minSec,
    required this.maxSec,
    required this.noRepeat,
    required this.night,
  });

  /// 바꿔 가며 보여 줄 자세 (떠 있기 정면·앉기 정면·앉기 옆)
  final List<int> poses;
  final double minSec;
  final double maxSec;

  /// 같은 자세를 연달아 고르지 않는다
  final bool noRepeat;

  /// 밤 쉼터의 자세 (잠들기)
  final int night;
}

/// 다음 쉼터 자세: [current]가 있고 noRepeat면 그것과 다른 자세 중 무작위 (자세가 하나뿐이면 그것)
int nextRestPose(RestSwapRules r, int? current, Random random) {
  final pool = r.noRepeat && current != null && r.poses.length > 1
      ? [for (final p in r.poses) if (p != current) p]
      : r.poses;
  return pool[random.nextInt(pool.length)];
}

/// 다음 자세로 바꿀 때까지의 시간: minSec~maxSec 사이 고르게 (밀리초 단위)
Duration nextRestGap(RestSwapRules r, Random random) => Duration(
      milliseconds: ((r.minSec + (r.maxSec - r.minSec) * random.nextDouble()) * 1000).round(),
    );

/// 정령 표정 신호 하나: Rive expr 번호와 그 표정을 둘 시간 (null이면 다른 신호가 올 때까지 그대로)
class SpiritCue {
  const SpiritCue(this.expr, {this.holdSec, this.trigger});

  final int expr;
  final double? holdSec;

  /// 같이 울릴 동작 트리거 (joy·greet, 정령 계약 4장). 없으면 표정만
  final String? trigger;

  SpiritCue withTrigger(String trigger) => SpiritCue(expr, holdSec: holdSec, trigger: trigger);
}

/// 표정 호출 표 (palette.json customPartsV33 expressions·expressionTriggers·holdSec, 16장 11/3·11/4,
/// 정령 계약 4장): 일(arrival·paintingGet·tap·companionMeet·newProp·nightRest·rapidTap …) → 표정
class SpiritCues {
  const SpiritCues(this._byEvent, [this._exprIds = const {}]);

  /// [parts]는 palette.json customPartsV33
  factory SpiritCues.fromJson(Map<String, dynamic> parts) {
    final rive = {
      for (final e in parts['expressions'] as List)
        (e as Map<String, dynamic>)['id'] as String: e['rive'] as int,
    };
    final hold = parts['holdSec'] as Map<String, dynamic>? ?? const {};
    final byEvent = <String, SpiritCue>{};
    for (final e in (parts['expressionTriggers'] as Map<String, dynamic>).entries) {
      final expr = rive[e.key] ?? (throw FormatException('expressionTriggers: 모르는 표정 ${e.key}'));
      final sec = hold[e.key];
      for (final event in e.value as List) {
        if (byEvent.containsKey(event)) throw FormatException('expressionTriggers: $event가 두 표정에 있다');
        byEvent[event as String] = SpiritCue(expr, holdSec: sec is num ? sec.toDouble() : null);
      }
    }
    return SpiritCues(byEvent, rive);
  }

  final Map<String, SpiritCue> _byEvent;

  /// 표정 id(happy·surprised …) → Rive expr 번호
  final Map<String, int> _exprIds;

  /// [event]의 표정. 표에 없으면 null
  SpiritCue? of(String event) => _byEvent[event];

  /// 표정 id [id]의 Rive expr 번호 (config ui.motion.restPet.expr처럼 표정을 이름으로 부를 때). 없으면 null
  int? exprOf(String id) => _exprIds[id];
}

/// 걷는 중 정령 걷기·뛰기 동작의 재생 빠르기 (config character.rive.walkPlayback, 16장 11/19 가안):
/// 분당 걸음 ÷ [refStepsPerMin]을 [min]~[max]로 자른다 (분당 100보 = 1배, 0.7~1.6배)
class WalkPlaybackRules {
  const WalkPlaybackRules({required this.refStepsPerMin, required this.min, required this.max});

  factory WalkPlaybackRules.fromJson(Map<String, dynamic> j) {
    final ref = (j['refStepsPerMin'] as num).toDouble();
    final lo = (j['min'] as num).toDouble();
    final hi = (j['max'] as num).toDouble();
    if (ref <= 0 || lo <= 0 || hi < lo) {
      throw const FormatException('character.rive.walkPlayback: refStepsPerMin > 0, 0 < min ≤ max');
    }
    return WalkPlaybackRules(refStepsPerMin: ref, min: lo, max: hi);
  }

  /// 1배가 되는 분당 걸음
  final double refStepsPerMin;

  /// 재생 빠르기 아래·위 끝
  final double min;
  final double max;

  /// 분당 걸음 [stepsPerMin]일 때 재생 빠르기. 걸음이 없으면(0 이하) 1배 (서 있는 동작은 늘 1배다)
  double rateFor(int stepsPerMin) =>
      stepsPerMin <= 0 ? 1 : (stepsPerMin / refStepsPerMin).clamp(min, max).toDouble();
}
