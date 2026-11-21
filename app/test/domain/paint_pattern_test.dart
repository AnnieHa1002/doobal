import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/day_card.dart';
import 'package:doobal/domain/paint_color.dart';
import 'package:doobal/domain/paint_pattern_rules.dart';
import 'package:doobal/domain/paint_trail.dart';
import 'package:doobal/domain/trail_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// T17b 물감 길 무늬의 규칙 값(config paintPattern·mapTrail.patterns), 거리 보상 판정, 토스트 글, 구간 무늬 찾기

Map<String, dynamic> _config() =>
    jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('config paintPattern·mapTrail.patterns', () {
    test('config 값을 읽는다 (16장 11/20 ②: 밤 #D9E4EF 1.2pt, 36pt 미만 끝 1개·여백 18pt, 64px 묶음, 바뀜 8pt)', () {
      final p = rules.paintPattern;
      expect(p.defaultId, 'drops');
      expect((p.whileWalking, p.autoSelectOnGain, p.ownedOnly, p.emptyRowDefaultOnly), (true, false, true, true));
      expect(p.states, ['pressed', 'inUse']);
      expect(p.allOwnedCoins, 100);
      expect(p.walkingScreen, isFalse);
      expect((p.nightOutlineColor, p.nightOutlinePt), (0xFFD9E4EF, 1.2));
      expect((p.shortUnderPt, p.shortCaps, p.shortGapPt), (36, 1, 18));
      expect(p.curveChunkPx, 64);
      expect((p.switchCaps, p.switchGapPt), (1, 8));
    });

    test('모르는 값이면 멈춘다', () {
      void bad(void Function(Map<String, dynamic> j) edit) {
        final j = _config();
        edit(j);
        expect(() => PaintPatternRules.fromJson(j), throwsFormatException);
      }

      Map<String, dynamic> pp(Map<String, dynamic> j) => j['paintPattern'] as Map<String, dynamic>;
      Map<String, dynamic> mp(Map<String, dynamic> j) =>
          (j['mapTrail'] as Map<String, dynamic>)['patterns'] as Map<String, dynamic>;
      bad((j) => pp(j)['segmentKey'] = 'pattern');
      bad((j) => (pp(j)['choose'] as Map)['appliesFrom'] = 'nextSegment');
      bad((j) => (pp(j)['choose'] as Map)['emptyRow'] = 'examples');
      bad((j) => (pp(j)['choose'] as Map)['states'] = ['pressed', 'locked']);
      bad((j) => (pp(j)['reward'] as Map)['give'] = 'random');
      bad((j) => (pp(j)['reward'] as Map)['allOwnedCoinsCountsTowardDailyCap'] = true);
      bad((j) => pp(j)['missingArt'] = 'hide');
      bad((j) => (mp(j)['night'] as Map)['when'] = 'always');
      bad((j) => (mp(j)['shortSegment'] as Map)['caps'] = 2);
      bad((j) => (mp(j)['curve'] as Map)['rotate'] = 'perTile');
    });
  });

  group('거리 보상 판정 (planPatternRewards)', () {
    List<PatternReward> plan(double km, {Set<String> owned = const {}, Set<int> given = const {}}) =>
        planPatternRewards(
          catalog: trailCatalog,
          trailKm: km,
          owned: owned,
          givenKms: given,
          allOwnedCoins: rules.paintPattern.allOwnedCoins,
        );

    test('문턱은 trails.json unlock.km 10·50·100', () {
      expect(trailCatalog.rewardKms, [10, 50, 100]);
      expect(trailCatalog.rewardPatterns.map((p) => p.id), ['trail_01', 'trail_02', 'trail_03']);
    });

    test('10km에 닿으면 첫 무늬(발자국), 9.99km는 아직', () {
      expect(plan(9.99), isEmpty);
      expect(plan(10), [const PatternReward.pattern(10, 'trail_01')]);
      // 부동소수 오차로 10km 바로 아래로 모인 값도 닿은 것
      expect(plan(10 - 1e-12), [const PatternReward.pattern(10, 'trail_01')]);
    });

    test('이미 산 무늬는 건너뛰고 아직 없는 무늬 중 표 차례로 첫 번째', () {
      expect(plan(10, owned: {'trail_01'}), [const PatternReward.pattern(10, 'trail_02')]);
      expect(plan(50, owned: {'trail_01', 'trail_03'}, given: {10}), [const PatternReward.pattern(50, 'trail_02')]);
    });

    test('셋 다 가졌으면 그 문턱은 100 럭', () {
      expect(plan(10, owned: {'trail_01', 'trail_02', 'trail_03'}), [const PatternReward.coins(10, 100)]);
    });

    test('이미 준 문턱은 다시 주지 않고, 여러 문턱을 한꺼번에 넘으면 낮은 것부터', () {
      expect(plan(120), [
        const PatternReward.pattern(10, 'trail_01'),
        const PatternReward.pattern(50, 'trail_02'),
        const PatternReward.pattern(100, 'trail_03'),
      ]);
      expect(plan(120, owned: {'trail_01', 'trail_02'}, given: {10, 50}), [const PatternReward.pattern(100, 'trail_03')]);
      expect(plan(120, owned: {'trail_01', 'trail_02', 'trail_03'}, given: {10, 50, 100}), isEmpty);
      // 상점에서 둘 산 뒤 60km: 10 → 남은 하나, 50 → 럭
      expect(plan(60, owned: {'trail_02', 'trail_03'}), [
        const PatternReward.pattern(10, 'trail_01'),
        const PatternReward.coins(50, 100),
      ]);
    });

    test('셋 다 가졌을 때 럭이 0이면 아무것도 없다', () {
      expect(
        planPatternRewards(
          catalog: trailCatalog,
          trailKm: 100,
          owned: {'trail_01', 'trail_02', 'trail_03'},
          givenKms: const {},
          allOwnedCoins: 0,
        ),
        isEmpty,
      );
    });

    test('토스트 한 줄: 무늬면 소품과 같은 꼴, 럭만이면 물감 길 거리와 럭', () {
      String toast(List<PatternReward> r) => patternRewardToast(trailCatalog, r, rules.coinAmountFormat);
      expect(toast([const PatternReward.pattern(10, 'trail_01')]), '새 무늬를 얻었어요 · 발자국');
      expect(
        toast([const PatternReward.pattern(10, 'trail_01'), const PatternReward.pattern(50, 'trail_02')]),
        '새 무늬를 얻었어요 · 발자국 외 1개',
      );
      expect(toast([const PatternReward.coins(100, 100)]), '물감 길 100km · +100 럭');
      expect(patternCoinsRef(100), 'trailPattern:100');
    });
  });

  group('구간 무늬 찾기', () {
    final trails = [
      const TrailPaint(startMs: 0, endMs: 100, segments: [
        PaintSegment(0, 'basic'),
        PaintSegment(40, 'basic', 'trail_01'),
        PaintSegment(70, 'sunset', 'trail_01'),
      ]),
      const TrailPaint(startMs: 200, segments: [PaintSegment(210, 'basic', 'trail_02')]),
    ];

    test('그 시각 구간의 무늬, 물감 길 밖·기본은 null, 첫 구간 앞은 첫 구간', () {
      expect(paintedPatternAt(trails, 10), isNull);
      expect(paintedPatternAt(trails, 40), 'trail_01');
      expect(paintedPatternAt(trails, 80), 'trail_01');
      expect(paintedColorAt(trails, 80, 'basic'), 'sunset');
      expect(paintedPatternAt(trails, 150), isNull);
      expect(paintedColorAt(trails, 150, 'basic'), 'basic');
      expect(paintedPatternAt(trails, 205), 'trail_02');
    });

    test('trailSegments: 무늬만 바뀌어도 물감 구간이 나뉜다', () {
      final segs = trailSegments(
        fundKm: 0,
        minutes: [
          for (var m = 0; m < 4; m++) MinuteTravel(minute: m, steps: 100, actualM: 70, inTrail: true),
        ],
        paintAt: (m) => 'basic',
        patternAt: (m) => m < 2 ? null : 'trail_03',
      );
      expect(segs, const [
        TrailSegment(0, 0.14, TrailKind.paint, 'basic'),
        TrailSegment(0.14, 0.28, TrailKind.paint, 'basic', 'trail_03'),
      ]);
    });

    test('엽서 구간: 색과 무늬가 같은 분끼리 이어 붙인다', () {
      expect(
        mergePatternStrokes([
          ('basic', null, 10),
          ('basic', null, 5),
          ('basic', 'trail_01', 5),
          ('sunset', 'trail_01', 0),
          ('sunset', 'trail_01', 7),
        ]),
        const [PaintStroke('basic', 15), PaintStroke('basic', 5, 'trail_01'), PaintStroke('sunset', 7, 'trail_01')],
      );
      // 무늬 없는 옛 꼴은 그대로
      expect(mergeStrokes([('basic', 3), ('basic', 4)]), const [PaintStroke('basic', 7)]);
    });
  });
}
