import 'package:doobal/app/profile_service.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/notification_permission.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/guestbook.dart';
import 'package:doobal/domain/journey.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/onboarding.dart';
import 'package:doobal/domain/prop.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/album/album_screen.dart';
import 'package:doobal/ui/album/painting_detail_screen.dart';
import 'package:doobal/ui/arrival/arrival_screen.dart';
import 'package:doobal/ui/common/confirm_sheet.dart';
import 'package:doobal/ui/common/toast.dart';
import 'package:doobal/ui/decorate/decorate_screen.dart';
import 'package:doobal/ui/guestbook/guestbook_write_screen.dart';
import 'package:doobal/ui/map/map_screen.dart';
import 'package:doobal/ui/map/map_sheets.dart';
import 'package:doobal/ui/note/note_screen.dart';
import 'package:doobal/ui/profile/profile_screen.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/settings/settings_screen.dart';
import 'package:doobal/ui/start/home_pick_screen.dart';
import 'package:doobal/ui/start/me_screen.dart';
import 'package:doobal/ui/start/permission_screen.dart';
import 'package:doobal/ui/start/welcome_screen.dart';
import 'package:doobal/ui/walk_record/walk_record_screen.dart';
import 'package:doobal/ui/walking/walking_screen.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

// 접근성 점검(M6): 휴대폰 글자 크기를 키웠을 때 화면이 넘치거나 글자가 칸 밖으로 잘리는지.
// 글자 크기를 1.3·1.6·2.0배로 두고 기준 화면(390×844)과 작은 화면(320×568)에서 화면마다 본다.
// 넘침 예외 말고도, 칸 높이를 고정해서 글자가 말없이 잘리는 곳을 `_Fit.check`가 같이 찾는다.
// 2.0배에서는 줄바꿈·스크롤로 읽히면 된다 (모든 줄이 완벽할 필요는 없다)

const _sizes = [Size(390, 844), Size(320, 568)];
const _scales = [1.3, 1.6, 2.0];

/// 한 화면을 한 크기·한 배율로 점검한다. 화면 상태를 바꿀 때마다 [check]로 모으고,
/// 끝나면 [verify]가 한꺼번에 따진다
class _Fit {
  _Fit(this.tester, this.size, this.scale) {
    // 휴대폰 글자 크기 설정과 같은 경로다 (MediaQuery.textScaler가 이 값을 읽는다).
    // 아래에서 올라오는 시트·확인 창·토스트도 같이 커진다
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // 프레임마다 나는 오류를 첫 하나만이 아니라 모두 모은다. expect 전에 꼭 되돌려 놓는다
    _previous = FlutterError.onError;
    FlutterError.onError = errors.add;
  }

  final WidgetTester tester;
  final Size size;
  final double scale;
  final errors = <FlutterErrorDetails>[];
  final problems = <String>[];
  void Function(FlutterErrorDetails)? _previous;
  var _scaleSeen = false;

  double get width => size.width;
  double get height => size.height;

  /// 지금 화면의 넘침 예외와 칸보다 큰 글자를 [step] 이름으로 모은다
  void check(String step) {
    final scaffold = find.byType(Scaffold);
    if (scaffold.evaluate().isNotEmpty) {
      _scaleSeen = true;
      final applied = MediaQuery.textScalerOf(tester.element(scaffold.first)).scale(10);
      if ((applied - 10 * scale).abs() > 1e-9) problems.add('$step: 글자 배율이 적용되지 않음');
    }
    for (final d in errors) {
      problems.add('$step: ${_describe(d)}');
    }
    errors.clear();
    for (final t in _clippedTexts(tester)) {
      problems.add('$step: $t');
    }
  }

  void restore() => FlutterError.onError = _previous;

  /// 모은 문제가 없어야 한다
  void verify() {
    expect(_scaleSeen, isTrue, reason: '점검한 화면이 없다');
    expect(problems, isEmpty, reason: '${size.width.round()}×${size.height.round()} · $scale배');
  }
}

/// 오류 한 줄 설명: `RenderFlex overflowed by 12 pixels on the bottom (Column file:...:123)`
String _describe(FlutterErrorDetails d) {
  final lines = d.toString().split('\n');
  final head = d.exceptionAsString().split('\n').first;
  final at = lines.indexWhere((l) => l.contains('relevant error-causing widget'));
  final where = at >= 0 && at + 1 < lines.length ? lines[at + 1].trim() : '';
  return '$head $where'.trim();
}

/// 한 줄 글자 상자(줄 높이)가 글자 모양보다 넉넉해서, 칸이 이만큼까지 낮아도 글자는 칸 안에 보인다
const _lineSlack = 1.3;

/// 글자가 자기 칸보다 커서 잘리거나 칸 밖으로 나가는 곳.
/// 칸 높이가 정해져 있으면 줄이 늘어도 넘침 예외 없이 말없이 잘려서 따로 찾는다.
/// 줄바꿈이 안 되는 한 줄 글은 칸보다 넓은지도 본다 (말줄임표로 줄이기로 한 글은 뺀다)
List<String> _clippedTexts(WidgetTester tester) {
  final found = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.hasSize) continue;
    // 아이콘 글자는 크기가 정해져 있어서 글자 배율과 상관없다
    if (element.findAncestorWidgetOfExactType<Icon>() != null) continue;
    final widget = element.widget as RichText;
    final text = widget.text.toPlainText();
    if (text.trim().isEmpty) continue;
    final box = render.size;
    // 글자가 차지하는 높이(줄 수만큼)와 가장 멀리 나간 오른쪽 끝
    final needHeight = render.getMinIntrinsicHeight(box.width);
    final right = render
        .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length))
        .fold(0.0, (m, b) => b.right > m ? b.right : m);
    final oneLine = widget.maxLines == 1 || !widget.softWrap;
    final tooTall = needHeight > box.height * _lineSlack + 0.5;
    final tooWide = oneLine && widget.overflow != TextOverflow.ellipsis && right > box.width + 1;
    if (tooTall || tooWide) {
      found.add('글자가 칸보다 큼 "$text" (칸 ${box.width.toStringAsFixed(0)}×'
          '${box.height.toStringAsFixed(0)}, 글자 ${right.toStringAsFixed(0)}×'
          '${needHeight.toStringAsFixed(0)})');
    }
  }
  return found;
}

/// 화면 하나를 크기 2 × 배율 3 = 6가지로 점검한다. [skip]이면 건너뛴다
/// (다른 작업이 고치는 중인 화면은 넘침만 보고서에 적고 여기서는 건너뛴다)
void _scaleCases(
  String name,
  Future<void> Function(WidgetTester tester, _Fit fit) body, {
  bool skip = false,
}) {
  group(name, () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('${size.width.round()}×${size.height.round()} · $scale배', (tester) async {
          final fit = _Fit(tester, size, scale);
          try {
            await body(tester, fit);
          } finally {
            fit.restore();
          }
          fit.verify();
        }, skip: skip);
      }
    }
  });
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// 시작 흐름을 [until] 단계 앞까지 채워 둔다 (그 단계가 지금 단계가 된다)
Future<void> _fillStart(WidgetTester tester, UiEnv e, OnboardingStep until) =>
    tester.runAsync(() async {
      final p = ProfileService(e.db, makeInstallId: () => '1' * 32);
      if (until.index > OnboardingStep.welcome.index) await p.confirmAge(t0);
      if (until.index > OnboardingStep.me.index) await p.saveMe('화가', Look.initial);
      if (until.index > OnboardingStep.home.index) await p.saveHome(sigungu.first);
    }) as Future<void>;

/// 시작 관문(DoobalApp)을 띄우고 [screen]이 뜨고 크로스페이드가 끝날 때까지
Future<void> _openStart(WidgetTester tester, UiEnv e, _Fit fit, Type screen) async {
  await pumpDoobal(tester, e, const DoobalApp(), width: fit.width, height: fit.height);
  await settle(tester, () => find.byType(screen).evaluate().isNotEmpty);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(screen), findsOneWidget);
}

/// 알림 권한을 흉내 낸다 ([granted]가 false면 휴대폰 설정에서 꺼진 상태)
class _FakeNotification implements NotificationPermission {
  _FakeNotification(this.granted);

  final bool granted;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<bool?> isGranted() async => granted;
}

/// 눌러서 [show]를 부르는 버튼 하나뿐인 화면 (시트·토스트를 띄워 볼 때)
class _Host extends StatelessWidget {
  const _Host(this.show);

  final void Function(BuildContext context) show;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (context) =>
                TextButton(onPressed: () => show(context), child: const Text('보이기')),
          ),
        ),
      );
}

/// 가려진 곳(스크롤 안)도 보이게 한 뒤 누른다
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// 목록 아래쪽에 있어 아직 만들어지지 않은 줄을 보일 때까지 스크롤한다
Future<void> _scrollTo(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);

/// 검색해서 (결과 목록도 점검하고) 결과 줄을 눌러 명소를 고른다
Future<void> _searchAndPick(WidgetTester tester, _Fit fit, String query, String id) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
  fit.check('검색 결과 "$query"');
  await tester.tap(find.byKey(ValueKey('result-$id')));
  await transition(tester);
  await settle(tester, () => false, tries: 6);
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('시작', () {
    _scaleCases('환영', (tester, fit) async {
      final e = UiEnv();
      await _openStart(tester, e, fit, WelcomeScreen);
      fit.check('환영');
      await end(tester, e);
    });

    _scaleCases('나', (tester, fit) async {
      final e = UiEnv();
      await _fillStart(tester, e, OnboardingStep.me);
      await _openStart(tester, e, fit, MeScreen);
      fit.check('닉네임이 비어 안내 글이 나옴');
      await tester.enterText(find.byType(TextField), '가나다라마바사아자차');
      await tester.pump();
      fit.check('닉네임 10자');
      await end(tester, e);
    });

    _scaleCases('출발 동네', (tester, fit) async {
      final e = UiEnv();
      await _fillStart(tester, e, OnboardingStep.home);
      await _openStart(tester, e, fit, HomePickScreen);
      fit.check('처음');
      // 시·도 칩을 눌러 목록을 펴고 하나 고른다
      final sido = sigungu.first.sido;
      await _tap(tester, find.text(sido));
      fit.check('시·도 칩을 눌러 목록이 펴짐');
      await _tap(tester, _key('sigungu-${sigungu.first.id}'));
      fit.check('시·군·구를 고름');
      // 이름 검색은 전국에서 찾아 시·도를 붙여 보여 준다
      final byLabel = sigungu.toList()..sort((a, b) => b.label.length - a.label.length);
      await tester.enterText(find.byType(TextField), byLabel.first.name);
      await tester.pump();
      fit.check('검색 결과');
      await tester.enterText(find.byType(TextField), '없는동네이름');
      await tester.pump();
      fit.check('검색 결과 없음');
      await end(tester, e);
    });

    _scaleCases('권한', (tester, fit) async {
      final e = UiEnv();
      await _fillStart(tester, e, OnboardingStep.permission);
      await _openStart(tester, e, fit, PermissionScreen);
      fit.check('처음');
      e.source.granted = false;
      await _tap(tester, find.text('허용하기').first);
      fit.check('걸음 거부 (설정에서 켜기)');
      e.source.granted = true;
      await _tap(tester, find.text('설정에서 켜기'));
      fit.check('걸음 허용됨');
      await _tap(tester, find.text('허용하기'));
      fit.check('알림까지 처리');
      await end(tester, e);
    });
  });

  group('지도', () {
    Future<void> openMap(WidgetTester tester, UiEnv e, _Fit fit) async {
      await openOnTop(tester, e, const MapScreen(),
          width: fit.width,
          height: fit.height,
          ready: () => find.byType(InteractiveViewer).evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
    }

    _scaleCases('명소 카드 (여기로 가기)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openMap(tester, e, fit);
      fit.check('처음');
      // 이름이 긴 명소
      await _searchAndPick(tester, fit, '인천', 'kr002');
      fit.check('명소 카드');
      await end(tester, e);
    });

    _scaleCases('명소 카드 (여정 중: 멈추기·바꾸기)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.ownPaintings({'kr054': Frame.gold});
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney('kr003', t1, useFund: false);
      });
      await openMap(tester, e, fit);
      fit.check('목적지 카드 (여정 멈추기)');
      await _searchAndPick(tester, fit, '군산', 'kr054');
      fit.check('얻은 그림의 카드 (목적지 바꾸기)');
      await end(tester, e);
    });
  });

  group('도착', () {
    Future<void> openArrival(WidgetTester tester, UiEnv e, _Fit fit, String id) async {
      await openOnTop(tester, e, ArrivalScreen(journeyId: id),
          width: fit.width,
          height: fit.height,
          ready: () => _key('arrival-card').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
      // 번지는 연출(1.9초)이 끝난 뒤
      await tester.pump(const Duration(seconds: 2));
    }

    final journeyId = 'j${t1.millisecondsSinceEpoch}';
    final day = DateTime.utc(2026, 11, 18, 3);

    _scaleCases('명소', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtGyeongbok);
      await openArrival(tester, e, fit, journeyId);
      fit.check('경복궁 첫 방문');
      await end(tester, e);
    });

    _scaleCases('명소 (이름이 길고 재방문 줄)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.insertArrival('j1', 'kr002', DateTime.utc(2026, 11, 10),
            frame: Frame.silver, km: 32.4);
        await e.insertArrival('j2', 'kr002', DateTime.utc(2026, 11, 12),
            visitNo: 2, prevFrame: Frame.silver, frame: Frame.silver, km: 21);
        await e.insertArrival('j3', 'kr002', day,
            visitNo: 3, prevFrame: Frame.silver, frame: Frame.silver, km: 22);
      });
      await openArrival(tester, e, fit, 'j3');
      fit.check('3번째 방문, 액자는 그대로예요');
      await end(tester, e);
    });

    _scaleCases('명소 (권역 소품 카드)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => e.insertArrival('j1', 'kr089', day));
      await openArrival(tester, e, fit, 'j1');
      expect(_key('arrival-prop'), findsOneWidget);
      fit.check('권역을 채운 소품 카드');
      await end(tester, e);
    });

    _scaleCases('첫 그림', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await openArrival(tester, e, fit, journeyId);
      fit.check('첫 그림');
      await end(tester, e);
    });
  });

  group('화집', () {
    Future<void> openAlbum(WidgetTester tester, UiEnv e, _Fit fit) async {
      await openOnTop(tester, e, const AlbumScreen(),
          width: fit.width,
          height: fit.height,
          ready: () => _key('wall-0').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
    }

    // 새 그림 점이 붙은 그림 몇 점을 얻고 벽에도 건다
    Future<void> seedAlbum(UiEnv e) async {
      await e.ownPaintings({
        'kr001': Frame.gold,
        'kr002': Frame.silver,
        'kr003': Frame.wood,
        'kr022': Frame.wood,
        sketchId: Frame.wood,
      }, seen: false);
      await e.svc.setWall(0, 'kr002');
      await e.svc.setWall(1, sketchId);
    }

    _scaleCases('그림 탭', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => seedAlbum(e));
      await openAlbum(tester, e, fit);
      fit.check('그림 탭 (새 그림 점)');
      // 이름이 긴 명소가 있는 권역
      await _tap(tester, _key('album-chip-gangwon'));
      fit.check('권역 칩 (강원)');
      await end(tester, e);
    });

    _scaleCases('소품 탭', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => seedAlbum(e));
      await openAlbum(tester, e, fit);
      await _tap(tester, _key('tab-props'));
      fit.check('소품 탭 맨 위');
      // 소품 27개가 칸별로 쭉 이어진다. 끝까지 내려 가며 본다
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView), Offset(0, -fit.height * 0.8));
        await tester.pump();
        fit.check('소품 탭 ${i + 1}번째 내림');
      }
      await end(tester, e);
    });

    _scaleCases('걸 그림 고르는 시트', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => seedAlbum(e));
      await openAlbum(tester, e, fit);
      await tester.longPress(_key('wall-2'));
      await transition(tester);
      expect(_key('pick-kr002'), findsOneWidget);
      fit.check('걸 그림 고르는 시트');
      await end(tester, e);
    });

    _scaleCases('그림 상세', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await e.insertArrival('j1', 'kr002', DateTime.utc(2026, 11, 10), km: 5);
        await e.insertArrival('j2', 'kr002', DateTime.utc(2026, 11, 12),
            visitNo: 2, prevFrame: Frame.wood, frame: Frame.silver, km: 25);
        await e.insertArrival('j3', 'kr002', DateTime.utc(2026, 11, 14),
            visitNo: 3, prevFrame: Frame.silver, frame: Frame.gold, km: 1234.5);
      });
      await openOnTop(tester, e, const PaintingDetailScreen(landmarkId: 'kr002'),
          width: fit.width,
          height: fit.height,
          ready: () => _key('detail-painting').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
      fit.check('그림 상세');
      await end(tester, e);
    });

    _scaleCases('첫 그림 상세', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, e.arriveAtSketch);
      await openOnTop(tester, e, const PaintingDetailScreen(landmarkId: sketchId),
          width: fit.width,
          height: fit.height,
          ready: () => _key('detail-first-pack').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
      fit.check('첫 그림 상세');
      await end(tester, e);
    });
  });

  group('방명록 쓰기', () {
    Future<void> openWrite(WidgetTester tester, UiEnv e, _Fit fit, String ticketId) async {
      await openOnTop(tester, e, GuestbookWriteScreen(ticketId: ticketId),
          width: fit.width,
          height: fit.height,
          ready: () =>
              _key('guestbook-tag').evaluate().isNotEmpty ||
              _key('guestbook-closed').evaluate().isNotEmpty);
      // 동의 줄이 정해질 때까지
      await settle(tester, () => false, tries: 6);
      expect(_key('guestbook-tag'), findsOneWidget);
    }

    Future<void> putTicket(UiEnv e, String id, TicketKind kind, String scope) =>
        e.db.into(e.db.guestbookTickets).insert(GuestbookTicketsCompanion.insert(
              id: id,
              kind: kind,
              scope: scope,
              openedUtc: t1.millisecondsSinceEpoch,
            ));

    _scaleCases('도착 기회 (처음: 동의 줄)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => putTicket(e, 'a:j1', TicketKind.arrival, 'kr002'));
      await openWrite(tester, e, fit, 'a:j1');
      expect(_key('guestbook-consent'), findsOneWidget);
      fit.check('빈 입력 칸');
      await tester.enterText(_key('guestbook-input'), '가' * rules.guestbookMaxChars);
      await tester.pump();
      fit.check('글자 수를 꽉 채움');
      // 금칙어 안내는 글자 수와 한 줄에 나란히 뜬다 (큰 글자에서는 안내가 줄바꿈된다)
      await tester.enterText(
          _key('guestbook-input'), '시발${'가' * (rules.guestbookMaxChars - 2)}');
      await tester.pump();
      expect(_key('guestbook-blocked'), findsOneWidget);
      fit.check('금칙어 안내 + 글자 수 꽉 참');
      await end(tester, e);
    });

    _scaleCases('걸음 숫자 기회', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => putTicket(e, 'm:12345', TicketKind.milestone, 'steps:12345'));
      await openWrite(tester, e, fit, 'm:12345');
      fit.check('남은 걸음이 붙은 태그');
      await end(tester, e);
    });
  });

  group('나의 정보', () {
    _scaleCases('나의 정보', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        for (var d = 0; d < 14; d++) {
          final day = '2026-11-${(18 - d).toString().padLeft(2, '0')}';
          await e.db.into(e.db.daySummaries).insertOnConflictUpdate(DaySummariesCompanion.insert(
                day: day,
                steps: 1200 * (d + 1),
                distanceM: 840.0 * (d + 1),
                countedSessions: 0,
              ));
        }
        await e.ownPaintings({'kr001': Frame.wood, 'kr002': Frame.silver, 'kr003': Frame.gold});
        await (e.db.update(e.db.travelFund)..where((t) => t.id.equals(1)))
            .write(const TravelFundCompanion(km: Value(1234.5)));
        await (e.db.update(e.db.profile)..where((t) => t.id.equals(1)))
            .write(const ProfileCompanion(nickname: Value('가나다라마바사아자차')));
      });
      await openOnTop(tester, e, const ProfileScreen(),
          width: fit.width,
          height: fit.height,
          ready: () => find.text('동행 도감').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
      fit.check('나의 정보');
      await end(tester, e);
    });
  });

  group('설정', () {
    Future<void> openSettings(
      WidgetTester tester,
      UiEnv e,
      _Fit fit, {
      List<Override> extra = const [],
    }) =>
        openOnTop(tester, e, const SettingsScreen(),
            width: fit.width,
            height: fit.height,
            extra: extra,
            ready: () =>
                find.text('권한 다시 열기').evaluate().isNotEmpty &&
                find.text('알림 받기').evaluate().isNotEmpty);

    _scaleCases('설정', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openSettings(tester, e, fit);
      fit.check('맨 위');
      // 목록 끝까지 내려 가며 본다
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), Offset(0, -fit.height * 0.8));
        await tester.pump();
        fit.check('${i + 1}번째 내림');
      }
      await end(tester, e);
    });

    _scaleCases('알림 (휴대폰 설정에서 꺼짐)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openSettings(tester, e, fit,
          extra: [notificationPermissionProvider.overrideWithValue(_FakeNotification(false))]);
      final blocked = find.text('휴대폰 설정에서 알림을 켜 주세요');
      await settle(tester, () => blocked.evaluate().isNotEmpty);
      await _scrollTo(tester, blocked);
      fit.check('권한 꺼짐 안내');
      await end(tester, e);
    });

    _scaleCases('계정 삭제 확인 창', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openSettings(tester, e, fit);
      await _scrollTo(tester, find.text('계정 삭제'));
      await _tap(tester, find.text('계정 삭제'));
      expect(find.text('계정을 삭제할까요?'), findsOneWidget);
      fit.check('첫 번째 확인 창');
      await _tap(tester, find.text('계속'));
      expect(find.text('정말 삭제할까요?'), findsOneWidget);
      fit.check('두 번째 확인 창');
      await end(tester, e);
    });

    _scaleCases('걸음 권한 토스트', (tester, fit) async {
      final e = UiEnv(source: FakeStepSource()..granted = false);
      await e.seed(tester);
      await openSettings(tester, e, fit);
      await _tap(tester, find.text('권한 다시 열기'));
      expect(find.textContaining('걸음 권한을 열지 못했어요'), findsOneWidget);
      fit.check('긴 토스트');
      await end(tester, e);
    });
  });

  group('노트', () {
    Future<void> openNote(WidgetTester tester, UiEnv e, _Fit fit) async {
      await openOnTop(tester, e, const NoteScreen(),
          width: fit.width,
          height: fit.height,
          ready: () => find.text('내 방명록').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 8);
    }

    Future<void> post(
      UiEnv e,
      String ticketId,
      String scope,
      String body,
      DateTime at, {
      PostStatus status = PostStatus.pending,
    }) =>
        e.db.into(e.db.guestbookPosts).insert(GuestbookPostsCompanion.insert(
              ticketId: ticketId,
              scope: scope,
              body: body,
              createdUtc: at.millisecondsSinceEpoch,
              status: status,
            ));

    _scaleCases('내 방명록 탭', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await post(e, 'a:j1', 'kr002', '인천 차이나타운에서 짜장면을 먹고 월미도까지 걸었어요. 바다가 좋아요', t1);
        await post(e, 'm:1234567', 'steps:1234567', '백이십만 걸음!',
            t1.add(const Duration(days: 1)),
            status: PostStatus.sent);
        await post(e, 'a:j0', 'sketch', '첫 그림', t1.subtract(const Duration(days: 2)));
      });
      await openNote(tester, e, fit);
      expect(find.text('백이십만 걸음!'), findsOneWidget);
      fit.check('내 방명록 탭');
      await end(tester, e);
    });

    _scaleCases('내 방명록 탭 (빈 상태)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openNote(tester, e, fit);
      expect(find.text('아직 남긴 방명록이 없어요'), findsOneWidget);
      fit.check('빈 상태');
      await end(tester, e);
    });

    _scaleCases('걷기 기록 탭', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        for (var i = 0; i < 3; i++) {
          final start = t1.add(Duration(hours: i, days: -i));
          await e.db.into(e.db.walkSessions).insert(WalkSessionsCompanion.insert(
                startUtc: Value<int>(start.millisecondsSinceEpoch),
                endUtc: start.add(const Duration(minutes: 40)).millisecondsSinceEpoch,
                steps: 12345 + i,
                distanceM: 8123.0 + i,
                runRatio: 0,
                qualified: true,
                counted: true,
              ));
        }
      });
      await openNote(tester, e, fit);
      await _tap(tester, _key('tab-walks'));
      await settle(tester, () => find.textContaining('12,345보').evaluate().isNotEmpty);
      expect(find.textContaining('12,345보'), findsWidgets);
      fit.check('걷기 기록 탭');
      await end(tester, e);
    });
  });

  group('걷기 기록', () {
    Future<void> openRecord(WidgetTester tester, UiEnv e, _Fit fit, {required bool review}) async {
      await openOnTop(
        tester,
        e,
        WalkRecordScreen(
          start: t1,
          end: t1.add(const Duration(minutes: 15)),
          ratioBefore: review ? null : 0.0,
          review: review,
        ),
        width: fit.width,
        height: fit.height,
        ready: () => find.text('기록을 정리하는 중').evaluate().isEmpty,
      );
      await settle(tester, () => false, tries: 8);
      // 진행 막대 연출(1.2초)이 끝난 뒤
      await tester.pump(const Duration(seconds: 2));
    }

    // 이름이 긴 목적지(엑스포과학공원 한빛탑)로 가는 중에 15분 걸었다
    Future<void> seedWalk(UiEnv e) async {
      await placeAt(e.db, nearGyeongbok, t0);
      await e.svc.startJourney('kr003', t1, useFund: false);
      e.source.records.add(walkRecord(t1, 15, 100));
    }

    _scaleCases('방금 마침', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => seedWalk(e));
      await openRecord(tester, e, fit, review: false);
      // 15분 × 100보는 1km를 넘어서 평균 줄과 1km 기록 줄도 같이 점검한다
      expect(find.text('1km 기록'), findsOneWidget);
      fit.check('걷기 기록 (진행 막대·긴 목적지 이름)');
      await end(tester, e);
    });

    _scaleCases('다시 보기', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await seedWalk(e);
        // 다시 보기는 동기화하지 않으니 저장돼 있어야 한다
        await e.svc.sync(t1.add(const Duration(minutes: 30)));
      });
      await openRecord(tester, e, fit, review: true);
      fit.check('걷기 기록 다시 보기');
      await end(tester, e);
    });
  });

  group('꾸미기', () {
    Future<void> openDecorate(WidgetTester tester, UiEnv e, _Fit fit) async {
      await openOnTop(tester, e, const DecorateScreen(),
          width: fit.width,
          height: fit.height,
          ready: () => _key('tab-hair').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
    }

    Future<void> ownProps(UiEnv e, List<String> ids) =>
        e.db.batch((b) => b.insertAll(e.db.propsOwned, [
              for (final id in ids) PropsOwnedCompanion.insert(propId: id, unlockedUtc: 1),
            ]));

    const tabs = ['hair', 'face', 'skin', 'cloth', 'hat', 'hand', 'bag', 'shoe', 'pet'];

    _scaleCases('모든 탭', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => ownProps(e, ['hat_02', 'cloth_02']));
      await openDecorate(tester, e, fit);
      for (final t in tabs) {
        await _tap(tester, _key('tab-$t'));
        fit.check('탭 $t');
      }
      await end(tester, e);
    });

    _scaleCases('머리 (직접 고르기·그라데이션)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openDecorate(tester, e, fit);
      await _tap(tester, _key('hair-custom'));
      fit.check('머리 직접 고르기');
      await _tap(tester, _key('hair-gradient'));
      await _tap(tester, _key('grad-custom'));
      fit.check('그라데이션 직접 고르기');
      await end(tester, e);
    });

    _scaleCases('피부 (직접 고르기)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openDecorate(tester, e, fit);
      await _tap(tester, _key('tab-skin'));
      await _tap(tester, _key('skin-custom'));
      fit.check('피부 직접 고르기');
      await end(tester, e);
    });

    _scaleCases('소품 (모자: 잠긴 소품 토스트)', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () => ownProps(e, ['hat_02']));
      await openDecorate(tester, e, fit);
      await _tap(tester, _key('tab-hat'));
      await _tap(tester, _key('prop-hat_02'));
      fit.check('모자 하나를 끼움');
      // 잠긴 소품을 누르면 얻는 방법이 토스트로 나온다
      final locked = props.firstWhere(
          (p) => p.slot == 'hat' && p.kind != PropUnlockKind.initial && p.id != 'hat_02');
      await _tap(tester, _key('prop-${locked.id}'));
      fit.check('잠긴 소품 토스트');
      await end(tester, e);
    });

    _scaleCases('저장하지 않고 나가기 시트', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await openDecorate(tester, e, fit);
      await _tap(tester, _key('hair-3'));
      await tester.tap(find.byTooltip('뒤로'));
      await transition(tester);
      expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
      fit.check('나가기 확인 시트');
      await end(tester, e);
    });
  });

  group('공용 시트·토스트', () {
    Future<void> show(WidgetTester tester, UiEnv e, _Fit fit, void Function(BuildContext) f) async {
      await openOnTop(tester, e, _Host(f), width: fit.width, height: fit.height);
      await tester.tap(find.text('보이기'));
      await transition(tester);
    }

    _scaleCases('확인 시트: 목적지 바꾸기', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await show(tester, e, fit, showChangeSheet);
      expect(find.text('바꾸기'), findsOneWidget);
      fit.check('목적지 바꾸기');
      await end(tester, e);
    });

    _scaleCases('경비 시트', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await show(tester, e, fit, (c) => showFundSheet(c, 1234.5));
      expect(find.text('더하기'), findsOneWidget);
      fit.check('경비 시트');
      await end(tester, e);
    });

    _scaleCases('멈추기 시트', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await show(tester, e, fit, (c) => showStopSheet(c, rules.travelFundCapKm));
      expect(find.text('멈추기'), findsOneWidget);
      fit.check('멈추기 시트');
      await end(tester, e);
    });

    _scaleCases('확인 시트: 꾸미기 나가기', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await show(
          tester, e, fit, (c) => showConfirmSheet(c, '저장하지 않고 나갈까요?', '나가기', '계속 꾸미기'));
      expect(find.text('계속 꾸미기'), findsOneWidget);
      fit.check('꾸미기 나가기');
      await end(tester, e);
    });

    _scaleCases('토스트', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await show(tester, e, fit, (c) => showToast(c, '걸음 권한을 열지 못했어요. 건강 앱 설정에서 켜 주세요'));
      expect(find.textContaining('걸음 권한을'), findsOneWidget);
      fit.check('긴 토스트');
      await end(tester, e);
    });
  });

  // 쉼터·걷는 중은 다른 작업이 크게 고치는 중이라 이 점검에서 고치지 않는다. 그 작업이 끝나면
  // skip을 빼서 같이 점검한다 (넘침 예외는 없다. 쉼터는 이름표가 출발하기 버튼과 겹쳐 보인다)
  group('쉼터·걷는 중 (건너뜀)', () {
    _scaleCases('쉼터', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester);
      await pumpDoobal(tester, e, const DoobalApp(), width: fit.width, height: fit.height);
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await settle(tester, () => false, tries: 6);
      expect(find.byType(RestScreen), findsOneWidget);
      fit.check('쉼터');
      await end(tester, e);
    }, skip: true);

    _scaleCases('걷는 중', (tester, fit) async {
      final e = UiEnv();
      await e.seed(tester, () async {
        await placeAt(e.db, nearGyeongbok, t0);
        await e.svc.startJourney('kr003', t1, useFund: false);
      });
      await pumpDoobal(tester, e, const DoobalApp(), width: fit.width, height: fit.height);
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      await tester.tap(find.text('출발하기'));
      await transition(tester);
      await settle(tester, () => false, tries: 8);
      expect(find.byType(WalkingScreen), findsOneWidget);
      fit.check('걷는 중');
      await end(tester, e);
    }, skip: true);
  });
}
