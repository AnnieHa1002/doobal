import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doobal/ui/common/basic_item_art.dart';
import 'package:doobal/ui/common/framed_painting.dart';

void main() {
  testWidgets('첫 여행 그림과 여섯 소품·도장 테두리를 표시한다', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: const Color(0xfff2e8d5),
                child: SizedBox(
                  width: 400,
                  height: 500,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 360,
                        height: 270,
                        child: FramedPainting.firstPack(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final id in BasicItemIcon.ids)
                            SizedBox(
                              width: 60,
                              height: 65,
                              child: BasicItemIcon(id: id, fallback: '?'),
                            ),
                        ],
                      ),
                      const SizedBox(
                        width: 110,
                        height: 110,
                        child: StampFace(
                          child: Center(child: Text('1', style: TextStyle(fontSize:40,color:Color(0xffa4502f)))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNWidgets(8));
    final destination = Platform.environment['DOOBAL_CAPTURE_DIR'];
    if (destination != null)
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        await File('$destination/ui_assets.png').writeAsBytes(bytes);
        image.dispose();
      });
  });
}
