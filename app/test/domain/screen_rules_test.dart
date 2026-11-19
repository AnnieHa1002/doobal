import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:doobal/domain/screen_rules.dart';
import 'package:doobal/domain/spirit_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> _config() =>
    jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _rive(Map<String, dynamic> c) =>
    (c['character'] as Map<String, dynamic>)['rive'] as Map<String, dynamic>;

void main() {
  final screen = rules.screen;
  final stage = screen.spirit;

  group('걷기 동작 재생 빠르기 (config character.rive.walkPlayback, 16장 11/19 가안)', () {
    final playback = stage.walkPlayback;

    test('분당 100보 = 1배, 0.7~1.6배로 자른다', () {
      expect(playback.refStepsPerMin, 100);
      expect(playback.rateFor(100), 1);
      expect(playback.rateFor(130), closeTo(1.3, 1e-9));
      expect(playback.rateFor(80), closeTo(0.8, 1e-9));
      expect(playback.rateFor(50), 0.7);
      expect(playback.rateFor(200), 1.6);
    });

    test('걸음이 없으면(분당 0) 1배', () {
      expect(playback.rateFor(0), 1);
      expect(playback.rateFor(-5), 1);
    });

    test('0 이하 기준·뒤집힌 범위는 config를 못 읽는다', () {
      for (final edit in <void Function(Map<String, dynamic>)>[
        (p) => p['refStepsPerMin'] = 0,
        (p) => p['min'] = 0,
        (p) => p['max'] = 0.5,
      ]) {
        final c = _config();
        edit(_rive(c)['walkPlayback'] as Map<String, dynamic>);
        expect(() => ScreenRules.fromJson(c), throwsFormatException);
      }
    });
  });

  group('config ui (16장 11/13 화면 세부)', () {
    test('새 소식 점은 배낭·동행·수레(새 상품일 때만), 노트에는 없다', () {
      expect(screen.newDots, {'backpack', 'companion', 'cart'});
      expect(screen.dotOn('note'), isFalse);
      expect(screen.cartDotOnNewItem, isTrue);
    });

    test('가로 화면은 걷는 중과 그림 크게 보기 (config v30, 16장 11/19. 크게 보기 잠금은 T18)', () {
      expect(screen.landscapeScreens, {'walking', 'bigView'});
    });

    test('꾸미기 미리보기는 밀어서 정면·옆·뒤, 표정 단추 없음', () {
      expect(stage.customizeSwipe, [0, 1, 5]);
      expect(stage.customizeExprButton, isFalse);
    });

    test('모르는 점 자리·세로가 아닌 나머지 화면은 config를 못 읽는다', () {
      final a = _config();
      ((a['ui'] as Map)['newDot'] as Map)['on'] = ['backpack', 'note'];
      expect(() => ScreenRules.fromJson(a), throwsFormatException);
      final b = _config();
      ((b['ui'] as Map)['orientation'] as Map)['others'] = 'any';
      expect(() => ScreenRules.fromJson(b), throwsFormatException);
    });
  });

  group('화면별 자세 (config character.rive.screens, 정령 계약 3장)', () {
    test('자세 번호: 쉼터 떠 있기 정면·밤 잠들기, 걷는 중 옆 이동·멈춤 둥둥 옆, 도착·꾸미기·만들기·나의 정보 정면, 뒤는 5', () {
      expect(stage.poseOf('rest'), 0);
      expect(stage.poseOf('restNight'), 4);
      expect(stage.poseOf('walking'), 6);
      expect(stage.poseOf('walkingIdle'), 1);
      for (final s in ['arrival', 'customize', 'maker', 'profile']) {
        expect(stage.poseOf(s), 0, reason: s);
      }
      for (final s in ['departMoment', 'splash', 'viewScenery', 'story']) {
        expect(stage.poseOf(s), 5, reason: s);
      }
      expect(() => stage.poseOf('nowhere'), throwsArgumentError);
    });

    test('옆모습은 왼쪽을 봐서 걷는 중(이동·멈춤)만 좌우로 뒤집는다', () {
      expect(stage.sideFacesLeft, isTrue);
      expect(stage.flips('walking'), isTrue);
      expect(stage.flips('walkingIdle'), isTrue);
      for (final s in ['rest', 'arrival', 'customize', 'maker']) {
        expect(stage.flips(s), isFalse, reason: s);
      }
    });

    test('riv 옆모습이 오른쪽을 보면 뒤집지 않는다', () {
      final c = _config();
      _rive(c)['sideFacesLeft'] = false;
      expect(ScreenRules.fromJson(c).spirit.flips('walking'), isFalse);
    });

    test('모르는 자세 이름은 config를 못 읽는다', () {
      final a = _config();
      (_rive(a)['screens'] as Map)['rest'] = 'dance';
      expect(() => ScreenRules.fromJson(a), throwsFormatException);
      final b = _config();
      (_rive(b)['restSwap'] as Map)['poses'] = ['floatFront', 'hop'];
      expect(() => ScreenRules.fromJson(b), throwsFormatException);
      final c = _config();
      (_rive(c)['customizePreview'] as Map)['swipe'] = <String>[];
      expect(() => ScreenRules.fromJson(c), throwsFormatException);
    });
  });

  group('쉼터 자세 바꾸기 (config restSwap, 16장 11/11)', () {
    final swap = stage.restSwap;

    test('config: 떠 있기 정면·앉기 정면(v30 쉼터 정령 정면만, 16장 11/19), 20~40초, 같은 자세 연속 없음, 밤 잠들기', () {
      expect(swap.poses, [0, 2]);
      expect((swap.minSec, swap.maxSec, swap.noRepeat, swap.night), (20, 40, true, 4));
    });

    test('다음 자세는 지금과 다르고, 나머지가 모두 나온다', () {
      final random = Random(7);
      for (final now in swap.poses) {
        final seen = <int>{};
        for (var i = 0; i < 200; i++) {
          final next = nextRestPose(swap, now, random);
          expect(next, isNot(now));
          expect(swap.poses, contains(next));
          seen.add(next);
        }
        expect(seen, swap.poses.toSet().difference({now}));
      }
    });

    test('처음(지금 자세 없음)에는 아무거나, noRepeat가 꺼지면 같은 자세도 나온다', () {
      final random = Random(3);
      expect({for (var i = 0; i < 200; i++) nextRestPose(swap, null, random)}, swap.poses.toSet());
      const loose = RestSwapRules(poses: [0, 2], minSec: 20, maxSec: 40, noRepeat: false, night: 4);
      expect({for (var i = 0; i < 200; i++) nextRestPose(loose, 0, random)}, {0, 2});
      const single = RestSwapRules(poses: [2], minSec: 20, maxSec: 40, noRepeat: true, night: 4);
      expect(nextRestPose(single, 2, random), 2);
    });

    test('간격은 20~40초 사이', () {
      final random = Random(11);
      final gaps = [for (var i = 0; i < 500; i++) nextRestGap(swap, random)];
      for (final g in gaps) {
        expect(g.inMilliseconds, inInclusiveRange(20000, 40000));
      }
      // 고르게 퍼진다 (한쪽에 몰리지 않음)
      expect(gaps.any((g) => g < const Duration(seconds: 25)), isTrue);
      expect(gaps.any((g) => g > const Duration(seconds: 35)), isTrue);
    });

    test('간격이 거꾸로면 config를 못 읽는다', () {
      final c = _config();
      (_rive(c)['restSwap'] as Map)['minSec'] = 50;
      expect(() => ScreenRules.fromJson(c), throwsFormatException);
    });
  });

  group('표정 호출 표 (palette.json customPartsV33, 정령 계약 4장)', () {
    final palette = SpiritPalette.fromJson(
        jsonDecode(File('assets/data/palette.json').readAsStringSync()) as Map<String, dynamic>);
    final cues = palette.cues;

    test('도착·그림 받기·누르기는 행복 1초, 만남·새 소품·권역 완성은 놀람 2초', () {
      for (final e in ['arrival', 'paintingGet', 'tap']) {
        expect((cues.of(e)!.expr, cues.of(e)!.holdSec), (1, 1), reason: e);
      }
      for (final e in ['companionMeet', 'newProp', 'regionComplete']) {
        expect((cues.of(e)!.expr, cues.of(e)!.holdSec), (2, 2), reason: e);
      }
    });

    test('밤 쉼터·잠들기는 졸림(계속), 연타는 화남 2초, 감동·오래 쉬다 돌아옴은 울먹임 3초', () {
      expect((cues.of('nightRest')!.expr, cues.of('nightRest')!.holdSec), (4, null));
      expect(cues.of('sleep')!.expr, 4);
      expect((cues.of('rapidTap')!.expr, cues.of('rapidTap')!.holdSec), (5, 2));
      expect((cues.of('storyMoving')!.expr, cues.of('storyMoving')!.holdSec), (3, 3));
      expect(cues.of('returnAfterLongRest')!.expr, 3);
      expect(cues.of('fall'), isNull);
    });

    test('트리거를 붙여도 표정·시간은 그대로', () {
      final c = cues.of('arrival')!.withTrigger('joy');
      expect((c.expr, c.holdSec, c.trigger), (1, 1, 'joy'));
    });

    test('같은 일이 두 표정에 있으면 못 읽는다', () {
      expect(
        () => SpiritCues.fromJson({
          'expressions': [
            {'id': 'happy', 'rive': 1},
            {'id': 'surprised', 'rive': 2},
          ],
          'expressionTriggers': {
            'happy': ['arrival'],
            'surprised': ['arrival'],
          },
        }),
        throwsFormatException,
      );
    });
  });
}
