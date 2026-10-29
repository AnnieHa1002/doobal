import '../../domain/prop.dart';
import '../common/format.dart';

/// 잠긴 소품을 얻는 방법 한 줄. 기본 소품은 처음부터 가진 것이라 null.
/// 거리는 `누적 150km · 지금 87km`(지금 거리는 버림), 걸음은 `누적 1,000,000보 · 지금 8,000보`,
/// 권역은 `전라 3/21` ([progress]는 regionProgress의 값), 동료 소품은 `동행 이야기 완결`
String? propHowTo(
  Prop p, {
  required double totalKm,
  required int totalSteps,
  required Map<String, ({int visited, int total})> progress,
}) =>
    switch (p.kind) {
      PropUnlockKind.initial => null,
      PropUnlockKind.distance =>
        '누적 ${formatInt(p.km!.round())}km · 지금 ${formatInt(totalKm.floor())}km',
      PropUnlockKind.steps =>
        '누적 ${formatInt(p.steps!)}보 · 지금 ${formatInt(totalSteps)}보',
      PropUnlockKind.region =>
        '${regionLabels[p.region] ?? p.region} ${progress[p.region]?.visited ?? 0}'
            '/${progress[p.region]?.total ?? 0}',
      PropUnlockKind.companion => '동행 이야기 완결',
    };
