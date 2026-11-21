import 'dart:math';

import 'package:doobal/domain/companion.dart' show RestLine;
import 'package:doobal/domain/decor_place.dart';
import 'package:doobal/domain/finale_roam.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 완결 동행 쉼터 돌아다니기 (T15, 16장 11/18 ④·11/19 ②, config companions.finaleRoam 가안)

final _stage = DecorStage.of(campTheme, rules.decor.place, screenHeightPx: rules.screenHeightPx)!;
final _rules = rules.decor.finaleRoam!;

FinaleRoamer _roamer(int seed) => FinaleRoamer(rules: _rules, stage: _stage, w: 69, h: 90, random: Random(seed));

void main() {
  test('처음엔 땅 띠 안 빈 자리에 서서 4~10초 멈춤', () {
    for (var seed = 0; seed < 20; seed++) {
      final r = _roamer(seed);
      final s = r.start();
      expect(_stage.inBand(s.at), isTrue);
      expect(_stage.blockedBy(r.boxAt(s.at)), isNull, reason: '정령·모닥불·수레 상자에 서지 않는다');
      expect(s.pose, RoamPose.stand);
      expect(s.leftSec, inInclusiveRange(4, 10));
    }
  });

  test('멈춤이 끝나면 새 곳으로 초당 12pt로 걷고, 닿으면 서거나 앉아 4~10초', () {
    final r = _roamer(3);
    var s = r.start();
    s = r.step(s, s.leftSec + 0.01);
    expect(s.pose, RoamPose.walk);
    expect(_stage.blockedBy(r.boxAt(s.target)), isNull);
    final from = s.at;
    s = r.step(s, 0.5);
    final moved = sqrt(pow(s.at.x - from.x, 2) + pow(s.at.y - from.y, 2));
    expect(moved, closeTo(6, 1e-9));
    expect(s.facingLeft, s.target.x < from.x);
    // 끝까지 걷는다
    for (var i = 0; i < 2000 && s.pose == RoamPose.walk; i++) {
      s = r.step(s, 0.1);
    }
    expect([RoamPose.stand, RoamPose.sit], contains(s.pose));
    expect(s.at, s.target);
    expect(s.leftSec, inInclusiveRange(4, 10));
  });

  test('오래 돌아다녀도 늘 띠 안, 멈출 때 앉는 비율은 약 30% (sitChance)', () {
    final r = _roamer(11);
    var s = r.start();
    var stops = 0, sits = 0;
    var was = s.pose;
    for (var i = 0; i < 200000; i++) {
      s = r.step(s, 0.05);
      expect(_stage.inBand(s.at), isTrue);
      if (was == RoamPose.walk && s.pose != RoamPose.walk) {
        stops++;
        if (s.pose == RoamPose.sit) sits++;
      }
      was = s.pose;
    }
    expect(stops, greaterThan(150));
    expect(sits / stops, closeTo(0.3, 0.1));
  });

  test('말풍선 한마디: 3줄 중 무작위, 바로 앞 줄은 다시 안 고름 (noRepeat), 줄이 없으면 null', () {
    const lines = [RestLine('a'), RestLine('b'), RestLine('c')];
    final random = Random(1);
    int? last;
    final seen = <int>{};
    for (var i = 0; i < 200; i++) {
      final next = pickRestLine(lines, last, random, noRepeat: true)!;
      expect(next, isNot(last));
      seen.add(next);
      last = next;
    }
    expect(seen, {0, 1, 2});
    expect(pickRestLine(const [], null, random, noRepeat: true), isNull);
    expect(pickRestLine(const [RestLine('a')], 0, random, noRepeat: true), 0);
    // noRepeat가 아니면 같은 줄이 다시 나올 수 있다
    var repeats = 0;
    last = null;
    for (var i = 0; i < 200; i++) {
      final next = pickRestLine(lines, last, random, noRepeat: false)!;
      if (next == last) repeats++;
      last = next;
    }
    expect(repeats, greaterThan(0));
  });
}
