import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doobal/ui/common/framed_painting.dart';
void main(){testWidgets('첫 그림 실제 에셋 로드와 액자 렌더', (tester) async {
 final key=GlobalKey();
 await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(child:RepaintBoundary(key:key,child:const SizedBox(width:360,height:270,child:FramedPainting.firstPack()))))));
 await tester.runAsync(()=>precacheImage(tester.widget<Image>(find.byType(Image)).image,key.currentContext!));
 await tester.pumpAndSettle();
 expect(tester.widget<RawImage>(find.byType(RawImage)).image,isNotNull);
 expect(tester.widget<Image>(find.byType(Image)).fit,BoxFit.contain);
 expect(tester.takeException(),isNull);
 final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
 final rendered=(await tester.runAsync(()=>boundary.toImage(pixelRatio:2)))!;
 final bytes=await tester.runAsync(()=>rendered.toByteData(format:ui.ImageByteFormat.png));
 File(Platform.environment['FIRST_PACK_QA_IMAGE']!).writeAsBytesSync(bytes!.buffer.asUint8List());rendered.dispose();
});}
