import 'dart:convert';

import 'package:doobal/app/profile_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/color.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/common/app_theme.dart';
import 'package:doobal/ui/common/figure_painter.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/toast.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/decorate/decorate_tabs.dart';
import 'package:doobal/ui/decorate/decorate_widgets.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 탭 내용이 스크롤 없이 다 보이도록 길게 잡은 높이
const _tall = 1400.0;

const _tabs = ['face', 'cloth', 'hat', 'hand', 'bag', 'shoe', 'pet'];
const _tabLabels = ['얼굴', '옷', '모자', '손', '가방', '신발', '어깨 친구'];

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _open(WidgetTester tester, UiEnv e, {double height = _tall}) =>
    openOnTop(tester, e, const DecorateScreen(),
        height: height, ready: () => _key('tab-face').evaluate().isNotEmpty);

/// 가려진 곳(옆으로 미는 탭 줄, 스크롤 안의 칸)도 보이게 한 뒤 누른다
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  // 직접 고르기가 열리면 보이게 미는 애니메이션(0.25초)이 돈다. 끝나야 그 자리를 정확히 누른다
  // (한 프레임은 만들고, 한 프레임은 시작하고, 한 프레임에 끝난다)
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// 탭을 누르면 가려진 탭을 보이게 미는 애니메이션(0.2초)이 돈다. _tap이 끝까지 기다린다
Future<void> _goTab(WidgetTester tester, String id) => _tap(tester, _key('tab-$id'));

/// 꾸미기에서 숨긴 머리·피부 탭을 따로 띄운 것: 고른 모습을 담는다
class _Picked {
  _Picked(this.start) : look = start;

  final Look start;
  Look look;

  /// 고른 모습의 머리 모양·머리색·피부색 (예전 사람 그림의 값)
  FigurePainter get shown => figureOf(look, lookPalette);
  bool get changed => look != start;
}

/// 숨긴 머리·피부 탭(정령 몸 색·베레모 색에 다시 쓴다)을 꾸미기 아래 칸과 같은 틀로 띄운다.
/// 화면 아래 [bodyHeight]만큼이 스크롤 칸이다
Future<_Picked> _openTab(
  WidgetTester tester,
  String tab, {
  Look look = Look.initial,
  double width = 390,
  double bodyHeight = 420,
}) async {
  phone(tester, width: width);
  final picked = _Picked(look);
  await tester.pumpWidget(MaterialApp(
    theme: testDisplayFont == null ? null : doobalTheme(testDisplayFont!),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: bodyHeight,
          child: StatefulBuilder(builder: (context, setState) {
            void set(Look l) => setState(() => picked.look = l);
            return SingleChildScrollView(
              key: ValueKey('body-$tab'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: tab == 'hair'
                  ? HairTab(look: picked.look, palette: lookPalette, onChanged: set)
                  : SkinTab(look: picked.look, palette: lookPalette, onChanged: set),
            );
          }),
        ),
      ),
    ),
  ));
  await tester.pump();
  return picked;
}

/// 번호 칸(눈·코 등)이 골라져 있는지
bool _chosen(WidgetTester tester, String key) => tester
    .widget<Semantics>(find.descendant(of: _key(key), matching: find.byType(Semantics)).first)
    .properties
    .selected!;

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<GameButton>(find.widgetWithText(GameButton, label)).onPressed != null;

/// 끼운 소품 줄의 그 칸 이름
String _worn(WidgetTester tester, String slot) => tester
    .widget<Text>(find.descendant(of: _key('equip-$slot'), matching: find.byType(Text)))
    .data!;

Future<Look> _stored(WidgetTester tester, UiEnv e) async {
  final r = await tester.runAsync(() => e.db.select(e.db.profile).getSingle());
  return Look.fromJson(jsonDecode(r!.look!) as Map<String, dynamic>);
}

/// 저장을 누르고 끝날 때까지 기다린 뒤 토스트를 치운다
Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(GameButton, '저장'));
  await settle(tester, () => find.text('저장했어요').evaluate().isNotEmpty);
  await tester.pump(toastDuration + const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _ownProps(AppDb db, List<String> ids) => db.batch((b) => b.insertAll(db.propsOwned, [
      for (final id in ids) PropsOwnedCompanion.insert(propId: id, unlockedUtc: 1),
    ]));

Future<void> _walked(AppDb db, double km) =>
    db.into(db.daySummaries).insertOnConflictUpdate(DaySummariesCompanion.insert(
          day: '2026-11-18',
          steps: 1000,
          distanceM: km * 1000,
          countedSessions: 0,
          // 거리 소품의 기준은 앱 걷기 이동 거리다
          travelM: Value(km * 1000),
          walkTravelM: Value(km * 1000),
        ));

/// 소품 칸 안의 체크 표시
Finder _check(String id) =>
    find.descendant(of: _key('prop-$id'), matching: find.byIcon(Icons.check_circle));

/// 색(불투명 ARGB)의 HSL 밝기
double _light(Color c) => hslOfArgb(c.toARGB32()).l;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('틀', () {
    testWidgets('제목, 묶음 머리줄(내 모습·소품), 탭 7개가 순서대로 있다 (머리·피부는 숨김)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(find.text('꾸미기'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(find.text('내 모습'), findsOneWidget);
      expect(find.text('소품'), findsOneWidget);
      for (final (i, label) in _tabLabels.indexed) {
        expect(find.descendant(of: _key('tab-${_tabs[i]}'), matching: find.text(label)),
            findsOneWidget,
            reason: label);
      }
      // 정령에는 머리·피부가 없다 (11/4)
      expect(_key('tab-hair'), findsNothing);
      expect(_key('tab-skin'), findsNothing);
      // 왼쪽부터 순서대로 (옆으로 밀어야 보이는 탭도 자리는 순서대로다)
      final xs = [for (final t in _tabs) tester.getTopLeft(_key('tab-$t')).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      // 묶음 머리줄: 내 모습은 얼굴 위, 소품은 옷 위
      final mine = tester.getTopLeft(find.text('내 모습'));
      final props = tester.getTopLeft(find.text('소품'));
      final cloth = tester.getTopLeft(_key('tab-cloth'));
      expect(mine.dx, lessThan(props.dx));
      expect(props.dx, closeTo(cloth.dx, 24));
      expect(props.dy, lessThan(cloth.dy));
      await end(tester, e);
    });

    testWidgets('미리보기는 쉼터와 같은 정령이고, 사람 그림은 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(find.descendant(of: _key('preview'), matching: find.byType(SpiritCharacter)),
          findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FigurePainter),
          findsNothing);
      // 정령은 미리보기 칸 가운데에 선다
      final box = tester.getRect(_key('preview'));
      final spirit = tester.getRect(find.byType(SpiritCharacter));
      expect(spirit.center.dx, closeTo(box.center.dx, 1));
      // 눌러도 저장할 것이 생기지 않는다
      await tester.tap(_key('preview'));
      await tester.pump();
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('고른 얼굴과 Rive에 붙은 소품이 저장 전에도 미리보기 정령에 입혀진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['cloth_02', 'pet_05', 'hat_02']));
      await _open(tester, e);
      SpiritLook worn() => tester.widget<SpiritCharacter>(find.byType(SpiritCharacter)).look;

      expect(worn(), SpiritLook.base);
      await _tap(tester, _key('eyes-5'));
      expect(worn().eye, 4);
      await _tap(tester, _key('nose-1'));
      expect(worn().nose, 3, reason: '코 없음은 Rive 값 3');
      await _goTab(tester, 'cloth');
      await _tap(tester, _key('prop-cloth_02'));
      expect(worn().outfit, 1);
      await _goTab(tester, 'pet');
      await _tap(tester, _key('prop-pet_05'));
      expect(worn().companion, 1);
      // 리깅 전 소품은 골라도 정령 값이 바뀌지 않는다
      final before = worn();
      await _goTab(tester, 'hat');
      await _tap(tester, _key('prop-hat_02'));
      expect(worn(), before);
      await end(tester, e);
    });

    testWidgets('처음에는 얼굴 탭이 열려 있고 저장·되돌리기는 눌리지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(_key('eyes-1'), findsOneWidget);
      expect(_chosen(tester, 'eyes-1'), isTrue);
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);
      expect(find.text('저장'), findsOneWidget);
      expect(find.text('되돌리기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('끼운 소품 줄: 칸마다 이름 (기본 소품)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(_worn(tester, 'cloth'), '앞치마 작업복');
      expect(_worn(tester, 'hat'), '베레모');
      expect(_worn(tester, 'hand'), '붓');
      expect(_worn(tester, 'bag'), '화구 가방');
      expect(_worn(tester, 'shoe'), '갈색 신발');
      expect(_worn(tester, 'pet'), '종이새');
      // 옷 · 모자 · 손 · 가방 · 신발 · 어깨 친구 순서
      final xs = [
        for (final s in ['cloth', 'hat', 'hand', 'bag', 'shoe', 'pet'])
          tester.getTopLeft(_key('equip-$s')).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      await end(tester, e);
    });

    testWidgets('옛 모습({hair, hairColor}만)도 기본값으로 열린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.db.into(e.db.profile).insertOnConflictUpdate(ProfileCompanion(
              id: const Value(1),
              look: const Value('{"hair":4,"hairColor":{"kind":"swatch","i":3}}'),
            ));
      });
      await _open(tester, e);

      expect(_chosen(tester, 'eyes-1'), isTrue);
      expect(_worn(tester, 'cloth'), '앞치마 작업복');
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('탭 7개를 눌러 바꾸면 그 탭의 내용이 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      const marker = {
        'face': 'eyes-1',
        'cloth': 'prop-cloth_01',
        'hat': 'prop-hat_01',
        'hand': 'prop-hand_01',
        'bag': 'prop-bag_01',
        'shoe': 'prop-shoe_01',
        'pet': 'prop-pet_01',
      };
      for (final t in _tabs) {
        await _goTab(tester, t);
        for (final m in marker.entries) {
          expect(_key(m.value), m.key == t ? findsOneWidget : findsNothing,
              reason: '$t / ${m.key}');
        }
      }
      // 되돌아와도 된다
      await _goTab(tester, 'face');
      expect(_key('eyes-1'), findsOneWidget);
      expect(_key('prop-pet_01'), findsNothing);
      await end(tester, e);
    });

    testWidgets('탭을 오가도 고른 것은 남고 저장 단추는 계속 켜져 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('eyes-3'));
      await _goTab(tester, 'hat');
      await _goTab(tester, 'face');
      expect(_chosen(tester, 'eyes-3'), isTrue);
      expect(_enabled(tester, '저장'), isTrue);
      await end(tester, e);
    });
  });

  // 머리·피부 탭은 꾸미기에서 숨겼다 (11/4). 정령 몸 색·베레모 색에 다시 쓸 때까지 탭만 따로 본다
  group('머리 탭 (숨김)', () {
    testWidgets('모양 6칸과 색 견본 10개, 직접 고르기·그라데이션 단추', (tester) async {
      await _openTab(tester, 'hair');

      for (var i = 1; i <= 6; i++) {
        expect(_key('hair-$i'), findsOneWidget);
      }
      expect(_key('hair-7'), findsNothing);
      for (final s in hairSwatches) {
        expect(_key('hair-swatch-${s.id}'), findsOneWidget, reason: s.name);
      }
      expect(find.text('직접 고르기'), findsOneWidget);
      expect(find.text('그라데이션'), findsOneWidget);
      expect(_key('picker'), findsNothing);
    });

    testWidgets('견본을 고르면 머리색이 바뀐다', (tester) async {
      final picked = await _openTab(tester, 'hair');

      await _tap(tester, _key('hair-swatch-10'));
      expect(picked.shown.hairColor, const Color(0xFFE39AB0));
      expect(picked.changed, isTrue);
    });

    testWidgets('머리 모양을 고르면 모양이 바뀐다', (tester) async {
      final picked = await _openTab(tester, 'hair');

      await _tap(tester, _key('hair-4'));
      expect(picked.shown.hair, 4);
    });

    testWidgets('같은 견본을 다시 누르면 바뀐 게 없다', (tester) async {
      final picked = await _openTab(tester, 'hair');

      await _tap(tester, _key('hair-swatch-1'));
      expect(picked.changed, isFalse);
      await _tap(tester, _key('hair-swatch-5'));
      expect(picked.changed, isTrue);
      await _tap(tester, _key('hair-swatch-1'));
      expect(picked.changed, isFalse);
    });

    testWidgets('직접 고르기: 색상환(색조 링)과 밝기 막대가 뜨고 지금 색에서 시작한다', (tester) async {
      final picked = await _openTab(tester, 'hair');

      await _tap(tester, _key('hair-custom'));
      expect(_key('picker'), findsOneWidget);
      expect(_key('hue-ring'), findsOneWidget);
      expect(_key('light-bar'), findsOneWidget);
      expect(find.textContaining('밝기'), findsOneWidget);
      // 견본 1에서 시작: 색은 그대로 (범위 안이라 안 잘린다)
      expect(picked.shown.hairColor, Color(hairSwatches.first.color));
      // 종류가 견본에서 직접 고르기로 바뀌었다
      expect(picked.changed, isTrue);

      // 견본을 누르면 직접 고르기는 닫힌다
      await _tap(tester, _key('hair-swatch-3'));
      expect(_key('picker'), findsNothing);
    });

    testWidgets('직접 고르기가 스크롤 아래에서 열려도 색상환·밝기 막대가 보이게 민다', (tester) async {
      await _openTab(tester, 'hair', bodyHeight: 300);

      await _tap(tester, _key('hair-custom'));
      final viewport = tester.getRect(_key('body-hair'));
      expect(viewport.contains(tester.getCenter(_key('hue-ring'))), isTrue);
      expect(viewport.contains(tester.getCenter(_key('light-bar'))), isTrue);
    });

    testWidgets('직접 고르기 밝기 제한: 막대 끝까지 끌어도 15~90%를 넘지 않는다', (tester) async {
      final picked = await _openTab(tester, 'hair');
      await _tap(tester, _key('hair-custom'));

      final bar = _key('light-bar');
      final left = tester.getTopLeft(bar);
      final size = tester.getSize(bar);
      final mid = Offset(left.dx + size.width / 2, left.dy + size.height / 2);

      // 가운데: 범위의 한가운데 (52.5%)
      await tester.tapAt(mid);
      await tester.pump();
      expect(_light(picked.shown.hairColor), closeTo(0.525, 0.01));

      // 왼쪽 끝을 지나 끌기: 15%
      await tester.dragFrom(mid, const Offset(-2000, 0));
      await tester.pump();
      expect(_light(picked.shown.hairColor), closeTo(0.15, 0.01));
      expect(_light(picked.shown.hairColor), greaterThan(0.14));
      expect(find.text('밝기 15%'), findsOneWidget);

      // 오른쪽 끝을 지나 끌기: 90%
      await tester.dragFrom(mid, const Offset(2000, 0));
      await tester.pump();
      expect(_light(picked.shown.hairColor), closeTo(0.90, 0.01));
      expect(_light(picked.shown.hairColor), lessThan(0.91));
      expect(find.text('밝기 90%'), findsOneWidget);
    });

    testWidgets('색상환을 누르면 그 방향의 색조가 되고, 밝기는 그대로다', (tester) async {
      final picked = await _openTab(tester, 'hair');
      await _tap(tester, _key('hair-custom'));

      // 밝기를 가운데로
      final bar = _key('light-bar');
      await tester.tapAt(tester.getCenter(bar));
      await tester.pump();
      final l0 = _light(picked.shown.hairColor);

      final ring = _key('hue-ring');
      final c = tester.getCenter(ring);
      final r = tester.getSize(ring).width / 2 - 18;
      double hue() => hslOfArgb(picked.shown.hairColor.toARGB32()).h;

      await tester.tapAt(c + Offset(0, r)); // 아래쪽 = 90도 (시계 방향으로 3시에서 90도)
      await tester.pump();
      expect(hue(), closeTo(90, 3));
      await tester.tapAt(c + Offset(-r, 0)); // 왼쪽 = 180도
      await tester.pump();
      expect(hue(), closeTo(180, 3));
      await tester.tapAt(c + Offset(0, -r)); // 위쪽 = 270도
      await tester.pump();
      expect(hue(), closeTo(270, 3));
      expect(_light(picked.shown.hairColor), closeTo(l0, 0.01));

      // 가운데 원 안은 눌러도 안 바뀐다
      final before = picked.shown.hairColor;
      await tester.tapAt(c);
      await tester.pump();
      expect(picked.shown.hairColor, before);
    });

    testWidgets('직접 고른 색은 custom hex로 남는다', (tester) async {
      final picked = await _openTab(tester, 'hair');
      await _tap(tester, _key('hair-custom'));
      final ring = _key('hue-ring');
      await tester.tapAt(tester.getCenter(ring) + Offset(tester.getSize(ring).width / 2 - 18, 0));
      await tester.pump();

      final color = picked.shown.hairColor;
      expect(picked.look.hairColor, CustomHairColor(hexFromArgb(color.toARGB32())));
    });

    testWidgets('그라데이션: 뿌리색·끝색 두 칸을 견본으로 골라 이어서 보인다', (tester) async {
      final picked = await _openTab(tester, 'hair');

      await _tap(tester, _key('hair-gradient'));
      expect(_key('grad-root'), findsOneWidget);
      expect(_key('grad-tip'), findsOneWidget);
      expect(find.text('뿌리색'), findsOneWidget);
      expect(find.text('끝색'), findsOneWidget);
      // 처음에는 두 칸 모두 지금 색
      expect(picked.shown.hairGradient!.tip, Color(hairSwatches.first.color));

      await _tap(tester, _key('grad-tip'));
      await _tap(tester, _key('grad-swatch-10'));
      var p = picked.shown;
      expect(p.hairColor, Color(hairSwatches.first.color));
      expect(p.hairGradient!.tip, Color(hairSwatches.last.color));
      // 구간은 palette.json (30%·85%)
      expect(p.hairGradient!.rootUntil, 0.3);
      expect(p.hairGradient!.tipFrom, 0.85);

      await _tap(tester, _key('grad-root'));
      await _tap(tester, _key('grad-swatch-6'));
      p = picked.shown;
      expect(p.hairColor, Color(hairSwatches[5].color));
      expect(p.hairGradient!.tip, Color(hairSwatches.last.color));
      expect(picked.look.hairColor, const GradientHairColor('#D6B26E', '#E39AB0'));
    });

    testWidgets('그라데이션 칸도 직접 고르기: 밝기 제한을 받는다', (tester) async {
      final picked = await _openTab(tester, 'hair');
      await _tap(tester, _key('hair-gradient'));
      await _tap(tester, _key('grad-tip'));
      expect(_key('picker'), findsNothing);
      await _tap(tester, _key('grad-custom'));
      expect(_key('picker'), findsOneWidget);

      final bar = _key('light-bar');
      await tester.ensureVisible(bar);
      await tester.pump();
      final mid = tester.getCenter(bar);
      await tester.dragFrom(mid, const Offset(2000, 0));
      await tester.pump();
      var p = picked.shown;
      expect(_light(p.hairGradient!.tip), closeTo(0.90, 0.01));
      // 뿌리색은 그대로
      expect(p.hairColor, Color(hairSwatches.first.color));

      await tester.dragFrom(mid, const Offset(-2000, 0));
      await tester.pump();
      p = picked.shown;
      expect(_light(p.hairGradient!.tip), closeTo(0.15, 0.01));

      // 견본을 고르면 직접 고르기는 닫힌다
      await _tap(tester, _key('grad-swatch-7'));
      expect(_key('picker'), findsNothing);
      expect(picked.shown.hairGradient!.tip, Color(hairSwatches[6].color));
    });

    testWidgets('견본·직접 고르기·그라데이션을 오가면 마지막 것이 머리색', (tester) async {
      final picked = await _openTab(tester, 'hair');

      await _tap(tester, _key('hair-gradient'));
      expect(picked.shown.hairGradient, isNotNull);
      await _tap(tester, _key('hair-custom'));
      expect(picked.shown.hairGradient, isNull);
      expect(_key('picker'), findsOneWidget);
      expect(_key('grad-root'), findsNothing);
      await _tap(tester, _key('hair-swatch-2'));
      expect(picked.shown.hairColor, Color(hairSwatches[1].color));
      expect(_key('picker'), findsNothing);
    });

    testWidgets('그라데이션·직접 고른 색으로 열면 해당 칸이 열려 있다', (tester) async {
      final picked = await _openTab(tester, 'hair',
          look: const Look(hair: 2, hairColor: GradientHairColor('#2B2522', '#102030')));

      expect(picked.shown.hairGradient!.tip, const Color(0xFF102030));
      expect(_key('grad-root'), findsOneWidget);
      // 끝색 칸은 견본이 아닌 색이라 직접 고르기가 열려 있다
      await _tap(tester, _key('grad-tip'));
      expect(_key('picker'), findsOneWidget);
      expect(picked.changed, isFalse);
    });

    testWidgets('좁은 화면(320)에서 직접 고르기·그라데이션이 열려도 넘치지 않는다', (tester) async {
      await _openTab(tester, 'hair', width: 320, bodyHeight: 260);
      await _tap(tester, _key('hair-custom'));
      expect(tester.takeException(), isNull);
      await _tap(tester, _key('hair-gradient'));
      await _tap(tester, _key('grad-custom'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('색상환·밝기 막대를 끌어도 안쪽 스크롤은 움직이지 않는다', (tester) async {
      await _openTab(tester, 'hair', bodyHeight: 300);
      await _tap(tester, _key('hair-custom'));

      final scroll = tester.state<ScrollableState>(find
          .descendant(of: _key('body-hair'), matching: find.byType(Scrollable))
          .first);
      final before = scroll.position.pixels;
      final ring = _key('hue-ring');
      final c = tester.getCenter(ring);
      await tester.dragFrom(c + const Offset(70, 0), const Offset(0, -60));
      await tester.pump();
      expect(scroll.position.pixels, before);
    });
  });

  group('얼굴 탭', () {
    testWidgets('눈 5 · 눈썹 5 · 코 7 · 입 6을 줄별로 고른다 (정령에 귀는 없다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'face');

      for (final t in ['눈', '눈썹', '코', '입']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('귀'), findsNothing);
      for (final (k, n) in [('eyes', 5), ('brows', 5), ('nose', 7), ('mouth', 6)]) {
        for (var i = 1; i <= n; i++) {
          expect(_key('$k-$i'), findsOneWidget, reason: '$k-$i');
        }
      }
      // 코 7칸은 6칸 줄을 넘어 다음 줄로 간다
      expect(tester.getTopLeft(_key('nose-7')).dy, greaterThan(tester.getTopLeft(_key('nose-6')).dy));
      for (final k in ['eyes-6', 'nose-8', 'brows-6', 'mouth-7', 'ears-1']) {
        expect(_key(k), findsNothing, reason: k);
      }
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('고르고 저장하면 look에 번호가 남는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'face');

      await _tap(tester, _key('eyes-3'));
      await _tap(tester, _key('nose-2'));
      await _tap(tester, _key('brows-3'));
      await _tap(tester, _key('mouth-4'));
      expect(_enabled(tester, '저장'), isTrue);
      await _save(tester);

      final look = await _stored(tester, e);
      expect((look.eyes, look.nose, look.brows, look.mouth), (3, 2, 3, 4));
      // 숨긴 귀는 그대로
      expect(look.ears, Look.initial.ears);
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });
  });

  group('피부 탭 (숨김)', () {
    testWidgets('견본 7개를 고르면 얼굴색이 바뀐다', (tester) async {
      final picked = await _openTab(tester, 'skin');

      for (final s in lookPalette.skin.swatches) {
        expect(_key('skin-swatch-${s.id}'), findsOneWidget, reason: s.name);
      }
      expect(_key('skin-swatch-8'), findsNothing);
      await _tap(tester, _key('skin-swatch-7'));
      expect(picked.shown.skin, const Color(0xFF966242));
      expect(picked.look.skin, const SwatchSkinColor(7));
    });

    testWidgets('직접 고르기 밝기 제한: 35~95%', (tester) async {
      final picked = await _openTab(tester, 'skin');
      await _tap(tester, _key('skin-custom'));
      expect(_key('picker'), findsOneWidget);

      final mid = tester.getCenter(_key('light-bar'));
      await tester.dragFrom(mid, const Offset(-2000, 0));
      await tester.pump();
      expect(_light(picked.shown.skin), closeTo(0.35, 0.01));
      expect(_light(picked.shown.skin), greaterThan(0.34));
      expect(find.text('밝기 35%'), findsOneWidget);

      await tester.dragFrom(mid, const Offset(2000, 0));
      await tester.pump();
      expect(_light(picked.shown.skin), closeTo(0.95, 0.01));
      expect(_light(picked.shown.skin), lessThan(0.96));
      expect(find.text('밝기 95%'), findsOneWidget);
      expect(picked.look.skin, isA<CustomSkinColor>());
    });

    testWidgets('직접 고르기는 머리와 달리 피부 견본으로 돌아가면 닫힌다', (tester) async {
      final picked = await _openTab(tester, 'skin');
      await _tap(tester, _key('skin-custom'));
      await _tap(tester, _key('skin-swatch-2'));
      expect(_key('picker'), findsNothing);
      expect(picked.shown.skin, Color(lookPalette.skin.swatches[1].color));
    });

    testWidgets('좁은 화면(320)에서 직접 고르기가 열려도 넘치지 않는다', (tester) async {
      await _openTab(tester, 'skin', width: 320, bodyHeight: 260);
      await _tap(tester, _key('skin-custom'));
      expect(tester.takeException(), isNull);
    });
  });

  group('소품 탭', () {
    testWidgets('그 칸의 가진 소품을 4열 격자로, 옷이 아니면 맨 앞에 없음 칸', (tester) async {
      final e = UiEnv();
      // 모두 가진 상태에서 격자를 본다
      await e.seed(
          tester,
          () => _ownProps(e.db, [
                for (final p in props)
                  if (p.kind != PropUnlockKind.initial) p.id,
              ]));
      await _open(tester, e);

      // 모자: 없음 + 7개 = 8칸 (4열 두 줄)
      await _goTab(tester, 'hat');
      expect(find.byType(PropCell), findsNWidgets(8));
      expect(_key('prop-none'), findsOneWidget);
      final order = ['none', 'hat_01', 'hat_02', 'hat_03', 'hat_04', 'hat_05', 'hat_10', 'hat_11'];
      final pos = [for (final id in order) tester.getTopLeft(_key('prop-$id'))];
      expect(pos.take(4).map((p) => p.dy).toSet(), hasLength(1));
      expect(pos.skip(4).map((p) => p.dy).toSet(), hasLength(1));
      expect(pos[4].dy, greaterThan(pos[0].dy));
      // 왼쪽에서 오른쪽으로 네 칸, 둘째 줄은 같은 세로줄
      final xs = [for (final p in pos.take(4)) p.dx];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(xs.toSet(), hasLength(4));
      expect([for (var i = 0; i < 4; i++) pos[4 + i].dx], [for (var i = 0; i < 4; i++) pos[i].dx]);

      // 옷: 없음 칸이 없다 (4개)
      await _goTab(tester, 'cloth');
      expect(find.byType(PropCell), findsNWidgets(4));
      expect(_key('prop-none'), findsNothing);
      expect(find.text('없음'), findsNothing);

      // 칸마다 MVP 소품 수 (+ 없음)
      for (final (slot, count) in [('hand', 6), ('bag', 3), ('shoe', 2), ('pet', 5)]) {
        await _goTab(tester, slot);
        expect(find.byType(PropCell), findsNWidgets(count + 1), reason: slot);
        expect(props.where((p) => p.slot == slot), hasLength(count));
      }
      await end(tester, e);
    });

    testWidgets('가진 소품만 칸이 되고 잠긴 소품은 보이지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02']));
      await _open(tester, e);
      await _goTab(tester, 'hat');

      // 없음 + 기본 hat_01 + 얻은 hat_02
      expect(find.byType(PropCell), findsNWidgets(3));
      for (final id in ['hat_03', 'hat_04', 'hat_05', 'hat_10', 'hat_11']) {
        expect(_key('prop-$id'), findsNothing, reason: id);
      }
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.descendant(of: find.byType(PropCell), matching: find.byType(Opacity)),
          findsNothing);
      // 고른 것(hat_01)에 체크
      expect(_check('hat_01'), findsOneWidget);
      expect(_check('hat_02'), findsNothing);

      await _tap(tester, _key('prop-hat_02'));
      expect(_worn(tester, 'hat'), '깃털 꽂은 여행 모자');
      expect(_check('hat_02'), findsOneWidget);
      expect(_check('hat_01'), findsNothing);
      expect(_enabled(tester, '저장'), isTrue);

      await _save(tester);
      expect((await _stored(tester, e)).slots['hat'], 'hat_02');

      // 옷은 기본 하나뿐이면 그 칸만 (없음 칸 없음)
      await _goTab(tester, 'cloth');
      expect(find.byType(PropCell), findsOneWidget);
      expect(_key('prop-cloth_01'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('소품 칸 위에 다음 거리 소품까지 남은 본격 걷기 거리 한 줄 (무엇인지는 숨김)', (tester) async {
      final e = UiEnv();
      // 이동 거리 87km: 다음 거리 소품은 100km(등산화)라 13km
      await e.seed(tester, () => _walked(e.db, 87));
      await _open(tester, e);

      // 내 모습 탭에는 없다
      expect(_key('next-prop'), findsNothing);
      for (final slot in ['hat', 'cloth', 'pet']) {
        await _goTab(tester, slot);
        expect(find.text('다음 소품까지 본격 걷기 13km'), findsOneWidget, reason: slot);
        // 줄은 칸들 위에 있다
        expect(tester.getBottomLeft(_key('next-prop')).dy,
            lessThan(tester.getTopLeft(find.byType(PropCell).first).dy));
      }
      expect(find.textContaining('등산화'), findsNothing);
      await end(tester, e);
    });

    testWidgets('거리 소품을 다 얻었으면 남은 거리 줄이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walked(e.db, 1000));
      await _open(tester, e);
      await _goTab(tester, 'hand');
      expect(_key('next-prop'), findsNothing);
      await end(tester, e);
    });

    testWidgets('없음 칸: 비우면 끼운 소품 줄이 없음이 되고 저장하면 null로 남는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'hat');

      expect(find.descendant(of: _key('prop-none'), matching: find.text('없음')), findsOneWidget);
      await _tap(tester, _key('prop-none'));
      expect(_worn(tester, 'hat'), '없음');
      expect(_check('none'), findsOneWidget);
      expect(_check('hat_01'), findsNothing);
      expect(_enabled(tester, '저장'), isTrue);

      await _save(tester);
      final look = await _stored(tester, e);
      expect(look.slots['hat'], isNull);
      expect(look.slots['cloth'], 'cloth_01');
      await end(tester, e);
    });

    testWidgets('비운 칸에 기본 소품을 다시 끼울 수 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'bag');
      await _tap(tester, _key('prop-none'));
      expect(_worn(tester, 'bag'), '없음');
      await _tap(tester, _key('prop-bag_01'));
      expect(_worn(tester, 'bag'), '화구 가방');
      // 저장된 모습과 같아졌다
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('소품 이름은 접근성 label로도 읽히고, 잠긴 소품은 읽히지도 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'hand');

      expect(find.bySemanticsLabel('붓'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('나침반')), findsNothing);
      expect(find.bySemanticsLabel('없음'), findsWidgets);
      handle.dispose();
      await end(tester, e);
    });
  });

  group('저장 · 되돌리기', () {
    testWidgets('저장하면 Profile.look에 JSON으로 남고 단추가 다시 꺼진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hand_02']));
      await _open(tester, e);

      await _tap(tester, _key('eyes-2'));
      await _tap(tester, _key('nose-3'));
      await _goTab(tester, 'hand');
      await _tap(tester, _key('prop-hand_02'));
      await _save(tester);

      final look = await _stored(tester, e);
      expect((look.eyes, look.nose), (2, 3));
      // 숨긴 머리·피부는 그대로
      expect(look.hair, Look.initial.hair);
      expect(look.skin, Look.initial.skin);
      expect(look.slots['hand'], 'hand_02');
      expect(look.slots['hat'], 'hat_01');
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);

      // 닉네임 같은 다른 열은 그대로
      final row = await tester.runAsync(() => ProfileService(e.db).row());
      expect(row!.nickname, '화가');
      await end(tester, e);
    });

    testWidgets('저장 뒤 다시 바꾸면 다시 켜지고, 되돌리기는 방금 저장한 모습으로 간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('eyes-3'));
      await _save(tester);
      await _tap(tester, _key('eyes-2'));
      expect(_enabled(tester, '저장'), isTrue);
      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      expect(_chosen(tester, 'eyes-3'), isTrue);
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('저장하면 "저장했어요" 토스트가 뜬다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('eyes-2'));
      await tester.tap(find.widgetWithText(GameButton, '저장'));
      await settle(tester, () => find.text('저장했어요').evaluate().isNotEmpty);
      expect(find.text('저장했어요'), findsOneWidget);
      await tester.pump(toastDuration + const Duration(seconds: 1));
      await end(tester, e);
    });

    testWidgets('되돌리기: 얼굴·소품 모두 저장된 모습으로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('brows-3'));
      await _goTab(tester, 'shoe');
      await _tap(tester, _key('prop-none'));
      expect(_enabled(tester, '되돌리기'), isTrue);

      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      expect(_worn(tester, 'shoe'), '갈색 신발');
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);
      await _goTab(tester, 'face');
      expect(_chosen(tester, 'brows-2'), isTrue);
      // DB는 그대로 (저장한 적 없다)
      final row = await tester.runAsync(() => e.db.select(e.db.profile).getSingle());
      expect(Look.fromJson(jsonDecode(row!.look!) as Map<String, dynamic>), Look.initial);
      await end(tester, e);
    });

    testWidgets('저장 단추는 바뀐 게 있을 때만 눌린다 (눌러도 아무 일 없다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await tester.tap(find.widgetWithText(GameButton, '저장'));
      await tester.pump();
      expect(find.text('저장했어요'), findsNothing);
      await end(tester, e);
    });
  });

  group('나가기', () {
    testWidgets('바꾼 게 없으면 확인 없이 나간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.text('열기'), findsOneWidget);
      expect(find.byType(DecorateScreen), findsNothing);
      await end(tester, e);
    });

    testWidgets('바꾸고 나가려 하면 확인 시트: 계속 꾸미기는 그대로 남고, 나가기는 저장 없이 나간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('eyes-3'));

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
      expect(find.widgetWithText(GameButton, '나가기'), findsOneWidget);
      expect(find.widgetWithText(GameButton, '계속 꾸미기'), findsOneWidget);
      // 주 = 나가기 (위), 보조 = 계속 꾸미기 (아래)
      GameButtonKind kindOf(String label) =>
          tester.widget<GameButton>(find.widgetWithText(GameButton, label)).kind;
      expect(kindOf('나가기'), GameButtonKind.primary);
      expect(kindOf('계속 꾸미기'), GameButtonKind.secondary);

      await tester.tap(find.text('계속 꾸미기'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsOneWidget);
      expect(_chosen(tester, 'eyes-3'), isTrue);
      expect(_enabled(tester, '저장'), isTrue);

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await tester.tap(find.text('나가기'));
      await transition(tester);
      expect(find.byType(DecorateScreen), findsNothing);
      expect(find.text('열기'), findsOneWidget);
      // 저장은 안 됐다
      final row = await tester.runAsync(() => e.db.select(e.db.profile).getSingle());
      expect(Look.fromJson(jsonDecode(row!.look!) as Map<String, dynamic>), Look.initial);
      await end(tester, e);
    });

    testWidgets('시스템 뒤로(안드로이드 뒤로 가기)도 같은 확인 시트', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('eyes-2'));

      await tester.binding.handlePopRoute();
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('계속 꾸미기'));
      await transition(tester);
      expect(find.byType(DecorateScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('시트 밖을 눌러 닫으면 계속 꾸민다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('eyes-2'));
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      await tester.tapAt(const Offset(195, 30));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('저장했거나 되돌렸으면 다시 확인 없이 나간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('eyes-2'));
      await _save(tester);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsNothing);
      await end(tester, e);

      final e2 = UiEnv();
      await e2.seed(tester);
      await _open(tester, e2);
      await _tap(tester, _key('eyes-3'));
      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsNothing);
      await end(tester, e2);
    });
  });

  group('화면 크기', () {
    testWidgets('좁고 낮은 화면(320×568)에서도 모든 탭이 넘치지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02', 'cloth_02']));
      await _open(tester, e, height: 568);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();

      for (final t in _tabs) {
        await _goTab(tester, t);
        expect(tester.takeException(), isNull, reason: t);
      }
      // 소품 이름이 길어도 (모자 8칸)
      await _goTab(tester, 'hat');
      await _tap(tester, _key('prop-hat_02'));
      expect(tester.takeException(), isNull);
      await end(tester, e);
    });

  });
}
