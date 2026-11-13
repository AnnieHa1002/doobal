
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
  // 시선(Gaze_* 층)은 v21 통합본에만 있었다. v33(16장 11/13)에는 없어서 그 시험은 뺐다
  // (setLook이 아무것도 하지 않는 것은 face_gaze_runtime_test가 본다)
}
