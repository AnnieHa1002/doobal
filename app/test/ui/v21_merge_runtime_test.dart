
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/domain/unified_wardrobe.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:doobal/ui/scene/spirit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

Future<(rive.File, SpiritController)> load() async {
  await rive.RiveNative.init();
  final f = (await rive.File.asset(
    SpiritCharacter.asset,
    riveFactory: rive.Factory.flutter,
  ))!;
  return (f, SpiritController(f));
}

void tick(SpiritController c, int n) {
  for (var i = 0; i < n; i++) {
    c.advance(1 / 60);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('v21 파츠 번호 변환과 코 없음, 저장 모델은 기존 번호 그대로', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    for (var eye = 0; eye < 6; eye++) {
      for (var nose = 0; nose < 8; nose++) {
        c.wear(SpiritLook(eye: eye, nose: nose));
        tick(c, 1);
        expect(c.instance.number('eye')!.value, eye + 1);
        expect(c.instance.number('nose')!.value, nose == 7 ? 0 : nose + 1);
      }
    }
  });
  test('v21 뒷모습·이동을 실제 자세로 연결하고 37소품과 색 유지', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    for (final p in unifiedProps) {
      final l = Look.initial.withSlot(p.slot, p.id);
      c.wear(spiritLookOf(l));
      for (final pose in [0, 1, 2, 3, 4, 5, 6]) {
        c.instance.number('poseChoice')!.value = pose.toDouble();
        tick(c, 1);
        expect(c.instance.number('${p.slot}Choice')!.value, p.choice);
        // 소품 색은 직접 고르지 않아서 Rive에 넣는 기본색 그대로 (16장 11/4)
        expect(c.instance.color(p.colorField)!.value.toARGB32(), p.argb);
      }
    }
    c.play(SpiritMotion.idle, direction: 2);
    expect(c.poseChoice, 5);
    c.setScene(speed: 1, sitting: false);
    expect(c.poseChoice, 6);
    c.play(SpiritMotion.wave);
    tick(c, 160);
    expect(c.poseChoice, 6);
  });
  test('시선은 정면·옆·앉기·이동과 반응에 유지, 잠들기에는 적용 안 함', () async {
    final (f, c) = await load();
    addTearDown(() {
      c.dispose();
      f.dispose();
    });
    c.wear(
      spiritLookOf(
        Look.initial.copyWith(
          eyes: 'mischievous',
          brows: 'none',
          nose: 'none',
          mouth: 'fangs',
        ),
      ),
    );
    c.setLook(1, -1);
    tick(c, 1);
    for (final n in [
      'Gaze_Front_2',
      'Gaze_Side_2',
      'Gaze_Move_2',
      'Gaze_Joy_2',
      'Gaze_Angry_2',
    ]) {
      final g = c.artboard.component(n)!;
      expect(g.x, 3);
      expect(g.y, -2);
      g.dispose();
    }
    for (final t in ['greet', 'joy', 'tapHead', 'tapBelly', 'angry']) {
      c.instance.trigger(t)!.trigger();
      tick(c, 180);
      expect(
        [
          for (final n in ['eye', 'brow', 'nose', 'mouth'])
            c.instance.number(n)!.value,
        ],
        [3, 0, 0, 3],
      );
    }
    c.play(SpiritMotion.sleep);
    tick(c, 60);
    c.play(SpiritMotion.idle);
    tick(c, 10);
    expect(c.instance.number('eye')!.value, 3);
    expect(c.instance.number('lookX')!.value, 1);
  });
}
