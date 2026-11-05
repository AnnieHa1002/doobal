import 'sky.dart';

// 배 9척 (boats.json v2, M4.5): 보상 배 3 + 상점 배 6. 배 구간 그림만 바뀌고 진행·거리와는 무관하다

/// 배를 얻는 길 (boats.json unlock.kind, default는 예약어라 initial)
enum BoatUnlockKind { initial, islandArrival, shop }

/// 캔버스 위 한 점 (px)
typedef BoatPoint = ({double x, double y});

/// 배 그림 판과 발 자리. 앞판·뒤판은 같은 원점이라 같은 변환으로 그린다
class BoatLayers {
  const BoatLayers({
    required this.rear,
    required this.front,
    required this.full,
    required this.mainFoot,
    required this.companionFoot,
  });

  final String rear;
  final String front;
  final String full;
  final BoatPoint mainFoot;
  final BoatPoint companionFoot;

  factory BoatLayers.fromJson(Map<String, dynamic> j) => BoatLayers(
        rear: j['rear'] as String,
        front: j['front'] as String,
        full: j['full'] as String,
        mainFoot: _point(j['mainFoot']),
        companionFoot: _point(j['companionFoot']),
      );
}

/// 배 한 척. [islands]·[allIslands]는 islandArrival, [price]는 shop에만 있다
class Boat {
  const Boat({
    required this.id,
    required this.name,
    required this.order,
    required this.kind,
    required this.layers,
    this.islands = const [],
    this.allIslands = false,
    this.price,
    this.nightOverlay,
  });

  final String id;
  final String name;
  final int order;
  final BoatUnlockKind kind;
  final BoatLayers layers;

  /// 도착해야 하는 섬 (landmark island 이름)
  final List<String> islands;

  /// true면 [islands]를 모두, false면 하나라도
  final bool allIslands;
  final int? price;

  /// 밤·새벽에만 얹는 창 불빛 그림
  final String? nightOverlay;

  factory Boat.fromJson(Map<String, dynamic> j) {
    final u = j['unlock'] as Map<String, dynamic>;
    return Boat(
      id: j['id'] as String,
      name: j['name'] as String,
      order: j['order'] as int,
      kind: switch (u['kind']) {
        'default' => BoatUnlockKind.initial,
        'islandArrival' => BoatUnlockKind.islandArrival,
        'shop' => BoatUnlockKind.shop,
        final k => throw FormatException('모르는 배 해금 조건: $k (${j['id']})'),
      },
      layers: BoatLayers.fromJson(j['layers'] as Map<String, dynamic>),
      islands: (u['islands'] as List?)?.cast<String>() ?? const [],
      allIslands: u['all'] as bool? ?? false,
      price: u['price'] as int?,
      nightOverlay: j['nightOverlay'] as String?,
    );
  }
}

/// boats.json 전체
class BoatCatalog {
  BoatCatalog({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.deckY,
    required this.assetDir,
    required this.boats,
  });

  final double canvasWidth;
  final double canvasHeight;

  /// 갑판 기준선 (정령 발을 여기에 맞춘다)
  final double deckY;

  /// assets 아래 그림 폴더
  final String assetDir;

  /// order 순서
  final List<Boat> boats;

  late final Map<String, Boat> _byId = {for (final b in boats) b.id: b};

  Boat? byId(String id) => _byId[id];

  /// 그림 파일의 에셋 경로
  String assetPath(String file) => 'assets/$assetDir/$file';

  /// 장면이 읽을 [boat]의 그림 경로와 자리
  BoatArt artOf(Boat boat) => BoatArt(
        id: boat.id,
        rear: assetPath(boat.layers.rear),
        front: assetPath(boat.layers.front),
        nightOverlay: boat.nightOverlay == null ? null : assetPath(boat.nightOverlay!),
        mainFoot: boat.layers.mainFoot,
        companionFoot: boat.layers.companionFoot,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
      );
}

/// 장면이 읽는 배 하나 (full 판은 쓰지 않는다)
class BoatArt {
  const BoatArt({
    required this.id,
    required this.rear,
    required this.front,
    required this.nightOverlay,
    required this.mainFoot,
    required this.companionFoot,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final String id;
  final String rear;
  final String front;
  final String? nightOverlay;
  final BoatPoint mainFoot;
  final BoatPoint companionFoot;
  final double canvasWidth;
  final double canvasHeight;
}

/// 화면에 놓인 배. 뒤판·창 불빛·앞판은 모두 이 한 자리에 그린다 (같은 원점·같은 변환)
typedef BoatPlacement = ({double left, double top, double width, double height, BoatPoint companionFoot});

/// 정령 발([footX], [footY])이 [art]의 mainFoot에 닿도록 배를 놓는다. [scale]은 배 캔버스 px → 화면 px
BoatPlacement placeBoat(
  BoatArt art, {
  required double footX,
  required double footY,
  required double scale,
}) {
  final left = footX - art.mainFoot.x * scale;
  final top = footY - art.mainFoot.y * scale;
  return (
    left: left,
    top: top,
    width: art.canvasWidth * scale,
    height: art.canvasHeight * scale,
    companionFoot: (x: left + art.companionFoot.x * scale, y: top + art.companionFoot.y * scale),
  );
}

/// 창 불빛을 켜는 때: 밤·새벽
bool boatLightOn(SkyPhase phase) => phase == SkyPhase.night || phase == SkyPhase.dawn;

/// 지금 얻은 보상 배 ([arrivedIslands]는 도착한 섬 이름, 내 동네 스케치 제외). order 순서
List<Boat> earnedRewardBoats(BoatCatalog catalog, Set<String> arrivedIslands) => [
      for (final b in catalog.boats)
        if (b.kind == BoatUnlockKind.islandArrival &&
            b.islands.isNotEmpty &&
            (b.allIslands
                ? b.islands.every(arrivedIslands.contains)
                : b.islands.any(arrivedIslands.contains)))
          b,
    ];

/// 탈 배: 고른 배, 안 골랐거나 데이터에 없는 배면 기본 배
Boat? boatOf(BoatCatalog catalog, String? chosenId, String defaultId) =>
    (chosenId == null ? null : catalog.byId(chosenId)) ?? catalog.byId(defaultId);

/// 새 배 토스트 한 줄 (가안): `새 배를 얻었어요 · 조각배`, 여럿이면 `… · 조각배 외 1척`
String newBoatToast(List<Boat> boats) => '새 배를 얻었어요 · ${boats.first.name}'
    '${boats.length > 1 ? ' 외 ${boats.length - 1}척' : ''}';

BoatCatalog parseBoats(Map<String, dynamic> json) {
  final canvas = json['canvas'] as List;
  return BoatCatalog(
    canvasWidth: (canvas[0] as num).toDouble(),
    canvasHeight: (canvas[1] as num).toDouble(),
    deckY: (json['deckY'] as num).toDouble(),
    assetDir: json['assetDir'] as String,
    boats: [for (final b in json['boats'] as List) Boat.fromJson(b as Map<String, dynamic>)]
      ..sort((a, b) => a.order.compareTo(b.order)),
  );
}

BoatPoint _point(dynamic v) {
  final p = v as List;
  return (x: (p[0] as num).toDouble(), y: (p[1] as num).toDouble());
}
