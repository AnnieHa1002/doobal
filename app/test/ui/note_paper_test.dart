import 'dart:io';
import 'dart:typed_data';

import 'package:doobal/ui/common/note_paper.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG 머리의 가로·세로 (그림 px)
Size _pngSize(String path) {
  final head = ByteData.sublistView(File(path).readAsBytesSync(), 16, 24);
  return Size(head.getUint32(0).toDouble(), head.getUint32(4).toDouble());
}

void main() {
  // Flutter paintImage는 centerSlice를 논리 픽셀로 받아 scale을 곱해 그림 px로 바꾼다.
  // 가운데 칸이 그림 밖이면 Impeller(안드로이드)에서 종이가 내용보다 작게 그려진다 (11/17 폰)
  test('메모지 9조각의 가운데 칸이 그림 안에 있다 (논리 픽셀 = 그림 px ÷ scale)', () {
    final px = _pngSize(notePaperAsset);
    expect(px, const Size(600, 600));
    final logical = Offset.zero & (px / notePaperScale);
    expect(notePaperSlice.left, greaterThan(0));
    expect(notePaperSlice.top, greaterThan(0));
    expect(notePaperSlice.right, lessThan(logical.right));
    expect(notePaperSlice.bottom, lessThan(logical.bottom));
    // 파일 이름 9s60 = 테두리 60px
    expect(notePaperSlice.left * notePaperScale, 60);
    expect((logical.right - notePaperSlice.right) * notePaperScale, 60);
  });

  test('하루 카드·화집 일기는 같은 메모지 바탕을 쓴다 (가운데 칸을 따로 적지 않음)', () {
    for (final path in ['lib/ui/day_card/day_card_view.dart', 'lib/ui/album/album_diary.dart']) {
      final src = File(path).readAsStringSync();
      expect(src.contains('notePaperImage'), isTrue, reason: path);
      expect(src.contains('centerSlice'), isFalse, reason: path);
    }
  });
}
