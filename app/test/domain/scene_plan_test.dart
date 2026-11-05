import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/scene_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plan = ScenePlan.fromJson(
    jsonDecode(File('assets/data/scene.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final assets = (jsonDecode(File('assets/data/scene_art.json').readAsStringSync()) as Map)['assets'] as Map;
  final files = {for (final v in assets.values) ((v as Map)['file'] as String).split('/').last};

  group('데이터', () {
    test('실제 scene.json v5의 값', () {
      expect(plan.cycle, 12288);
      expect(plan.grove.speed, 0.1);
      expect(plan.front.speed, 0.3);
      expect(plan.back.speed, 0.2);
      expect(plan.front.feetY, 2081);
      expect(plan.back.feetY, 1780);
      expect(plan.back.haze, 0.25);
      expect(plan.tallClearX, 140);
      expect(plan.tallNearOpacity, 0.35);
      expect(plan.grovePieces.length, 9);
      expect(plan.roadsidePieces.length, 14);
    });

    test('모든 조각에 그림이 있다', () {
      for (final p in [...plan.grovePieces, ...plan.roadsidePieces]) {
        expect(files.contains(p.file), isTrue, reason: p.file);
      }
    });

    test('사람 실루엣은 없다 (11/4)', () {
      expect(plan.roadsidePieces.where((p) => p.id.contains('people')), isEmpty);
    });
  });

  group('고르기', () {
    test('군락은 지역 태그와 겹치는 것만', () {
      final ids = {for (final p in plan.eligible(SceneRow.grove, 'jeju', 'summer')) p.id};
      expect(ids, containsAll(['bg_cluster_hill_a', 'L2_mountain_shoulder_left', 'L2_jeju_basalt_patch']));
      expect(ids, isNot(contains('bg_cluster_city_a')));
      expect(ids, isNot(contains('L2_river_shore_patch')));
    });

    test('바다 지역은 군락이 없다', () {
      expect(plan.eligible(SceneRow.grove, 'sea', 'summer'), isEmpty);
    });

    test('길가는 공용 + 태그 겹침, 그 계절에 있는 것만', () {
      final ids = {for (final p in plan.eligible(SceneRow.front, 'capital', 'spring')) p.id};
      expect(ids, contains('bg_object_utility_pole_a'));
      expect(ids, contains('L3_spring_cherry'));
      expect(ids, isNot(contains('L3_autumn_maple')));
      final mountain = {for (final p in plan.eligible(SceneRow.front, 'gangwon', 'spring')) p.id};
      expect(mountain, isNot(contains('bg_object_utility_pole_a')));
    });

    test('겨울 길가는 소나무·활엽수·전봇대·덤불뿐', () {
      final ids = {for (final p in plan.eligible(SceneRow.front, 'capital', 'winter')) p.id};
      expect(ids, {
        'bg_object_utility_pole_a',
        'bg_object_bush_a',
        'bg_object_bush_b',
        'L3_common_broadleaf',
        'L3_common_pine_cluster',
      });
    });

    test('뒷줄은 큰 조각만, 전봇대(앞줄 전용)는 빠진다', () {
      final pool = plan.eligible(SceneRow.back, 'capital', 'summer');
      expect(pool, isNotEmpty);
      expect(pool.every((p) => p.big), isTrue);
      expect(pool.where((p) => p.id == 'bg_object_utility_pole_a'), isEmpty);
    });
  });

  group('시드 배치', () {
    List<PlacedPiece> at(SceneRow row, {String seed = 'kr001', int cycle = 0}) =>
        plan.place(row, seed: seed, region: 'capital', season: 'spring', cycleIndex: cycle);

    test('같은 시드·주기면 같은 그림, 칸 수는 layout대로', () {
      for (final row in SceneRow.values) {
        final a = at(row);
        final b = at(row);
        expect(a.length, plan.spec(row).slots, reason: row.name);
        for (var i = 0; i < a.length; i++) {
          expect(a[i].piece.id, b[i].piece.id);
          expect(a[i].x, b[i].x);
          expect(a[i].height, b[i].height);
        }
      }
    });

    test('다른 시드나 다른 주기면 배열이 달라진다', () {
      String ids(List<PlacedPiece> l) => l.map((p) => '${p.piece.id}@${p.x}').join(',');
      expect(ids(at(SceneRow.front)), isNot(ids(at(SceneRow.front, seed: 'kr002'))));
      expect(ids(at(SceneRow.front)), isNot(ids(at(SceneRow.front, cycle: 1))));
    });

    test('자리는 그 주기 안, 왼쪽에서 오른쪽 순서', () {
      for (final row in SceneRow.values) {
        for (final cycle in [0, 1, 7]) {
          final l = at(row, cycle: cycle);
          for (var i = 0; i < l.length; i++) {
            expect(l[i].x, greaterThanOrEqualTo(cycle * plan.cycle));
            expect(l[i].x, lessThan((cycle + 1) * plan.cycle));
            if (i > 0) expect(l[i].x, greaterThan(l[i - 1].x));
          }
        }
      }
    });

    test('군락 사이는 gapMinPx(2500) 이상', () {
      for (var seed = 0; seed < 30; seed++) {
        final l = at(SceneRow.grove, seed: 's$seed');
        for (var i = 1; i < l.length; i++) {
          expect(l[i].x - l[i - 1].x, greaterThanOrEqualTo(2500));
        }
      }
    });

    test('같은 조각이 잇달아 서지 않는다', () {
      for (var seed = 0; seed < 30; seed++) {
        final l = at(SceneRow.front, seed: 's$seed');
        for (var i = 1; i < l.length; i++) {
          expect(identical(l[i].piece, l[i - 1].piece), isFalse, reason: 's$seed');
        }
      }
    });

    test('높이: 큰 조각 900~1100, 작은 조각 380~480, 뒷줄은 앞줄의 0.4~0.5배', () {
      for (var seed = 0; seed < 30; seed++) {
        for (final p in at(SceneRow.front, seed: 's$seed')) {
          if (p.piece.big) {
            expect(p.height, inInclusiveRange(900, 1100), reason: p.piece.id);
          } else {
            expect(p.height, inInclusiveRange(380, 480), reason: p.piece.id);
          }
        }
        for (final p in at(SceneRow.back, seed: 's$seed')) {
          expect(p.height, inInclusiveRange(900 * 0.4, 1100 * 0.5), reason: p.piece.id);
        }
      }
    });
  });

  group('키 큰 조각 흐리기', () {
    double op(double left, double right) => ScenePlan.tallOpacity(
          left: left,
          right: right,
          center: 585,
          clear: 140,
          near: 0.35,
          fade: 80,
        );

    test('정령 상자(445~725)에 걸치면 0.35', () {
      expect(op(600, 700), 0.35);
      expect(op(100, 445), 0.35);
      expect(op(725, 900), 0.35);
    });

    test('멀리 있으면 1, 사이는 부드럽게', () {
      expect(op(900, 1000), 1);
      expect(op(100, 300), 1);
      expect(op(765, 900), closeTo(0.35 + 0.65 * 0.5, 1e-9));
      expect(op(100, 405), closeTo(0.35 + 0.65 * 0.5, 1e-9));
    });
  });
}
