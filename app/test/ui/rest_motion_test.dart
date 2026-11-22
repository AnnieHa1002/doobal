import 'dart:math';

import 'package:doobal/app/screen_providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/decor_place.dart';
import 'package:doobal/ui/rest/prop_wiggle.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/scene/doobal_character.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

// 연출 ② 쉼터 (T19, 16장 11/20 Q008, config ui.motion.restPet·decorWiggle, 캔버스 2-2 메모):
// 정령 몸 위를 좌우로 문지르면 행복 표정 + 몸 기울기, 그림 안 거는 꾸밈 물품을 누르면 발을 축으로 흔들림.
// 탭 바 없이 쉼터만 띄워서 390×844 폰이면 장면 pt = 화면 pt (k 1)

final _stage = DecorStage.of(campTheme, rules.decor.place, screenHeightPx: rules.screenHeightPx)!;
final _pet = rules.motion.restPet!;
final _wiggle = rules.motion.decorWiggle!;

Future<void> _own(UiEnv e, List<String> ids) => e.db.batch((b) => b.insertAll(e.db.decorOwned, [
      for (final (i, id) in ids.indexed) DecorOwnedCompanion.insert(decorId: id, gotUtc: 1000 + i),
    ]));

Future<void> _place(UiEnv e, String id, ScenePoint foot) {
  final r = _stage.toRatio(foot);
  return e.db.into(e.db.decorPlaced).insert(DecorPlacedCompanion.insert(
        decorId: id,
        xRatio: r.x,
        yRatio: r.y,
        flipped: const Value(false),
        placedUtc: 1,
      ));
}

Future<void> _open(WidgetTester tester, UiEnv e) async {
  phone(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...e.overrides,
      restWiggleProvider.overrideWithValue(const WiggleSpec.off()),
      restSwapRandomProvider.overrideWithValue(Random(5)),
    ],
    child: const MaterialApp(home: RestScreen()),
  ));
  await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
  await settle(tester, () => find.byKey(const ValueKey('rest-side-decorate')).evaluate().isNotEmpty);
  await tester.pump();
}

/// 움직임 줄이기 켜기 (기기 설정)
void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// 변환의 회전각 (도)
double _deg(Transform t) {
  final m = t.transform;
  return atan2(m.entry(1, 0), m.entry(0, 0)) * 180 / pi;
}

/// 꾸밈 물품 [id]의 흔들림 각도 (도)
double _decorDeg(WidgetTester tester, String id) => _deg(tester.widget<Transform>(find
    .descendant(of: find.byKey(ValueKey('decor-wiggle-$id')), matching: find.byType(Transform))
    .first));

double _tilt(WidgetTester tester) => _deg(tester.widget<Transform>(find.byKey(const ValueKey('rest-pet-tilt'))));

DoobalCharacter _doobal(WidgetTester tester) => tester.widget<DoobalCharacter>(find.byType(DoobalCharacter));

/// 정령 600 캔버스 상자와 그 안 몸 가운데 (몸 상자 x 200~400·y 135~445의 가운데)
Rect _spiritBox(WidgetTester tester) => tester.getRect(find.byKey(const ValueKey('rest-pet')));
Offset _body(WidgetTester tester) {
  final r = _spiritBox(tester);
  return r.topLeft + const Offset(300, 290) * (r.width / 600);
}

/// 정령 몸 위에서 [moves](가로 pt, 밀리초)대로 문지른다
Future<void> _rub(WidgetTester tester, Offset from, List<(double, int)> moves) async {
  final g = await tester.startGesture(from);
  for (final (dx, ms) in moves) {
    await g.moveBy(Offset(dx, 0), timeStamp: Duration(milliseconds: ms));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up(timeStamp: Duration(milliseconds: moves.last.$2 + 16));
}

/// 0.6초 안에 오른쪽 → 왼쪽 → 오른쪽 (방향 두 번 바뀜)
const _quickRub = [(30.0, 50), (-30.0, 200), (30.0, 350)];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('꾸밈 물품 누르면 흔들림 (decorWiggle)', () {
    testWidgets('그림 안 거는 물품을 누르면 발을 축으로 0 → +6 → −3 → 0도, 0.4초에 끝', (tester) async {
      final e = UiEnv();
      const foot = ScenePoint(300, 760);
      await e.seed(tester, () async {
        await _own(e, ['decor_bench']);
        await _place(e, 'decor_bench', foot);
      });
      await _open(tester, e);
      expect(_decorDeg(tester, 'decor_bench'), 0);
      // 축 = 발: 그림 상자 왼쪽 위에서 (발 − 상자 왼쪽 위) × k(1)
      final art = tester.getRect(find.byKey(const ValueKey('decor-art-decor_bench')));
      final t = tester.widget<Transform>(find
          .descendant(of: find.byKey(const ValueKey('decor-wiggle-decor_bench')), matching: find.byType(Transform))
          .first);
      expect(t.alignment, Alignment.topLeft);
      expect(t.origin!.dx, closeTo(foot.x - art.left, 0.5));
      expect(t.origin!.dy, closeTo(foot.y - art.top, 0.5));

      await tester.tap(find.byKey(const ValueKey('decor-decor_bench')));
      await tester.pump();
      final step = Duration(microseconds: (_wiggle.sec / 3 * 1e6).round());
      await tester.pump(step);
      expect(_decorDeg(tester, 'decor_bench'), closeTo(6, 0.05));
      await tester.pump(step);
      expect(_decorDeg(tester, 'decor_bench'), closeTo(-3, 0.05));
      await tester.pump(step);
      expect(_decorDeg(tester, 'decor_bench'), closeTo(0, 1e-6));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_decorDeg(tester, 'decor_bench'), 0);
      expect(find.byKey(const ValueKey('painting-pick-sheet')), findsNothing, reason: '시트는 안 뜬다');
      await end(tester, e);
    });

    testWidgets('흔드는 중에 다시 누르면 처음부터 (끝으로 건너뛰고 다시)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _own(e, ['decor_bench', 'decor_flower_pot']);
        await _place(e, 'decor_bench', const ScenePoint(300, 760));
        await _place(e, 'decor_flower_pot', const ScenePoint(380, 720));
      });
      await _open(tester, e);
      await tester.tap(find.byKey(const ValueKey('decor-decor_bench')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_decorDeg(tester, 'decor_bench'), isNot(0));
      await tester.tap(find.byKey(const ValueKey('decor-decor_flower_pot')));
      await tester.pump();
      expect(_decorDeg(tester, 'decor_bench'), 0, reason: '앞 물품은 끝 상태');
      await tester.pump(Duration(microseconds: (_wiggle.sec / 3 * 1e6).round()));
      expect(_decorDeg(tester, 'decor_flower_pot'), closeTo(6, 0.05));
      await tester.pump(const Duration(milliseconds: 400));
      await end(tester, e);
    });

    testWidgets('꾸미기 중(서랍이 열림)에는 눌러도 흔들지 않고 고르기만', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _own(e, ['decor_bench']);
        await _place(e, 'decor_bench', const ScenePoint(300, 760));
      });
      await _open(tester, e);
      await tester.tap(find.byKey(const ValueKey('rest-side-decorate')));
      // 서랍이 열리며 장면이 올라갈 때까지
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('decor-decor_bench')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(_decorDeg(tester, 'decor_bench'), 0);
      }
      expect(find.byKey(const ValueKey('decor-flip-button')), findsOneWidget, reason: '고르기는 그대로');
      await end(tester, e);
    });

    testWidgets('흔드는 중에 꾸미기를 열면 바로 멈춘다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _own(e, ['decor_bench']);
        await _place(e, 'decor_bench', const ScenePoint(300, 760));
      });
      await _open(tester, e);
      await tester.tap(find.byKey(const ValueKey('decor-decor_bench')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_decorDeg(tester, 'decor_bench'), isNot(0));
      await tester.tap(find.byKey(const ValueKey('rest-side-decorate')));
      await tester.pump();
      expect(_decorDeg(tester, 'decor_bench'), 0);
      await tester.pump(const Duration(milliseconds: 400));
      await end(tester, e);
    });

    testWidgets('움직임 줄이기면 끝 상태만 (흔들지 않음)', (tester) async {
      _reduceMotion(tester);
      final e = UiEnv();
      await e.seed(tester, () async {
        await _own(e, ['decor_bench']);
        await _place(e, 'decor_bench', const ScenePoint(300, 760));
      });
      await _open(tester, e);
      await tester.tap(find.byKey(const ValueKey('decor-decor_bench')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(_decorDeg(tester, 'decor_bench'), 0);
      }
      await end(tester, e);
    });

    testWidgets('그림 거는 물품(이젤)은 흔들지 않고 지금처럼 그림 고르기', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _own(e, ['decor_easel']);
        await _place(e, 'decor_easel', const ScenePoint(360, 700));
      });
      await _open(tester, e);
      await tester.tap(find.byKey(const ValueKey('decor-decor_easel')));
      await tester.pump(const Duration(milliseconds: 130));
      expect(_decorDeg(tester, 'decor_easel'), 0);
      await transition(tester);
      await settle(tester, () => find.byKey(const ValueKey('painting-pick-empty')).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('painting-pick-empty')), findsOneWidget);
      await end(tester, e);
    });
  });

  group('정령 쓰다듬기 (restPet)', () {
    testWidgets('0.6초 안에 좌우가 두 번 바뀌면 행복 표정 1초 + 문지르는 쪽으로 4도, 0.3초에 되돌림', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      final before = _spiritBox(tester);
      expect(_tilt(tester), 0);
      expect(_doobal(tester).cue, isNull);

      await _rub(tester, _body(tester), _quickRub);
      final cue = _doobal(tester).cue!;
      expect((cue.expr, cue.holdSec, cue.trigger), (1, _pet.exprSec, null), reason: 'happy = Rive expr 1, 동작 트리거 없음');
      // 마지막 쪽이 오른쪽이라 +4도에서 시작한다 (첫 프레임), 0.15초면 줄어드는 중
      expect(_tilt(tester), closeTo(_pet.tiltDeg, 1e-6));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_tilt(tester), inExclusiveRange(0, _pet.tiltDeg));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_tilt(tester), 0);
      // 정령 몸 위의 좌우 끌기는 장면을 밀지 않는다
      expect(_spiritBox(tester), before);
      await end(tester, e);
    });

    testWidgets('왼쪽으로 끝나면 −4도 쪽, 계속 문지르면 다시 (같은 표정을 새로)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _rub(tester, _body(tester), const [(-30.0, 50), (30.0, 200), (-30.0, 350)]);
      final first = _doobal(tester).cue;
      expect(first, isNotNull);
      expect(_tilt(tester), lessThan(0));
      await tester.pump(const Duration(milliseconds: 400));
      await _rub(tester, _body(tester), _quickRub);
      expect(identical(_doobal(tester).cue, first), isFalse, reason: '다시 쓰다듬으면 새 신호');
      expect(_tilt(tester), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 400));
      await end(tester, e);
    });

    testWidgets('천천히 문지르면(바뀜 사이 0.6초 넘게) 반응 없음', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _rub(tester, _body(tester), const [(30.0, 50), (-30.0, 500), (30.0, 1200)]);
      expect(_doobal(tester).cue, isNull);
      expect(_tilt(tester), 0);
      await end(tester, e);
    });

    testWidgets('움직임 줄이기면 기울지 않고 표정만', (tester) async {
      _reduceMotion(tester);
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      await _rub(tester, _body(tester), _quickRub);
      expect(_doobal(tester).cue?.expr, 1);
      for (var i = 0; i < 4; i++) {
        expect(_tilt(tester), 0);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await end(tester, e);
    });

    testWidgets('정령 상자 안이어도 몸 밖에서 시작한 끌기는 장면을 민다 (쓰다듬기 아님)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _open(tester, e);
      final box = _spiritBox(tester);
      // 몸 상자(x 200~400) 오른쪽 바깥, 600 캔버스 x 500·y 300
      final outside = box.topLeft + const Offset(500, 300) * (box.width / 600);
      expect(outside.dx, lessThan(390));
      final g = await tester.startGesture(outside);
      for (var i = 1; i <= 6; i++) {
        await g.moveBy(const Offset(-20, 0), timeStamp: Duration(milliseconds: 16 * i));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_spiritBox(tester).left, lessThan(box.left), reason: '장면이 왼쪽으로 밀렸다');
      await g.up();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_doobal(tester).cue, isNull);
      await end(tester, e);
    });
  });
}
