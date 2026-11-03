import 'package:doobal/domain/diary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('항목 모양 (UI 명세 10장)', () {
    test('같은 id면 늘 같고, 기울기는 사진 −2~2°·테이프 −6~6°', () {
      for (var i = 0; i < 300; i++) {
        final a = diaryLookOf('j-$i');
        final b = diaryLookOf('j-$i');
        expect((a.photoTurnDeg, a.tapeTurnDeg, a.tapeColor, a.twoTapes),
            (b.photoTurnDeg, b.tapeTurnDeg, b.tapeColor, b.twoTapes));
        expect(a.photoTurnDeg, inInclusiveRange(-2, 2));
        expect(a.tapeTurnDeg, inInclusiveRange(-6, 6));
        expect(a.tapeColor, inInclusiveRange(0, diaryTapeColors - 1));
      }
    });

    test('여러 항목이면 기울기·테이프 색·장 수가 고루 섞인다', () {
      final looks = [for (var i = 0; i < 300; i++) diaryLookOf('j-$i')];
      expect(looks.map((l) => l.tapeColor).toSet(), {0, 1, 2});
      expect(looks.map((l) => l.twoTapes).toSet(), {true, false});
      expect(looks.where((l) => l.photoTurnDeg < 0), isNotEmpty);
      expect(looks.where((l) => l.photoTurnDeg > 0), isNotEmpty);
    });
  });

  group('글', () {
    test('달 머리줄·날짜는 한국 날짜 (UTC 15시 = 다음 날 0시)', () {
      expect(diaryMonthLabel(DateTime.utc(2027, 3, 31, 15)), '2027년 4월');
      expect(diaryMonthLabel(DateTime.utc(2027, 3, 31, 14, 59)), '2027년 3월');
      // 2027년 4월 1일은 목요일
      expect(diaryDateLabel(DateTime.utc(2027, 3, 31, 15)), '4월 1일 (목)');
      expect(diaryDateLabel(DateTime.utc(2026, 11, 18)), '11월 18일 (수)');
    });

    test('걸린 시간: 분, 시간, 시간 분 (1분이 안 되면 1분)', () {
      expect(walkedForLabel(const Duration(minutes: 14, seconds: 50)), '14분');
      expect(walkedForLabel(const Duration(seconds: 20)), '1분');
      expect(walkedForLabel(const Duration(hours: 1, minutes: 5)), '1시간 5분');
      expect(walkedForLabel(const Duration(hours: 2)), '2시간');
    });
  });
}
