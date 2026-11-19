// 물감 길 무늬 (trails.json v1, 16장 11/19 상점 무늬): 기본 방울 + 무늬 3종. 소품이 아니라 물감처럼 칠하는 재료.
// 읽기만 한다. 얻기·고르기·구간마다 저장·지도에 그리기는 T17 (규칙 값은 config paintPattern)

/// 무늬를 얻는 길 (trails.json unlock.kind, default는 예약어라 initial)
enum TrailUnlockKind {
  /// 처음부터, 무제한
  initial,

  /// 물감 길 누적 실제 거리가 [TrailPattern.km] 이상. 상점에서도 [TrailPattern.shopPrice] 럭에 산다
  trailKm,
}

/// 무늬 하나. 그림은 회색조 타일(512×64)·끝(64×64)에 구간 색을 곱한다
class TrailPattern {
  const TrailPattern({
    required this.id,
    required this.name,
    required this.kind,
    required this.tile,
    required this.cap,
    this.km,
    this.shopPrice,
    this.icon,
    this.pending = false,
  });

  final String id;
  final String name;
  final TrailUnlockKind kind;

  /// 타일·끝 그림 이름 (확장자 없이)
  final String tile;
  final String cap;

  /// trailKm: 물감 길 누적 실제 거리(km)
  final double? km;

  /// 상점 값(럭). shop.json 무늬 상품 값과 같다
  final int? shopPrice;

  /// 칸 아이콘 그림 이름. 기본 방울은 없다 (앱이 방울 타일로 만든다)
  final String? icon;

  /// 그림 납품 전. 그림이 없으면 그 구간도 방울 타일로 그린다
  final bool pending;

  factory TrailPattern.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final u = j['unlock'] as Map<String, dynamic>;
    final kind = switch (u['kind']) {
      'default' => TrailUnlockKind.initial,
      'trailKm' => TrailUnlockKind.trailKm,
      final k => throw FormatException('모르는 무늬 얻는 길: $k ($id)'),
    };
    final km = (u['km'] as num?)?.toDouble();
    if (kind == TrailUnlockKind.trailKm && km == null) {
      throw FormatException('무늬 거리 값이 없다: $id');
    }
    return TrailPattern(
      id: id,
      name: j['name'] as String,
      kind: kind,
      tile: j['tile'] as String,
      cap: j['cap'] as String,
      km: km,
      shopPrice: u['shopPrice'] as int?,
      icon: j['icon'] as String?,
      pending: j['pending'] as bool? ?? false,
    );
  }
}

/// trails.json 전체
class TrailCatalog {
  TrailCatalog({required this.defaultId, required this.patterns});

  /// 기본 무늬 id (방울)
  final String defaultId;

  /// 파일에 적힌 순서 그대로
  final List<TrailPattern> patterns;

  late final Map<String, TrailPattern> _byId = {for (final p in patterns) p.id: p};

  TrailPattern? byId(String id) => _byId[id];

  TrailPattern get defaultPattern => _byId[defaultId]!;
}

TrailCatalog parseTrails(Map<String, dynamic> json) {
  final patterns = [
    for (final p in json['patterns'] as List) TrailPattern.fromJson(p as Map<String, dynamic>),
  ];
  final ids = <String>{};
  for (final p in patterns) {
    if (!ids.add(p.id)) throw FormatException('무늬 id가 겹친다: ${p.id}');
  }
  final defaultId = json['default'] as String;
  if (!ids.contains(defaultId)) throw FormatException('기본 무늬가 목록에 없다: $defaultId');
  return TrailCatalog(defaultId: defaultId, patterns: patterns);
}
