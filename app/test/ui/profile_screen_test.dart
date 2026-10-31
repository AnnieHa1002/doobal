import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/ui/common/figure_painter.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/profile/profile_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

/// 한 화면에 다 보이도록 길게 잡은 높이
const _tall = 1400.0;

/// 하루 요약 한 줄을 (이미 있으면 덮어써서) 넣는다
Future<void> _day(AppDb db, String day, int steps, double distanceM) =>
    db.into(db.daySummaries).insertOnConflictUpdate(DaySummariesCompanion.insert(
          day: day,
          steps: steps,
          distanceM: distanceM,
          countedSessions: 0,
        ));

Finder _stat(String id) => find.byKey(ValueKey('stat-$id'));

Finder _in(Finder owner, String text) => find.descendant(of: owner, matching: find.text(text));

Finder _bars() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('bar-');
    });

Finder _bar(String day) => find.byKey(ValueKey('bar-$day'));

Color _barColor(WidgetTester tester, String day) =>
    ((tester.widget<Container>(_bar(day))).decoration! as BoxDecoration).color!;

Future<void> _open(WidgetTester tester, UiEnv e) =>
    openOnTop(tester, e, const ProfileScreen(),
        height: _tall, ready: () => find.text('동행 도감').evaluate().isNotEmpty);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  testWidgets('제목, 닉네임, 숫자 카드 4개가 DB 값과 맞는다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      // 오늘(한국 11월 18일) 12,345보, 어제 6,000보, 11월 10일 3,000보 → 누적 14.6km
      await _day(e.db, '2026-11-18', 12345, 8300);
      await _day(e.db, '2026-11-17', 6000, 4200);
      await _day(e.db, '2026-11-10', 3000, 2100);
      await e.ownPaintings({'kr001': Frame.wood, 'kr002': Frame.silver, 'kr003': Frame.gold});
      await (e.db.update(e.db.travelFund)..where((t) => t.id.equals(1)))
          .write(const TravelFundCompanion(km: Value(4.5)));
    });
    await _open(tester, e);

    expect(find.text('나의 정보'), findsOneWidget);
    expect(find.byTooltip('뒤로'), findsOneWidget);
    expect(find.text('화가'), findsOneWidget);
    expect(find.byKey(const ValueKey('portrait')), findsOneWidget);

    expect(_in(_stat('steps'), '12,345'), findsOneWidget);
    expect(_in(_stat('steps'), '오늘 걸음'), findsOneWidget);
    expect(_in(_stat('km'), '14.6 km'), findsOneWidget);
    expect(_in(_stat('km'), '누적 거리'), findsOneWidget);
    expect(_in(_stat('paintings'), '3'), findsOneWidget);
    expect(_in(_stat('paintings'), '모은 그림'), findsOneWidget);
    expect(_in(_stat('fund'), '4.5 km'), findsOneWidget);
    expect(_in(_stat('fund'), '여행 경비'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('숫자 카드는 큰 숫자 40·라벨 12, 카드는 카드색 + 잉크 2.5 테두리', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () => _day(e.db, '2026-11-18', 1500, 1050));
    await _open(tester, e);

    expect(tester.widget<Text>(_in(_stat('steps'), '1,500')).textSpan!.style!.fontSize, 40);
    expect(tester.widget<Text>(_in(_stat('steps'), '오늘 걸음')).style!.fontSize, 12);
    final card = tester.widget<Container>(
        find.descendant(of: _stat('steps'), matching: find.byType(Container)).first);
    final box = card.decoration! as BoxDecoration;
    expect(box.color, Palette.card);
    expect((box.border! as Border).top.color, Palette.ink);
    expect((box.border! as Border).top.width, 2.5);
    expect(find.text('나의 정보'), findsOneWidget);
    expect(tester.widget<Text>(find.text('나의 정보')).style!.fontSize, 22);
    await end(tester, e);
  });

  testWidgets('기록이 없으면 숫자는 모두 0이고 막대는 14개 모두 최소 높이', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _open(tester, e);

    expect(_in(_stat('steps'), '0'), findsOneWidget);
    expect(_in(_stat('km'), '0.0 km'), findsOneWidget);
    expect(_in(_stat('paintings'), '0'), findsOneWidget);
    expect(_in(_stat('fund'), '0.0 km'), findsOneWidget);
    expect(_bars(), findsNWidgets(14));
    for (final bar in _bars().evaluate()) {
      expect(tester.getSize(find.byWidget(bar.widget)).height, 4);
    }
    await end(tester, e);
  });

  testWidgets('최근 14일 막대: 14개, 오늘이 맨 오른쪽, 가장 높은 날이 꽉 차고 오늘은 테라코타', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _day(e.db, '2026-11-18', 12345, 8300);
      await _day(e.db, '2026-11-17', 6000, 4200);
      // 14일 밖이라 막대에 없다
      await _day(e.db, '2026-11-04', 99999, 0);
    });
    await _open(tester, e);

    expect(find.text('최근 14일'), findsOneWidget);
    expect(_bars(), findsNWidgets(14));
    expect(_bar('2026-11-05'), findsOneWidget);
    expect(_bar('2026-11-04'), findsNothing);
    // 왼쪽에서 오른쪽으로 오래된 날부터, 오늘이 맨 오른쪽
    final xs = [
      for (final d in ['2026-11-05', '2026-11-17', '2026-11-18']) tester.getTopLeft(_bar(d)).dx,
    ];
    expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue);

    // 오늘 값이 가장 커서 막대 영역을 꽉 채운다 (96). 어제는 4 + 92 × 6000 / 12345, 빈 날은 4
    expect(tester.getSize(_bar('2026-11-18')).height, 96);
    expect(tester.getSize(_bar('2026-11-17')).height, closeTo(4 + 92 * 6000 / 12345, 1e-6));
    expect(tester.getSize(_bar('2026-11-10')).height, 4);
    expect(_barColor(tester, '2026-11-18'), Palette.terracotta);
    expect(_barColor(tester, '2026-11-17'), Palette.moss);
    expect(_barColor(tester, '2026-11-10'), isNot(Palette.moss));

    // 요일 글자 (11월 18일은 수요일)
    expect(find.text('수'), findsNWidgets(2));
    await end(tester, e);
  });

  testWidgets('동행 도감: 3칸 모두 실루엣과 지형 힌트, 이름은 숨긴다', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _open(tester, e);

    expect(find.text('동행 도감'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('companion-$i')), findsOneWidget);
    }
    expect(_in(find.byKey(const ValueKey('companion-0')), '바닷가를 걷다 보면…'), findsOneWidget);
    expect(_in(find.byKey(const ValueKey('companion-1')), '도시를 걷다 보면…'), findsOneWidget);
    expect(_in(find.byKey(const ValueKey('companion-2')), '산길을 걷다 보면…'), findsOneWidget);
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('companion-0')), matching: find.byIcon(Icons.person)),
      findsOneWidget,
    );
    for (final name in ['퐁', '휴', '심 박사']) {
      expect(find.textContaining(name), findsNothing, reason: name);
    }
    await end(tester, e);
  });

  testWidgets('초상은 프로필의 머리 모양·머리색으로 그리고, 닉네임을 보인다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await e.db.into(e.db.profile).insertOnConflictUpdate(ProfileCompanion(
            id: const Value(1),
            nickname: const Value('나그네'),
            look: const Value('{"hair":4,"hairColor":{"kind":"swatch","i":3}}'),
          ));
    });
    await _open(tester, e);

    expect(find.text('나그네'), findsOneWidget);
    final paint = tester.widget<CustomPaint>(find.descendant(
        of: find.byKey(const ValueKey('portrait')), matching: find.byType(CustomPaint)));
    final painter = paint.painter! as FigurePainter;
    expect(painter.hair, 4);
    expect(painter.hairColor, Color(hairArgb(const SwatchHairColor(3), hairSwatches)));
    await end(tester, e);
  });

  testWidgets('좁은 화면(320)과 큰 숫자·긴 닉네임에서도 넘치지 않는다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await _day(e.db, '2026-11-18', 123456, 98765432);
      await e.db.into(e.db.profile).insertOnConflictUpdate(
          ProfileCompanion(id: const Value(1), nickname: const Value('아주아주 긴 닉네임입니다 열글자넘음')));
    });
    await _open(tester, e);
    tester.view.physicalSize = const Size(320, _tall);
    await tester.pump();

    expect(find.text('123,456'), findsOneWidget);
    expect(find.text('98765.4 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await end(tester, e);
  });

  testWidgets('꾸미기 버튼은 꾸미기 화면으로 가고, 뒤로 오면 나의 정보', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _open(tester, e);

    await tester.tap(find.text('꾸미기'));
    await transition(tester);
    await settle(tester, () => find.byKey(const ValueKey('tab-hair')).evaluate().isNotEmpty);
    expect(find.text('꾸미기'), findsOneWidget);
    expect(find.byType(DecorateScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-hair')), findsOneWidget);
    expect(find.text('준비 중'), findsNothing);
    expect(find.text('나의 정보'), findsNothing);

    // 바꾸지 않았으니 확인 없이 나온다
    await tester.tap(find.byTooltip('뒤로'));
    await transition(tester);
    expect(find.text('나의 정보'), findsOneWidget);
    expect(find.byType(DecorateScreen), findsNothing);

    await tester.tap(find.byTooltip('뒤로'));
    await transition(tester);
    expect(find.text('열기'), findsOneWidget);
    await end(tester, e);
  });

  testWidgets('꾸미기에서 저장하고 돌아오면 초상이 새 머리색·피부색으로 바뀐다', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _open(tester, e);
    FigurePainter portrait() => tester
        .widget<CustomPaint>(find.descendant(
            of: find.byKey(const ValueKey('portrait')), matching: find.byType(CustomPaint)))
        .painter! as FigurePainter;
    expect(portrait().hairColor, Color(hairSwatches.first.color));
    expect(portrait().skin, FigurePainter.defaultSkin);

    await tester.tap(find.text('꾸미기'));
    await transition(tester);
    await settle(tester, () => find.byKey(const ValueKey('tab-hair')).evaluate().isNotEmpty);
    await tester.tap(find.byKey(const ValueKey('hair-swatch-9')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('tab-skin')));
    await tester.tap(find.byKey(const ValueKey('tab-skin')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('skin-swatch-5')));
    await tester.pump();
    await tester.tap(find.text('저장'));
    await settle(tester, () => find.text('저장했어요').evaluate().isNotEmpty);

    await tester.tap(find.byTooltip('뒤로'));
    await transition(tester);
    await settle(tester, () => portrait().skin != FigurePainter.defaultSkin);
    expect(portrait().hairColor, Color(hairSwatches[8].color));
    expect(portrait().skin, Color(lookPalette.skin.swatches[4].color));
    await end(tester, e);
  });
}
