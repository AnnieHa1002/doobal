// 쉼터 테마 themes/camp_wide.json v3. 좌표는 장면 왼쪽 위 기준 pt (기준 화면 390×844, 장면 폭 585)

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

/// 쉼터 물건 하나 (배낭·노트·지도·수레·방명록 표지판·동행).
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

  factory CampObject.fromJson(Map<String, dynamic> j, {String? id}) => CampObject(
        id: id ?? j['id'] as String,
        label: j['label'] as String,
        box: CampBox(_d(j['x']), _d(j['y']), _d(j['w']), _d(j['h'])),
        artW: _d(j['artW']),
        artH: _d(j['artH']),
        labelTop: _d(j['labelTop']),
        onlyWhenTicket: j['onlyWhenTicket'] as bool? ?? false,
        art: j['art'] == null ? null : CampArt.fromJson(j['art'] as Map<String, dynamic>),
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
  final CampObject companion;
  final CampFire campfire;
  final CampSign firstSign;

  /// 겹치면 먼저 눌리는 순서
  final List<String> hitOrder;

  CampObject object(String id) => objects.firstWhere((o) => o.id == id);

  /// 기기 pt ÷ 장면 pt. 세로 화면은 폭 비례. 가로 화면은 장면 폭이 화면 폭과 같아지게(밀 곳 없음)
  double scaleFor(double width, double height) =>
      width > height ? width / widthPt : width / refW;

  /// 누름 상자를 Stack에 쌓을 순서: 뒤에 쌓을수록 위라 hitOrder를 뒤집는다.
  /// 정령은 빠진다(누름 상자가 아니라 그림이 직접 받으므로 언제나 가장 아래).
  /// [shown]은 지금 서 있는 물건 id
  List<String> hitStack(Set<String> shown) => [
        for (final id in hitOrder.reversed)
          if (id != campCharacterId && shown.contains(id)) id,
      ];

  factory CampTheme.fromJson(Map<String, dynamic> j) {
    final scene = j['scene'] as Map<String, dynamic>;
    final ref = _list(scene['refScreenPt']);
    final character = j['character'] as Map<String, dynamic>;
    final fire = j['campfire'] as Map<String, dynamic>;
    final sign = j['firstSign'] as Map<String, dynamic>;
    return CampTheme(
      id: j['id'] as String,
      approx: j['approx'] as bool? ?? false,
      widthPt: _d(scene['widthPt']),
      refW: ref[0],
      refH: ref[1],
      objects: [
        for (final o in j['objects'] as List) CampObject.fromJson(o as Map<String, dynamic>),
      ],
      character: CampCharacter(
        x: _d(character['x']),
        y: _d(character['y']),
        w: _d(character['w']),
        heightPt: _d(character['heightPt']),
      ),
      companion: CampObject.fromJson(j['companion'] as Map<String, dynamic>, id: campCompanionId),
      campfire: CampFire(
        box: CampBox(_d(fire['x']), _d(fire['y']), _d(fire['w']), _d(fire['h'])),
        frames: fire['frames'] as int,
        frameSec: _d(fire['frameSec']),
      ),
      firstSign: CampSign(
        box: CampBox(_d(sign['x']), _d(sign['y']), _d(sign['w']), _d(sign['h'])),
        label: sign['label'] as String,
      ),
      hitOrder: (j['hitOrder'] as List).cast<String>(),
    );
  }
}

double _d(dynamic v) => (v as num).toDouble();

List<double> _list(dynamic v) => [for (final n in v as List) _d(n)];
