import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/motion_rules.dart';
import 'package:doobal/domain/spirit_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 연출 5개 중 ②③④ (T19, 16장 11/20 Q008, config ui.motion, 디자인 기획 가안)

Map<String, dynamic> _config() =>
    jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _motion(Map<String, dynamic> j) =>
    (j['ui'] as Map<String, dynamic>)['motion'] as Map<String, dynamic>;

void main() {
  group('config ui.motion 읽기', () {
    test('지금 config: 쓰다듬기·흔들림·수레·방울 값 (가안 그대로)', () {
      final m = rules.motion;
      final pet = m.restPet!;
      expect((pet.rubFlipsWithinSec, pet.rubFlips, pet.expr, pet.exprSec, pet.tiltDeg, pet.returnSec),
          (0.6, 2, 'happy', 1.0, 4.0, 0.3));
      final w = m.decorWiggle!;
      expect(w.degs, [6.0, 3.0, 0.0]);
      expect((w.sec, w.offInEditMode), (0.4, true));
      final c = m.cartSlot!;
      expect((c.newSlotLockFadeSec, c.dropPt, c.dropSec, c.scaleFrom, c.oncePerUnlock), (0.2, 12.0, 0.25, 1.1, true));
      expect((c.boughtRisePt, c.boughtFadeSec, c.soldStampScaleFrom, c.soldStampSec), (16.0, 0.25, 1.3, 0.2));
      final d = m.dropPickup!;
      expect((d.luxCountSec, d.luxStep, d.luxBounceScale, d.tubeDelaySec), (0.3, 1, 1.15, 0.1));
    });

    test('ui.motion이 없으면 연출 없음', () {
      final j = _config();
      (j['ui'] as Map<String, dynamic>).remove('motion');
      final m = MotionRules.fromJson(j);
      expect([m.restPet, m.decorWiggle, m.cartSlot, m.dropPickup], everyElement(isNull));
    });

    test('모르는 값은 읽지 않는다', () {
      void bad(void Function(Map<String, dynamic> m) edit) {
        final j = _config();
        edit(_motion(j));
        expect(() => MotionRules.fromJson(j), throwsFormatException);
      }

      Map<String, dynamic> p(Map<String, dynamic> m, String k) => m[k] as Map<String, dynamic>;
      bad((m) => m['reducedMotion'] = 'slower');
      bad((m) => m['repeat'] = 'queue');
      bad((m) => m['sound'] = true);
      bad((m) => p(m, 'restPet')['screen'] = 'walking');
      bad((m) => p(m, 'restPet')['tapRules'] = 'rubOnly');
      bad((m) => p(m, 'restPet')['rubFlips'] = 0);
      bad((m) => p(m, 'restPet')['returnSec'] = 0);
      bad((m) => p(m, 'decorWiggle')['pivot'] = 'center');
      bad((m) => p(m, 'decorWiggle')['degs'] = <num>[]);
      bad((m) => p(m, 'cartSlot')['dropSec'] = -1);
      bad((m) => p(m, 'cartSlot')['oncePerUnlock'] = false);
      bad((m) => p(m, 'dropPickup')['plusOne'] = 'counted');
      bad((m) => p(m, 'dropPickup')['luxStep'] = 0);
    });

    test('쓰다듬기 표정 happy = Rive expr 1 (palette customPartsV33)', () {
      final palette = SpiritPalette.fromJson(
        jsonDecode(File('assets/data/palette.json').readAsStringSync()) as Map<String, dynamic>,
      );
      expect(palette.cues.exprOf(rules.motion.restPet!.expr), 1);
      expect(palette.cues.exprOf('없는 표정'), isNull);
    });
  });

  group('② 쓰다듬기 세기 (RubCounter)', () {
    final pet = rules.motion.restPet!;

    test('0.6초 안에 좌우가 두 번 바뀌면 쓰다듬기, 그때 문지르는 쪽', () {
      final r = RubCounter(pet);
      expect(r.move(30, 0.0), isNull, reason: '처음 쪽(오른쪽)만 정함');
      expect(r.side, 1);
      expect(r.move(-30, 0.2), isNull, reason: '한 번 바뀜');
      expect(r.move(30, 0.4), 1, reason: '두 번 바뀜 = 쓰다듬기, 오른쪽으로');
      // 센 것을 비우고 다시: 두 번 더 바뀌어야
      expect(r.move(-30, 0.5), isNull);
      expect(r.move(30, 0.6), 1);
      expect(r.move(-30, 0.7), isNull);
      expect(r.move(-10, 0.75), isNull, reason: '같은 쪽으로 더 끌기는 바뀜이 아님');
      expect(r.move(30, 0.8), 1);
    });

    test('천천히 문지르면(바뀜 사이 0.6초 넘게) 쓰다듬기가 아니다', () {
      final r = RubCounter(pet);
      r.move(30, 0);
      expect(r.move(-30, 0.5), isNull);
      expect(r.move(30, 1.2), isNull, reason: '두 번째 바뀜은 첫 바뀜과 0.7초 떨어짐');
      expect(r.move(-30, 1.7), -1, reason: '1.2·1.7은 0.6초 안');
    });

    test('4pt 안의 손 떨림은 바뀜으로 안 세고, 한쪽으로 쭉 끌기는 쓰다듬기가 아니다', () {
      final r = RubCounter(pet);
      r.move(20, 0);
      expect(r.move(-3, 0.05), isNull);
      expect(r.move(10, 0.1), isNull);
      expect(r.move(-3, 0.15), isNull);
      expect(r.move(10, 0.2), isNull);
      expect(r.side, 1);
      for (var i = 0; i < 20; i++) {
        expect(r.move(8, 0.25 + i * 0.01), isNull);
      }
    });

    test('손을 떼면 처음부터', () {
      final r = RubCounter(pet);
      r
        ..move(30, 0)
        ..move(-30, 0.1)
        ..reset();
      expect(r.side, 0);
      expect(r.move(30, 0.2), isNull);
      expect(r.move(-30, 0.3), isNull);
    });

    test('기울기: 바로 ±4도, 0.3초에 0으로 (끝으로 갈수록 느리게)', () {
      expect(pet.tiltAt(0, 1), 4);
      expect(pet.tiltAt(0, -1), -4);
      expect(pet.tiltAt(0.15, 1), closeTo(4 * 0.125, 1e-9));
      expect(pet.tiltAt(0.3, 1), 0);
      expect(pet.tiltAt(1, -1), 0);
    });
  });

  group('② 물품 흔들림', () {
    final w = rules.motion.decorWiggle!;

    test('0 → +6 → −3 → 0도를 0.4초에 칸마다 같은 시간', () {
      expect(w.angleAt(0), 0);
      expect(w.angleAt(0.4 / 3), closeTo(6, 1e-9));
      expect(w.angleAt(0.8 / 3), closeTo(-3, 1e-9));
      expect(w.angleAt(0.4), 0);
      expect(w.angleAt(0.5), 0);
      // 칸 가운데는 두 값 사이
      expect(w.angleAt(0.2), closeTo(1.5, 1e-9));
    });
  });

  group('③ 수레 칸', () {
    final c = rules.motion.cartSlot!;

    test('새 칸: 자물쇠 0.2초 흐려짐 → 물건이 12pt 위·1.1배에서 0.25초에 선반으로', () {
      expect(c.unlockSec, closeTo(0.45, 1e-9));
      final start = c.unlockAt(0);
      expect((start.lockOpacity, start.itemShown), (1.0, false));
      final half = c.unlockAt(0.1);
      expect(half.lockOpacity, closeTo(0.5, 1e-9));
      final drop = c.unlockAt(0.2);
      expect((drop.lockOpacity, drop.itemShown, drop.itemDy, drop.itemScale), (0.0, true, -12.0, 1.1));
      final mid = c.unlockAt(0.325);
      expect(mid.itemDy, closeTo(-12 * 0.75, 1e-9), reason: '떨어질수록 빨라짐 (u² = 0.25)');
      expect(mid.itemScale, closeTo(1.05, 1e-9));
      final end = c.unlockAt(0.45);
      expect((end.lockOpacity, end.itemShown, end.itemDy, end.itemScale), (0.0, true, 0.0, 1.0));
    });

    test('산 칸: 물건이 16pt 떠오르며 0.25초에 사라지고 → 도장이 1.3배에서 0.2초에 1배', () {
      expect(c.soldSec, closeTo(0.45, 1e-9));
      final start = c.soldAt(0);
      expect((start.itemDy, start.itemOpacity, start.stampShown), (0.0, 1.0, false));
      final up = c.soldAt(0.125);
      expect(up.itemOpacity, closeTo(0.5, 1e-9));
      expect(up.itemDy, closeTo(-16 * 0.75, 1e-9));
      final stamp = c.soldAt(0.25);
      expect((stamp.itemOpacity, stamp.stampShown, stamp.stampScale), (0.0, true, 1.3));
      expect(c.soldAt(0.35).stampScale, closeTo(1.15, 1e-9));
      final end = c.soldAt(0.45);
      expect((end.itemOpacity, end.stampShown, end.stampScale), (0.0, true, 1.0));
    });
  });

  group('④ 방울 줍기 럭 숫자', () {
    final d = rules.motion.dropPickup!;

    test('숫자는 0.3초 동안 1씩 고르게, 끝에 다 오른 값', () {
      expect(d.countAt(10, 13, 0), 10);
      expect(d.countAt(10, 13, 0.1), 11);
      expect(d.countAt(10, 13, 0.2), 12);
      expect(d.countAt(10, 13, 0.29), 12);
      expect(d.countAt(10, 13, 0.3), 13);
      expect(d.countAt(0, 1, 0.31), 1);
      expect(d.countAt(5, 5, 0.1), 5);
    });

    test('크기는 1 → 1.15 → 1 (가운데가 가장 큼)', () {
      expect(d.scaleAt(0), 1);
      expect(d.scaleAt(0.15), closeTo(1.15, 1e-9));
      expect(d.scaleAt(0.3), 1);
    });
  });
}
