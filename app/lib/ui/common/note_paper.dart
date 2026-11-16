import 'package:flutter/painting.dart';

/// 메모지 종이 그림 (600×600, 테두리 60px를 두고 가운데를 늘리는 9조각). 하루 카드·화집 일기가 같이 쓴다
const notePaperAsset = 'assets/ui/ui_note_paper_plain_9s60_v01_clean.png';

/// 그림 3px를 1pt로 그린다 (테두리 60px = 20pt)
const notePaperScale = 3.0;

/// 늘리는 가운데 칸. Flutter는 centerSlice를 그림 px가 아니라 논리 픽셀(그림 px ÷ scale)로 받는다:
/// 그림 px 60~540 ÷ 3 = 20~180. 그림 px로 적으면 가운데 칸이 그림 밖으로 나가, 안드로이드(Impeller)에서
/// 종이가 내용보다 작게 그려진다 (11/17 폰에서 봄. 시험 그리기(Skia)는 그림 전체를 늘려 그려서 안 보였다)
const notePaperSlice = Rect.fromLTRB(20, 20, 180, 180);

/// 메모지 종이 바탕 (BoxDecoration.image)
const notePaperImage = DecorationImage(
  image: AssetImage(notePaperAsset),
  centerSlice: notePaperSlice,
  scale: notePaperScale,
);
