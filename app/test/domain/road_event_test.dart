import 'dart:convert';
import 'dart:io';

import 'package:doobal/domain/road_event.dart';
import 'package:flutter_test/flutter_test.dart';

final _catalog = EventCatalog.fromJson(
    jsonDecode(File('assets/data/events.json').readAsStringSync()) as Map<String, dynamic>);

/// 아무 조건도 채우지 않는 기록
PraiseFacts _facts({
  double remainingKm = 50,
  double progressPct = 10,
  double lastProgressPct = 5,
  int etaGainDays = 0,
  double todayOverAvgKm = 0,
  double runKm = 0,
  int todaySteps = 100,
  double sessionKm = 1,
  double totalKm = 1,
  bool night = false,
}) =>
    PraiseFacts(
      dest: '두물머리',
      remainingKm: remainingKm,
      progressPct: progressPct,
      lastProgressPct: lastProgressPct,
      etaGainDays: etaGainDays,
      todayOverAvgKm: todayOverAvgKm,
      runKm: runKm,
      todaySteps: todaySteps,
      sessionKm: sessionKm,
      totalKm: totalKm,
      night: night,
    );

RoadEventPick _pick(PraiseFacts f, {int k = 1, String? lastScene, String? lastPraise}) =>
    pickRoadEvent(
      catalog: _catalog,
      installId: 'install',
      journeyId: 7,
      k: k,
      terrain: 'mountain',
      season: 'spring',
      night: false,
      facts: f,
      lastSceneTextId: lastScene,
      lastPraiseId: lastPraise,
    );

void main() {
  group('events.json', () {
    test('장면 32개(지형 4 × 계절 4 × 낮밤 2)가 모두 있고 문구가 셋씩', () {
      expect(_catalog.scenes, hasLength(32));
      for (final t in ['mountain', 'coast', 'field', 'city']) {
        for (final s in ['spring', 'summer', 'autumn', 'winter']) {
          for (final n in [false, true]) {
            expect(_catalog.scene(t, s, n).texts, hasLength(3), reason: '$t $s $n');
          }
        }
      }
    });

    test('칭찬 조건 9개는 우선순위 순서, 기본 8개', () {
      expect([for (final r in _catalog.rules) r.id],
          ['R01', 'R02', 'R03', 'R04', 'R05', 'R06', 'R07', 'R08', 'R09']);
      expect(_catalog.defaults, hasLength(8));
    });
  });

  group('칭찬 고르기', () {
    test('아무 조건도 안 맞으면 기본 묶음', () {
      expect(_catalog.defaults.keys, contains(_pick(_facts()).praiseId));
    });

    test('여럿 맞으면 우선순위가 가장 높은 것', () {
      final p = _pick(_facts(remainingKm: 8, todaySteps: 8000, totalKm: 100));
      expect(p.praiseId, 'R01');
      expect(p.praiseText, '두물머리까지 8.0km. 목적지가 보이는 것 같아.');
    });

    test('진행률은 그 칸에서 기준을 넘을 때만, 글에는 넘은 기준이 들어간다', () {
      final p = _pick(_facts(lastProgressPct: 48, progressPct: 53));
      expect(p.praiseId, 'R02');
      expect(p.praiseText, contains('50%'));
      expect(_pick(_facts(lastProgressPct: 53, progressPct: 58)).praiseId, isNot('R02'));
    });

    test('걸음은 천 단위 쉼표, km는 소수 1자리', () {
      expect(_pick(_facts(todaySteps: 12345)).praiseText, contains('12,345보'));
      expect(_pick(_facts(runKm: 0.72)).praiseText, contains('0.7km'));
    });

    test('밤에는 늦은 시간 문구, 낮에는 아니다', () {
      expect(_pick(_facts(night: true)).praiseId, 'R08');
      expect(_catalog.defaults.keys, contains(_pick(_facts()).praiseId));
    });
  });

  group('시드', () {
    test('같은 입력이면 늘 같은 결과', () {
      expect(_pick(_facts(), k: 3).sceneTextId, _pick(_facts(), k: 3).sceneTextId);
      expect(eventSeed('a|1|2|s'), eventSeed('a|1|2|s'));
    });

    test('직전 문구는 다시 나오지 않는다', () {
      for (var k = 1; k <= 30; k++) {
        final first = _pick(_facts(), k: k);
        final next = _pick(_facts(), k: k, lastScene: first.sceneTextId, lastPraise: first.praiseId);
        expect(next.sceneTextId, isNot(first.sceneTextId), reason: 'k $k');
        expect(next.praiseId, isNot(first.praiseId), reason: 'k $k');
      }
    });

    test('FNV-1a 값이 판마다 같다 (알려진 값)', () {
      expect(eventSeed(''), 0x811C9DC5);
      expect(eventSeed('a'), 0xE40C292C);
    });
  });

  group('2km 칸', () {
    test('넘을 때마다 한 칸, 이미 만든 칸은 건너뛴다', () {
      expect(newEventSlots(eventM: 1999, everyKm: 2, doneK: 0), isEmpty);
      expect(newEventSlots(eventM: 2000, everyKm: 2, doneK: 0), [1]);
      expect(newEventSlots(eventM: 6100, everyKm: 2, doneK: 1), [2, 3]);
      expect(newEventSlots(eventM: 6100, everyKm: 2, doneK: 3), isEmpty);
    });
  });
}
