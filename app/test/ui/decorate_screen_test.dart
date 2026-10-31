import 'dart:convert';
import 'dart:math' as math;

import 'package:doobal/app/profile_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/color.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/ui/common/figure_painter.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/toast.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/decorate/decorate_widgets.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 탭 내용이 스크롤 없이 다 보이도록 길게 잡은 높이
const _tall = 1400.0;

const _tabs = ['hair', 'face', 'skin', 'cloth', 'hat', 'hand', 'bag', 'shoe', 'pet'];
const _tabLabels = ['머리', '얼굴', '피부', '옷', '모자', '손', '가방', '신발', '어깨 친구'];

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _open(WidgetTester tester, UiEnv e, {double height = _tall}) =>
    openOnTop(tester, e, const DecorateScreen(),
        height: height, ready: () => _key('tab-hair').evaluate().isNotEmpty);

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

/// 미리보기 자리표시 그림
FigurePainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FigurePainter))
    .painter! as FigurePainter;

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
        ));

/// 소품 칸 안의 자물쇠·체크 표시
Finder _lock(String id) => find.descendant(of: _key('prop-$id'), matching: find.byIcon(Icons.lock));
Finder _check(String id) =>
    find.descendant(of: _key('prop-$id'), matching: find.byIcon(Icons.check_circle));

/// 색(불투명 ARGB)의 HSL 밝기
double _light(Color c) => hslOfArgb(c.toARGB32()).l;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('틀', () {
    testWidgets('제목, 묶음 머리줄(내 모습·소품), 탭 9개가 명세 순서로 있다', (tester) async {
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
      // 왼쪽부터 순서대로 (옆으로 밀어야 보이는 탭도 자리는 순서대로다)
      final xs = [for (final t in _tabs) tester.getTopLeft(_key('tab-$t')).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      // 묶음 머리줄: 내 모습은 머리·얼굴·피부 위, 소품은 옷 위
      final mine = tester.getTopLeft(find.text('내 모습'));
      final props = tester.getTopLeft(find.text('소품'));
      final cloth = tester.getTopLeft(_key('tab-cloth'));
      expect(mine.dx, lessThan(props.dx));
      expect(props.dx, closeTo(cloth.dx, 24));
      expect(props.dy, lessThan(cloth.dy));
      await end(tester, e);
    });

    testWidgets('처음에는 저장된 모습이 미리보기에 나오고 저장·되돌리기는 눌리지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      final p = _painter(tester);
      expect(p.hair, 1);
      expect(p.hairColor, Color(hairSwatches.first.color));
      expect(p.hairGradient, isNull);
      expect(p.skin, Color(lookPalette.skin.swatches.first.color));
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);
      expect(find.text('저장'), findsOneWidget);
      expect(find.text('되돌리기'), findsOneWidget);
      // 첫 탭은 머리
      expect(_key('hair-1'), findsOneWidget);
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

      final p = _painter(tester);
      expect(p.hair, 4);
      expect(p.hairColor, Color(hairSwatches[2].color));
      expect(p.skin, Color(lookPalette.skin.swatches.first.color));
      expect(_worn(tester, 'cloth'), '앞치마 작업복');
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('탭 9개를 눌러 바꾸면 그 탭의 내용이 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      const marker = {
        'hair': 'hair-1',
        'face': 'eyes-1',
        'skin': 'skin-swatch-1',
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
      await _goTab(tester, 'hair');
      expect(_key('hair-1'), findsOneWidget);
      expect(_key('prop-pet_01'), findsNothing);
      await end(tester, e);
    });

    testWidgets('탭을 오가도 고른 것은 남고 저장 단추는 계속 켜져 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-swatch-6'));
      await _goTab(tester, 'skin');
      await _goTab(tester, 'hat');
      await _goTab(tester, 'hair');
      expect(_painter(tester).hairColor, Color(hairSwatches[5].color));
      expect(_enabled(tester, '저장'), isTrue);
      await end(tester, e);
    });

    testWidgets('미리보기를 누르면 작게 흔들렸다가 가만히 선다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      double tilt() {
        final t = tester.widget<Transform>(_key('figure-wiggle'));
        return math.asin(t.transform.storage[1]);
      }

      expect(tilt(), 0);
      await tester.tap(_key('preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tilt().abs(), greaterThan(0.01));
      expect(tilt().abs(), lessThan(0.1));
      await tester.pump(const Duration(seconds: 1));
      expect(tilt().abs(), lessThan(1e-9));
      // 저장할 것이 생기지 않는다
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });
  });

  group('머리 탭', () {
    testWidgets('모양 6칸과 색 견본 10개, 직접 고르기·그라데이션 단추', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

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
      await end(tester, e);
    });

    testWidgets('견본을 고르면 미리보기 머리색이 바뀌고 저장이 켜진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-swatch-10'));
      expect(_painter(tester).hairColor, const Color(0xFFE39AB0));
      expect(_enabled(tester, '저장'), isTrue);
      expect(_enabled(tester, '되돌리기'), isTrue);
      await end(tester, e);
    });

    testWidgets('머리 모양을 고르면 미리보기 모양이 바뀐다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-4'));
      expect(_painter(tester).hair, 4);
      expect(_enabled(tester, '저장'), isTrue);
      await end(tester, e);
    });

    testWidgets('같은 견본을 다시 누르면 바뀐 게 없어서 저장은 꺼진 채다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-swatch-1'));
      expect(_enabled(tester, '저장'), isFalse);
      await _tap(tester, _key('hair-swatch-5'));
      expect(_enabled(tester, '저장'), isTrue);
      await _tap(tester, _key('hair-swatch-1'));
      // 저장된 모습으로 돌아왔으니 다시 꺼진다
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('직접 고르기: 색상환(색조 링)과 밝기 막대가 뜨고 지금 색에서 시작한다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-custom'));
      expect(_key('picker'), findsOneWidget);
      expect(_key('hue-ring'), findsOneWidget);
      expect(_key('light-bar'), findsOneWidget);
      expect(find.textContaining('밝기'), findsOneWidget);
      // 견본 1에서 시작: 색은 그대로 (범위 안이라 안 잘린다)
      expect(_painter(tester).hairColor, Color(hairSwatches.first.color));
      // 종류가 견본에서 직접 고르기로 바뀌었으니 저장은 켜진다
      expect(_enabled(tester, '저장'), isTrue);

      // 견본을 누르면 직접 고르기는 닫힌다
      await _tap(tester, _key('hair-swatch-3'));
      expect(_key('picker'), findsNothing);
      await end(tester, e);
    });

    testWidgets('직접 고르기가 스크롤 아래에서 열려도 색상환·밝기 막대가 보이게 민다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, height: 844);

      await _tap(tester, _key('hair-custom'));
      final viewport = tester.getRect(_key('body-hair'));
      expect(viewport.contains(tester.getCenter(_key('hue-ring'))), isTrue);
      expect(viewport.contains(tester.getCenter(_key('light-bar'))), isTrue);
      await end(tester, e);
    });

    testWidgets('직접 고르기 밝기 제한: 막대 끝까지 끌어도 15~90%를 넘지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('hair-custom'));

      final bar = _key('light-bar');
      final left = tester.getTopLeft(bar);
      final size = tester.getSize(bar);
      final mid = Offset(left.dx + size.width / 2, left.dy + size.height / 2);

      // 가운데: 범위의 한가운데 (52.5%)
      await tester.tapAt(mid);
      await tester.pump();
      expect(_light(_painter(tester).hairColor), closeTo(0.525, 0.01));

      // 왼쪽 끝을 지나 끌기: 15%
      await tester.dragFrom(mid, const Offset(-2000, 0));
      await tester.pump();
      expect(_light(_painter(tester).hairColor), closeTo(0.15, 0.01));
      expect(_light(_painter(tester).hairColor), greaterThan(0.14));
      expect(find.text('밝기 15%'), findsOneWidget);

      // 오른쪽 끝을 지나 끌기: 90%
      await tester.dragFrom(mid, const Offset(2000, 0));
      await tester.pump();
      expect(_light(_painter(tester).hairColor), closeTo(0.90, 0.01));
      expect(_light(_painter(tester).hairColor), lessThan(0.91));
      expect(find.text('밝기 90%'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('색상환을 누르면 그 방향의 색조가 되고, 밝기는 그대로다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('hair-custom'));

      // 밝기를 가운데로
      final bar = _key('light-bar');
      await tester.tapAt(tester.getCenter(bar));
      await tester.pump();
      final l0 = _light(_painter(tester).hairColor);

      final ring = _key('hue-ring');
      final c = tester.getCenter(ring);
      final r = tester.getSize(ring).width / 2 - 18;
      double hue() => hslOfArgb(_painter(tester).hairColor.toARGB32()).h;

      await tester.tapAt(c + Offset(0, r)); // 아래쪽 = 90도 (시계 방향으로 3시에서 90도)
      await tester.pump();
      expect(hue(), closeTo(90, 3));
      await tester.tapAt(c + Offset(-r, 0)); // 왼쪽 = 180도
      await tester.pump();
      expect(hue(), closeTo(180, 3));
      await tester.tapAt(c + Offset(0, -r)); // 위쪽 = 270도
      await tester.pump();
      expect(hue(), closeTo(270, 3));
      expect(_light(_painter(tester).hairColor), closeTo(l0, 0.01));

      // 가운데 원 안은 눌러도 안 바뀐다
      final before = _painter(tester).hairColor;
      await tester.tapAt(c);
      await tester.pump();
      expect(_painter(tester).hairColor, before);
      await end(tester, e);
    });

    testWidgets('직접 고른 색은 저장하면 custom hex로 남는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('hair-custom'));
      final ring = _key('hue-ring');
      await tester.tapAt(tester.getCenter(ring) + Offset(tester.getSize(ring).width / 2 - 18, 0));
      await tester.pump();
      final color = _painter(tester).hairColor;
      await _save(tester);

      final look = await _stored(tester, e);
      expect(look.hairColor, CustomHairColor(hexFromArgb(color.toARGB32())));
      await end(tester, e);
    });

    testWidgets('그라데이션: 뿌리색·끝색 두 칸을 견본으로 골라 미리보기에 이어서 보인다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-gradient'));
      expect(_key('grad-root'), findsOneWidget);
      expect(_key('grad-tip'), findsOneWidget);
      expect(find.text('뿌리색'), findsOneWidget);
      expect(find.text('끝색'), findsOneWidget);
      // 처음에는 두 칸 모두 지금 색
      expect(_painter(tester).hairGradient!.tip, Color(hairSwatches.first.color));

      await _tap(tester, _key('grad-tip'));
      await _tap(tester, _key('grad-swatch-10'));
      var p = _painter(tester);
      expect(p.hairColor, Color(hairSwatches.first.color));
      expect(p.hairGradient!.tip, Color(hairSwatches.last.color));
      // 구간은 palette.json (30%·85%)
      expect(p.hairGradient!.rootUntil, 0.3);
      expect(p.hairGradient!.tipFrom, 0.85);

      await _tap(tester, _key('grad-root'));
      await _tap(tester, _key('grad-swatch-6'));
      p = _painter(tester);
      expect(p.hairColor, Color(hairSwatches[5].color));
      expect(p.hairGradient!.tip, Color(hairSwatches.last.color));
      expect(_enabled(tester, '저장'), isTrue);

      await _save(tester);
      expect((await _stored(tester, e)).hairColor, const GradientHairColor('#D6B26E', '#E39AB0'));
      await end(tester, e);
    });

    testWidgets('그라데이션 칸도 직접 고르기: 밝기 제한을 받는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
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
      var p = _painter(tester);
      expect(_light(p.hairGradient!.tip), closeTo(0.90, 0.01));
      // 뿌리색은 그대로
      expect(p.hairColor, Color(hairSwatches.first.color));

      await tester.dragFrom(mid, const Offset(-2000, 0));
      await tester.pump();
      p = _painter(tester);
      expect(_light(p.hairGradient!.tip), closeTo(0.15, 0.01));

      // 견본을 고르면 직접 고르기는 닫히고, 뿌리색 칸으로 가면 견본(체크)이 보인다
      await _tap(tester, _key('grad-swatch-7'));
      expect(_key('picker'), findsNothing);
      expect(_painter(tester).hairGradient!.tip, Color(hairSwatches[6].color));
      await end(tester, e);
    });

    testWidgets('견본·직접 고르기·그라데이션을 오가면 마지막 것이 머리색', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-gradient'));
      expect(_painter(tester).hairGradient, isNotNull);
      await _tap(tester, _key('hair-custom'));
      expect(_painter(tester).hairGradient, isNull);
      expect(_key('picker'), findsOneWidget);
      expect(_key('grad-root'), findsNothing);
      await _tap(tester, _key('hair-swatch-2'));
      expect(_painter(tester).hairColor, Color(hairSwatches[1].color));
      expect(_key('picker'), findsNothing);
      await end(tester, e);
    });

    testWidgets('저장된 그라데이션·직접 고른 색은 열 때 해당 칸이 열려 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        final look = const Look(
          hair: 2,
          hairColor: GradientHairColor('#2B2522', '#102030'),
        );
        await e.db.into(e.db.profile).insertOnConflictUpdate(
            ProfileCompanion(id: const Value(1), look: Value(jsonEncode(look.toJson()))));
      });
      await _open(tester, e);

      expect(_painter(tester).hairGradient!.tip, const Color(0xFF102030));
      expect(_key('grad-root'), findsOneWidget);
      // 끝색 칸은 견본이 아닌 색이라 직접 고르기가 열려 있다
      await _tap(tester, _key('grad-tip'));
      expect(_key('picker'), findsOneWidget);
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });
  });

  group('얼굴 탭', () {
    testWidgets('눈 3 · 코 3 · 눈썹 3 · 귀 2를 줄별로 고른다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'face');

      for (final t in ['눈', '코', '눈썹', '귀']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (var i = 1; i <= 3; i++) {
        for (final k in ['eyes', 'nose', 'brows']) {
          expect(_key('$k-$i'), findsOneWidget, reason: '$k-$i');
        }
      }
      expect(_key('ears-1'), findsOneWidget);
      expect(_key('ears-2'), findsOneWidget);
      for (final k in ['eyes-4', 'nose-4', 'brows-4', 'ears-3']) {
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
      await _tap(tester, _key('ears-2'));
      expect(_enabled(tester, '저장'), isTrue);
      await _save(tester);

      final look = await _stored(tester, e);
      expect((look.eyes, look.nose, look.brows, look.ears), (3, 2, 3, 2));
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });
  });

  group('피부 탭', () {
    testWidgets('견본 7개를 고르면 미리보기 얼굴색이 바뀐다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'skin');

      for (final s in lookPalette.skin.swatches) {
        expect(_key('skin-swatch-${s.id}'), findsOneWidget, reason: s.name);
      }
      expect(_key('skin-swatch-8'), findsNothing);
      await _tap(tester, _key('skin-swatch-7'));
      expect(_painter(tester).skin, const Color(0xFF966242));
      expect(_enabled(tester, '저장'), isTrue);
      await end(tester, e);
    });

    testWidgets('직접 고르기 밝기 제한: 35~95%', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'skin');
      await _tap(tester, _key('skin-custom'));
      expect(_key('picker'), findsOneWidget);

      final mid = tester.getCenter(_key('light-bar'));
      await tester.dragFrom(mid, const Offset(-2000, 0));
      await tester.pump();
      expect(_light(_painter(tester).skin), closeTo(0.35, 0.01));
      expect(_light(_painter(tester).skin), greaterThan(0.34));
      expect(find.text('밝기 35%'), findsOneWidget);

      await tester.dragFrom(mid, const Offset(2000, 0));
      await tester.pump();
      expect(_light(_painter(tester).skin), closeTo(0.95, 0.01));
      expect(_light(_painter(tester).skin), lessThan(0.96));
      expect(find.text('밝기 95%'), findsOneWidget);

      await _save(tester);
      final stored = (await _stored(tester, e)).skin;
      expect(stored, isA<CustomSkinColor>());
      await end(tester, e);
    });

    testWidgets('직접 고르기는 머리와 달리 피부 견본으로 돌아가면 닫힌다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'skin');
      await _tap(tester, _key('skin-custom'));
      await _tap(tester, _key('skin-swatch-2'));
      expect(_key('picker'), findsNothing);
      expect(_painter(tester).skin, Color(lookPalette.skin.swatches[1].color));
      await end(tester, e);
    });
  });

  group('소품 탭', () {
    testWidgets('그 칸의 MVP 소품을 4열 격자로, 옷이 아니면 맨 앞에 없음 칸', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
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

    testWidgets('가진 것은 고를 수 있고 잠긴 것은 흐리게 보인다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02']));
      await _open(tester, e);
      await _goTab(tester, 'hat');

      double opacityOf(String id) => tester
          .widget<Opacity>(find
              .descendant(of: _key('prop-$id'), matching: find.byType(Opacity))
              .first)
          .opacity;
      // 가진 것(기본 hat_01, 얻은 hat_02)은 또렷하고 잠긴 것은 흐리다 (자물쇠)
      for (final id in ['hat_01', 'hat_02']) {
        expect(_lock(id), findsNothing);
      }
      for (final id in ['hat_03', 'hat_04', 'hat_05', 'hat_10', 'hat_11']) {
        expect(opacityOf(id), lessThan(1), reason: id);
        expect(_lock(id), findsOneWidget, reason: id);
      }
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
      await end(tester, e);
    });

    testWidgets('잠긴 칸을 누르면 얻는 방법이 나오고 모습은 안 바뀐다 (거리)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _walked(e.db, 87));
      await _open(tester, e);
      await _goTab(tester, 'hand');

      await tester.tap(_key('prop-hand_03'));
      await tester.pump();
      expect(find.text('누적 150km · 지금 87km'), findsOneWidget);
      expect(_worn(tester, 'hand'), '붓');
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('잠긴 칸 얻는 방법: 권역·걸음·동행 소품은 화집과 같은 문구', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      // 토스트는 앞 것이 사라진 뒤에 새 것이 뜬다
      Future<void> showHowTo(String id) async {
        await tester.tap(_key('prop-$id'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      await _goTab(tester, 'pet');
      await showHowTo('pet_02');
      expect(find.text('수도권 0/12'), findsOneWidget);

      await _goTab(tester, 'hat');
      await showHowTo('hat_10');
      expect(find.text('동행 이야기 완결'), findsOneWidget);
      expect(find.text('수도권 0/12'), findsNothing);

      await _goTab(tester, 'cloth');
      await showHowTo('cloth_04');
      expect(find.text('누적 1,000,000보 · 지금 0보'), findsOneWidget);
      expect(find.text('동행 이야기 완결'), findsNothing);
      expect(_enabled(tester, '저장'), isFalse);
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

    testWidgets('이름과 잠김은 접근성 label로도 읽힌다', (tester) async {
      final handle = tester.ensureSemantics();
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'hand');

      expect(find.bySemanticsLabel('붓'), findsOneWidget);
      expect(find.bySemanticsLabel('나침반, 잠김'), findsOneWidget);
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

      await _tap(tester, _key('hair-5'));
      await _tap(tester, _key('hair-swatch-4'));
      await _goTab(tester, 'skin');
      await _tap(tester, _key('skin-swatch-3'));
      await _goTab(tester, 'hand');
      await _tap(tester, _key('prop-hand_02'));
      await _save(tester);

      final look = await _stored(tester, e);
      expect(look.hair, 5);
      expect(look.hairColor, const SwatchHairColor(4));
      expect(look.skin, const SwatchSkinColor(3));
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

      await _tap(tester, _key('hair-swatch-6'));
      await _save(tester);
      await _tap(tester, _key('hair-swatch-2'));
      expect(_enabled(tester, '저장'), isTrue);
      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      expect(_painter(tester).hairColor, Color(hairSwatches[5].color));
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('저장하면 "저장했어요" 토스트가 뜬다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _tap(tester, _key('hair-swatch-6'));
      await tester.tap(find.widgetWithText(GameButton, '저장'));
      await settle(tester, () => find.text('저장했어요').evaluate().isNotEmpty);
      expect(find.text('저장했어요'), findsOneWidget);
      await tester.pump(toastDuration + const Duration(seconds: 1));
      await end(tester, e);
    });

    testWidgets('되돌리기: 머리·피부·소품 모두 저장된 모습으로, 직접 고르기도 닫힌다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _tap(tester, _key('hair-3'));
      await _tap(tester, _key('hair-custom'));
      await _goTab(tester, 'skin');
      await _tap(tester, _key('skin-swatch-6'));
      await _goTab(tester, 'shoe');
      await _tap(tester, _key('prop-none'));
      expect(_enabled(tester, '되돌리기'), isTrue);

      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      final p = _painter(tester);
      expect(p.hair, 1);
      expect(p.hairColor, Color(hairSwatches.first.color));
      expect(p.skin, Color(lookPalette.skin.swatches.first.color));
      expect(_worn(tester, 'shoe'), '갈색 신발');
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);
      await _goTab(tester, 'hair');
      expect(_key('picker'), findsNothing);
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
      await _tap(tester, _key('hair-swatch-8'));

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
      expect(_painter(tester).hairColor, Color(hairSwatches[7].color));
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
      await _tap(tester, _key('hair-2'));

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
      await _tap(tester, _key('hair-2'));
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
      await _tap(tester, _key('hair-2'));
      await _save(tester);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsNothing);
      await end(tester, e);

      final e2 = UiEnv();
      await e2.seed(tester);
      await _open(tester, e2);
      await _tap(tester, _key('hair-3'));
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
      // 직접 고르기(색상환 + 밝기 막대)와 그라데이션이 열려도
      await _goTab(tester, 'hair');
      await _tap(tester, _key('hair-custom'));
      expect(tester.takeException(), isNull);
      await _tap(tester, _key('hair-gradient'));
      await _tap(tester, _key('grad-custom'));
      expect(tester.takeException(), isNull);
      await _goTab(tester, 'skin');
      await _tap(tester, _key('skin-custom'));
      expect(tester.takeException(), isNull);
      // 소품 이름이 길어도 (모자 8칸)
      await _goTab(tester, 'hat');
      await _tap(tester, _key('prop-hat_02'));
      expect(tester.takeException(), isNull);
      await end(tester, e);
    });

    testWidgets('색상환·밝기 막대를 끌어도 안쪽 스크롤은 움직이지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, height: 700);
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
      await end(tester, e);
    });
  });
}
