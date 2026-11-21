// 쉼터 테마 themes/camp_wide.json v5. 좌표는 장면 왼쪽 위 기준 pt (기준 화면 390×844, 장면 폭 585).
// v5(16장 11/18): 땅 위 물건은 수레만 남고 배낭·노트·지도·방명록 표지판·동행 자리·hitOrder가 빠졌다.
// 빠진 것은 없으면 안 그린다 (쉼터 옆 버튼은 T14). 꾸밈 물품 자리 decor(땅 띠·못 놓는 자리·이젤 첫 자리)는
// [CampDecor] (T15, 없으면 쉼터 꾸미기를 열지 않는다)

/// 장면 위의 사각형 (pt)
class CampBox {
  const CampBox(this.x, this.y, this.w, this.h);

  final double x;
  final double y;
  final double w;
  final double h;

  bool contains(double px, double py) => px >= x && px < x + w && py >= y && py < y + h;
}

/// 물건 그림 파일. [bbox]는 투명 여백을 뺀 상자(x, y, w, h)이고 이 상자를 물건 그림 크기에 맞춘다
class CampArt {
  const CampArt({required this.file, required this.canvas, required this.bbox});

  final String file;

  /// 그림 파일 크기 (w, h)
  final List<double> canvas;
  final List<double> bbox;

  factory CampArt.fromJson(Map<String, dynamic> j) => CampArt(
        file: j['file'] as String,
        canvas: _list(j['canvas']),
        bbox: _list(j['bbox']),
      );
}

/// 쉼터 물건 하나 (v5는 수레만, v3은 배낭·노트·지도·수레·방명록 표지판·동행).
/// [box]는 누름 상자(이름표까지), 그림은 그 왼쪽 위에서 [artW]×[artH], 이름표는 위에서 [labelTop]
class CampObject {
  const CampObject({
    required this.id,
    required this.label,
    required this.box,
    required this.artW,
    required this.artH,
    required this.labelTop,
    this.onlyWhenTicket = false,
    this.art,
    this.artSourceFile,
    this.artSourceNight,
    this.itemsOnMax = 0,
    this.itemsOnIconPt = 0,
  });

  final String id;
  final String label;
  final CampBox box;
  final double artW;
  final double artH;
  final double labelTop;

  /// 방명록 기회가 있을 때만 선다
  final bool onlyWhenTicket;

  /// 그림 파일. 없으면 자리표시 (수레·동행은 다른 트랙이 끼운다)
  final CampArt? art;

  /// 납품 파일 이름 (artSource.file). 끼우는 트랙이 파일이 있는지 보고 읽는다 (수레)
  final String? artSourceFile;

  /// 밤에 얹는 층 파일 이름 (artSource.nightLantern)
  final String? artSourceNight;

  /// 그 위에 얹는 그날 물건 아이콘 최대 수와 크기(pt) (v5 수레 itemsOn, 오늘의 수레). 없으면 0
  final int itemsOnMax;
  final double itemsOnIconPt;

  factory CampObject.fromJson(Map<String, dynamic> j, {String? id}) => CampObject(
        id: id ?? j['id'] as String,
        label: j['label'] as String,
        box: CampBox(_d(j['x']), _d(j['y']), _d(j['w']), _d(j['h'])),
        artW: _d(j['artW']),
        artH: _d(j['artH']),
        // v5 수레에는 없다: 그림 바로 아래
        labelTop: _d(j['labelTop'] ?? j['artH']),
        onlyWhenTicket: j['onlyWhenTicket'] as bool? ?? false,
        art: j['art'] == null ? null : CampArt.fromJson(j['art'] as Map<String, dynamic>),
        artSourceFile: (j['artSource'] as Map?)?['file'] as String?,
        artSourceNight: (j['artSource'] as Map?)?['nightLantern'] as String?,
        itemsOnMax: ((j['itemsOn'] as Map?)?['max'] as int?) ?? 0,
        itemsOnIconPt: (((j['itemsOn'] as Map?)?['iconPt'] as num?) ?? 0).toDouble(),
      );
}

/// 정령 자리. 발은 상자 아래 가운데에 온다
class CampCharacter {
  const CampCharacter({required this.x, required this.y, required this.w, required this.heightPt});

  final double x;
  final double y;
  final double w;
  final double heightPt;

  double get footX => x + w / 2;
  double get footY => y + heightPt;
  CampBox get box => CampBox(x, y, w, heightPt);
}

/// 모닥불 불꽃: 프레임 [frames]장을 [frameSec]초씩
class CampFire {
  const CampFire({required this.box, required this.frames, required this.frameSec});

  final CampBox box;
  final int frames;
  final double frameSec;
}

/// 첫날 이정표 글 자리
class CampSign {
  const CampSign({required this.box, required this.label});

  final CampBox box;
  final String label;
}

/// 꾸밈 물품 땅 띠 (camp_wide decor.groundBand): 물품 발 디딤점이 들어갈 수 있는 범위 (장면 pt)
class CampGroundBand {
  const CampGroundBand({required this.xMin, required this.xMax, required this.footYMin, required this.footYMax});

  final double xMin;
  final double xMax;
  final double footYMin;
  final double footYMax;
}

/// 꾸밈 물품을 못 놓는 자리 하나 (camp_wide decor.blocked). 정령은 둥둥 정령 상자(characterFloat) + 둘레 [padPt]
class CampBlocked {
  const CampBlocked({required this.id, required this.box});

  /// character·campfire·cart (config rest.decor.blocked가 이 id로 고른다)
  final String id;
  final CampBox box;
}

/// 쉼터 꾸미기 자리 (camp_wide v5 decor, 개발 기획 가안)
class CampDecor {
  const CampDecor({required this.band, required this.blocked, this.easelFootX, this.easelFootY});

  final CampGroundBand band;
  final List<CampBlocked> blocked;

  /// 첫 그림 선물 이젤이 처음 놓이는 발 자리 (decor.easelStart). 없으면 땅 띠 가운데
  final double? easelFootX;
  final double? easelFootY;

  CampBlocked? blockedOf(String id) {
    for (final b in blocked) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// 쉼터 동행·정령은 물건처럼 누르지만 [CampTheme.objects]에는 없다
const campCharacterId = 'character';
const campCompanionId = 'companion';
const campCartId = 'cart';
const campGuestbookSignId = 'guestbookSign';

/// themes/camp_wide.json. 위치는 캔버스 2-2 메모(approx)
class CampTheme {
  const CampTheme({
    required this.id,
    required this.approx,
    required this.widthPt,
    required this.refW,
    required this.refH,
    required this.objects,
    required this.character,
    required this.companion,
    required this.campfire,
    required this.firstSign,
    required this.hitOrder,
    this.decor,
  });

  final String id;
  final bool approx;

  /// 장면 폭 (기준 화면에서)
  final double widthPt;

  /// 기준 화면 크기
  final double refW;
  final double refH;
  final List<CampObject> objects;
  final CampCharacter character;
  /// 불 옆 동행 자리. v5에는 없어 null (동행을 쉼터에 그리지 않는다)
  final CampObject? companion;
  final CampFire campfire;
  final CampSign firstSign;

  /// 겹치면 먼저 눌리는 순서. 파일에 없으면(v5) 물건 순서, 동행, 정령
  final List<String> hitOrder;

  /// 꾸밈 물품 자리 (v4부터). 없으면 null
  final CampDecor? decor;

  CampObject object(String id) => objects.firstWhere((o) => o.id == id);

  /// [id] 물건. 테마에 없으면 null (동행은 [companion])
  CampObject? objectOrNull(String id) {
    if (id == campCompanionId) return companion;
    for (final o in objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// 기기 pt ÷ 장면 pt. 세로 화면은 폭 비례. 가로 화면은 장면 폭이 화면 폭과 같아지게(밀 곳 없음)
  double scaleFor(double width, double height) =>
      width > height ? width / widthPt : width / refW;

  /// 누름 상자를 Stack에 쌓을 순서: 뒤에 쌓을수록 위라 hitOrder를 뒤집는다.
  /// 정령은 빠진다(누름 상자가 아니라 그림이 직접 받으므로 언제나 가장 아래).
  /// [shown]은 지금 서 있는 물건 id. 테마에 자리가 없는 물건은 빠진다
  List<String> hitStack(Set<String> shown) => [
        for (final id in hitOrder.reversed)
          if (id != campCharacterId && shown.contains(id) && objectOrNull(id) != null) id,
      ];

  factory CampTheme.fromJson(Map<String, dynamic> j) {
    final scene = j['scene'] as Map<String, dynamic>;
    final ref = _list(scene['refScreenPt']);
    final character = j['character'] as Map<String, dynamic>;
    final fire = j['campfire'] as Map<String, dynamic>;
    final sign = j['firstSign'] as Map<String, dynamic>;
    final objects = [
      for (final o in j['objects'] as List) CampObject.fromJson(o as Map<String, dynamic>),
    ];
    final companion = j['companion'] as Map<String, dynamic>?;
    return CampTheme(
      id: j['id'] as String,
      approx: j['approx'] as bool? ?? false,
      widthPt: _d(scene['widthPt']),
      refW: ref[0],
      refH: ref[1],
      objects: objects,
      character: CampCharacter(
        x: _d(character['x']),
        y: _d(character['y']),
        w: _d(character['w']),
        heightPt: _d(character['heightPt']),
      ),
      companion: companion == null ? null : CampObject.fromJson(companion, id: campCompanionId),
      campfire: CampFire(
        box: CampBox(_d(fire['x']), _d(fire['y']), _d(fire['w']), _d(fire['h'])),
        frames: fire['frames'] as int,
        frameSec: _d(fire['frameSec']),
      ),
      firstSign: CampSign(
        box: CampBox(_d(sign['x']), _d(sign['y']), _d(sign['w']), _d(sign['h'])),
        label: sign['label'] as String,
      ),
      hitOrder: (j['hitOrder'] as List?)?.cast<String>() ??
          [for (final o in objects) o.id, campCompanionId, campCharacterId],
      decor: _decorOf(j),
    );
  }
}

/// camp_wide decor. 정령 못 놓는 자리는 둥둥 정령(characterFloat: 가운데 x·폭·키·그림자 발 y·뜬 높이)의 몸 상자에
/// 둘레를 더한다. characterFloat가 없으면 정령 상자(character)
CampDecor? _decorOf(Map<String, dynamic> j) {
  final d = j['decor'] as Map<String, dynamic>?;
  if (d == null) return null;
  final band = d['groundBand'] as Map<String, dynamic>;
  final blocked = <CampBlocked>[];
  for (final b in (d['blocked'] as List?) ?? const []) {
    final m = b as Map<String, dynamic>;
    final id = m['id'] as String;
    final pad = _d(m['padPt'] ?? 0);
    final CampBox box;
    if (m['from'] case final String from) {
      final f = j[from] as Map<String, dynamic>? ??
          (throw FormatException('camp_wide decor.blocked $id: $from이 없다'));
      final footY = _d(f['footY'] ?? _d(f['y']) + _d(f['heightPt']));
      final top = footY - _d(f['liftPt'] ?? 0) - _d(f['heightPt']);
      box = CampBox(_d(f['x']) - pad, top - pad, _d(f['w']) + pad * 2, footY - top + pad * 2);
    } else {
      box = CampBox(_d(m['x']) - pad, _d(m['y']) - pad, _d(m['w']) + pad * 2, _d(m['h']) + pad * 2);
    }
    blocked.add(CampBlocked(id: id, box: box));
  }
  final easel = d['easelStart'] as Map<String, dynamic>?;
  return CampDecor(
    band: CampGroundBand(
      xMin: _d(band['xMin']),
      xMax: _d(band['xMax']),
      footYMin: _d(band['footYMin']),
      footYMax: _d(band['footYMax']),
    ),
    blocked: blocked,
    easelFootX: easel == null ? null : _d(easel['footX']),
    easelFootY: easel == null ? null : _d(easel['footY']),
  );
}

double _d(dynamic v) => (v as num).toDouble();

List<double> _list(dynamic v) => [for (final n in v as List) _d(n)];
