import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/painting_saver.dart';

/// 그림 크게 보기의 사진첩 저장 (gal). 테스트는 FakePaintingSaver로 바꾼다
final paintingSaverProvider = Provider<PaintingSaver>((ref) => const GalPaintingSaver());
