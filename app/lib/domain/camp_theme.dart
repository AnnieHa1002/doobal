/// 쉼터의 물건 하나 (지도·배낭·노트). x·y는 화면 비율(중심), size는 pt
class CampObject {
  const CampObject({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.size,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final double size;

  factory CampObject.fromJson(Map<String, dynamic> j) => CampObject(
        id: j['id'] as String,
        label: j['label'] as String,
        x: _d(j['x']),
        y: _d(j['y']),
        size: _d(j['size']),
      );
}

/// 캐릭터·동료·이정표가 서는 자리. x는 가로 비율(중심), footY는 발 높이 비율
class FootSpot {
  const FootSpot(this.x, this.footY);

  final double x;
  final double footY;

  factory FootSpot.fromJson(Map<String, dynamic> j) => FootSpot(_d(j['x']), _d(j['footY']));
}

/// themes/camp.json. 그림이 나오기 전까지 위치는 잠정값(approx)
class CampTheme {
  const CampTheme({
    required this.id,
    required this.approx,
    required this.objects,
    required this.character,
    required this.companion,
    required this.signpost,
  });

  final String id;
  final bool approx;
  final List<CampObject> objects;
  final FootSpot character;
  final FootSpot companion;
  final FootSpot signpost;

  CampObject object(String id) => objects.firstWhere((o) => o.id == id);

  factory CampTheme.fromJson(Map<String, dynamic> j) => CampTheme(
        id: j['id'] as String,
        approx: j['approx'] as bool? ?? false,
        objects: [
          for (final o in j['objects'] as List) CampObject.fromJson(o as Map<String, dynamic>),
        ],
        character: FootSpot.fromJson(j['character'] as Map<String, dynamic>),
        companion: FootSpot.fromJson(j['companion'] as Map<String, dynamic>),
        signpost: FootSpot.fromJson(j['signpost'] as Map<String, dynamic>),
      );
}

double _d(dynamic v) => (v as num).toDouble();
