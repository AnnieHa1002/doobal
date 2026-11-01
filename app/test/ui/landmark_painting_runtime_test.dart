import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:doobal/domain/landmark.dart';
import 'package:doobal/ui/common/framed_painting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('101곳 실제 에셋을 모두 해독하고 그림 전체를 표시한다', (tester) async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/data/landmarks.json'),
    );
    final landmarks = (data['landmarks'] as List)
        .map((j) => Landmark.fromJson(j))
        .toList();
    expect(landmarks, hasLength(101));
      await tester.runAsync(() async {
    for (final l in landmarks) {
      final bytes = await rootBundle.load(
        'assets/paintings/${l.painting}.webp',
      );
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1536, reason: l.id);
      expect(frame.image.height, 1152, reason: l.id);
      frame.image.dispose();
      codec.dispose();
    }
      });
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 360,
                height: 270,
                child: PaintingFace(landmark: landmarks.first),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => precacheImage(tester.widget<Image>(find.byType(Image)).image, key.currentContext!));
    await tester.pumpAndSettle();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(find.byIcon(Icons.landscape_outlined), findsNothing);
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final rendered = (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
    final png = await tester.runAsync(() => rendered.toByteData(format: ui.ImageByteFormat.png));
    final path = Platform.environment['LANDMARK_QA_IMAGE'];
    if (path != null) File(path).writeAsBytesSync(png!.buffer.asUint8List());
    rendered.dispose();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 225,
            child: PaintingFace(landmark: landmarks[87]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      contains('산불 이전'),
    );
    expect(tester.takeException(), isNull);
  });
}
