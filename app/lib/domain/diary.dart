import 'time_kst.dart';

/// 화집 일기 항목 하나의 모양 (UI 명세 10장): 사진 기울기 −2~2°, 마스킹테이프 기울기 −6~6°와 색,
/// 테이프 1장 또는 2장. 항목(여정 id)마다 늘 같은 값이라 다시 열어도 그대로다
class DiaryLook {
  const DiaryLook({
    required this.photoTurnDeg,
    required this.tapeTurnDeg,
    required this.tapeColor,
    required this.twoTapes,
  });

  final double photoTurnDeg;
  final double tapeTurnDeg;

  /// 테이프 색 번호 (0 ~ [diaryTapeColors] - 1)
  final int tapeColor;

  /// 테이프를 왼쪽 위·오른쪽 위 두 장 붙이는가 (아니면 가운데 위 한 장)
  final bool twoTapes;
}

/// 테이프 색 가짓수 (에셋 요구서 9장 마스킹테이프 3종)
const diaryTapeColors = 3;

/// [id]로 정한 항목 모양. 같은 id면 늘 같다 (Dart hashCode에 기대지 않는다)
DiaryLook diaryLookOf(String id) {
  final h = _fnv(id);
  double spread(int bits, double max) => ((bits % 1001) / 1000 * 2 - 1) * max;
  return DiaryLook(
    photoTurnDeg: spread(h, 2),
    tapeTurnDeg: spread(h >> 10, 6),
    tapeColor: (h >> 20) % diaryTapeColors,
    twoTapes: (h >> 24).isOdd,
  );
}

int _fnv(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7fffffff;
  }
  return h;
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 일기 달 머리줄: 한국 날짜로 `2027년 4월`
String diaryMonthLabel(DateTime utc) {
  final d = kstDate(utc);
  return '${d.year}년 ${d.month}월';
}

/// 일기 날짜: 한국 날짜로 `4월 1일 (목)`
String diaryDateLabel(DateTime utc) {
  final d = kstDate(utc);
  return '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';
}

/// 걸린 시간: `14분`, `1시간 5분`, `2시간` (1분이 안 되면 1분)
String walkedForLabel(Duration d) {
  final minutes = d.inMinutes < 1 ? 1 : d.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m분';
  return m == 0 ? '$h시간' : '$h시간 $m분';
}
