import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/color_props.dart';
import 'package:doobal/domain/shop_cart.dart';
import 'package:doobal/domain/time_kst.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/common/app_text.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/shop/shop_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 소품 칸 아이콘(11/23 v01)을 눈으로 볼 때만 도는 시험. 그림을 [DOOBAL_ICONS_CAPTURE_DIR]에 PNG로 남긴다:
/// 상점 수레(소품·색 소품·미니 친구), 화집(= 배낭) 소품 탭, 꾸미기 선반
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  final dir = Platform.environment['DOOBAL_ICONS_CAPTURE_DIR'];

  /// 수레 날 전날까지 걸은 거리: 미니 친구(25km)·얼굴·손·둥실(75km)이 수레에 나온다 (config shop.cart.kindsByKm)
  const cartKm = 80.0;

  /// 처음 여는 날(빈 기록)의 수레 줄 (shop_screen_test와 같은 계산, 설치 번호 0×32)
  List<String> line(String day) {
    final have = havePropIds(props, const {});
    return planCart(
      rules: rules.shopCart,
      items: [...shopCatalog.items, ...colorShopItems(props)],
      owned: (i) => have.contains(i.propId),
      haveBase: have.contains,
      totalKm: cartKm,
      timesShown: const {},
      seed: '0' * 32,
      day: day,
    );
  }

  bool isColor(String id) => RegExp(r'_c\d+$').hasMatch(id);
  bool isPet(String id) => id.startsWith('pet_');

  /// 색·미니 친구가 아닌 소품 상품 (모자·옷·신발·얼굴·손·둥실)
  bool isPlainProp(String id) =>
      props.any((p) => p.id == id) && !isColor(id) && !isPet(id) && !id.startsWith('effect_');

  /// 11/18부터 수레 줄이 [ok]인 첫날
  String dayWhere(bool Function(List<String> ids) ok) {
    for (var n = 0; n < 400; n++) {
      final day = addDays('2026-11-18', n);
      if (ok(line(day))) return day;
    }
    throw StateError('그런 날이 없다');
  }

  testWidgets('소품 칸 아이콘 찍기 (상점·화집 소품 탭·꾸미기)', skip: dir == null, (tester) async {
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

    Future<void> wait([int n = 30]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> shot(String name) async {
      await wait();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('$dir/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        image.dispose();
      });
    }

    Future<void> show(UiEnv e, Widget screen, Size size) async {
      tester.view.physicalSize = size * 2;
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: e.overrides,
          child: MaterialApp(
            theme: ThemeData(fontFamily: bodyFont, scaffoldBackgroundColor: const Color(0xFFF2E8D5)),
            home: screen,
          ),
        ),
      ));
      await wait(40);
    }

    // 1) 상점: 기본 소품만 가진 채 80km 걸은 다음 날 (색 소품은 기본 소품을 가진 것만 나온다).
    // 색 소품 + 미니 친구가 나오는 날, 그 밖의 소품이 둘 이상 나오는 날
    final days = {
      'icons_shop_cart': dayWhere((ids) => ids.any(isColor) && ids.any(isPet)),
      'icons_shop_cart_props': dayWhere((ids) => ids.where(isPlainProp).length >= 2),
    };
    for (final MapEntry(key: name, value: day) in days.entries) {
      debugPrint('$name 수레 날 $day: ${line(day).join(', ')}');
      final shop = UiEnv();
      shop.now = kstDayStartUtc(day).add(const Duration(hours: 12));
      await shop.seed(tester, () async {
        await shop.db.into(shop.db.daySummaries).insert(DaySummariesCompanion.insert(
              day: addDays(day, -1),
              steps: 100000,
              distanceM: cartKm * 1000,
              countedSessions: 0,
            ));
      });
      await show(shop, const ShopScreen(), const Size(390, 844));
      await shot(name);
      await end(tester, shop);
    }

    // 2) 화집(= 배낭) 소품 탭·꾸미기 선반: 소품을 모두 가진 상태
    final all = UiEnv();
    await all.seed(tester, () async {
      await all.db.delete(all.db.propsOwned).go();
      await all.db.batch((b) => b.insertAll(all.db.propsOwned, [
            for (final p in props) PropsOwnedCompanion.insert(propId: p.id, unlockedUtc: 1),
          ]));
    });
    await show(all, const AlbumScreen(), const Size(390, 5600));
    await tester.tap(find.byKey(const ValueKey('tab-props')));
    await tester.pump();
    await shot('icons_album_props');

    for (final slot in ['hat', 'cloth', 'pet', 'float']) {
      await show(all, const DecorateScreen(), const Size(390, 1500));
      final tab = find.byKey(ValueKey('tab-$slot'));
      await tester.ensureVisible(tab);
      await tester.pump();
      await tester.tap(tab);
      await tester.pump();
      await shot('icons_decorate_$slot');
    }
    await end(tester, all);
  });
}
