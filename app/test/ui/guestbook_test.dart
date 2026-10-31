import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/landmark.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/guestbook/guestbook_write_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'ui_env.dart';

final _sign = find.byKey(const ValueKey('signpost'));
final _tag = find.byKey(const ValueKey('guestbook-tag'));
final _input = find.byKey(const ValueKey('guestbook-input'));
final _count = find.byKey(const ValueKey('guestbook-count'));
final _stepsLeft = find.byKey(const ValueKey('guestbook-steps-left'));
final _consent = find.byKey(const ValueKey('guestbook-consent'));
final _blocked = find.byKey(const ValueKey('guestbook-blocked'));
final _closed = find.byKey(const ValueKey('guestbook-closed'));
final _arrivalCard = find.byKey(const ValueKey('arrival-card'));

const _consentText = '남긴 글은 다른 사람들에게 보여요. 이용약관에 동의하고 남겨요';

final _journeyId = 'j${t1.millisecondsSinceEpoch}';

String _tagText(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: _tag, matching: find.byType(Text)))
    .data!;

/// 버튼 [label]이 눌리는 상태인가 (GameButton은 onPressed가 null이면 흐리고 안 눌린다)
bool _enabled(WidgetTester tester, String label) =>
    tester.widget<GameButton>(find.widgetWithText(GameButton, label)).onPressed != null;

/// 쓰기 화면(기회 [ticketId])을 앱 첫 화면 위에 열고 태그(또는 닫힘 안내)가 뜰 때까지 기다린다
Future<void> _openWrite(
  WidgetTester tester,
  UiEnv e,
  String ticketId, {
  List<Override> extra = const [],
}) async {
  await openOnTop(
    tester,
    e,
    GuestbookWriteScreen(ticketId: ticketId),
    extra: extra,
    ready: () => _tag.evaluate().isNotEmpty || _closed.evaluate().isNotEmpty,
  );
  // 동의 줄이 정해질 때까지
  await settle(tester, () => false, tries: 6);
}

/// 도착 화면(여정 [id])을 앱 첫 화면 위에 열고 카드와 방명록 버튼 상태가 정해질 때까지 기다린다
Future<void> _openArrival(WidgetTester tester, UiEnv e, String id) async {
  await openOnTop(tester, e, ArrivalScreen(journeyId: id),
      ready: () => _arrivalCard.evaluate().isNotEmpty);
  await settle(tester, () => false, tries: 6);
  await tester.pump(const Duration(seconds: 2));
}

/// 기회 행을 직접 넣는다
Future<void> _putTicket(
  UiEnv e,
  String id,
  TicketKind kind,
  String scope, {
  DateTime? used,
  DateTime? closed,
}) =>
    e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
          id: id,
          kind: kind,
          scope: scope,
          openedUtc: t1.millisecondsSinceEpoch,
          usedUtc: Value(used?.millisecondsSinceEpoch),
          closedUtc: Value(closed?.millisecondsSinceEpoch),
        ));

/// 글을 쓰고 "남기기"를 눌러 쓰기 화면이 닫힐 때까지 기다린다
Future<void> _writeAndSave(WidgetTester tester, String text) async {
  await tester.enterText(_input, text);
  await tester.pump();
  await tester.tap(find.text('남기기'));
  await settle(tester, () => find.text('방명록을 남겼어요').evaluate().isNotEmpty, tries: 12);
  await transition(tester);
}

Future<List<GuestbookPostRow>> _posts(WidgetTester tester, UiEnv e) =>
    tester.runAsync(() => e.db.select(e.db.guestbookPosts).get()).then((v) => v!);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('쉼터 표지판', () {
    Future<void> openRest(WidgetTester tester, UiEnv e) async {
      await pumpDoobal(tester, e, const DoobalApp());
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
    }

    testWidgets('쓸 기회가 없으면 서지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await openRest(tester, e);
      expect(find.byType(RestScreen), findsOneWidget);
      expect(_sign, findsNothing);
      expect(find.text('방명록'), findsNothing);
      await end(tester, e);
    });

    testWidgets('도착 기회가 있으면 서고, 이정표 옆(테마의 자리)에 이름표 "방명록"이 붙는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001');
      });
      await openRest(tester, e);
      expect(_sign, findsOneWidget);
      expect(find.descendant(of: _sign, matching: find.text('방명록')), findsOneWidget);
      // 가로는 테마의 guestbookSign.x 비율, 아래 가장자리 근처(이름표가 붙는다)는 footY 아래
      expect(tester.getCenter(_sign).dx, closeTo(campTheme.guestbookSign.x * 390, 1));
      expect(tester.getRect(_sign).top, lessThan(campTheme.guestbookSign.footY * 844));
      expect(tester.getRect(_sign).bottom, greaterThan(campTheme.guestbookSign.footY * 844));
      await end(tester, e);
    });

    testWidgets('걸음 숫자 기회만 있어도 선다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'm:100', TicketKind.milestone, 'steps:100');
      });
      await openRest(tester, e);
      expect(_sign, findsOneWidget);
      await end(tester, e);
    });

    testWidgets('쓰거나 닫힌 기회는 표지판을 세우지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001', used: t1);
        await _putTicket(e, 'a:j2', TicketKind.arrival, 'kr002', closed: t1);
      });
      await openRest(tester, e);
      expect(_sign, findsNothing);
      await end(tester, e);
    });

    testWidgets('누르면 그 기회의 쓰기 화면, 쓰고 돌아오면 표지판이 사라진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001');
      });
      await openRest(tester, e);
      await tester.tap(_sign);
      await transition(tester);
      await settle(tester, () => _tag.evaluate().isNotEmpty);
      expect(find.byType(GuestbookWriteScreen), findsOneWidget);
      expect(_tagText(tester), '경복궁 도착');

      await _writeAndSave(tester, '경복궁 좋았어요');
      expect(find.byType(GuestbookWriteScreen), findsNothing);
      expect(find.text('방명록을 남겼어요'), findsOneWidget);
      await settle(tester, () => _sign.evaluate().isEmpty);
      expect(_sign, findsNothing);
      expect((await _posts(tester, e)).single.body, '경복궁 좋았어요');
      await end(tester, e);
    });

    testWidgets('도착 기회를 쓰면 다음은 걸음 숫자 기회: 표지판이 남아 "100보"로 이어진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.arriveAtGyeongbok();
        // 도착 화면은 본 것으로 둔다 (앱을 열자마자 도착 화면이 올라오지 않게)
        await e.svc.markArrivalShown(_journeyId);
      });
      await openRest(tester, e);
      expect(_sign, findsOneWidget);
      await tester.tap(_sign);
      await transition(tester);
      await settle(tester, () => _tag.evaluate().isNotEmpty);
      // 도착 기회가 먼저
      expect(_tagText(tester), '경복궁 도착');
      expect(_stepsLeft, findsNothing);
      await _writeAndSave(tester, '도착!');
      await settle(tester, () => false, tries: 6);

      // 3,000보를 걸어서 100·1,000 기회가 열려 있다: 남은 걸음이 같아 숫자가 작은 100이 먼저
      expect(_sign, findsOneWidget);
      await tester.tap(_sign);
      await transition(tester);
      await settle(tester, () => _tag.evaluate().isNotEmpty);
      expect(_tagText(tester), '100보');
      expect(find.text('남은 ${rules.guestbookWindowSteps}보'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('쓰기 화면', () {
    testWidgets('태그: 명소 도착, 첫 여정 도착, 걸음 숫자(천 단위 쉼표)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001');
        await _putTicket(e, 'a:j2', TicketKind.arrival, 'sketch');
        await _putTicket(e, 'm:12345', TicketKind.milestone, 'steps:12345');
        await _putTicket(e, 'm:100', TicketKind.milestone, 'steps:100');
      });
      for (final (id, tag) in [
        ('a:j1', '경복궁 도착'),
        ('a:j2', '내 동네 스케치 도착'),
        ('m:12345', '12,345보'),
        ('m:100', '100보'),
      ]) {
        await _openWrite(tester, e, id);
        expect(_tagText(tester), tag, reason: id);
        await tester.pumpWidget(const SizedBox());
      }
      await end(tester, e);
    });

    testWidgets('입력 칸은 200자까지, 글자 수는 "n/200"', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1');
      expect(tester.widget<Text>(_count).data, '0/200');

      await tester.enterText(_input, '안녕하세요');
      await tester.pump();
      expect(tester.widget<Text>(_count).data, '5/200');

      // 250자를 붙여 넣어도 200자에서 멈춘다
      await tester.enterText(_input, '가' * 250);
      await tester.pump();
      expect(tester.widget<Text>(_count).data, '200/200');
      expect(tester.widget<TextField>(_input).controller!.text, '가' * 200);

      // 이모지는 한 글자로 센다
      await tester.enterText(_input, '😀' * 3);
      await tester.pump();
      expect(tester.widget<Text>(_count).data, '3/200');
      await end(tester, e);
    });

    testWidgets('남은 걸음은 걸음 숫자 기회에만 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001');
        await _putTicket(e, 'm:12345', TicketKind.milestone, 'steps:12345');
        // 열린 지 얼마 안 돼 걸음이 조금 쌓였다 (남은 500 - 123)
        await e.db.into(e.db.stepMinutes).insert(StepMinutesCompanion.insert(
            minuteUtc: Value(t1.millisecondsSinceEpoch ~/ 60000 + 1), steps: 123));
      });
      e.now = t1.add(const Duration(minutes: 10));
      await _openWrite(tester, e, 'a:j1');
      expect(_stepsLeft, findsNothing);
      await tester.pumpWidget(const SizedBox());

      await _openWrite(tester, e, 'm:12345');
      expect(tester.widget<Text>(_stepsLeft).data, '남은 377보');
      await end(tester, e);
    });

    testWidgets('주 버튼 "남기기"는 글이 유효할 때만 켜진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1');
      expect(_enabled(tester, '남기기'), isFalse);

      await tester.enterText(_input, '   \n ');
      await tester.pump();
      expect(_enabled(tester, '남기기'), isFalse);

      await tester.enterText(_input, '안녕');
      await tester.pump();
      expect(_enabled(tester, '남기기'), isTrue);

      await tester.enterText(_input, '');
      await tester.pump();
      expect(_enabled(tester, '남기기'), isFalse);

      await tester.enterText(_input, '가' * 200);
      await tester.pump();
      expect(_enabled(tester, '남기기'), isTrue);
      await end(tester, e);
    });

    testWidgets('금칙어에 걸리면 입력 칸 아래에 테라코타 안내가 뜨고 "남기기"가 꺼진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1');
      expect(_blocked, findsNothing);

      await tester.enterText(_input, '오늘 진짜 시발 날씨');
      await tester.pump();
      expect(_blocked, findsOneWidget);
      final note = tester.widget<Text>(_blocked);
      expect(note.data, '이 표현은 방명록에 남길 수 없어요');
      // 빨간색이 아니라 테라코타, 어떤 단어인지는 말하지 않는다
      expect(note.style!.color, Palette.terracotta);
      expect(find.textContaining('시발'), findsOneWidget); // 입력한 글뿐
      // 입력 칸 아래에 있다
      expect(tester.getTopLeft(_blocked).dy, greaterThan(tester.getBottomLeft(_input).dy));
      expect(_enabled(tester, '남기기'), isFalse);

      // 초성 줄임도 같다
      await tester.enterText(_input, 'ㅅㅂ');
      await tester.pump();
      expect(_blocked, findsOneWidget);
      expect(_enabled(tester, '남기기'), isFalse);

      // 고치면 안내가 사라지고 버튼이 켜진다
      await tester.enterText(_input, '오늘 날씨가 좋아요');
      await tester.pump();
      expect(_blocked, findsNothing);
      expect(_enabled(tester, '남기기'), isTrue);
      await end(tester, e);
    });

    testWidgets('걸린 글은 꺼진 "남기기"를 눌러도 저장되지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1');

      await tester.enterText(_input, '병신');
      await tester.pump();
      await tester.tap(find.text('남기기'), warnIfMissed: false);
      await settle(tester, () => false, tries: 6);

      expect(find.byType(GuestbookWriteScreen), findsOneWidget);
      expect(await _posts(tester, e), isEmpty);
      await end(tester, e);
    });

    testWidgets('명소 이름이 든 글과 일반 글은 안내가 뜨지 않는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1');

      for (final l in landmarks) {
        await tester.enterText(_input, '${l.name}에서 걸었어요');
        await tester.pump();
        expect(_blocked, findsNothing, reason: l.name);
        expect(_enabled(tester, '남기기'), isTrue, reason: l.name);
      }
      await end(tester, e);
    });

    testWidgets('명소 이름은 검사에서 빠지고(허용 목록), 추가 목록의 낱말은 공백을 끼워도 걸린다', (tester) async {
      // 패키지가 욕설로 보는 낱말("시발점")을 이름으로 가진 명소를 하나 더 둔다
      final first = landmarks.first;
      final trap = Landmark(
        id: 'kr900',
        name: '시발점',
        sido: first.sido,
        sigungu: first.sigungu,
        region: first.region,
        backdrop: first.backdrop,
        terrain: first.terrain,
        types: first.types,
        latLng: first.latLng,
        island: first.island,
        painting: first.painting,
      );
      final e = UiEnv(appLandmarks: [...landmarks, trap]);
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1',
          extra: [extraBlockedWordsProvider.overrideWithValue(const ['나쁜말'])]);

      await tester.enterText(_input, '시발점에서 출발해요');
      await tester.pump();
      expect(_blocked, findsNothing);
      expect(_enabled(tester, '남기기'), isTrue);

      await tester.enterText(_input, '시발점에서 시발');
      await tester.pump();
      expect(_blocked, findsOneWidget);

      await tester.enterText(_input, '그건 나 쁜-말이야');
      await tester.pump();
      expect(_blocked, findsOneWidget);
      expect(_enabled(tester, '남기기'), isFalse);
      await end(tester, e);
    });

    testWidgets('남기면 저장하고 토스트를 띄운 뒤 닫는다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1');
      await _writeAndSave(tester, '  좋았어요  ');

      expect(find.byType(GuestbookWriteScreen), findsNothing);
      expect(find.text('열기'), findsOneWidget);
      expect(find.text('방명록을 남겼어요'), findsOneWidget);
      final post = (await _posts(tester, e)).single;
      expect((post.ticketId, post.scope, post.body, post.status),
          ('a:j1', 'kr001', '좋았어요', PostStatus.pending));
      // 기회는 쓴 것으로 바뀌어 더는 열려 있지 않다
      final row = await tester.runAsync(() => (e.db.select(e.db.guestbookTickets)
            ..where((t) => t.id.equals('a:j1')))
          .getSingle());
      expect(row!.usedUtc, isNotNull);
      await end(tester, e);
    });

    testWidgets('동의 줄은 방명록을 처음 쓸 때만 나오고, 쓰면 동의 시각이 적힌다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001');
        await _putTicket(e, 'm:100', TicketKind.milestone, 'steps:100');
      });
      expect((await tester.runAsync(e.svc.guestbookConsented))!, isFalse);

      await _openWrite(tester, e, 'a:j1');
      expect(_consent, findsOneWidget);
      expect(tester.widget<Text>(_consent).data, _consentText);
      await _writeAndSave(tester, '첫 글');
      expect((await tester.runAsync(e.svc.guestbookConsented))!, isTrue);

      // 두 번째부터는 없다
      await _openWrite(tester, e, 'm:100');
      expect(_tagText(tester), '100보');
      expect(_consent, findsNothing);
      await end(tester, e);
    });

    testWidgets('이미 동의한 기록이 있으면 처음 쓰는 기회여도 동의 줄이 없다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001');
        await e.db.into(e.db.profile).insertOnConflictUpdate(
            const ProfileCompanion(id: Value(1), guestbookConsentAt: Value(5)));
      });
      await _openWrite(tester, e, 'a:j1');
      expect(_tagText(tester), '경복궁 도착');
      expect(_consent, findsNothing);
      await end(tester, e);
    });

    testWidgets('저장하는 사이 기회가 끝났으면 토스트로 알리고 닫는다 (글은 안 남는다)', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () => _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001'));
      await _openWrite(tester, e, 'a:j1');
      await tester.enterText(_input, '늦었네');
      await tester.pump();
      // 글을 쓰는 동안 다음 여정을 시작해서 기회가 닫혔다
      await tester.runAsync(() => (e.db.update(e.db.guestbookTickets)
            ..where((t) => t.id.equals('a:j1')))
          .write(GuestbookTicketsCompanion(closedUtc: Value(t1.millisecondsSinceEpoch))));
      await tester.tap(find.text('남기기'));
      await settle(tester, () => find.textContaining('때가 지났어요').evaluate().isNotEmpty, tries: 12);
      await transition(tester);

      expect(find.byType(GuestbookWriteScreen), findsNothing);
      expect(find.text('방명록을 남길 수 있는 때가 지났어요'), findsOneWidget);
      expect(find.text('방명록을 남겼어요'), findsNothing);
      expect(await _posts(tester, e), isEmpty);
      await end(tester, e);
    });

    testWidgets('이미 쓰거나 닫혀서 열 수 없는 기회로 열면 안내만 나온다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await _putTicket(e, 'a:j1', TicketKind.arrival, 'kr001', used: t1);
      });
      await _openWrite(tester, e, 'a:j1');
      expect(_closed, findsOneWidget);
      expect(find.text('방명록을 남길 수 있는 때가 지났어요'), findsOneWidget);
      expect(_input, findsNothing);
      expect(find.text('남기기'), findsNothing);
      // 뒤로는 된다
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('열기'), findsOneWidget);
      await end(tester, e);
    });
  });

  group('도착 화면의 방명록 쓰기', () {
    testWidgets('주 버튼 "방명록 쓰기"가 맨 위, 이어서 화집에 걸기·다음 목적지', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtGyeongbok);
      await _openArrival(tester, e, _journeyId);

      expect(_enabled(tester, '방명록 쓰기'), isTrue);
      final write = tester.getTopLeft(find.text('방명록 쓰기')).dy;
      final hang = tester.getTopLeft(find.text('화집에 걸기')).dy;
      final next = tester.getTopLeft(find.text('다음 목적지')).dy;
      expect(write, lessThan(hang));
      expect(hang, lessThan(next));
      // 주 버튼은 테라코타, 나머지는 보조(카드색)
      expect(tester.widget<GameButton>(find.widgetWithText(GameButton, '방명록 쓰기')).kind,
          GameButtonKind.primary);
      expect(tester.widget<GameButton>(find.widgetWithText(GameButton, '화집에 걸기')).kind,
          GameButtonKind.secondary);
      await end(tester, e);
    });

    testWidgets('누르면 이 도착의 쓰기 화면이 열리고, 쓰고 돌아오면 버튼이 꺼진다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtGyeongbok);
      await _openArrival(tester, e, _journeyId);

      await tester.tap(find.text('방명록 쓰기'));
      await transition(tester);
      await settle(tester, () => _tag.evaluate().isNotEmpty);
      expect(find.byType(GuestbookWriteScreen), findsOneWidget);
      expect(_tagText(tester), '경복궁 도착');

      await _writeAndSave(tester, '여기가 경복궁');
      expect(find.byType(GuestbookWriteScreen), findsNothing);
      expect(find.byType(ArrivalScreen), findsOneWidget);
      await settle(tester, () => !_enabled(tester, '방명록 쓰기'));
      expect(_enabled(tester, '방명록 쓰기'), isFalse);
      // 다른 버튼은 그대로 눌린다
      expect(_enabled(tester, '화집에 걸기'), isTrue);
      expect(_enabled(tester, '다음 목적지'), isTrue);
      expect((await _posts(tester, e)).single.scope, 'kr001');
      await end(tester, e);
    });

    testWidgets('첫 여정(내 동네 스케치) 도착: 쓰기 화면 태그는 "내 동네 스케치 도착"', (tester) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await _openArrival(tester, e, _journeyId);

      expect(_enabled(tester, '방명록 쓰기'), isTrue);
      await tester.tap(find.text('방명록 쓰기'));
      await transition(tester);
      await settle(tester, () => _tag.evaluate().isNotEmpty);
      expect(_tagText(tester), '내 동네 스케치 도착');
      await _writeAndSave(tester, '첫 스케치');
      expect((await _posts(tester, e)).single.scope, 'sketch');
      await end(tester, e);
    });

    testWidgets('이미 썼거나 기회가 없는 도착은 버튼이 꺼져 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.arriveAtGyeongbok();
        await e.svc.writeGuestbook('a:$_journeyId', '이미 씀', e.now);
      });
      await _openArrival(tester, e, _journeyId);
      expect(find.text('방명록 쓰기'), findsOneWidget);
      expect(_enabled(tester, '방명록 쓰기'), isFalse);
      await end(tester, e);

      // 기회가 만들어지기 전에 쌓인 옛 도착 기록 (기회 행이 없다)
      final old = UiEnv();
      await old.seed(tester, () => old.insertArrival('j1', 'kr001', DateTime.utc(2026, 11, 18, 3)));
      await _openArrival(tester, old, 'j1');
      expect(_enabled(tester, '방명록 쓰기'), isFalse);
      await end(tester, old);
    });

    testWidgets('다음 여정을 시작해 닫힌 도착은 버튼이 꺼져 있다', (tester) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.arriveAtGyeongbok();
        await e.svc.startJourney('kr003', e.now.add(const Duration(minutes: 1)), useFund: false);
      });
      await _openArrival(tester, e, _journeyId);
      expect(_enabled(tester, '방명록 쓰기'), isFalse);
      await end(tester, e);
    });
  });
}
