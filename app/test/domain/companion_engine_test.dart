import 'package:doobal/domain/companion.dart';
import 'package:doobal/domain/companion_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Companion? _pick({
  Set<String> met = const {},
  String terrain = 'field',
  int age = 0,
  String install = 'install-a',
  String journey = 'j1',
  int k = 1,
}) =>
    pickMeeting(
      companions: companionCatalog.companions,
      metIds: met,
      terrain: terrain,
      installAgeDays: age,
      installId: install,
      journeyId: journey,
      k: k,
      rules: rules,
    );

void main() {
  group('첫 만남', () {
    test('아무도 안 만났으면 지형과 상관없이 첫 칸에서 반드시 만난다', () {
      for (final terrain in ['mountain', 'coast', 'field', 'city']) {
        for (var i = 0; i < 50; i++) {
          expect(_pick(terrain: terrain, install: 'i$i'), isNotNull, reason: '$terrain i$i');
        }
      }
    });

    test('지형이 맞는 동행이 먼저 나온다', () {
      expect(_pick(terrain: 'coast')!.id, 'bright');
      expect(_pick(terrain: 'city')!.id, 'rest');
      expect(_pick(terrain: 'mountain')!.id, 'doctor');
    });

    test('맞는 지형이 없으면 시드로 셋 다 나올 수 있다', () {
      final who = {for (var i = 0; i < 100; i++) _pick(install: 'i$i')!.id};
      expect(who, {'bright', 'rest', 'doctor'});
    });
  });

  group('둘째·셋째', () {
    test('지형이 맞는 칸의 확률이 더 높고, 값은 config 근처다', () {
      const n = 4000;
      var match = 0;
      var other = 0;
      for (var k = 1; k <= n; k++) {
        if (_pick(met: {'rest'}, terrain: 'coast', k: k) != null) match++;
        if (_pick(met: {'rest'}, terrain: 'field', k: k) != null) other++;
      }
      expect(match, greaterThan(other * 2));
      expect(match / n, closeTo(rules.companionMeetChanceMatch, 0.03));
      expect(other / n, closeTo(rules.companionMeetChanceOther, 0.02));
    });

    test('이미 만난 동행의 지형은 확률을 올리지 않는다', () {
      const n = 4000;
      var c = 0;
      for (var k = 1; k <= n; k++) {
        if (_pick(met: {'bright'}, terrain: 'coast', k: k) != null) c++;
      }
      expect(c / n, closeTo(rules.companionMeetChanceOther, 0.02));
    });

    test('만나도 이미 만난 동행은 안 나온다', () {
      for (var k = 1; k <= 2000; k++) {
        expect(_pick(met: {'bright', 'rest'}, k: k)?.id, anyOf(isNull, 'doctor'));
      }
    });

    test('셋 다 만났으면 안 나온다 (보장 기한이 지나도)', () {
      expect(_pick(met: {'bright', 'rest', 'doctor'}, age: 100), isNull);
    });
  });

  group('설치 후 보장', () {
    final second = rules.companionGuaranteeDays[0];
    final third = rules.companionGuaranteeDays[1];

    test('config 값은 14·28일이다', () {
      expect(rules.companionGuaranteeDays, [14, 28]);
    });

    test('한 명만 만났으면 14일째부터 다음 칸에서 반드시 둘째를 만난다', () {
      expect(meetingDue(metCount: 1, installAgeDays: second - 1, guaranteeDays: [second, third]),
          isFalse);
      for (var k = 1; k <= 200; k++) {
        final c = _pick(met: {'bright'}, age: second, k: k);
        expect(c, isNotNull, reason: 'k=$k');
        expect(c!.id, isNot('bright'));
      }
    });

    test('두 명을 만났으면 14일이 지나도 28일 전에는 보장이 없고, 28일째부터 반드시', () {
      expect(meetingDue(metCount: 2, installAgeDays: third - 1, guaranteeDays: [second, third]),
          isFalse);
      final notDue = [
        for (var k = 1; k <= 200; k++) _pick(met: {'bright', 'rest'}, age: third - 1, k: k),
      ];
      expect(notDue.where((c) => c == null), isNotEmpty);
      for (var k = 1; k <= 200; k++) {
        expect(_pick(met: {'bright', 'rest'}, age: third, k: k)?.id, 'doctor');
      }
    });

    test('기한이 한참 지났으면 칸마다 한 명씩 이어서 만난다', () {
      expect(_pick(met: {'bright'}, age: 90), isNotNull);
      expect(_pick(met: {'bright', 'rest'}, age: 90)?.id, 'doctor');
    });
  });

  group('시드', () {
    test('같은 설치·여정·칸이면 늘 같은 결과', () {
      for (var k = 1; k <= 200; k++) {
        final a = _pick(met: {'rest'}, terrain: 'coast', k: k);
        final b = _pick(met: {'rest'}, terrain: 'coast', k: k);
        expect(a?.id, b?.id);
      }
    });

    test('설치·여정이 다르면 결과가 달라진다', () {
      List<String?> run(String install, String journey) => [
            for (var k = 1; k <= 200; k++)
              _pick(met: {'rest'}, terrain: 'coast', install: install, journey: journey, k: k)?.id,
          ];
      expect(run('a', 'j1'), isNot(run('b', 'j1')));
      expect(run('a', 'j1'), isNot(run('a', 'j2')));
    });
  });

  group('함께 걷기 세기', () {
    const minute = 60000;
    const stints = [
      CompanionStint(10 * minute, 'bright'),
      CompanionStint(100 * minute, null),
      CompanionStint(200 * minute, 'rest'),
    ];

    test('시작 시각에 함께 걷던 동행이 누구인가', () {
      expect(companionAt(stints, 9 * minute), isNull);
      expect(companionAt(stints, 10 * minute), 'bright');
      expect(companionAt(stints, 99 * minute), 'bright');
      expect(companionAt(stints, 100 * minute), isNull);
      expect(companionAt(stints, 250 * minute), 'rest');
      expect(companionAt(const [], 250 * minute), isNull);
    });

    test('고른 그 분 안에 시작한 걷기는 함께 걸은 것이다 (걷기 시작은 분으로 내려간다)', () {
      const picked = [CompanionStint(10 * minute + 30000, 'bright')];
      expect(companionAt(picked, 10 * minute), 'bright');
      expect(companionAt(picked, 9 * minute), isNull);
    });

    test('한 분 안에 두 번 바꾸면 나중 것이 그 분의 동행이다', () {
      const twice = [
        CompanionStint(10 * minute + 1000, 'bright'),
        CompanionStint(10 * minute + 2000, 'rest'),
      ];
      expect(companionAt(twice, 10 * minute), 'rest');
    });

    test('혼자 걷기·만나기 전 걷기는 어디에도 안 쌓이고, 바꾸면 그때 동행에게 쌓인다', () {
      final counts = walksTogether(
        [5 * minute, 20 * minute, 30 * minute, 150 * minute, 210 * minute],
        stints,
      );
      expect(counts, {'bright': 2, 'rest': 1});
    });

    test('줄 순서가 섞여 있어도 시작 시각 순서로 본다', () {
      final counts = walksTogether([50 * minute], stints.reversed.toList());
      expect(counts, {'bright': 1});
    });

    test('걷기 4번마다 1장, 8장에서 멈춘다', () {
      expect(rules.companionWalksPerChapter, 4);
      expect(rules.companionChapters, 8);
      expect(openedChapter(0, rules), 0);
      expect(openedChapter(3, rules), 0);
      expect(openedChapter(4, rules), 1);
      expect(openedChapter(7, rules), 1);
      expect(openedChapter(8, rules), 2);
      expect(openedChapter(32, rules), 8);
      expect(openedChapter(100, rules), 8);
    });
  });

  group('이야기 단위', () {
    test('지문은 다음 말 줄에 붙는다', () {
      final beats = storyBeats(const [
        StoryLine(who: StorySpeaker.narr, text: '지문'),
        StoryLine(who: StorySpeaker.companion, text: '안녕'),
        StoryLine(who: StorySpeaker.me, text: '응'),
      ]);
      expect(beats, hasLength(2));
      expect(beats[0].direction, '지문');
      expect(beats[0].who, StorySpeaker.companion);
      expect(beats[1].direction, isNull);
      expect(beats[1].who, StorySpeaker.me);
    });

    test('이어진 지문은 합치고, 끝 지문은 그대로 한 단위다', () {
      final beats = storyBeats(const [
        StoryLine(who: StorySpeaker.narr, text: '하나'),
        StoryLine(who: StorySpeaker.narr, text: '둘'),
        StoryLine(who: StorySpeaker.me, text: '응'),
        StoryLine(who: StorySpeaker.narr, text: '끝'),
      ]);
      expect(beats, hasLength(2));
      expect(beats[0].direction, '하나 둘');
      expect(beats[1].who, StorySpeaker.narr);
      expect(beats[1].text, '끝');
    });

    test('실제 데이터: 세 동행 모두 프롤로그·1~8장이 있고, 프롤로그는 함께/혼자를 고른다', () {
      expect(companionCatalog.companions, hasLength(3));
      for (final c in companionCatalog.companions) {
        expect([for (final ch in c.chapters) ch.no], [for (var i = 0; i <= 8; i++) i], reason: c.id);
        expect(c.chapters.first.choices, ['together', 'solo'], reason: c.id);
        for (final ch in c.chapters) {
          expect(storyBeats(ch.lines), isNotEmpty, reason: '${c.id} ${ch.no}');
        }
      }
    });

    test('캔버스 3-4와 같다: 퐁이 프롤로그는 5단위이고 첫 단위에 지문이 있다', () {
      final beats = storyBeats(companionCatalog.byId('bright')!.chapters.first.lines);
      expect(beats, hasLength(5));
      expect(beats.first.direction, contains('뒤뚱뒤뚱'));
      expect(beats.first.text, contains('민들레'));
    });
  });
}
