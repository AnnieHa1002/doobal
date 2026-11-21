import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/ui/common/app_text.dart';
import 'package:doobal/ui/shop/shop_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

/// 상점을 눈으로 볼 때만 도는 시험. 그림을 [DOOBAL_SHOP_CAPTURE_DIR]에 PNG로 남긴다
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final dir = Platform.environment['DOOBAL_SHOP_CAPTURE_DIR'];

  testWidgets('상점 찍기', skip: dir == null, (tester) async {
    await tester.runAsync(() async {
      Future<ByteData> font(String name) async =>
          ByteData.sublistView(await File('assets/fonts/$name.ttf').readAsBytes());
      await (FontLoader(bodyFont)
            ..addFont(font('NotoSansKR-Regular'))
            ..addFont(font('NotoSansKR-SemiBold'))
            ..addFont(font('NotoSansKR-Bold')))
          .load();
    });
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final e = UiEnv();
    await e.seed(tester, () async {
      await e.db
          .into(e.db.coinLedger)
          .insert(CoinLedgerCompanion.insert(day: '2026-11-18', kind: CoinKind.gift, amount: 1240));
      await e.db.into(e.db.boatsOwned).insert(BoatsOwnedCompanion.insert(boatId: 'boat_cruise', atUtc: 1));
    });

    Future<void> wait([int n = 12]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> shot(String name) async {
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        image.dispose();
      });
    }

    for (final (n, (name, size)) in [('390', const Size(390, 844)), ('375', const Size(375, 667))].indexed) {
      tester.view.physicalSize = size * 2;
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: e.overrides,
          child: MaterialApp(
            theme: ThemeData(
              fontFamily: bodyFont,
              scaffoldBackgroundColor: const Color(0xFFF2E8D5),
            ),
            home: const ShopScreen(),
          ),
        ),
      ));
      await wait(40);
      await shot('shop_${name}_top');
      // 앞 크기에서 산 칸은 SOLD라 다음 칸을 산다
      await tester.tap(find.byKey(ValueKey('cart-slot-$n')));
      await wait();
      await tester.pump(const Duration(milliseconds: 400));
      await shot('shop_${name}_sheet');
      await tester.tap(find.text('구매'));
      await wait(20);
      await tester.pump(const Duration(seconds: 3));
      await wait();
      await shot('shop_${name}_sold');
      await tester.drag(find.byKey(const ValueKey('shop-scroll')), const Offset(0, -600));
      await wait();
      await shot('shop_${name}_bottom');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    await end(tester, e);
  });
}
