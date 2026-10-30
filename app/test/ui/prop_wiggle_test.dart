import 'dart:math' as math;

import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/journey.dart' show Frame;
import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_env.dart';

/// 정해 둔 값을 차례로 돌려주는 난수 (다 쓰면 마지막 값을 되풀이한다)
class _ScriptedRandom implements math.Random {
  _ScriptedRandom({this.ints = const [0], this.doubles = const [0.5]});

  final List<int> ints;
  final List<double> doubles;
  var _i = 0;
  var _d = 0;

  @override
  int nextInt(int max) => ints[math.min(_i++, ints.length - 1)].clamp(0, max - 1);

  @override
  double nextDouble() => doubles[math.min(_d++, doubles.length - 1)];

  @override
  bool nextBool() => false;
}

/// 1초마다 0.6초 흔든다 (간격을 고정해서 몇 번째 pump에 흔들리는지 알 수 있다)
WiggleSpec _spec(List<int> ints) => WiggleSpec(
      minGap: const Duration(seconds: 1),
      maxGap: const Duration(seconds: 1),
      random: _ScriptedRandom(ints: ints),
    );

const _ids = ['map', 'backpack', 'note', 'guestbook'];

/// 물건 [id]의 지금 기울기(라디안). 회전 Transform의 행렬에서 읽는다
double _tilt(WidgetTester tester, String id) {
  final t = tester.widget<Transform>(find
      .descendant(of: find.byKey(ValueKey('wiggle-$id')), matching: find.byType(Transform))
      .first);
  return math.asin(t.transform.storage[1]);
}

/// 지금 기울어진 물건 id (여럿이면 여럿)
List<String> _tilted(WidgetTester tester) => [
      for (final id in _ids)
        if (find.byKey(ValueKey('wiggle-$id')).evaluate().isNotEmpty &&
            _tilt(tester, id).abs() > 1e-9)
          id,
    ];

/// 쉼터만 [spec]으로 연다 (물건 흔들림 확인용). 쉬는 중 알약이 뜰 때까지 기다린다
Future<void> _openRest(WidgetTester tester, UiEnv e, WiggleSpec spec) async {
  phone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [...e.overrides, restWiggleProvider.overrideWithValue(spec)],
    child: const MaterialApp(home: RestScreen()),
  ));
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
  await tester.pump();
}

/// 간격(1초)이 지나 흔들림이 막 시작한 뒤 [after]만큼 더 지난 때로
Future<void> _wiggleStarted(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 70));
}

/// 흔들림이 끝날 때까지 (0.6초)
Future<void> _wiggleEnds(WidgetTester tester) => tester.pump(const Duration(milliseconds: 700));

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('고르기·간격·각도', () {
    test('알림 점이 있는 물건이 있으면 그 중에서만 고른다', () {
      const notice = {'backpack', 'guestbook'};
      expect(pickWiggleTarget(_ids, notice, _ScriptedRandom(ints: [0])), 'backpack');
      expect(pickWiggleTarget(_ids, notice, _ScriptedRandom(ints: [1])), 'guestbook');
      final random = math.Random(1);
      final picked = {for (var i = 0; i < 200; i++) pickWiggleTarget(_ids, notice, random)};
      expect(picked, notice);
    });

    test('알림 점이 없으면 전체에서 고른다 (알림 id가 목록에 없어도 같다)', () {
      expect(pickWiggleTarget(_ids, {}, _ScriptedRandom(ints: [0])), 'map');
      expect(pickWiggleTarget(_ids, {}, _ScriptedRandom(ints: [3])), 'guestbook');
      expect(pickWiggleTarget(_ids, {'없는 물건'}, _ScriptedRandom(ints: [2])), 'note');
      final random = math.Random(2);
      expect({for (var i = 0; i < 200; i++) pickWiggleTarget(_ids, {}, random)}, _ids.toSet());
    });

    test('고를 물건이 없으면 null', () {
      expect(pickWiggleTarget(const [], {'backpack'}, math.Random(1)), isNull);
    });

    test('간격은 3~6초 사이 (기본 설정)', () {
      const spec = WiggleSpec();
      expect(wiggleGap(spec, _ScriptedRandom(doubles: [0])), const Duration(seconds: 3));
      expect(wiggleGap(spec, _ScriptedRandom(doubles: [1])), const Duration(seconds: 6));
      expect(wiggleGap(spec, _ScriptedRandom(doubles: [0.5])), const Duration(milliseconds: 4500));
      final random = math.Random(3);
      for (var i = 0; i < 100; i++) {
        final gap = wiggleGap(spec, random);
        expect(gap, greaterThanOrEqualTo(const Duration(seconds: 3)));
        expect(gap, lessThanOrEqualTo(const Duration(seconds: 6)));
      }
    });

    test('기울기: 0에서 시작해 좌우로 몇 도 흔들리고 0으로 끝난다', () {
      const spec = WiggleSpec();
      final max = spec.degrees * math.pi / 180;
      expect(wiggleAngle(0, spec), 0);
      expect(wiggleAngle(1, spec).abs(), lessThan(1e-12));
      final angles = [for (var i = 1; i < 100; i++) wiggleAngle(i / 100, spec)];
      expect(angles.every((a) => a.abs() <= max), isTrue);
      expect(angles.any((a) => a > max * 0.5), isTrue, reason: '오른쪽으로 기운다');
      expect(angles.any((a) => a < -max * 0.5), isTrue, reason: '왼쪽으로 기운다');
      // 기본 설정의 연출: 0.6초, 몇 도 (10도 안쪽이면 살짝)
      expect(spec.duration, const Duration(milliseconds: 600));
      expect(spec.degrees, inInclusiveRange(1, 10));
    });
  });

  group('쉼터 물건', () {
    testWidgets('간격이 지나면 물건 하나가 기울었다가 0으로 돌아오고, 또 간격이 지나면 다시 흔들린다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openRest(tester, e, _spec([0]));

      // 알림 점이 없어서 전체에서 첫 번째(지도)를 고른다. 처음에는 모두 0도, 회전 Transform은 있다
      for (final id in ['map', 'backpack', 'note']) {
        expect(_tilt(tester, id), 0, reason: id);
      }
      expect(find.byKey(const ValueKey('wiggle-guestbook')), findsNothing);

      await tester.pump(const Duration(milliseconds: 900));
      expect(_tilted(tester), isEmpty, reason: '간격(1초) 전');

      await _wiggleStarted(tester);
      expect(_tilted(tester), ['map']);
      final maxTilt = const WiggleSpec().degrees * math.pi / 180;
      expect(_tilt(tester, 'map').abs(), lessThanOrEqualTo(maxTilt));

      await _wiggleEnds(tester);
      expect(_tilted(tester), isEmpty);
      expect(_tilt(tester, 'map'), 0);

      await _wiggleStarted(tester);
      expect(_tilted(tester), ['map']);
      await _wiggleEnds(tester);
      expect(_tilted(tester), isEmpty);
      await end(tester, e);
    });

    testWidgets('흔들리는 동안 좌우로 오간다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openRest(tester, e, _spec([0]));

      await tester.pump(const Duration(seconds: 1));
      final seen = <double>[];
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        seen.add(_tilt(tester, 'map'));
      }
      expect(seen.any((a) => a > 0.01), isTrue);
      expect(seen.any((a) => a < -0.01), isTrue);
      await _wiggleEnds(tester);
      await end(tester, e);
    });

    testWidgets('알림 점이 없으면 전체에서 고른다 (세 번째 = 노트)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openRest(tester, e, _spec([2]));

      await _wiggleStarted(tester);
      expect(_tilted(tester), ['note']);
      await _wiggleEnds(tester);
      await end(tester, e);
    });

    testWidgets('알림 점이 있는 물건(배낭 점, 방명록 표지판) 중에서만 고른다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        // 안 본 그림 → 배낭 점, 쓸 기회 → 방명록 표지판
        await e.ownPaintings({'kr001': Frame.wood}, seen: false);
        await e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
              id: 'a:j1',
              kind: TicketKind.arrival,
              scope: 'kr001',
              openedUtc: t1.millisecondsSinceEpoch,
            ));
      });
      // 알림이 있는 물건은 [배낭, 방명록]: 첫 흔들림은 둘째(방명록), 다음은 첫째(배낭)
      await _openRest(tester, e, _spec([1, 0]));
      expect(find.byKey(const ValueKey('backpack-dot')), findsOneWidget);
      expect(find.byKey(const ValueKey('signpost')), findsOneWidget);

      await _wiggleStarted(tester);
      expect(_tilted(tester), ['guestbook']);
      await _wiggleEnds(tester);
      expect(_tilted(tester), isEmpty);

      await _wiggleStarted(tester);
      expect(_tilted(tester), ['backpack']);
      await _wiggleEnds(tester);
      await end(tester, e);
    });

    testWidgets('배낭 점만 있으면 배낭만 흔들린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => e.ownPaintings({'kr001': Frame.wood}, seen: false));
      // 어느 칸을 골라도 (마지막 칸) 알림 물건 하나뿐이라 배낭
      await _openRest(tester, e, _spec([3]));

      await _wiggleStarted(tester);
      expect(_tilted(tester), ['backpack']);
      await _wiggleEnds(tester);
      await end(tester, e);
    });

    testWidgets('흔들리는 중에도 물건을 누르면 열린다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openRest(tester, e, _spec([0]));

      await _wiggleStarted(tester);
      expect(_tilted(tester), ['map']);
      await tester.tap(find.byIcon(Icons.map_outlined));
      await transition(tester);
      expect(find.byType(MapScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('흔들림을 끄면(off) 오래 기다려도 흔들리지 않고 프레임도 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openRest(tester, e, const WiggleSpec.off());

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 3));
        expect(_tilted(tester), isEmpty);
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
      await end(tester, e);
    });

    testWidgets('기본 설정(3~6초)에서도 pumpAndSettle이 끝나고, 흔들림이 지나면 0도로 돌아온다',
        (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _openRest(tester, e, const WiggleSpec());

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(_tilted(tester), isEmpty);
      await end(tester, e);
    });

    testWidgets('화면을 치우면 기다리던 타이머와 흔들던 애니메이션이 남지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);

      // 간격을 세는 중에 치운다
      await _openRest(tester, e, _spec([0]));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // 흔드는 중에 치운다
      await _openRest(tester, e, _spec([0]));
      await _wiggleStarted(tester);
      expect(_tilted(tester), ['map']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      await end(tester, e);
    });
  });
}
