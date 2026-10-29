/// 소품 해금 조건. props.json의 unlock.kind (default는 예약어라 initial)
enum PropUnlockKind { initial, distance, region, steps }

/// props.json의 소품 하나 (MVP 24개만 읽는다)
class Prop {
  const Prop({
    required this.id,
    required this.slot,
    required this.name,
    required this.kind,
    this.km,
    this.region,
    this.steps,
  });

  final String id;
  final String slot;
  final String name;
  final PropUnlockKind kind;

  /// distance: 누적 걸은 거리(km), region: 권역 이름, steps: 누적 걸음
  final double? km;
  final String? region;
  final int? steps;

  factory Prop.fromJson(Map<String, dynamic> j) {
    final u = j['unlock'] as Map<String, dynamic>;
    return Prop(
      id: j['id'] as String,
      slot: j['slot'] as String,
      name: j['name'] as String,
      kind: switch (u['kind']) {
        'default' => PropUnlockKind.initial,
        'distance' => PropUnlockKind.distance,
        'region' => PropUnlockKind.region,
        'steps' => PropUnlockKind.steps,
        final k => throw FormatException('모르는 소품 해금 조건: $k (${j['id']})'),
      },
      km: (u['km'] as num?)?.toDouble(),
      region: u['region'] as String?,
      steps: u['steps'] as int?,
    );
  }
}

/// props.json 전체에서 status가 mvp인 것만. pending(이벤트·동료 소품)은 아직 다루지 않는다
List<Prop> parseProps(Map<String, dynamic> json) => [
      for (final p in json['props'] as List)
        if ((p as Map<String, dynamic>)['status'] == 'mvp') Prop.fromJson(p),
    ];

/// 지금 얻은 소품 id. 누적 거리는 센서로 잰 실제 걸은 거리(배 환산 아님)
Set<String> earnedPropIds(
  List<Prop> props,
  double totalKm,
  int totalSteps,
  Set<String> completedRegions,
) {
  return {
    for (final p in props)
      if (switch (p.kind) {
        PropUnlockKind.initial => true,
        PropUnlockKind.distance => totalKm >= p.km!,
        PropUnlockKind.region => completedRegions.contains(p.region),
        PropUnlockKind.steps => totalSteps >= p.steps!,
      })
        p.id,
  };
}
