import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/profile/profile_screen.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart' show badgeCatalog;
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
        height: _tall, ready: () => find.text('최근 14일').evaluate().isNotEmpty);

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
    expect((box.border! as Border).top.width, InkLine.panel);
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

  testWidgets('동행 도감은 없다 (11/4, 동행 화면과 겹쳐서 뺌)', (tester) async {
    final e = UiEnv();
    await e.seed(tester);
    await _open(tester, e);
    expect(find.text('동행 도감'), findsNothing);
    await end(tester, e);
  });

  testWidgets('초상은 쉼터·꾸미기와 같은 정령이고, 닉네임을 보인다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await e.db.into(e.db.profile).insertOnConflictUpdate(ProfileCompanion(
            id: const Value(1),
            nickname: const Value('나그네'),
            look: const Value('{"eyes":"e4","mouth":"m5","body":{"kind":"swatch","i":9}}'),
          ));
    });
    await _open(tester, e);

    expect(find.text('나그네'), findsOneWidget);
    final portrait = find.byKey(const ValueKey('portrait'));
    final spirit = find.descendant(of: portrait, matching: find.byType(SpiritCharacter));
    expect(spirit, findsOneWidget);
    // 고른 얼굴을 입는다
    final look = tester.widget<SpiritCharacter>(spirit).look;
    expect((look.eye, look.mouth), (3, 4));
    // 고른 몸 색(테라코타)과 기준 밝기도 쉼터와 같은 값으로 입는다
    expect((look.bodyArgb, look.bodyBaseArgb), (0xFFC9775A, 0xFFFFF5E2));
    await end(tester, e);
  });

  testWidgets('폰에 저장돼 있던 옛 사람형 모습은 기본 정령(기본 얼굴·크림)으로 보인다', (tester) async {
    final e = UiEnv();
    await e.seed(tester, () async {
      await e.db.into(e.db.profile).insertOnConflictUpdate(ProfileCompanion(
            id: const Value(1),
            nickname: const Value('옛 화가'),
            look: const Value('{"hair":4,"hairColor":{"kind":"swatch","i":3},"eyes":3,"mouth":6}'),
          ));
    });
    await _open(tester, e);

    final spirit = find.descendant(
        of: find.byKey(const ValueKey('portrait')), matching: find.byType(SpiritCharacter));
    final look = tester.widget<SpiritCharacter>(spirit).look;
    expect((look.eye, look.brow, look.nose, look.mouth), (0, 1, 6, 6));
    expect(look.bodyArgb, 0xFFF3E4C4);
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
    await settle(tester, () => find.byKey(const ValueKey('tab-me')).evaluate().isNotEmpty);
    expect(find.text('꾸미기'), findsOneWidget);
    expect(find.byType(DecorateScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-me')), findsOneWidget);
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

  group('나 탭 도장 (16장 11/19 ③: 화집에서 옮겨 옴)', () {
    Future<void> owned(UiEnv e, Map<String, int> badges, {bool seen = false}) =>
        e.db.batch((b) => b.insertAll(e.db.badgesOwned, [
              for (final x in badges.entries)
                BadgesOwnedCompanion.insert(badgeId: x.key, atUtc: x.value, seen: Value(seen)),
            ]));

    Future<void> openStamps(WidgetTester tester, UiEnv e) =>
        openOnTop(tester, e, const ProfileScreen(),
            height: 3000, ready: () => find.byKey(const ValueKey('me-stamps')).evaluate().isNotEmpty);

    testWidgets('최근 14일 아래·노트 위에 `도장` + 받은 수, 묶음별: 받은 도장은 이름·받은 날, 못 받은 도장은 이름·조건 글',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => owned(e, {
            'b_first_walk': DateTime.utc(2026, 11, 18, 3).millisecondsSinceEpoch,
            'b_night': DateTime.utc(2026, 11, 19, 14).millisecondsSinceEpoch,
          }));
      await openStamps(tester, e);
      await settle(tester, () => find.text('첫 걸음').evaluate().isNotEmpty);

      // 차례: 최근 14일 → 도장 → 노트 (config ui.tabs.me: records · badges · … · note)
      final days = tester.getTopLeft(find.text('최근 14일')).dy;
      final stamps = tester.getTopLeft(find.byKey(const ValueKey('me-stamps'))).dy;
      final note = tester.getTopLeft(find.byKey(const ValueKey('me-note'))).dy;
      expect(days < stamps && stamps < note, isTrue);
      expect(find.text('도장'), findsOneWidget);
      expect(find.text('2 / ${badgeCatalog.badges.length}'), findsOneWidget);
      // 묶음 이름과 묶음별 받은 수
      for (final name in ['걷기 습관', '시간대', '지형·계절', '여정', '동행']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('1 / 6'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('0 / 5'), findsOneWidget);
      // 받은 도장: 이름과 받은 날(한국 날짜)
      expect(find.text('첫 걸음'), findsOneWidget);
      expect(find.text('11월 18일'), findsOneWidget);
      expect(find.text('밤 산책'), findsOneWidget);
      expect(find.text('11월 19일'), findsOneWidget);
      // 못 받은 도장은 이름과 조건 글만 있고 진행도·자물쇠는 없다
      final locked = badgeCatalog.badges.firstWhere((b) => b.id == 'b_walk_5km');
      expect(find.text(locked.name), findsOneWidget);
      expect(find.text(locked.desc), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsNothing);

      // 나 탭에는 새 소식 점이 없어(ui.tabs.dots.me 비었음) 보이면 본 것으로 적는다
      await settle(tester, () => false, tries: 6);
      final rows = (await tester.runAsync(() => e.db.select(e.db.badgesOwned).get()))!;
      expect(rows.every((r) => r.seen), isTrue);
      await end(tester, e);
    });

    testWidgets('받은 도장 칸을 누르면 이름·설명·받은 날 시트가 뜨고, 못 받은 칸은 눌러도 안 뜬다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => owned(e, {
            'b_walk_5km': DateTime.utc(2026, 11, 20, 3).millisecondsSinceEpoch,
          }, seen: true));
      await openStamps(tester, e);
      await settle(tester, () => find.text('한 번에 5km').evaluate().isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('stamp-b_walk_5km')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final sheet = find.byKey(const ValueKey('stamp-sheet'));
      expect(sheet, findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('한 번에 5km')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('걷기 한 번에 5km')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('11월 20일에 받았어요')), findsOneWidget);

      // 시트를 닫고, 못 받은 칸을 누른다
      Navigator.of(tester.element(sheet)).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('stamp-b_walk_10km')), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('stamp-sheet')), findsNothing);
      await end(tester, e);
    });
  });
}
