// 지도·화집 (T18, 16장 11/19·11/20): 연필 선 지도와 핀(config map.style), 지도 카드 그림 칸
// (map.card.paintingSlot), 화집 탭(album.tabs)·소품 바로 입기(album.propsTab)·가진 것만(album.ownedOnly)·
// 크게 보기 가로(album.bigView). 모양은 문자열 값이라 아는 값만 받고, 모르는 값이면 FormatException

/// 연필로 그릴 수 있는 선 (map.style.lines.pencil)
const mapPencilLines = {'regionBorders', 'offAppTrail', 'nextRoute', 'seaRoute'};

/// 화집 탭으로 쓸 수 있는 것 (album.tabs). 도장은 11/19부터 나 탭이라 여기 없다
const albumTabIds = {'paintings', 'props', 'paints'};

class MapAlbumRules {
  const MapAlbumRules({
    required this.map,
    required this.paintingSlot,
    required this.albumTabs,
    required this.propsTab,
    required this.ownedOnly,
    required this.bigView,
  });

  /// [j]는 config.json 전체
  factory MapAlbumRules.fromJson(Map<String, dynamic> j) {
    final map = j['map'] as Map<String, dynamic>;
    final album = j['album'] as Map<String, dynamic>;
    final tabs = [for (final t in album['tabs'] as List) t as String];
    for (final t in tabs) {
      if (!albumTabIds.contains(t)) throw FormatException('album.tabs: 모르는 탭 $t');
    }
    if (tabs.isEmpty || tabs.toSet().length != tabs.length) {
      throw const FormatException('album.tabs: 비었거나 겹친다');
    }
    return MapAlbumRules(
      map: MapStyleRules.fromJson(map['style'] as Map<String, dynamic>),
      paintingSlot: PaintingSlotRules.fromJson(
        (map['card'] as Map<String, dynamic>)['paintingSlot'] as Map<String, dynamic>,
      ),
      albumTabs: List.unmodifiable(tabs),
      propsTab: PropsTabRules.fromJson(album['propsTab'] as Map<String, dynamic>),
      ownedOnly: album['ownedOnly'] as bool,
      bigView: BigViewRules.fromJson(album['bigView'] as Map<String, dynamic>),
    );
  }

  final MapStyleRules map;
  final PaintingSlotRules paintingSlot;

  /// 화집 탭 차례 (paintings·props·paints)
  final List<String> albumTabs;
  final PropsTabRules propsTab;

  /// 배낭(화집)은 가진 것만: 안 가진 칸·예시·잠긴 칸 없음 (16장 11/20)
  final bool ownedOnly;
  final BigViewRules bigView;
}

/// 지도 연필 선·핀 (map.style, 디자인 기획 캔버스 4-1). 크기·색은 캔버스 값이라 그리는 쪽(ui/map)에 둔다
class MapStyleRules {
  const MapStyleRules({
    required this.pencil,
    required this.nextRouteDashed,
    required this.jitterPt,
    required this.unvisitedCircle,
    required this.visitedPin,
    required this.destinationFlag,
    required this.pinsNonScaling,
  });

  factory MapStyleRules.fromJson(Map<String, dynamic> j) {
    final lines = j['lines'] as Map<String, dynamic>;
    final pencil = {for (final l in lines['pencil'] as List) l as String};
    for (final l in pencil) {
      if (!mapPencilLines.contains(l)) throw FormatException('map.style.lines.pencil: 모르는 선 $l');
    }
    final next = lines['nextRoute'] as String;
    if (next != 'pencilDashed' && next != 'pencil') {
      throw FormatException('map.style.lines.nextRoute: 모르는 값 $next');
    }
    final jitter = (lines['jitterPt'] as num).toDouble();
    if (jitter < 0) throw const FormatException('map.style.lines.jitterPt는 0 이상');
    final unvisited = j['unvisited'] as String;
    if (unvisited != 'pencilCircle' && unvisited != 'faint') {
      throw FormatException('map.style.unvisited: 모르는 값 $unvisited');
    }
    final visited = (j['visited'] as Map<String, dynamic>)['kind'] as String;
    if (visited != 'pushPin' && visited != 'dot') {
      throw FormatException('map.style.visited.kind: 모르는 값 $visited');
    }
    final dest = j['destination'] as String;
    if (dest != 'paperFlagPin' && dest != 'dot') {
      throw FormatException('map.style.destination: 모르는 값 $dest');
    }
    return MapStyleRules(
      pencil: Set.unmodifiable(pencil),
      nextRouteDashed: next == 'pencilDashed',
      jitterPt: jitter,
      unvisitedCircle: unvisited == 'pencilCircle',
      visitedPin: visited == 'pushPin',
      destinationFlag: dest == 'paperFlagPin',
      pinsNonScaling: j['pinsNonScaling'] as bool,
    );
  }

  /// 살짝 떨리는 연필로 긋는 선 ([mapPencilLines] 중)
  final Set<String> pencil;

  /// 다음 길(지금 자리 → 목적지)을 점선으로
  final bool nextRouteDashed;

  /// 연필 선이 떨리는 폭 (화면 pt, 가안)
  final double jitterPt;

  /// 안 가 본 명소 = 연필 동그라미 (아니면 흐린 점)
  final bool unvisitedCircle;

  /// 다녀온 명소 = 압정 핀, 머리 색은 그 그림 액자 등급 (아니면 점)
  final bool visitedPin;

  /// 목적지 = 종이 깃발 핀
  final bool destinationFlag;

  /// 핀은 확대해도 화면 크기 그대로
  final bool pinsNonScaling;

  bool isPencil(String line) => pencil.contains(line);
}

/// 지도 현재 목적지·명소 카드의 그림 칸 (map.card.paintingSlot, 16장 11/19 밤 창구 Q004)
class PaintingSlotRules {
  const PaintingSlotRules({
    required this.count,
    required this.emptyDashed,
    required this.filledThumbnail,
    required this.tapBigView,
  });

  factory PaintingSlotRules.fromJson(Map<String, dynamic> j) {
    final count = j['count'] as int;
    if (count < 1) throw const FormatException('map.card.paintingSlot.count는 1 이상');
    final empty = j['empty'] as String;
    if (empty != 'pencilDashed') throw FormatException('map.card.paintingSlot.empty: 모르는 값 $empty');
    final filled = j['filled'] as String;
    if (!filled.startsWith('frameGradeColor')) {
      throw FormatException('map.card.paintingSlot.filled: 모르는 값 $filled');
    }
    return PaintingSlotRules(
      count: count,
      emptyDashed: true,
      filledThumbnail: filled.contains('thumbnail'),
      tapBigView: j['tap'] == 'bigView',
    );
  }

  /// 칸 수 (MVP 1, 3칸은 출시 뒤)
  final int count;

  /// 받기 전 칸은 연필 점선
  final bool emptyDashed;

  /// 받은 칸은 액자 색 + 썸네일
  final bool filledThumbnail;

  /// 받은 칸을 누르면 크게 보기
  final bool tapBigView;
}

/// 화집 소품 탭 바로 입기 (album.propsTab, 16장 11/19)
class PropsTabRules {
  const PropsTabRules({
    required this.tapToWear,
    required this.tapAgainRemoves,
    required this.neverRemove,
    required this.joyTrigger,
    required this.joySec,
    required this.toast,
  });

  factory PropsTabRules.fromJson(Map<String, dynamic> j) {
    final joy = j['joy'] as Map<String, dynamic>;
    final sec = (joy['sec'] as num).toDouble();
    if (sec <= 0) throw const FormatException('album.propsTab.joy.sec는 0보다 커야 한다');
    return PropsTabRules(
      tapToWear: j['tapToWear'] as bool,
      tapAgainRemoves: j['tapAgainRemoves'] as bool,
      neverRemove: Set.unmodifiable({for (final s in j['neverRemove'] as List) s as String}),
      joyTrigger: joy['trigger'] as String,
      joySec: sec,
      toast: j['toast'] as bool,
    );
  }

  /// 누르면 바로 입는다 (같은 칸은 바뀜)
  final bool tapToWear;

  /// 입은 것을 다시 누르면 벗는다
  final bool tapAgainRemoves;

  /// 다시 눌러도 벗지 않는 칸 (옷 — 옷 없는 정령 없음)
  final Set<String> neverRemove;

  /// 입으면 위 정령이 잠깐 기뻐한다: Rive 트리거와 표정을 둘 시간(초)
  final String joyTrigger;
  final double joySec;

  /// 한 줄 토스트
  final bool toast;
}

/// 그림 크게 보기 화면 방향 (album.bigView, 16장 11/19 Annie): 폰을 돌리면 가로(센서, 버튼 없음), 닫으면 세로
class BigViewRules {
  const BigViewRules({required this.landscape, required this.portraitOnClose});

  factory BigViewRules.fromJson(Map<String, dynamic> j) {
    final rotate = j['rotate'] as String;
    if (rotate != 'sensor') throw FormatException('album.bigView.rotate: 모르는 값 $rotate');
    return BigViewRules(
      landscape: j['landscape'] as bool,
      portraitOnClose: j['portraitOnClose'] as bool,
    );
  }

  /// 크게 보기에서 가로로 돌릴 수 있다 (ui.orientation.landscape에도 bigView가 있어야 한다)
  final bool landscape;

  /// 닫으면 세로로 돌아온다
  final bool portraitOnClose;
}
