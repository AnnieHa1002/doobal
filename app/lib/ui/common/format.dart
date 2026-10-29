import '../../domain/arrival.dart';
import '../../domain/journey.dart' show Frame;

/// 1234567 → '1,234,567'
String formatInt(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// 12.34 → '12.3 km'
String formatKm(double km, {int digits = 1}) => '${km.toStringAsFixed(digits)} km';

/// 65초 → '1:05', 1시간 이상은 '1:02:03'. 음수는 0으로
String formatDuration(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = total % 3600 ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h == 0) return '$m:$ss';
  return '$h:${m.toString().padLeft(2, '0')}:$ss';
}

/// 날짜만 쓴다: '11월 24일'
String formatMonthDay(DateTime d) => '${d.month}월 ${d.day}일';

/// 권역 7의 짧은 이름. 지도 칩 순서 그대로다 (수도권부터 울릉까지)
const regionLabels = {
  'capital': '수도권',
  'gangwon': '강원',
  'chungcheong': '충청',
  'jeolla': '전라',
  'gyeongsang': '경상',
  'jeju': '제주',
  'ulleung': '울릉',
};

/// 지형 이름 (landmarks.json의 terrain)
const terrainLabels = {
  'mountain': '산길',
  'coast': '바닷가',
  'field': '들판',
  'city': '도시',
};

/// 액자 등급 이름: '나무 액자'
String frameLabel(Frame f) => switch (f) {
      Frame.wood => '나무 액자',
      Frame.silver => '은 액자',
      Frame.gold => '금 액자',
    };

/// 액자 등급 이름만: '나무'·'은'·'금' (재방문 줄에 쓴다)
String frameName(Frame f) => switch (f) {
      Frame.wood => '나무',
      Frame.silver => '은',
      Frame.gold => '금',
    };

/// 도착 화면의 재방문 줄. 첫 방문이면 null, 액자가 올랐으면 `은 → 금으로 바뀌었어요`,
/// 그대로면 `액자는 그대로예요 (지난번 32km)` (지난번 거리를 모르면 괄호 없이)
String? revisitLine(int visitNo, Frame? prev, Frame now, double? prevBestKm) =>
    switch (revisitKind(visitNo, prev, now)) {
      RevisitKind.first => null,
      RevisitKind.frameUp => '${frameName(prev!)} → ${frameName(now)}으로 바뀌었어요',
      RevisitKind.unchanged => prevBestKm == null
          ? '액자는 그대로예요'
          : '액자는 그대로예요 (지난번 ${prevBestKm.round()}km)',
    };

/// 소품 칸 이름. 소품 탭에 나오는 순서 그대로다 (모자·옷·손·가방·신발·어깨 친구)
const propSlotLabels = {
  'hat': '모자',
  'cloth': '옷',
  'hand': '손',
  'bag': '가방',
  'shoe': '신발',
  'pet': '어깨 친구',
};
