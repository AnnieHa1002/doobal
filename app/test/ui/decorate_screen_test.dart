import 'dart:convert';

import 'package:doobal/app/profile_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/color.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/item_cell.dart';
import 'package:doobal/ui/common/toast.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 탭 내용이 스크롤 없이 다 보이도록 길게 잡은 높이
const _tall = 1400.0;

/// 탭 줄 순서 (내 모습, 그 뒤로 소품 9칸)
const _tabs = ['me', 'hat', 'face', 'cloth', 'shoe', 'hand', 'bag', 'pet', 'float', 'effect'];
const _tabLabels = [
  '내 모습',
  '모자',
  '얼굴 소품',
  '옷',
  '신발',
  '손',
  '가방',
  '미니 친구',
  '둥실',
  '효과',
];

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _open(WidgetTester tester, UiEnv e, {double height = _tall}) =>
    openOnTop(tester, e, const DecorateScreen(),
        height: height, ready: () => _key('tab-me').evaluate().isNotEmpty);

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

/// 얼굴 파츠 칸이 골라져 있는지
bool _chosen(WidgetTester tester, String key) => tester
    .widget<Semantics>(find.descendant(of: _key(key), matching: find.byType(Semantics)).first)
    .properties
    .selected!;

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<GameButton>(find.widgetWithText(GameButton, label)).onPressed != null;

/// 미리보기 정령이 입은 값
SpiritLook _worn(WidgetTester tester) =>
    tester.widget<SpiritCharacter>(find.byType(SpiritCharacter)).look;

/// 미리보기 아래 요약 줄
String _summary(WidgetTester tester) => tester.widget<Text>(find.descendant(
      of: _key('summary'),
      matching: find.byType(Text),
    )).data!;

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

/// 색마다 따로 된 상점 소품 (id `<기본>_c<n>`). 칸 배치를 보는 시험은 기본 소품만 쓴다
bool _isColorVariant(Prop p) => RegExp(r'_c\d+$').hasMatch(p.id);

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

/// 소품 칸 안의 상태 글자 (입는 중 / 가짐)
Finder _state(String id, String text) =>
    find.descendant(of: _key('prop-$id'), matching: find.text(text));

/// 견본 칸의 체크
Finder _swatchCheck(String key) =>
    find.descendant(of: _key(key), matching: find.byIcon(Icons.check));

/// 색(불투명 ARGB)의 HSL 밝기
double _light(int argb) => hslOfArgb(argb).l;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('틀', () {
    testWidgets('머리줄(제목·가진 소품 수), 탭 줄(내 모습 | 소품 + 9탭)이 순서대로 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(find.text('꾸미기'), findsOneWidget);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      // 처음부터 가진 소품 6개 (베레모·여행복·갈색 신발·큰 붓·화구 가방·종이새)
      expect(find.text('가진 소품 6개'), findsOneWidget);
      expect(find.text('내 모습'), findsOneWidget);
      expect(find.text('소품'), findsOneWidget);
      for (final (i, label) in _tabLabels.indexed) {
        expect(find.descendant(of: _key('tab-${_tabs[i]}'), matching: find.text(label)),
            findsOneWidget,
            reason: label);
      }
      // 사람형 탭(얼굴·머리·피부)은 없다
      for (final old in ['face-old', 'hair', 'skin']) {
        expect(_key('tab-$old'), findsNothing);
      }
      // 왼쪽부터 순서대로 (옆으로 밀어야 보이는 탭도 자리는 순서대로다)
      final xs = [for (final t in _tabs) tester.getTopLeft(_key('tab-$t')).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      // '소품' 글자는 내 모습과 모자 탭 사이에 있다
      final label = tester.getTopLeft(find.text('소품')).dx;
      expect(label, greaterThan(tester.getTopLeft(_key('tab-me')).dx));
      expect(label, lessThan(tester.getTopLeft(_key('tab-hat')).dx));
      await end(tester, e);
    });

    testWidgets('가진 소품이 늘면 알약의 수도 는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02', 'cloth_01']));
      await _open(tester, e);
      expect(find.text('가진 소품 8개'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('미리보기는 쉼터와 같은 정령이고, 몸 색(크림)을 입으며 사람 그림은 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(find.descendant(of: _key('preview'), matching: find.byType(SpiritCharacter)),
          findsOneWidget);
      // 기본 옷 여행복은 Rive 옷 1 (16장 11/8)
      expect(_worn(tester).bodyArgb,0xFFF3E4C4);
      expect(_worn(tester).choices['bag'],1);
      expect(_worn(tester).choices['cloth'],4);
      // 정령은 미리보기 칸 가운데에 선다
      final box = tester.getRect(_key('preview'));
      final spirit = tester.getRect(find.byType(SpiritCharacter));
      expect(spirit.center.dx, closeTo(box.center.dx, 1));
      // 연타 화남 규칙을 준다 (쉼터와 같다)
      expect(tester.widget<SpiritCharacter>(find.byType(SpiritCharacter)).tapRules, isNotNull);
      // 눌러도 저장할 것이 생기지 않는다
      await tester.tap(_key('preview'));
      await tester.pump();
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('미리보기 아래 요약 줄: 입고 있는 소품 이름을 칸 순서로, 바꾸면 따라 바뀐다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02']));
      await _open(tester, e);

      expect(_summary(tester), '베레모 · 여행복 · 갈색 신발 · 큰 붓 · 종이새');
      await _tap(tester, _key('prop-hat_02'));
      expect(_summary(tester), startsWith('여행 모자 · 여행복'));
      await _tap(tester, _key('prop-none'));
      expect(_summary(tester), startsWith('여행복 · 갈색 신발'));
      // 다 비울 수는 없지만(옷) 나머지를 비우면 옷만 남는다
      for (final slot in ['shoe', 'bag', 'pet']) {
        await _goTab(tester, slot);
        await _tap(tester, _key('prop-none'));
      }
      expect(_summary(tester), '여행복');
      await end(tester, e);
    });

    testWidgets('동작 미리보기 단추 6개: 눌러도 저장할 것은 생기지 않고, 요약 줄에 동작 미리보기가 붙는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      const names = ['기본', '기쁨', '인사', '배 눌림', '잠들기', '화남','머리 눌림'];
      for (final (i, n) in names.indexed) {
        expect(find.descendant(of: _key('expr-$i'), matching: find.text(n)), findsOneWidget);
      }
      // 위에서 아래로
      final ys = [for (var i = 0; i < 6; i++) tester.getTopLeft(_key('expr-$i')).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      Finder spirit() => find.byType(SpiritCharacter);
      expect(tester.widget<SpiritCharacter>(spirit()).expression, 0);
      expect(_summary(tester), isNot(contains('동작 미리보기')));

      await tester.tap(_key('expr-5'));
      await tester.pump();
      expect(tester.widget<SpiritCharacter>(spirit()).expression, 5);
      expect(_summary(tester), endsWith('동작 미리보기'));
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);

      await tester.tap(_key('expr-0'));
      await tester.pump();
      expect(tester.widget<SpiritCharacter>(spirit()).expression, 0);
      expect(_summary(tester), isNot(contains('동작 미리보기')));
      await end(tester, e);
    });

    testWidgets('고른 얼굴·몸 색과 Rive에 붙은 소품이 저장 전에도 미리보기 정령에 입혀진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['cloth_01', 'pet_05', 'hat_02']));
      await _open(tester, e);

      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e3'));
      expect(_worn(tester).eye, 2);
      await _tap(tester, _key('nose-none'));
      expect(_worn(tester).nose, 7, reason: '코 없음은 Rive 값 3');
      await _tap(tester, _key('nose-n2'));
      expect(_worn(tester).nose, 1, reason: '고리는 Rive 값 0');
      await _tap(tester, _key('body-swatch-9'));
      expect(_worn(tester).bodyArgb, 0xFFC9775A);
      await _goTab(tester, 'cloth');
      // 앞치마(300km 보상)는 T5 전까지 Rive 옷 그림이 없다
      await _tap(tester, _key('prop-cloth_01'));
      expect(_worn(tester).outfit, 0);
      await _tap(tester, _key('prop-cloth_02'));
      expect(_worn(tester).outfit, 1);
      await _goTab(tester, 'pet');
      await _tap(tester, _key('prop-pet_05'));
      expect(_worn(tester).companion, 1);
      // 리깅 전 소품은 골라도 정령 값이 바뀌지 않는다
      final before = _worn(tester).choices['hat'];
      await _goTab(tester, 'hat');
      await _tap(tester, _key('prop-hat_02'));
      expect(_worn(tester).choices['hat'],2);
      expect(_worn(tester).choices['hat'],isNot(before));
      await end(tester, e);
    });

    testWidgets('소품 칸: 그림이 있는 소품은 그림을, 없는 소품과 없음 칸은 그림 없이 놓는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02']));
      await _open(tester, e);

      Finder art(String id) =>
          find.descendant(of: _key('prop-$id'), matching: find.byType(Image));
      expect(art('hat_01'), findsOneWidget);
      expect(art('hat_02'), findsNothing);
      expect(art('none'), findsNothing);
      await end(tester, e);
    });

    testWidgets('요약 줄은 미리보기 폭을 다 쓰고, 표정 단추·정령 발과 겹치지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e, height: 800);

      final preview = tester.getRect(_key('preview'));
      final summary = tester.getRect(_key('summary'));
      expect(summary.right, preview.right - 12);
      expect(tester.getRect(_key('expr-5')).bottom, lessThanOrEqualTo(summary.top));
      // 정령 캔버스 600 안에서 발바닥은 y440이다
      final spirit = tester.getRect(find.byType(SpiritCharacter));
      expect(spirit.top + spirit.height * 440 / 600, lessThanOrEqualTo(summary.top));
      await end(tester, e);
    });

    testWidgets('처음에는 모자 탭이 열려 있고 저장·되돌리기는 눌리지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      expect(_key('prop-hat_01'), findsOneWidget);
      expect(_key('eyes-e1'), findsNothing);
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);
      expect(find.text('저장'), findsOneWidget);
      expect(find.text('되돌리기'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('옛 사람형 모습({hair, ...})도 기본 정령으로 열리고 소품 칸은 살아 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _ownProps(e.db, ['hat_02']);
        await e.db.into(e.db.profile).insertOnConflictUpdate(ProfileCompanion(
              id: const Value(1),
              look: const Value('{"hair":4,"hairColor":{"kind":"swatch","i":3},"eyes":3,'
                  '"slots":{"hat":"hat_02"}}'),
            ));
      });
      await _open(tester, e);

      expect(_summary(tester), startsWith('여행 모자 · 여행복'));
      await _goTab(tester, 'me');
      expect(_chosen(tester, 'eyes-e1'), isTrue);
      expect(_swatchCheck('body-swatch-1'), findsOneWidget);
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('탭 10개를 눌러 바꾸면 그 탭의 내용이 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      const marker = {
        'me': 'eyes-e1',
        'hat': 'prop-hat_01',
        'face': 'empty-slot',
        'cloth': 'prop-cloth_02',
        'shoe': 'prop-shoe_01',
        'hand': 'hand-none',
        'bag': 'prop-bag_01',
        'pet': 'prop-pet_01',
        'float': 'empty-slot',
        'effect': 'empty-slot',
      };
      // 손 탭은 가진 소품이 없어 맨손 칸 하나뿐이다
      Finder at(String m) => m == 'hand-none' ? find.text('맨손') : _key(m);
      for (final t in _tabs) {
        await _goTab(tester, t);
        for (final m in marker.entries) {
          // 같은 표시가 여러 탭에 있으면(안내 글) 그 탭들에서만 있다
          final shared = marker.entries.where((x) => x.value == m.value).map((x) => x.key);
          expect(at(m.value), shared.contains(t) ? findsOneWidget : findsNothing,
              reason: '$t / ${m.key}');
        }
      }
      // 되돌아와도 된다
      await _goTab(tester, 'me');
      expect(_key('eyes-e1'), findsOneWidget);
      expect(_key('prop-pet_01'), findsNothing);
      await end(tester, e);
    });

    testWidgets('탭을 오가도 고른 것은 남고 저장 단추는 계속 켜져 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e4'));
      await _goTab(tester, 'hat');
      await _goTab(tester, 'me');
      expect(_chosen(tester, 'eyes-e4'), isTrue);
      expect(_enabled(tester, '저장'), isTrue);
      await end(tester, e);
    });
  });

  group('내 모습 탭', () {
    testWidgets('눈 5 · 눈썹 5 · 코 7 · 입 6칸과 줄 이름, 파츠는 palette.json 순서', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');

      for (final (title, key) in [('눈', 'eyes'), ('눈썹', 'brows'), ('코', 'nose'), ('입', 'mouth')]) {
        final parts = spiritPalette.faces[key]!;
        expect(find.text(title), findsOneWidget, reason: title);
        for (final p in parts) {
          expect(_key('$key-${p.id}'), findsOneWidget, reason: '$key-${p.id}');
        }
        // 왼쪽에서 오른쪽으로
        final positions=[for(final p in parts)tester.getTopLeft(_key('$key-${p.id}'))];
        final sorted=[...positions]..sort((a,b)=>a.dy==b.dy?a.dx.compareTo(b.dx):a.dy.compareTo(b.dy));
        expect(positions,orderedEquals(sorted),reason:key);
      }
      expect([for (final k in ['eyes', 'brows', 'nose', 'mouth']) spiritPalette.faces[k]!.length],
          [6, 7, 8, 8]);
      // 줄은 위에서 아래로 눈 → 눈썹 → 코 → 입
      final ys = [for (final k in ['eyes-e1', 'brows-none', 'nose-none', 'mouth-m1']) tester.getTopLeft(_key(k)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      // 짧은 이름 (캔버스): '콩 눈' → '콩', 쑥스러움 → '///'
      expect(find.descendant(of: _key('eyes-e2'), matching: find.text('순한')), findsOneWidget);
      expect(find.descendant(of: _key('nose-n1'), matching: find.text('///')), findsOneWidget);
      expect(find.descendant(of: _key('mouth-m6'), matching: find.text('긴웃음')), findsOneWidget);
      // 기본 얼굴이 골라져 있다
      for (final k in ['eyes-e1', 'brows-b1', 'nose-n7', 'mouth-m7']) {
        expect(_chosen(tester, k), isTrue, reason: k);
      }
      expect(_chosen(tester, 'eyes-e2'), isFalse);
      await end(tester, e);
    });

    testWidgets('파츠 이름이 접근성 label이다 (줄 이름 + palette 이름)', (tester) async {
      final handle = tester.ensureSemantics();
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');

      expect(find.bySemanticsLabel('눈 부드러운 눈'), findsOneWidget);
      expect(find.bySemanticsLabel('코 빗금'), findsOneWidget);
      expect(find.bySemanticsLabel('입 긴 미소'), findsOneWidget);
      expect(find.bySemanticsLabel('몸 색 팔레트'), findsNothing);
      handle.dispose();
      await end(tester, e);
    });

    testWidgets('고르면 저장할 것이 생기고, 저장하면 id로 남는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');

      await _tap(tester, _key('eyes-e3'));
      await _tap(tester, _key('brows-b6'));
      await _tap(tester, _key('nose-n4'));
      await _tap(tester, _key('mouth-m5'));
      expect(_chosen(tester, 'eyes-e3'), isTrue);
      expect(_chosen(tester, 'eyes-e1'), isFalse);
      expect(_enabled(tester, '저장'), isTrue);
      await _save(tester);

      final look = await _stored(tester, e);
      expect((look.eyes, look.brows, look.nose, look.mouth), ('e3', 'b6', 'n4', 'm5'));
      expect(look.body, const SwatchBodyColor(1));
      expect(look.slots, defaultSlots);
      expect(_enabled(tester, '저장'), isFalse);
      // 닉네임 같은 다른 열은 그대로
      final row = await tester.runAsync(() => ProfileService(e.db).row());
      expect(row!.nickname, '화가');
      await end(tester, e);
    });

    testWidgets('몸 색: 견본 10개 + 직접 고르기, 이름 글자와 체크가 따라간다', (tester) async {
      final handle = tester.ensureSemantics();
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');

      for (final s in spiritPalette.body.swatches) {
        expect(_key('body-swatch-${s.id}'), findsOneWidget, reason: s.name);
        expect(find.bySemanticsLabel(s.name), findsOneWidget, reason: s.name);
      }
      expect(find.bySemanticsLabel('직접 고르기'), findsOneWidget);
      expect(find.text('색 견본 · 몸 색 크림'), findsOneWidget);
      expect(_swatchCheck('body-swatch-1'), findsOneWidget);

      await _tap(tester, _key('body-swatch-6'));
      expect(find.text('색 견본 · 몸 색 연두'), findsOneWidget);
      expect(_swatchCheck('body-swatch-6'), findsOneWidget);
      expect(_swatchCheck('body-swatch-1'), findsNothing);
      expect(_worn(tester).bodyArgb, 0xFFCDE0AC);
      expect(_enabled(tester, '저장'), isTrue);

      // 같은 견본으로 돌아오면 바뀐 게 없다
      await _tap(tester, _key('body-swatch-1'));
      expect(_enabled(tester, '저장'), isFalse);
      handle.dispose();
      await end(tester, e);
    });

    testWidgets('몸 색을 저장하면 견본 번호로 남는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');
      await _tap(tester, _key('body-swatch-10'));
      await _save(tester);
      expect((await _stored(tester, e)).body, const SwatchBodyColor(10));
      await end(tester, e);
    });

    testWidgets('+ 직접 고르기: 지금 색에서 시작하는 색상환과 밝기 막대(채도 막대 없음)가 열린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');

      expect(_key('picker'), findsNothing);
      await _tap(tester, _key('body-custom'));
      expect(_key('picker'), findsOneWidget);
      expect(_key('hue-ring'), findsOneWidget);
      expect(_key('light-bar'), findsOneWidget);
      expect(find.textContaining('밝기'), findsOneWidget);
      expect(find.textContaining('채도'), findsNothing);
      expect(find.text('색 견본 · 몸 색 직접 고르기'), findsOneWidget);
      // 크림에서 이어서 시작한다
      expect(_worn(tester).bodyArgb, 0xFFF3E4C4);
      expect(_enabled(tester, '저장'), isTrue);

      // 견본을 누르면 닫힌다
      await _tap(tester, _key('body-swatch-3'));
      expect(_key('picker'), findsNothing);
      await end(tester, e);
    });

    testWidgets('직접 고르기 밝기에는 제한이 없다: 막대 끝까지 끌면 0%와 100%', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');
      await _tap(tester, _key('body-custom'));

      final bar = _key('light-bar');
      final left = tester.getTopLeft(bar);
      final size = tester.getSize(bar);
      final mid = Offset(left.dx + size.width / 2, left.dy + size.height / 2);

      await tester.tapAt(mid);
      await tester.pump();
      expect(_light(_worn(tester).bodyArgb!), closeTo(0.5, 0.01));

      await tester.dragFrom(mid, const Offset(-2000, 0));
      await tester.pump();
      expect(_light(_worn(tester).bodyArgb!), lessThan(0.01));
      expect(find.text('밝기 0%'), findsOneWidget);

      await tester.dragFrom(mid, const Offset(2000, 0));
      await tester.pump();
      expect(_light(_worn(tester).bodyArgb!), greaterThan(0.99));
      expect(find.text('밝기 100%'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('색상환을 누르면 그 방향의 색조가 되고, 직접 고른 색은 custom hex로 저장된다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');
      await _tap(tester, _key('body-custom'));

      final ring = _key('hue-ring');
      final c = tester.getCenter(ring);
      final r = tester.getSize(ring).width / 2 - 18;
      await tester.tapAt(c + Offset(0, r)); // 아래쪽 = 90도
      await tester.pump();
      expect(hslOfArgb(_worn(tester).bodyArgb!).h, closeTo(90, 3));
      await tester.tapAt(c + Offset(-r, 0)); // 왼쪽 = 180도
      await tester.pump();
      final argb = _worn(tester).bodyArgb!;
      expect(hslOfArgb(argb).h, closeTo(180, 3));

      await _save(tester);
      expect((await _stored(tester, e)).body, CustomBodyColor(hexFromArgb(argb)));
      // 저장 뒤에 다시 열어도 직접 고른 색이 이어진다
      expect(_key('picker'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('저장해 둔 직접 고른 색으로 열면 색상환이 열려 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.db.into(e.db.profile).insertOnConflictUpdate(ProfileCompanion(
              id: const Value(1),
              look: Value(jsonEncode(
                  Look.initial.copyWith(body: const CustomBodyColor('#336699')).toJson())),
            ));
      });
      await _open(tester, e);
      await _goTab(tester, 'me');

      expect(_key('picker'), findsOneWidget);
      expect(_worn(tester).bodyArgb, 0xFF336699);
      expect(find.text('색 견본 · 몸 색 직접 고르기'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('소품 탭 (선반)', () {
    testWidgets('그 칸의 가진 소품을 선반 3열로, 옷이 아니면 맨 앞에 없음 칸', (tester) async {
      final e = UiEnv();
      // 모두 가진 상태에서 격자를 본다
      await e.seed(
          tester,
          () => _ownProps(e.db, [
                for (final p in props)
                  if (p.kind != PropUnlockKind.initial && !_isColorVariant(p)) p.id,
              ]));
      await _open(tester, e);

      // 모자: 없음 + MVP 모자 4개 = 5칸 (3열 두 줄)
      await _goTab(tester, 'hat');
      final hats = [for (final p in props) if (p.slot == 'hat' && !_isColorVariant(p)) p.id];
      expect(hats, hasLength(4));
      expect(find.byType(ItemCell), findsNWidgets(5));
      expect(_key('prop-none'), findsOneWidget);
      final pos = [for (final id in ['none', ...hats]) tester.getTopLeft(_key('prop-$id'))];
      expect(pos.take(3).map((p) => p.dy).toSet(), hasLength(1));
      expect(pos.skip(3).map((p) => p.dy).toSet(), hasLength(1));
      expect(pos[3].dy, greaterThan(pos[0].dy));
      // 왼쪽에서 오른쪽으로 세 칸, 다음 줄은 같은 세로줄에서 다시 시작
      final xs = [for (final p in pos.take(3)) p.dx];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(xs.toSet(), hasLength(3));
      expect([for (var i = 0; i < 2; i++) pos[3 + i].dx], [for (var i = 0; i < 2; i++) pos[i].dx]);

      // 옷: 없음 칸이 없다 (5개)
      await _goTab(tester, 'cloth');
      expect(find.byType(ItemCell), findsNWidgets(5));
      expect(_key('prop-none'), findsNothing);

      // 칸마다 MVP 소품 수 (+ 없음)
      for (final (slot, count) in [('hand', 5), ('bag', 5), ('shoe', 5), ('pet', 5), ('face', 3), ('float', 5), ('effect', 5)]) {
        await _goTab(tester, slot);
        expect(find.byType(ItemCell), findsNWidgets(count + 1), reason: slot);
        expect(props.where((p) => p.slot == slot && !_isColorVariant(p)), hasLength(count));
      }
      await end(tester, e);
    });

    testWidgets('공용 칸: 파일이 있는 소품은 64×64 그림, 없는 소품은 점선 + 이름, 없음 칸은 빈 점선', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02']));
      await _open(tester, e);
      await _goTab(tester, 'hat');

      Finder inCell(String id, Finder f) => find.descendant(of: _key('prop-$id'), matching: f);
      expect(tester.getSize(inCell('hat_01', find.byType(ItemArt))), const Size(64, 64));
      final image = tester.widget<Image>(inCell('hat_01', find.byType(Image))).image as ResizeImage;
      expect(image.width, 192);
      expect(inCell('hat_01', find.byType(ItemPlaceholder)), findsNothing);

      final name = props.firstWhere((p) => p.id == 'hat_02').name;
      expect(inCell('hat_02', find.byType(Image)), findsNothing);
      expect(
        find.descendant(of: inCell('hat_02', find.byType(ItemPlaceholder)), matching: find.text(name)),
        findsOneWidget,
      );

      expect(inCell('none', find.byType(Image)), findsNothing);
      expect(
        find.descendant(of: inCell('none', find.byType(ItemPlaceholder)), matching: find.byType(Text)),
        findsNothing,
      );
      await end(tester, e);
    });

    testWidgets('이름표: 이름과 입는 중 / 가짐, 없음 칸은 이름만 (손은 맨손)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02', 'hand_02']));
      await _open(tester, e);
      await _goTab(tester, 'hat');

      expect(find.descendant(of: _key('prop-hat_01'), matching: find.text('베레모')), findsOneWidget);
      expect(_state('hat_01', '입는 중'), findsOneWidget);
      expect(_state('hat_02', '가짐'), findsOneWidget);
      expect(_state('hat_02', '입는 중'), findsNothing);
      expect(find.descendant(of: _key('prop-none'), matching: find.text('없음')), findsOneWidget);
      expect(find.descendant(of: _key('prop-none'), matching: find.text('입는 중')), findsNothing);
      expect(find.descendant(of: _key('prop-none'), matching: find.text('가짐')), findsNothing);

      await _tap(tester, _key('prop-hat_02'));
      expect(_state('hat_02', '입는 중'), findsOneWidget);
      expect(_state('hat_01', '가짐'), findsOneWidget);
      await _tap(tester, _key('prop-none'));
      expect(_state('hat_01', '가짐'), findsOneWidget);
      expect(_state('hat_02', '가짐'), findsOneWidget);

      // 손: 없음 칸 이름은 맨손
      await _goTab(tester, 'hand');
      expect(find.descendant(of: _key('prop-none'), matching: find.text('맨손')), findsOneWidget);
      expect(find.text('없음'), findsNothing);
      await end(tester, e);
    });

    testWidgets('가진 소품만 칸이 되고 잠긴 소품은 보이지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02']));
      await _open(tester, e);
      await _goTab(tester, 'hat');

      // 없음 + 기본 hat_01 + 얻은 hat_02
      expect(find.byType(ItemCell), findsNWidgets(3));
      for (final id in ['hat_04', 'hat_05', 'hat_10', 'hat_11']) {
        expect(_key('prop-$id'), findsNothing, reason: id);
      }
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(_state('hat_01', '입는 중'), findsOneWidget);

      await _tap(tester, _key('prop-hat_02'));
      expect(_summary(tester), startsWith('여행 모자'));
      expect(_enabled(tester, '저장'), isTrue);

      await _save(tester);
      expect((await _stored(tester, e)).slots['hat'], 'hat_02');

      // 옷은 기본 하나뿐이면 그 칸만 (없음 칸 없음)
      await _goTab(tester, 'cloth');
      expect(find.byType(ItemCell), findsOneWidget);
      expect(_key('prop-cloth_02'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('가진 게 없는 얼굴 소품·둥실·효과 탭은 안내 글만 (없음 칸 없음)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      for (final (slot, text) in [
        ('face', '아직 가진 얼굴 소품이 없어요'),
        ('float', '아직 가진 둥실 소품이 없어요'),
        ('effect', '아직 가진 효과가 없어요'),
      ]) {
        await _goTab(tester, slot);
        expect(find.text(text), findsOneWidget, reason: slot);
        expect(find.byType(ItemCell), findsNothing, reason: slot);
      }
      await end(tester, e);
    });

    testWidgets('얻으면 안내 글이 없어지고 그 소품이 칸이 된다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_11', 'hat_10']));
      await _open(tester, e);

      await _goTab(tester, 'face');
      expect(_key('empty-slot'), findsNothing);
      expect(find.byType(ItemCell), findsNWidgets(2)); // 없음 + 안경
      expect(_state('hat_11', '가짐'), findsOneWidget);
      await _tap(tester, _key('prop-hat_11'));
      expect(_state('hat_11', '입는 중'), findsOneWidget);
      expect(_summary(tester), contains('안경'));

      await _goTab(tester, 'float');
      expect(_state('hat_10', '가짐'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('소품 칸 위에 다음 거리 소품까지 남은 본격 걷기 거리 한 줄 (무엇인지는 숨김)', (tester) async {
      final e = UiEnv();
      // 이동 거리 87km: 다음 거리 소품은 100km(등산화)라 13km
      await e.seed(tester, () => _walked(e.db, 87));
      await _open(tester, e);

      // 내 모습 탭에는 없다
      await _goTab(tester, 'me');
      expect(_key('next-prop'), findsNothing);
      for (final slot in ['hat', 'cloth', 'pet']) {
        await _goTab(tester, slot);
        expect(find.text('다음 소품까지 본격 걷기 13km'), findsOneWidget, reason: slot);
        // 줄은 칸들 위에 있다
        expect(tester.getBottomLeft(_key('next-prop')).dy,
            lessThan(tester.getTopLeft(find.byType(ItemCell).first).dy));
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

    testWidgets('없음 칸: 비우면 요약 줄에서 빠지고 저장하면 null로 남는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'hat');

      expect(_summary(tester), startsWith('베레모'));
      await _tap(tester, _key('prop-none'));
      expect(_summary(tester), isNot(contains('베레모')));
      expect(_enabled(tester, '저장'), isTrue);

      await _save(tester);
      final look = await _stored(tester, e);
      expect(look.slots['hat'], isNull);
      expect(look.slots['cloth'], 'cloth_02');
      await end(tester, e);
    });

    testWidgets('비운 칸에 기본 소품을 다시 끼울 수 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'bag');
      await _tap(tester, _key('prop-none'));
      expect(_summary(tester), isNot(contains('큰 붓')));
      await _tap(tester, _key('prop-hand_01'));
      expect(_summary(tester), contains('큰 붓'));
      // 저장된 모습과 같아졌다
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('소품 이름은 접근성 label로도 읽히고(입는 중 포함), 잠긴 소품은 읽히지도 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'bag');

      expect(find.bySemanticsLabel('큰 붓, 입는 중'), findsOneWidget);
      expect(find.bySemanticsLabel('화구 가방, 가짐'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('이젤 배낭')), findsNothing);
      expect(find.bySemanticsLabel('없음'), findsOneWidget);
      handle.dispose();
      await end(tester, e);
    });
  });

  test('Look에 소품 색이 없다: 옛 tints·propColors 키는 읽지 않고 저장하지도 않는다', () {
    final look = Look.fromJson({
      ...Look.initial.toJson(),
      'tints': {'hat_01': {'kind': 'swatch', 'i': 4}},
      'propColors': {'hat_01': '#D276A0'},
    });
    expect(look, Look.initial);
    expect(look.toJson().containsKey('tints'), isFalse);
    expect(look.toJson().containsKey('propColors'), isFalse);
  });

  group('저장 · 되돌리기', () {
    testWidgets('소품 칸에는 색 고르기가 없다 (색은 상점 색 소품, 16장 11/4·11/13 Annie)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      for (final t in ['hat', 'cloth', 'shoe', 'bag', 'pet']) {
        await _goTab(tester, t);
        expect(find.text('소품 색'), findsNothing, reason: t);
        expect(_key('prop-color-custom'), findsNothing, reason: t);
      }
      await end(tester, e);
    });

    testWidgets('저장하면 Profile.look에 JSON으로 남고 단추가 다시 꺼진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hand_02']));
      await _open(tester, e);

      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e2'));
      await _tap(tester, _key('nose-n5'));
      await _tap(tester, _key('body-swatch-2'));
      await _goTab(tester, 'bag');
      await _tap(tester, _key('prop-hand_02'));
      await _save(tester);

      final look = await _stored(tester, e);
      expect((look.eyes, look.nose, look.body), ('e2', 'n5', const SwatchBodyColor(2)));
      expect(look.brows, Look.initial.brows);
      expect(look.slots['bag'], 'hand_02');
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
      await _goTab(tester, 'me');

      await _tap(tester, _key('eyes-e4'));
      await _save(tester);
      await _tap(tester, _key('eyes-e2'));
      expect(_enabled(tester, '저장'), isTrue);
      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      expect(_chosen(tester, 'eyes-e4'), isTrue);
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });

    testWidgets('저장하면 "저장했어요" 토스트가 뜬다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e2'));
      await tester.tap(find.widgetWithText(GameButton, '저장'));
      await settle(tester, () => find.text('저장했어요').evaluate().isNotEmpty);
      expect(find.text('저장했어요'), findsOneWidget);
      await tester.pump(toastDuration + const Duration(seconds: 1));
      await end(tester, e);
    });

    testWidgets('되돌리기: 얼굴·몸 색·소품 모두 저장된 모습으로', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);

      await _goTab(tester, 'me');
      await _tap(tester, _key('brows-b6'));
      await _tap(tester, _key('body-swatch-5'));
      await _goTab(tester, 'shoe');
      await _tap(tester, _key('prop-none'));
      expect(_enabled(tester, '되돌리기'), isTrue);

      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      expect(_state('shoe_01', '입는 중'), findsOneWidget);
      expect(_enabled(tester, '저장'), isFalse);
      expect(_enabled(tester, '되돌리기'), isFalse);
      await _goTab(tester, 'me');
      expect(_chosen(tester, 'brows-b1'), isTrue);
      expect(_swatchCheck('body-swatch-1'), findsOneWidget);
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

    testWidgets('동작 미리보기만 바꿔도 확인 없이 나간다 (저장할 것이 아니다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await tester.tap(_key('expr-3'));
      await tester.pump();

      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsNothing);
      await end(tester, e);
    });

    testWidgets('바꾸고 나가려 하면 확인 시트: 계속 꾸미기는 그대로 남고, 나가기는 저장 없이 나간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e4'));

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
      expect(_chosen(tester, 'eyes-e4'), isTrue);
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
      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e2'));

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
      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e2'));
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
      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e2'));
      await _save(tester);
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsNothing);
      await end(tester, e);

      final e2 = UiEnv();
      await e2.seed(tester);
      await _open(tester, e2);
      await _goTab(tester, 'me');
      await _tap(tester, _key('eyes-e4'));
      await tester.tap(find.widgetWithText(GameButton, '되돌리기'));
      await tester.pump();
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(DecorateScreen), findsNothing);
      await end(tester, e2);
    });
  });

  group('색 소품 (명세 M4.5 D)', () {
    /// 칸 순서: 위에서 아래, 왼쪽에서 오른쪽
    List<String> order(WidgetTester tester, List<String> ids) {
      final pos = {for (final id in ids) id: tester.getTopLeft(_key('prop-$id'))};
      return [...ids]..sort((a, b) {
          final dy = pos[a]!.dy.compareTo(pos[b]!.dy);
          return dy != 0 ? dy : pos[a]!.dx.compareTo(pos[b]!.dx);
        });
    }

    testWidgets('산 색 소품은 같은 칸에 기본 소품 바로 뒤 따로 된 칸, 그림이 없으면 그 색 상자', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02_c1', 'hat_02', 'hat_01_c2']));
      await _open(tester, e);
      await _goTab(tester, 'hat');

      const ids = ['none', 'hat_01', 'hat_01_c2', 'hat_02', 'hat_02_c1'];
      expect(find.byType(ItemCell), findsNWidgets(ids.length));
      expect(order(tester, ids), ids);
      expect(find.descendant(of: _key('prop-hat_01_c2'), matching: find.text('밤바다 베레모')),
          findsOneWidget);
      expect(_state('hat_01_c2', '가짐'), findsOneWidget);

      Finder inCell(String id, Finder f) => find.descendant(of: _key('prop-$id'), matching: f);
      final hex = props.firstWhere((p) => p.id == 'hat_01_c2').materialArgb!;
      final box = tester.widget<DecoratedBox>(inCell('hat_01_c2', _key('item-swatch')));
      expect((box.decoration as BoxDecoration).color, Color(hex));
      expect(tester.getSize(inCell('hat_01_c2', _key('item-swatch'))), const Size(56, 50));
      expect(inCell('hat_01_c2', find.byType(ItemPlaceholder)), findsNothing);
      // 기본 소품은 그대로 (그림 파일 또는 점선)
      expect(inCell('hat_02', _key('item-swatch')), findsNothing);
      await end(tester, e);
    });

    testWidgets('기본 소품이 없으면 색 소품 기록이 있어도 안 보인다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02_c1']));
      await _open(tester, e);
      await _goTab(tester, 'hat');
      expect(_key('prop-hat_02_c1'), findsNothing);
      expect(find.byType(ItemCell), findsNWidgets(2));
      await end(tester, e);
    });

    testWidgets('입으면 같은 칸 기본 소품은 벗겨지고, 저장하면 모습에 남는다. 정령은 기본 소품 그림', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_01_c1', 'cloth_01', 'cloth_02_c1']));
      await _open(tester, e);
      await _goTab(tester, 'hat');
      final before = _worn(tester);

      await _tap(tester, _key('prop-hat_01_c1'));
      expect(_state('hat_01_c1', '입는 중'), findsOneWidget);
      expect(_state('hat_01', '가짐'), findsOneWidget);
      expect(_summary(tester), startsWith('봄하늘 베레모 · 여행복'));
      expect(_worn(tester).outfit,before.outfit);
      expect(_worn(tester).choices,before.choices);

      // 색 소품(별밤 여행복)은 그림이 없어 기본 여행복 그림으로 보인다(색은 T5 때). 맨몸이 되지 않는다
      await _goTab(tester, 'cloth');
      await _tap(tester, _key('prop-cloth_02'));
      expect(_worn(tester).outfit, 1);
      await _tap(tester, _key('prop-cloth_02_c1'));
      expect(_state('cloth_02_c1', '입는 중'), findsOneWidget);
      expect(_state('cloth_02', '가짐'), findsOneWidget);
      expect(_worn(tester).outfit, 1);
      // 앞치마로 바꾸면 여행복이 빠진다
      await _tap(tester, _key('prop-cloth_01'));
      expect(_worn(tester).outfit, 0);
      await _tap(tester, _key('prop-cloth_02_c1'));
      expect(_worn(tester).outfit, 1);

      await _save(tester);
      final stored = await _stored(tester, e);
      expect(stored.slots['hat'], 'hat_01_c1');
      expect(stored.slots['cloth'], 'cloth_02_c1');
      await end(tester, e);
    });

    testWidgets('색 소품을 입은 모습으로 열면 그 칸이 입는 중이다', (tester) async {
      final e = UiEnv();
      final look = Look.initial.withSlot('hat', 'hat_01_c3');
      await e.seed(tester, () async {
        await _ownProps(e.db, ['hat_01_c3']);
        await ProfileService(e.db).saveLook(look);
      });
      await _open(tester, e);
      await _goTab(tester, 'hat');
      expect(_state('hat_01_c3', '입는 중'), findsOneWidget);
      expect(_state('hat_01', '가짐'), findsOneWidget);
      expect(_summary(tester), startsWith('이끼숲 베레모'));
      expect(_enabled(tester, '저장'), isFalse);
      await end(tester, e);
    });
  });

  group('화면 크기', () {
    testWidgets('좁고 낮은 화면(320×568)에서도 모든 탭이 넘치지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _ownProps(e.db, ['hat_02', 'cloth_01']));
      await _open(tester, e, height: 568);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pump();

      for (final t in _tabs) {
        await _goTab(tester, t);
        expect(tester.takeException(), isNull, reason: t);
      }
      // 직접 고르기를 열어도, 소품 이름이 길어도 (모자 칸)
      await _goTab(tester, 'me');
      await _tap(tester, _key('body-custom'));
      expect(tester.takeException(), isNull);
      await _goTab(tester, 'hat');
      await _tap(tester, _key('prop-hat_02'));
      expect(tester.takeException(), isNull);
      await end(tester, e);
    });
  });
}
