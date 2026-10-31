import 'package:doobal/domain/notification_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// 한국 시각 → UTC (한국은 UTC+9)
DateTime _kst(int month, int day, int hour, [int minute = 0, int second = 0, int ms = 0]) =>
    DateTime.utc(2026, month, day, hour - 9, minute, second, ms);

const _install = '00000000000000000000000000000000';

/// 한국 11월 18일 낮 12시 (조용한 시간이 아니다)
final _noon = _kst(11, 18, 12);

NoticeCandidate _n(NoticeKind k, {String key = '', Map<String, Object> vars = const {}}) =>
    NoticeCandidate(k, key: key, vars: vars);

NoticeDecision _pick(
  List<NoticeCandidate> candidates, {
  DateTime? now,
  Set<NoticeKind>? enabled,
  Map<String, int> sent = const {},
  bool foreground = false,
  PendingNotice? pending,
}) =>
    pickNotice(
      candidates: candidates,
      now: now ?? _noon,
      rules: rules,
      catalog: noticeCatalog,
      installId: _install,
      enabled: enabled ?? NoticeKind.values.toSet(),
      sentByDay: sent,
      inForeground: foreground,
      pending: pending,
    );

/// 모든 변수를 채울 수 있는 값 (문구 전체를 채워 보는 테스트용)
const _allVars = <String, Object>{
  'milestone': 12345,
  'remainingKm': 8.26,
  'dest': '경복궁',
  'companion': '폐이',
};

void main() {
  group('config 숫자', () {
    test('조용한 시간 22시~8시, 하루 최대 2, 10km, 72시간', () {
      expect(rules.notificationQuietFromHour, 22);
      expect(rules.notificationQuietToHour, 8);
      expect(rules.notificationDailyMax, 2);
      expect(rules.notificationNearDestKm, 10);
      expect(rules.notificationInactiveHours, 72);
    });
  });

  group('조용한 시간 (한국 시간)', () {
    test('22:00 정각은 조용하고, 21:59:59.999는 아니다', () {
      expect(isQuietTime(_kst(11, 18, 22), rules), isTrue);
      expect(isQuietTime(_kst(11, 18, 21, 59, 59, 999), rules), isFalse);
    });

    test('08:00 정각은 조용하지 않고, 07:59:59.999는 조용하다', () {
      expect(isQuietTime(_kst(11, 19, 8), rules), isFalse);
      expect(isQuietTime(_kst(11, 19, 7, 59, 59, 999), rules), isTrue);
    });

    test('자정을 지나도 조용하고, 낮은 아니다', () {
      expect(isQuietTime(_kst(11, 18, 23, 59, 59), rules), isTrue);
      expect(isQuietTime(_kst(11, 19, 0), rules), isTrue);
      expect(isQuietTime(_kst(11, 19, 3), rules), isTrue);
      expect(isQuietTime(_noon, rules), isFalse);
    });

    test('기기 시간대가 아니라 한국 시간이다: UTC 13:00은 한국 22:00', () {
      expect(isQuietTime(DateTime.utc(2026, 11, 18, 13), rules), isTrue);
      expect(isQuietTime(DateTime.utc(2026, 11, 18, 12, 59), rules), isFalse);
      // UTC 23:00은 한국 다음 날 08:00
      expect(isQuietTime(DateTime.utc(2026, 11, 18, 23), rules), isFalse);
    });

    test('끝나는 시각: 밤이면 다음 날 08:00, 새벽이면 그날 08:00, 22:00 정각은 다음 날', () {
      expect(quietEnd(_kst(11, 18, 23), rules), _kst(11, 19, 8));
      expect(quietEnd(_kst(11, 19, 3), rules), _kst(11, 19, 8));
      expect(quietEnd(_kst(11, 18, 22), rules), _kst(11, 19, 8));
      expect(quietEnd(_kst(11, 19, 7, 59, 59), rules), _kst(11, 19, 8));
      expect(quietEnd(_kst(11, 19, 0), rules), _kst(11, 19, 8));
    });
  });

  group('조사', () {
    test('받침 있음·없음', () {
      expect(hasBatchim('한강'), isTrue);
      expect(hasBatchim('폐이'), isFalse);
      expect(hasBatchim('휴'), isFalse);
      expect(hasBatchim('심 박사'), isFalse);
      expect(hasBatchim('서울'), isTrue);
      expect(hasBatchim(''), isFalse);
    });

    test('한글이 아니면 받침 없는 것으로 본다', () {
      expect(hasBatchim('3'), isFalse);
      expect(hasBatchim('km'), isFalse);
    });

    test('이/가', () {
      expect(josa('폐이', '이/가'), '가');
      expect(josa('휴', '이/가'), '가');
      expect(josa('심 박사', '이/가'), '가');
      expect(josa('한강', '이/가'), '이');
      // 쓴 순서가 반대여도 같다
      expect(josa('한강', '가/이'), '이');
      expect(josa('폐이', '가/이'), '가');
    });

    test('을/를 · 은/는 · 과/와', () {
      expect(josa('경복궁', '을/를'), '을');
      expect(josa('설악산', '을/를'), '을');
      expect(josa('휴', '을/를'), '를');
      expect(josa('경복궁', '은/는'), '은');
      expect(josa('휴', '은/는'), '는');
      expect(josa('경복궁', '과/와'), '과');
      expect(josa('휴', '와/과'), '와');
    });

    test('으로/로: ㄹ 받침은 로', () {
      expect(josa('서울', '으로/로'), '로');
      expect(josa('경복궁', '으로/로'), '으로');
      expect(josa('휴', '으로/로'), '로');
    });

    test('모르는 토큰은 null', () {
      expect(josa('휴', '이/를'), isNull);
      expect(josa('휴', '이'), isNull);
      expect(josa('휴', '가/나/다'), isNull);
    });
  });

  group('문구 채우기', () {
    test('milestone은 천 단위 쉼표, remainingKm은 소수 1자리', () {
      expect(fillNotice('{milestone}보 표지판', {'milestone': 12345}), '12,345보 표지판');
      expect(fillNotice('{milestone}보', {'milestone': 100}), '100보');
      expect(fillNotice('{milestone}보', {'milestone': 1234567}), '1,234,567보');
      expect(fillNotice('{dest}까지 {remainingKm}km', {'dest': '경복궁', 'remainingKm': 8.26}),
          '경복궁까지 8.3km');
      expect(fillNotice('{remainingKm}km', {'remainingKm': 10}), '10.0km');
      expect(fillNotice('{remainingKm}km', {'remainingKm': 9.04}), '9.0km');
    });

    test('dest·companion은 그대로, 같은 변수가 둘이어도 된다', () {
      expect(fillNotice('{dest} 도착! {dest}', {'dest': '내 동네 스케치'}), '내 동네 스케치 도착! 내 동네 스케치');
    });

    test('조사는 앞에 채운 값의 받침으로 고른다', () {
      expect(fillNotice('{companion}{이/가} 할 말이 있대.', {'companion': '폐이'}),
          '폐이가 할 말이 있대.');
      expect(fillNotice('{companion}{이/가} 할 말이 있대.', {'companion': '한강'}),
          '한강이 할 말이 있대.');
      expect(fillNotice('{dest}{으로/로} 가자', {'dest': '서울'}), '서울로 가자');
      expect(fillNotice('{dest}{을/를} 본다', {'dest': '경복궁'}), '경복궁을 본다');
    });

    test('토큰이 없는 문구는 그대로 (문구 v3에는 {이/가}가 없다)', () {
      expect(fillNotice('폐이가 할 말이 있대.', {}), '폐이가 할 말이 있대.');
      expect(fillNotice('', {}), '');
    });

    test('채울 값이 없는 변수·모르는 조사는 FormatException', () {
      expect(() => fillNotice('{dest}', {}), throwsFormatException);
      expect(() => fillNotice('{companion}{이/를}', {'companion': '휴'}), throwsFormatException);
    });
  });

  group('notifications.json', () {
    test('다섯 종류가 우선순위 1~5이고 문구가 둘씩이다', () {
      for (final k in NoticeKind.values) {
        expect(noticeCatalog.priorityOf(k), k.index + 1, reason: k.id);
        expect(noticeCatalog.specs[k]!.texts, hasLength(2), reason: k.id);
      }
    });

    test('모든 문구가 변수를 다 채우면 {}가 남지 않는다 (문구가 바뀌어도)', () {
      for (final spec in noticeCatalog.specs.values) {
        for (final t in spec.texts) {
          for (final s in [t.title, t.body]) {
            final out = fillNotice(s, _allVars);
            expect(out, isNotEmpty);
            expect(out, isNot(contains('{')), reason: s);
            expect(out, isNot(contains('}')), reason: s);
          }
        }
      }
    });

    test('v3 꼴(조사 토큰이 없고 본문이 바뀐 것)도 읽히고 채워진다', () {
      final v3 = NoticeCatalog.fromJson({
        'version': 3,
        'vars': ['companion', 'dest', 'milestone', 'remainingKm'],
        'kinds': [
          for (final k in NoticeKind.values)
            {
              'id': k.id,
              'priority': k.index + 1,
              'texts': [
                {'title': '${k.id} 하나', 'body': '본문 하나'},
                {'title': '{companion}의 ${k.id}', 'body': '{companion}가 할 말이 있대.'},
              ],
            },
        ],
      });
      expect(v3.priorityOf(NoticeKind.n4), 4);
      expect(v3.specs[NoticeKind.n3]!.texts[1].body, '{companion}가 할 말이 있대.');
      final m = buildNotice(_n(NoticeKind.n3, vars: {'companion': '폐이'}), v3, _install,
          _noon);
      expect(m.body, anyOf('본문 하나', '폐이가 할 말이 있대.'));
    });

    test('종류가 빠졌거나 모르는 id면 FormatException', () {
      expect(
          () => NoticeCatalog.fromJson({
                'kinds': [
                  {
                    'id': 'N1',
                    'priority': 1,
                    'texts': [
                      {'title': 'a', 'body': 'b'}
                    ],
                  }
                ],
              }),
          throwsFormatException);
      expect(
          () => NoticeCatalog.fromJson({
                'kinds': [
                  {
                    'id': 'N9',
                    'priority': 1,
                    'texts': [
                      {'title': 'a', 'body': 'b'}
                    ],
                  }
                ],
              }),
          throwsFormatException);
    });
  });

  group('글 고르기 (시드)', () {
    final c = _n(NoticeKind.n1, key: 'm:3000', vars: {'milestone': 3000});

    /// 시드가 고른 쪽(0 또는 1)의 글을 변수까지 채운 것
    (String, String) text(NoticeKind kind, int index, Map<String, Object> vars) {
      final t = noticeCatalog.specs[kind]!.texts[index];
      return (fillNotice(t.title, vars), fillNotice(t.body, vars));
    }

    test('같은 설치·종류·한국 날짜는 늘 같은 글이다 (고정)', () {
      // 2026-11-18은 1번, 11-19는 0번 (이 설치 번호와 N1일 때)
      final d18 = buildNotice(c, noticeCatalog, _install, _kst(11, 18, 9));
      expect((d18.title, d18.body), text(NoticeKind.n1, 1, c.vars));
      expect(d18.key, 'm:3000');
      expect(d18.payload, 'N1:m:3000');
      final d19 = buildNotice(c, noticeCatalog, _install, _kst(11, 19, 9));
      expect((d19.title, d19.body), text(NoticeKind.n1, 0, c.vars));
      // 몇 번을 불러도 같다
      for (var i = 0; i < 3; i++) {
        final again = buildNotice(c, noticeCatalog, _install, _kst(11, 18, 21));
        expect((again.title, again.body), (d18.title, d18.body));
      }
    });

    test('날짜는 한국 날짜다: 한국 자정에 바뀐다', () {
      final before =
          buildNotice(c, noticeCatalog, _install, DateTime.utc(2026, 11, 18, 14, 59, 59));
      final after = buildNotice(c, noticeCatalog, _install, DateTime.utc(2026, 11, 18, 15));
      expect((before.title, before.body), text(NoticeKind.n1, 1, c.vars));
      expect((after.title, after.body), text(NoticeKind.n1, 0, c.vars));
    });

    test('날짜가 바뀌면 두 문구가 다 나오고, 설치 번호와 종류에 따라 달라진다', () {
      final seen = <String>{};
      for (var d = 1; d <= 28; d++) {
        seen.add(buildNotice(c, noticeCatalog, _install, _kst(11, d, 9)).title);
      }
      expect(seen, hasLength(2));

      /// 28일 동안 시드가 고른 쪽(0 또는 1)
      List<int> picks(String installId, NoticeKind kind) {
        final first = noticeCatalog.specs[kind]!.texts[0];
        return [
          for (var d = 1; d <= 28; d++)
            buildNotice(_n(kind, vars: _allVars), noticeCatalog, installId, _kst(11, d, 9))
                        .title ==
                    fillNotice(first.title, _allVars)
                ? 0
                : 1,
        ];
      }

      expect(picks('a' * 32, NoticeKind.n2), isNot(picks('b' * 32, NoticeKind.n2)));
      expect(picks(_install, NoticeKind.n2), isNot(picks(_install, NoticeKind.n4)));
    });

    test('N4: 남은 거리는 소수 1자리로 채운다', () {
      final c4 = _n(NoticeKind.n4, key: 'j1', vars: {'dest': '경복궁', 'remainingKm': 9.96});
      for (var d = 1; d <= 6; d++) {
        final m = buildNotice(c4, noticeCatalog, _install, _kst(11, d, 9));
        expect('${m.title} ${m.body}', isNot(contains('{')));
        if (m.title.contains('km')) expect(m.title, '경복궁까지 10.0km');
      }
    });
  });

  group('pickNotice', () {
    test('낮이고 앱이 꺼져 있으면 지금 보낸다', () {
      final d = _pick([_n(NoticeKind.n2, key: 'j1', vars: {'dest': '경복궁'})]);
      expect(d.action, NoticeAction.sendNow);
      expect(d.chosen!.kind, NoticeKind.n2);
      expect(d.message!.kind, NoticeKind.n2);
      expect(d.message!.title, isNotEmpty);
      expect(d.at, isNull);
      expect(d.replacesPending, isFalse);
      expect(d.dropped, isEmpty);
    });

    test('후보가 없으면 아무것도 안 한다', () {
      final d = _pick([]);
      expect(d.action, NoticeAction.nothing);
      expect(d.chosen, isNull);
      expect(d.message, isNull);
    });

    group('조용한 시간 → 08:00에 1개 예약', () {
      final n1 = _n(NoticeKind.n1, key: 'm:100', vars: {'milestone': 100});

      test('밤 23시에 생기면 다음 날 08:00 (한국)', () {
        final d = _pick([n1], now: _kst(11, 18, 23));
        expect(d.action, NoticeAction.schedule);
        expect(d.at, _kst(11, 19, 8));
        expect(d.chosen, same(n1));
        expect(d.replacesPending, isFalse);
      });

      test('새벽 3시에 생기면 그날 08:00', () {
        final d = _pick([n1], now: _kst(11, 19, 3));
        expect(d.action, NoticeAction.schedule);
        expect(d.at, _kst(11, 19, 8));
      });

      test('22:00 정각은 예약, 08:00 정각은 지금 보낸다', () {
        expect(_pick([n1], now: _kst(11, 18, 22)).action, NoticeAction.schedule);
        expect(_pick([n1], now: _kst(11, 18, 21, 59, 59, 999)).action, NoticeAction.sendNow);
        expect(_pick([n1], now: _kst(11, 19, 7, 59, 59, 999)).action, NoticeAction.schedule);
        expect(_pick([n1], now: _kst(11, 19, 8)).action, NoticeAction.sendNow);
      });

      test('한꺼번에 여럿 생겨도 1개만 예약한다', () {
        final d = _pick([_n(NoticeKind.n4, key: 'j1', vars: {'dest': 'a', 'remainingKm': 9}), n1],
            now: _kst(11, 18, 23));
        expect(d.action, NoticeAction.schedule);
        expect(d.chosen!.kind, NoticeKind.n1);
        expect(d.dropped.map((c) => c.kind), [NoticeKind.n4]);
      });

      test('이미 예약된 것보다 우선순위가 높으면 바꿔 끼운다', () {
        final d = _pick([n1],
            now: _kst(11, 18, 23), pending: PendingNotice(NoticeKind.n4, _kst(11, 19, 8)));
        expect(d.action, NoticeAction.schedule);
        expect(d.replacesPending, isTrue);
        expect(d.at, _kst(11, 19, 8));
        expect(d.chosen!.kind, NoticeKind.n1);
      });

      test('낮거나 같으면 예약된 것을 그대로 둔다', () {
        final n4 = _n(NoticeKind.n4, key: 'j1', vars: {'dest': 'a', 'remainingKm': 9});
        final lower = _pick([n4],
            now: _kst(11, 18, 23), pending: PendingNotice(NoticeKind.n1, _kst(11, 19, 8)));
        expect(lower.action, NoticeAction.nothing);
        expect(lower.replacesPending, isFalse);
        expect(lower.dropped, [n4]);

        final same = _pick([_n(NoticeKind.n1, key: 'm:1000', vars: {'milestone': 1000})],
            now: _kst(11, 18, 23), pending: PendingNotice(NoticeKind.n1, _kst(11, 19, 8)));
        expect(same.action, NoticeAction.nothing);
      });

      test('낮에는 남아 있는 예약을 따지지 않는다', () {
        final d = _pick([n1], pending: PendingNotice(NoticeKind.n1, _kst(11, 19, 8)));
        expect(d.action, NoticeAction.sendNow);
        expect(d.replacesPending, isFalse);
      });
    });

    group('하루 최대', () {
      final n2 = _n(NoticeKind.n2, key: 'j1', vars: {'dest': '경복궁'});

      test('하루 3번째는 안 보낸다', () {
        expect(_pick([n2], sent: {'2026-11-18': 0}).action, NoticeAction.sendNow);
        expect(_pick([n2], sent: {'2026-11-18': 1}).action, NoticeAction.sendNow);
        final blocked = _pick([n2], sent: {'2026-11-18': 2});
        expect(blocked.action, NoticeAction.nothing);
        expect(blocked.dropped, [n2]);
        expect(_pick([n2], sent: {'2026-11-18': 3}).action, NoticeAction.nothing);
      });

      test('한국 자정에 개수가 초기화된다 (날짜는 한국 날짜)', () {
        final full = {'2026-11-18': 2};
        // 18일 21:59:59까지는 18일이라 막힌다
        expect(_pick([n2], now: _kst(11, 18, 21, 59, 59), sent: full).action,
            NoticeAction.nothing);
        // 19일 08:00은 19일이라 새로 센다
        expect(_pick([n2], now: _kst(11, 19, 8), sent: full).action, NoticeAction.sendNow);
        // 18일 밤에 생긴 것은 19일 08:00에 뜨니까 19일로 센다 (18일이 차 있어도 예약된다)
        final night = _pick([n2], now: _kst(11, 18, 23, 30), sent: full);
        expect(night.action, NoticeAction.schedule);
        expect(night.at, _kst(11, 19, 8));
        // 19일 새벽에 생겼어도 19일 08:00에 뜨니까 19일로 센다
        expect(_pick([n2], now: _kst(11, 19, 0, 30), sent: full).action, NoticeAction.schedule);
      });

      test('예약한 알림이 뜨는 날에 이미 차 있으면 예약하지 않는다', () {
        // 19일 08:00에 N5 둘이 이미 나가기로 했다고 치면
        final d = _pick([n2], now: _kst(11, 19, 2), sent: {'2026-11-19': 2});
        expect(d.action, NoticeAction.nothing);
      });
    });

    test('같은 동기화의 N1+N2는 N1만, N2+N4는 N2만 (순서와 상관없다)', () {
      final n1 = _n(NoticeKind.n1, key: 'm:100', vars: {'milestone': 100});
      final n2 = _n(NoticeKind.n2, key: 'j1', vars: {'dest': '경복궁'});
      final n4 = _n(NoticeKind.n4, key: 'j2', vars: {'dest': '경복궁', 'remainingKm': 9});
      final a = _pick([n2, n1]);
      expect(a.chosen, same(n1));
      expect(a.dropped, [n2]);
      final b = _pick([n4, n2]);
      expect(b.chosen, same(n2));
      expect(b.dropped, [n4]);
      final c = _pick([n4, n2, n1]);
      expect(c.chosen, same(n1));
      expect(c.dropped, hasLength(2));
    });

    test('같은 종류가 여럿이면 앞에 온 것을 쓴다', () {
      final first = _n(NoticeKind.n1, key: 'm:5000', vars: {'milestone': 5000});
      final second = _n(NoticeKind.n1, key: 'm:1000', vars: {'milestone': 1000});
      final d = _pick([first, second]);
      expect(d.chosen, same(first));
      expect(d.dropped, [second]);
    });

    test('꺼진 종류는 판정에서 뺀다', () {
      final n1 = _n(NoticeKind.n1, key: 'm:100', vars: {'milestone': 100});
      final n2 = _n(NoticeKind.n2, key: 'j1', vars: {'dest': '경복궁'});
      final noN1 = NoticeKind.values.toSet()..remove(NoticeKind.n1);
      final d = _pick([n1, n2], enabled: noN1);
      expect(d.action, NoticeAction.sendNow);
      expect(d.chosen, same(n2));
      expect(d.dropped, [n1]);

      final none = _pick([n1, n2], enabled: <NoticeKind>{});
      expect(none.action, NoticeAction.nothing);
      expect(none.dropped, [n1, n2]);
    });

    test('앱이 앞에 있으면 화면 안 표시만 한다 (밤이어도, 하루 최대가 차 있어도)', () {
      final n2 = _n(NoticeKind.n2, key: 'j1', vars: {'dest': '경복궁'});
      final n4 = _n(NoticeKind.n4, key: 'j2', vars: {'dest': '경복궁', 'remainingKm': 9});
      final day = _pick([n4, n2], foreground: true);
      expect(day.action, NoticeAction.inApp);
      expect(day.chosen, same(n2));
      expect(day.message, isNotNull);
      expect(day.at, isNull);
      expect(day.dropped, [n4]);

      expect(_pick([n2], foreground: true, now: _kst(11, 18, 23)).action, NoticeAction.inApp);
      expect(_pick([n2], foreground: true, sent: {'2026-11-18': 5}).action, NoticeAction.inApp);
      // 꺼진 종류는 앞에 있어도 뺀다
      expect(_pick([n2], foreground: true, enabled: <NoticeKind>{}).action, NoticeAction.nothing);
    });

    test('글은 시드로 고른 것이고 변수가 채워져 있다', () {
      final d = _pick([_n(NoticeKind.n1, key: 'm:12345', vars: {'milestone': 12345})]);
      final m = buildNotice(d.chosen!, noticeCatalog, _install, _noon);
      expect((d.message!.title, d.message!.body), (m.title, m.body));
      expect(d.message!.payload, 'N1:m:12345');
      expect('${m.title} ${m.body}', isNot(contains('{')));
    });
  });

  group('N4: 목적지 10km 안', () {
    test('10km보다 크다가 10km 이하로 들어온 동기화만', () {
      bool enter(double before, double after) =>
          enteredNearDest(remainingBefore: before, remainingAfter: after, nearKm: 10);
      expect(enter(10.1, 9.9), isTrue);
      expect(enter(10.01, 10.0), isTrue);
      expect(enter(25, 3), isTrue);
      // 이미 안에 있었으면 다시 알리지 않는다 (10.0 정각도 안이다)
      expect(enter(10.0, 9.0), isFalse);
      expect(enter(9.9, 9.0), isFalse);
      expect(enter(3, 0), isFalse);
      // 아직 밖이다
      expect(enter(12, 10.01), isFalse);
      expect(enter(12, 11), isFalse);
    });
  });

  group('N5: 며칠 미접속', () {
    DateTime? plan(DateTime now, {bool enabled = true, InactiveState state = InactiveState.none}) =>
        planInactive(now: now, rules: rules, enabled: enabled, state: state);

    test('백그라운드로 가면 지금 + 72시간에 예약한다', () {
      final now = _kst(11, 18, 14, 30);
      expect(plan(now), _kst(11, 21, 14, 30));
      expect(plan(now), now.add(const Duration(hours: 72)));
    });

    test('이미 예약돼 있으면 그대로 두고, 울린 뒤 안 열었으면 다시 예약하지 않는다', () {
      final now = _kst(11, 18, 14);
      expect(plan(now, state: InactiveState.pending), isNull);
      expect(plan(now, state: InactiveState.fired), isNull);
    });

    test('꺼져 있으면 예약하지 않는다', () {
      expect(plan(_kst(11, 18, 14), enabled: false), isNull);
    });

    test('72시간 뒤가 조용한 시간이면 그 시간이 끝나는 08:00으로 미룬다', () {
      // 한국 23:00 → 72시간 뒤 21일 23:00 (조용) → 22일 08:00
      expect(plan(_kst(11, 18, 23)), _kst(11, 22, 8));
      // 한국 03:00 → 21일 03:00 (조용) → 21일 08:00
      expect(plan(_kst(11, 18, 3)), _kst(11, 21, 8));
      // 한국 21:59 → 21일 21:59 (조용하지 않다)
      expect(plan(_kst(11, 18, 21, 59)), _kst(11, 21, 21, 59));
    });
  });

  group('알림 켜고 끄기', () {
    test('기본은 모두 켠다', () {
      const s = NoticeSettings();
      expect(s.all, isTrue);
      expect(s.enabled, NoticeKind.values.toSet());
    });

    test('종류 하나를 끄면 그것만 빠진다', () {
      final s = const NoticeSettings().withKind(NoticeKind.n3, false);
      expect(s.isOn(NoticeKind.n3), isFalse);
      expect(s.enabled, {NoticeKind.n1, NoticeKind.n2, NoticeKind.n4, NoticeKind.n5});
      expect(s.withKind(NoticeKind.n3, true).enabled, NoticeKind.values.toSet());
    });

    test('전체를 끄면 모두 빠지고, 종류별 값은 그대로 남는다', () {
      final s = const NoticeSettings().withKind(NoticeKind.n2, false).withAll(false);
      expect(s.enabled, isEmpty);
      expect(s.isOn(NoticeKind.n1), isFalse);
      final back = s.withAll(true);
      expect(back.enabled, {NoticeKind.n1, NoticeKind.n3, NoticeKind.n4, NoticeKind.n5});
    });
  });
}
