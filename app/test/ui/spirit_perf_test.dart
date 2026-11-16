import 'package:doobal/domain/screen_rules.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:doobal/ui/scene/spirit_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

/// T5 정령 메모리·성능 (계약 7장): riv 한 번 읽기, 덮이거나 앱이 뒤로 가면 멈추고 돌아와 잇기

Future<void> _waitRive(WidgetTester tester, int count) async {
  for (var i = 0; i < 160 && find.byType(rive.RiveWidget).evaluate().length < count; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  expect(find.byType(rive.RiveWidget), findsNWidgets(count));
}

/// 정령 [n]개를 가로로 세운다. [factories]를 주면 정령마다 그 그리기로
Widget _row(int n, List<SpiritController> ready, {List<rive.Factory?>? factories}) => MaterialApp(
      home: Row(
        children: [
          for (var i = 0; i < n; i++)
            SizedBox(
              width: 120,
              height: 300,
              child: SpiritStanding(onReady: ready.add, riveFactory: factories?[i]),
            ),
        ],
      ),
    );

void main() {
  /// 실제로 읽은 그리기 (읽을 때마다 하나)
  late List<rive.Factory> reads;

  /// 앱이 실제로 쓰는 읽기 (riv 파일)
  late Future<rive.File?> Function(rive.Factory) real;
  setUp(() {
    SpiritFile.reset();
    reads = [];
    real = SpiritFile.read;
    SpiritFile.read = (factory) {
      reads.add(factory);
      return real(factory);
    };
  });
  tearDown(SpiritFile.reset);

  testWidgets('정령이 셋 떠도 riv는 한 번 읽고, 컨트롤러·아트보드·뷰 모델은 정령마다 따로다', (tester) async {
    final ready = <SpiritController>[];
    await tester.pumpWidget(_row(3, ready));
    await _waitRive(tester, 3);
    expect(reads, [rive.Factory.flutter]);
    expect(SpiritFile.reads, 1);
    expect(ready.length, 3);
    expect(ready.map((c) => c.file).toSet().length, 1, reason: '같은 파일 인스턴스');
    expect(ready.map((c) => c.artboard).toSet().length, 3);
    expect(ready.map((c) => c.instance).toSet().length, 3);

    // 한 정령의 자세·표정이 다른 정령에 번지지 않는다
    ready[0].setPose(4);
    ready[1].cue(const SpiritCue(2));
    await tester.pump(const Duration(milliseconds: 50));
    expect(ready.map((c) => (c.poseChoice, c.expression)), [(4, 0), (0, 2), (0, 0)]);

    // 모두 사라지면 (미리 읽은 것이 아니므로) 놓고, 다시 뜨면 다시 읽는다 (시험 사이에 파일이 남지 않음)
    await tester.pumpWidget(const SizedBox());
    expect(SpiritFile.holds(rive.Factory.flutter), isFalse);
    ready.clear();
    await tester.pumpWidget(_row(1, ready));
    await _waitRive(tester, 1);
    expect(SpiritFile.reads, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('앱 시작 때 미리 읽은 파일은 정령이 모두 사라져도 두고, 다음 정령이 다시 읽지 않는다', (tester) async {
    SpiritCharacter.preload(); // 시험은 기본 그리기가 Flutter 그리기 (flutter_test_config)
    expect(SpiritFile.holds(rive.Factory.flutter), isTrue);
    final ready = <SpiritController>[];
    await tester.pumpWidget(_row(2, ready));
    await _waitRive(tester, 2);
    expect(SpiritFile.reads, 1);

    await tester.pumpWidget(const SizedBox());
    expect(SpiritFile.holds(rive.Factory.flutter), isTrue);
    await tester.pumpWidget(_row(1, ready));
    await _waitRive(tester, 1);
    expect(SpiritFile.reads, 1);
    expect(ready.last.file, same(ready.first.file));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('그리기(Factory)가 다르면 따로 읽고 따로 놓는다 (하루 카드 공유 이미지는 Flutter 그리기)', (tester) async {
    // 시험 환경은 Rive 그리기 화면 텍스처가 없어 실제로는 Flutter 그리기로 읽고, 나눠 두는 열쇠만 Rive 그리기다
    SpiritFile.read = (factory) {
      reads.add(factory);
      return real(rive.Factory.flutter);
    };
    final ready = <SpiritController>[];
    await tester.pumpWidget(_row(3, ready, factories: [null, rive.Factory.rive, rive.Factory.rive]));
    await _waitRive(tester, 3);
    expect(reads.toSet(), {rive.Factory.flutter, rive.Factory.rive});
    expect(reads.length, 2);
    expect(ready.map((c) => c.file).toSet().length, 2);

    // Rive 그리기 정령만 사라지면 그 파일만 놓는다
    await tester.pumpWidget(_row(1, ready));
    expect(SpiritFile.holds(rive.Factory.rive), isFalse);
    expect(SpiritFile.holds(rive.Factory.flutter), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('읽기에 실패하면 정령 자리가 비고, 다음 정령이 다시 읽는다 (rive_native·파일이 없을 때 전처럼)', (tester) async {
    var fail = 2;
    SpiritFile.read = (factory) {
      reads.add(factory);
      if (fail-- == 2) throw StateError('rive_native 없음');
      if (fail == 0) return Future.value(null);
      return real(factory);
    };
    final ready = <SpiritController>[];
    // 같이 뜬 둘은 같은 실패를 받는다
    await tester.pumpWidget(_row(2, ready));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(find.byType(rive.RiveWidget), findsNothing);
    expect(find.byType(SpiritCharacter), findsNWidgets(2));
    expect(SpiritFile.holds(rive.Factory.flutter), isFalse);
    expect(reads.length, 1);

    // 다음 정령: 파일이 null이면 또 빈 칸
    await tester.pumpWidget(_row(3, ready));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    expect(find.byType(rive.RiveWidget), findsNothing);
    expect(reads.length, 2);

    // 그다음은 읽힌다
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_row(1, ready));
    await _waitRive(tester, 1);
    expect(reads.length, 3);
    expect(ready, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('다른 화면에 덮이면 advance·다시 그리기가 멈추고, 돌아오면 멈춘 자리에서 잇는다', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    late SpiritController c;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: Scaffold(body: SpiritStanding(onReady: (r) => c = r)),
    ));
    await _waitRive(tester, 1);

    // 표정 2초: 보이는 동안만 시간이 간다
    c.cue(const SpiritCue(1, holdSec: 2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.expression, 1);
    expect(c.isTickerActive, isTrue, reason: '보이는 동안은 늘 그린다 (떠 있기·깜빡임)');

    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('위 화면'))));
    // 정령이 계속 그리면 여기서 끝나지 않는다
    await tester.pumpAndSettle();
    expect(c.isTickerActive, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: '덮인 정령은 프레임을 부르지 않는다');

    // 덮인 동안 입력이 바뀌어도 그리지 않고, 시간도 가지 않는다
    c.setPose(4);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(c.expression, 1, reason: '덮인 5초는 표정 시간에 안 들어간다');

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.isTickerActive, isTrue);
    expect(c.poseChoice, 4, reason: '덮인 동안 바꾼 자세가 돌아오면 보인다');
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.expression, 1, reason: '남은 표정 시간을 잇는다');
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.expression, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('앱이 뒤로 가 있던 시간은 건너뛰지 않고, 돌아오면 멈춘 자리에서 잇는다', (tester) async {
    late SpiritController c;
    await tester.pumpWidget(MaterialApp(home: SpiritStanding(onReady: (r) => c = r)));
    await _waitRive(tester, 1);
    c.cue(const SpiritCue(1, holdSec: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(c.expression, 1);

    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    expect(tester.binding.framesEnabled, isFalse, reason: '뒤에 있는 동안은 프레임이 없다 (그리지 않음)');
    await tester.pump(const Duration(seconds: 30));
    expect(c.expression, 1);

    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(c.expression, 1, reason: '돌아온 첫 프레임이 30초를 한꺼번에 흘려보내지 않는다');
    expect(c.isTickerActive, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.expression, 1);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(c.expression, 0, reason: '남은 0.8초가 지나면 늘 두는 표정으로');

    // 실기기는 뒤에서 프레임이 없어, 돌아온 첫 프레임이 뒤에 있던 시간 전체를 들고 온다: 그 한 번을 버린다
    c.cue(const SpiritCue(2, holdSec: 1));
    c.setAway(true);
    c.setAway(false);
    c.advance(30);
    expect(c.expression, 2);
    c.advance(.5);
    expect(c.expression, 2, reason: '그다음 프레임부터는 시간이 간다');
    c.advance(.6);
    expect(c.expression, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
