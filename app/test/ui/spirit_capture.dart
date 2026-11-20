import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

/// 정령 그림을 떠서 보는 시험의 도우미 (T17a, 11/21).
///
/// 정령 v11에는 스크립트 그림(ScriptedDrawable)이 있어 rive 0.15가 지연 그리기로 그린다: 상태를 바꾼 뒤 실시간이
/// 조금 흘러야 뜬 그림이 따라온다. 가짜 시간인 위젯 시험에는 그 틈이 없어 그림이 처음 모습에 멈춘다.
/// 맥 실험(11/21): 같은 0.15에서 v36은 바로 따라온다. v11은 그림을 뜰 때마다 실시간 틈(약 40ms)이 있어야 하고,
/// 정령을 만든 뒤 **그린 프레임 140장**(60Hz 약 2.3초) 동안은 처음 모습(정면 둥둥) 그대로다. 정령마다 매번,
/// 애니메이션 시간을 미리 돌려도 같다. v11 워터마크 판에 든 Rive CLI 부트업(`Watermark`·`RiveCLIBootUp`) 때문으로
/// 보인다(추정, v36·정식 판에는 없음). 앱에서 어떻게 보이는지는 폰에서 본다(docs/트랙/정령v11_T17a.md).
/// 그래서 그림을 뜨기 전에 [settleSpirit], 정령을 만든 뒤 한 번 [warmUpSpirit]을 부른다

/// 다시 그리게 하고 실시간 틈을 [times]번 준다
Future<void> settleSpirit(
  WidgetTester tester,
  Iterable<rive.RiveWidgetController> controllers, {
  int times = 2,
  int ms = 40,
}) async {
  for (var i = 0; i < times; i++) {
    for (final c in controllers) {
      c.scheduleRepaint();
    }
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  }
}

/// 뜬 그림이 상태를 따라올 때까지 기다린다: 잠들기 자세(누운 그림)로 두고, [lying]이 모든 정령에서 참일 때까지
/// 틈을 준다. [lying]은 [i]번 정령을 떠서 누운 그림인지(불투명 위 끝이 서 있을 때보다 한참 아래인지) 본다.
/// 끝나면 자세는 부른 쪽이 다시 둔다
Future<void> warmUpSpirit(
  WidgetTester tester,
  List<SpiritController> controllers,
  Future<bool> Function(int i) lying,
) async {
  for (final c in controllers) {
    c.setPose(4);
  }
  for (var n = 0; n < 150; n++) {
    for (final c in controllers) {
      c.advance(1 / 60);
    }
    await settleSpirit(tester, controllers, times: 1, ms: 30);
    var all = true;
    for (var i = 0; i < controllers.length && all; i++) {
      all = await lying(i);
    }
    if (all) return;
  }
  fail('정령 그림이 상태를 따라오지 않는다 (rive 지연 그리기 준비가 안 끝남)');
}
