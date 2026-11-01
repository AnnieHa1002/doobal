import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/bucket.dart';
import 'package:doobal/domain/focus_walk.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/rules.dart';
import 'package:doobal/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 본격 걷기를 화면에 보이는 쪽: 걷는 중 화면이 이번 걷기를 본격 걷기로 가리는 규칙과 화면 글.
// config: 걷기 1번 = 10분 이상(빈 분 2분 이하로 이어서) · 1,000보 이상, 여행 거리 1.3배·럭 2배

// 한국 시간 2026-11-18 10:00 = UTC 01:00
final _t10 = DateTime.utc(2026, 11, 18, 1);
DateTime _at(int minutes, [int seconds = 0]) =>
    _t10.add(Duration(minutes: minutes, seconds: seconds));

/// config.json을 [edit]로 고친 규칙
Rules _rulesWith(void Function(Map<String, dynamic> config) edit) {
  final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
  edit(j);
  return Rules.fromJson(j);
}

/// 10:00부터 분마다 [steps]보인 걷기/뛰기 분 (걸음 0은 빈 분)
List<GaitMinute> _live(List<int> steps) => classifyGait(minutesFrom(_at(0), steps), rules);

/// 저장된 걷기 구간 [startMin, endMin) (10:00 기준 분)
WalkSession _saved(int startMin, int endMin, {bool qualified = true}) => WalkSession(
      start: _at(startMin),
      end: _at(endMin),
      steps: 1000,
      distanceM: 700,
      runRatio: 0,
      qualified: qualified,
      counted: qualified,
    );

bool _focused({
  DateTime? start,
  List<WalkSession> saved = const [],
  List<GaitMinute> live = const [],
}) =>
    isFocusedWalk(start: start ?? _at(0), saved: saved, live: live, rules: rules);

void main() {
  group('배수 글', () {
    test('formatMultiplier: 끝의 0은 뗀다', () {
      expect(formatMultiplier(1.3), '1.3');
      expect(formatMultiplier(2.0), '2');
      expect(formatMultiplier(1.25), '1.25');
      expect(formatMultiplier(1.0), '1');
      expect(formatMultiplier(10.0), '10');
      expect(formatMultiplier(0.5), '0.5');
    });

    test('딱지·알림 글은 config 배수 그대로 (config 1.3 → ×1.3)', () {
      expect(focusBadgeText(rules), '×1.3');
      expect(focusBadgeText(_rulesWith((j) => (j['bonus'] as Map)['travelMultiplier'] = 1.25)),
          '×1.25');
      expect(focusBadgeText(_rulesWith((j) => (j['bonus'] as Map)['travelMultiplier'] = 2)), '×2');
    });

    test('토스트: 럭 단가가 없으면(config 지금 값) 여행 거리 이야기만', () {
      expect(rules.coinsPerKm, isNull);
      expect(focusToastText(rules), '본격 걷기! 여행 거리 1.3배');
    });

    test('토스트: 럭 단가가 있으면 · 럭 2배(config coinMultiplier)가 붙는다', () {
      final r = _rulesWith((j) => (j['coins'] as Map)['perKm'] = 10);
      expect(focusToastText(r), '본격 걷기! 여행 거리 1.3배 · 럭 2배');
      final r2 = _rulesWith((j) {
        (j['coins'] as Map)['perKm'] = 10;
        (j['bonus'] as Map)['coinMultiplier'] = 2.5;
      });
      expect(focusToastText(r2), '본격 걷기! 여행 거리 1.3배 · 럭 2.5배');
    });

    test('앱 종료 뒤 토스트: 걸음이 있으면 더했다고, 없으면 멈췄다는 말만', () {
      expect(orphanWalkToast(1234), '걷기가 멈췄어요 · 그동안 1,234보는 평소 걸음으로 더했어요');
      expect(orphanWalkToast(7), '걷기가 멈췄어요 · 그동안 7보는 평소 걸음으로 더했어요');
      expect(orphanWalkToast(0), '걷기가 멈췄어요');
      expect(orphanWalkToast(-5), '걷기가 멈췄어요');
    });
  });

  group('isFocusedWalk: 센서 분만으로', () {
    test('10분 × 100보 = 1,000보 → 걷기 1번 (경계값)', () {
      expect(_focused(live: _live(List.filled(10, 100))), isTrue);
    });

    test('10분 × 99보 = 990보 → 아직', () {
      expect(_focused(live: _live(List.filled(10, 99))), isFalse);
    });

    test('9분 × 150보(1,350보, 길이 9분) → 아직', () {
      expect(_focused(live: _live(List.filled(9, 150))), isFalse);
    });

    test('아무것도 없으면 아니다', () {
      expect(_focused(), isFalse);
      expect(_focused(live: _live(const [0, 0, 0])), isFalse);
    });

    test('빈 분이 2분(config maxGapMin)이면 이어진 구간: 5×200, 빈 2, 3×100 = 10분 · 1,300보', () {
      final live = _live([200, 200, 200, 200, 200, 0, 0, 100, 100, 100]);
      expect(_focused(live: live), isTrue);
    });

    test('빈 분이 3분이면 두 구간으로 갈라져 각각 5분이라 아니다 (걸음은 합쳐 2,000보여도)', () {
      final live = _live([200, 200, 200, 200, 200, 0, 0, 0, 200, 200, 200, 200, 200]);
      expect(_focused(live: live), isFalse);
    });

    test('한 분 안에서 걷기/뛰기가 바뀌어 같은 분이 두 번 나와도 더해서 센다 (50+50 × 10분)', () {
      final live = [
        for (var i = 0; i < 10; i++) ...[
          GaitMinute(epochMinute(_at(0)) + i, 50, Gait.walk),
          GaitMinute(epochMinute(_at(0)) + i, 50, Gait.run),
        ],
      ];
      expect(_focused(live: live), isTrue);
    });
  });

  group('isFocusedWalk: 저장된 걷기 구간', () {
    test('인정된 구간이 창 안에 있으면 true (센서가 비어 있어도)', () {
      expect(_focused(saved: [_saved(0, 12)]), isTrue);
    });

    test('인정 못 한 구간은 아니다', () {
      expect(_focused(saved: [_saved(0, 9, qualified: false)]), isFalse);
    });

    test('창이 열리기 전에 걷던 구간이 이어져 창 안으로 들어오면 true (인정은 구간 전체로 가린다)', () {
      // 09:50~10:12 한 구간, 창은 10:00에 열었다
      expect(_focused(start: _at(0), saved: [_saved(-10, 12)]), isTrue);
    });

    test('창이 열리기 전에 끝난 구간은 아니다 (마지막 분 09:59 < 10:00)', () {
      expect(_focused(start: _at(0), saved: [_saved(-12, 0)]), isFalse);
    });

    test('마지막 분이 창 시작 분과 같으면 true: 구간 끝 10:01, 창 10:00:00', () {
      expect(_focused(start: _at(0), saved: [_saved(-12, 1)]), isTrue);
    });

    test('마지막 분 시작(10:00:00)이 창 시작(10:00:30)보다 앞이면 그 분은 창 밖이라 아니다', () {
      expect(_focused(start: _at(0, 30), saved: [_saved(-12, 1)]), isFalse);
      // 한 분 뒤까지 이어졌다면 10:01:00 분이 창 안이다
      expect(_focused(start: _at(0, 30), saved: [_saved(-12, 2)]), isTrue);
    });

    test('저장된 구간이 인정 못 해도 센서 분이 채우면 true, 둘 다 못 채우면 false', () {
      expect(_focused(saved: [_saved(0, 5, qualified: false)], live: _live(List.filled(10, 100))),
          isTrue);
      expect(_focused(saved: [_saved(0, 5, qualified: false)], live: _live(List.filled(5, 100))),
          isFalse);
    });
  });

  group('walkCoins: 이번 걷기의 럭', () {
    final r10 = _rulesWith((j) => (j['coins'] as Map)['perKm'] = 10);

    test('럭 단가가 없으면(config 지금 값) 0', () {
      expect(walkCoins(actualM: 5000, bonusActualM: 2000, rules: rules), 0);
    });

    test('보너스 밖 실제 km + 보너스 분의 실제 km × 2, × 단가, 내림', () {
      // 보너스 없이 1,234m: 1.234 × 10 = 12.34 → 12
      expect(walkCoins(actualM: 1234, bonusActualM: 0, rules: r10), 12);
      // 2,000m 중 500m가 보너스 분: (1.5 + 0.5 × 2) × 10 = 25
      expect(walkCoins(actualM: 2000, bonusActualM: 500, rules: r10), 25);
      // 3,000m 중 1,000m: (2 + 1 × 2) × 10 = 40
      expect(walkCoins(actualM: 3000, bonusActualM: 1000, rules: r10), 40);
    });

    test('부동소수 오차로 한 개 모자라지 않는다 (2.1km × 10 = 21)', () {
      expect(walkCoins(actualM: 2100, bonusActualM: 0, rules: r10), 21);
    });
  });
}
