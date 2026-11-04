import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/badge.dart';
import 'package:flutter_test/flutter_test.dart';

final _badges = parseBadges(
    jsonDecode(File('assets/data/badges.json').readAsStringSync()) as Map<String, dynamic>);

Badge _badge(String id) => _badges.firstWhere((b) => b.id == id);

void main() {
  test('20개를 order 순서로 읽는다', () {
    expect(_badges, hasLength(20));
    expect(_badges.first.id, 'b_first_walk');
    for (var i = 1; i < _badges.length; i++) {
      expect(_badges[i].order, greaterThan(_badges[i - 1].order));
    }
  });

  test('모르는 조건은 FormatException', () {
    expect(
        () => Badge.fromJson({
              'id': 'x',
              'name': 'x',
              'group': 'g',
              'icon': 'i',
              'order': 1,
              'cond': {'kind': 'streak'},
            }),
        throwsFormatException);
  });

  group('조건 판정 (도장 20개 전부)', () {
    final cases = <String, (BadgeFacts, BadgeFacts)>{
      'b_first_walk': (const BadgeFacts(), const BadgeFacts(sessionsCount: 1)),
      'b_walk_5km': (const BadgeFacts(bestSessionKm: 4.99), const BadgeFacts(bestSessionKm: 5)),
      'b_walk_10km': (const BadgeFacts(bestSessionKm: 9.9), const BadgeFacts(bestSessionKm: 10)),
      'b_day_10k': (const BadgeFacts(dayStepsBest: 9999), const BadgeFacts(dayStepsBest: 10000)),
      'b_day_20k': (const BadgeFacts(dayStepsBest: 19999), const BadgeFacts(dayStepsBest: 20000)),
      'b_walks_100': (const BadgeFacts(sessionsCount: 99), const BadgeFacts(sessionsCount: 100)),
      'b_dawn': (
        const BadgeFacts(walksInPhase: {'night': 3}),
        const BadgeFacts(walksInPhase: {'dawn': 1}),
      ),
      'b_sunset': (const BadgeFacts(), const BadgeFacts(walksInPhase: {'sunset': 1})),
      'b_night': (const BadgeFacts(), const BadgeFacts(walksInPhase: {'night': 1})),
      'b_mountain': (
        const BadgeFacts(terrainEvents: {'mountain': 9, 'city': 30}),
        const BadgeFacts(terrainEvents: {'mountain': 10}),
      ),
      'b_coast': (const BadgeFacts(), const BadgeFacts(terrainEvents: {'coast': 10})),
      'b_field': (const BadgeFacts(), const BadgeFacts(terrainEvents: {'field': 10})),
      'b_city': (const BadgeFacts(), const BadgeFacts(terrainEvents: {'city': 10})),
      'b_seasons': (
        const BadgeFacts(seasonsWalked: {'spring', 'summer', 'autumn'}),
        const BadgeFacts(seasonsWalked: {'spring', 'summer', 'autumn', 'winter'}),
      ),
      'b_first_arrival': (const BadgeFacts(), const BadgeFacts(arrivalCount: 1)),
      'b_first_boat': (const BadgeFacts(), const BadgeFacts(seaCrossed: true)),
      'b_first_gold': (
        const BadgeFacts(frames: {'wood', 'silver'}),
        const BadgeFacts(frames: {'gold'}),
      ),
      'b_journey_100': (
        const BadgeFacts(bestJourneyKm: 99.9),
        const BadgeFacts(bestJourneyKm: 100),
      ),
      'b_all_friends': (const BadgeFacts(companionsMet: 2), const BadgeFacts(companionsMet: 3)),
      'b_first_finale': (const BadgeFacts(), const BadgeFacts(finaleCount: 1)),
    };

    test('모든 도장에 시험이 있다', () {
      expect(cases.keys.toSet(), {for (final b in _badges) b.id});
    });

    for (final e in cases.entries) {
      test(e.key, () {
        expect(badgeMet(_badge(e.key).cond, e.value.$1), isFalse);
        expect(badgeMet(_badge(e.key).cond, e.value.$2), isTrue);
      });
    }
  });

  test('이미 받은 도장은 다시 주지 않고, 같은 기록이면 같은 결과', () {
    const f = BadgeFacts(sessionsCount: 1, arrivalCount: 1);
    expect([for (final b in newBadges(_badges, f, const {})) b.id],
        ['b_first_walk', 'b_first_arrival']);
    expect([for (final b in newBadges(_badges, f, const {'b_first_walk'})) b.id],
        ['b_first_arrival']);
    expect(newBadges(_badges, f, const {'b_first_walk', 'b_first_arrival'}), isEmpty);
  });
}
