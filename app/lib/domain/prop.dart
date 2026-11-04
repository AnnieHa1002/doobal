import 'dart:math' as math;

import 'format_int.dart';

/// 소품 해금 조건. props.json의 unlock.kind (default는 예약어라 initial)
enum PropUnlockKind { initial, distance, region, steps, companion, shop }

/// props.json의 소품 하나 (status mvp만 읽는다)
class Prop {
  const Prop({
    required this.id,
    required this.slot,
    required this.name,
    required this.kind,
    this.km,
    this.region,
    this.steps,
    this.companion,
    this.price,
    this.tintable = false,
  });

  final String id;
  final String slot;
  final String name;
  final PropUnlockKind kind;

  /// distance: 누적 걸은 거리(km), region: 권역 이름, steps: 누적 걸음
  final double? km;
  final String? region;
  final int? steps;

  /// companion: 이 소품을 주는 동료 id. companions.json이 생기면 채워진다 (그전에는 null)
  final String? companion;

  /// shop: 상점 값(럭). 사면 얻은 소품에 들어간다
  final int? price;

  /// 색을 고를 수 있는 소품 (props.json에 tint가 있다). 견본·기본 색은 palette.json tintProps
  final bool tintable;

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
        'companion' => PropUnlockKind.companion,
        'shop' => PropUnlockKind.shop,
        final k => throw FormatException('모르는 소품 해금 조건: $k (${j['id']})'),
      },
      km: (u['km'] as num?)?.toDouble(),
      region: u['region'] as String?,
      steps: u['steps'] as int?,
      companion: u['companion'] as String?,
      price: u['price'] as int?,
      tintable: j['tint'] != null,
    );
  }
}

/// props.json 전체에서 status가 mvp인 것만. pending(이벤트 소품)은 아직 다루지 않는다
List<Prop> parseProps(Map<String, dynamic> json) => [
      for (final p in json['props'] as List)
        if ((p as Map<String, dynamic>)['status'] == 'mvp') Prop.fromJson(p),
    ];

/// 지금 얻은 소품 id. 거리 소품은 걷는 중 화면에서 걸은 이동 거리(본격 걷기 보너스 포함, 배 구간 환산 아님)로 센다.
/// 동료 소품은 동료 이야기를 마칠 때(M4), 상점 소품은 살 때(M4.5) 주므로 여기서 주지 않는다
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
        PropUnlockKind.companion || PropUnlockKind.shop => false,
      })
        p.id,
  };
}

/// 다음 거리 소품까지 남은 본격 걷기 이동 거리(km): [totalKm]보다 먼 거리 소품 중 가장 가까운 것까지.
/// 거리 소품을 다 얻었으면 null. 무엇인지는 화면에 보이지 않는다 (UI 명세 12장, 16장 11/3)
double? kmToNextDistanceProp(List<Prop> props, double totalKm) {
  double? next;
  for (final p in props) {
    if (p.kind != PropUnlockKind.distance || p.km! <= totalKm) continue;
    if (next == null || p.km! < next) next = p.km;
  }
  return next == null ? null : next - totalKm;
}

/// 꾸미기 소품 칸 위 한 줄: `다음 소품까지 본격 걷기 63km`. 남은 거리는 올림이라 1km보다 적게 남아도
/// 0km로 보이지 않는다 (더한 거리의 소수 오차로 한 칸 더 올라가지 않게 아주 작은 값은 뺀다)
String nextPropText(double km) =>
    '다음 소품까지 본격 걷기 ${formatInt(math.max(1, (km - 1e-6).ceil()))}km';

/// 새로 얻은 소품 토스트 한 줄 (가안): `새 소품을 얻었어요 · 지팡이`, 여럿이면 `… · 지팡이 외 1개`
String newPropToast(List<Prop> props) => '새 소품을 얻었어요 · ${props.first.name}'
    '${props.length > 1 ? ' 외 ${props.length - 1}개' : ''}';

/// 토스트로 알리는 소품인가: 거리·걸음 소품만. 권역 소품은 도착 화면이 따로 알리고,
/// 기본 소품은 처음부터 가진 것이다 (동행 소품은 M4에서 이야기를 마칠 때 준다)
bool announcesProp(Prop p) => p.kind == PropUnlockKind.distance || p.kind == PropUnlockKind.steps;
