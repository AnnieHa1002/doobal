import 'dart:convert';

import 'package:doobal/app/auto_sync.dart';
import 'package:doobal/app/profile_service.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/data/live_steps.dart';
import 'package:doobal/data/notification_permission.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/onboarding.dart';
import 'package:doobal/domain/sigungu.dart';
import 'package:doobal/domain/sketch.dart';
import 'package:doobal/domain/sky.dart';
import 'package:doobal/main.dart';
import 'package:doobal/ui/common/game_button.dart';
import 'package:doobal/ui/common/palette.dart';
import 'package:doobal/ui/rest/rest_screen.dart';
import 'package:doobal/ui/scene/sky_painter.dart';
import 'package:doobal/ui/start/home_pick_screen.dart';
import 'package:doobal/ui/start/me_screen.dart';
import 'package:doobal/ui/start/permission_screen.dart';
import 'package:doobal/ui/start/start_gate.dart';
import 'package:doobal/ui/start/welcome_screen.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../app/helpers.dart';
import '../domain/helpers.dart';
import 'ui_env.dart';

class _FakeNotification implements NotificationPermission {
  _FakeNotification(this.granted);

  final bool granted;
  var requests = 0;

  @override
  Future<bool> requestPermission() async {
    requests++;
    return granted;
  }

  @override
  Future<bool?> isGranted() async => requests == 0 ? null : granted;
}

/// 묻다가 예외가 나는 걸음 출처 (건강 앱이 없는 기기)
class _ThrowingSource extends FakeStepSource {
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    throw StateError('건강 앱이 없다');
  }
}

/// 걸음 센서 권한을 묻다가 예외가 나는 기기 (동작 정보 채널이 없다)
class _ThrowingLive extends FakeLiveSteps {
  _ThrowingLive() : super(permitted: false);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    throw StateError('채널이 없다');
  }
}

/// 앱(DoobalApp = 시작 관문)을 폰 크기로 띄운다. [extra]는 e.overrides 뒤에 덧붙인다
Future<void> _pump(
  WidgetTester tester,
  UiEnv e, {
  List<Override> extra = const [],
  double height = 844,
}) async {
  phone(tester, height: height);
  await tester.pumpWidget(
    ProviderScope(overrides: [...e.overrides, ...extra], child: const DoobalApp()),
  );
}

/// 시작 흐름을 [until] 단계 앞까지 채워 둔다 (그 단계가 지금 단계가 된다)
Future<void> _fill(WidgetTester tester, UiEnv e, OnboardingStep until) =>
    tester.runAsync(() async {
      final p = ProfileService(e.db, makeInstallId: () => '1' * 32);
      if (until.index > OnboardingStep.welcome.index) await p.confirmAge(t0);
      if (until.index > OnboardingStep.me.index) await p.saveMe('화가', Look.initial);
      if (until.index > OnboardingStep.home.index) await p.saveHome(sigungu.first);
    }) as Future<void>;

/// [screen]이 뜰 때까지 기다리고, 크로스페이드(0.25초)가 끝나 앞 화면이 빠질 때까지 흘려 보낸다
Future<void> _arrive(WidgetTester tester, Type screen) async {
  await settle(tester, () => find.byType(screen).evaluate().isNotEmpty);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(screen), findsOneWidget);
}

Future<ProfileRow> _profile(WidgetTester tester, UiEnv e) async =>
    (await tester.runAsync(() => ProfileService(e.db).row()))!;

/// 앱을 뒤로 보냈다가 앞으로 가져온다 (휴대폰 설정에 다녀오는 것과 같다)
void _leaveAndReturn(WidgetTester tester) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

Finder _button(String label) => find.widgetWithText(GameButton, label);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<GameButton>(_button(label)).onPressed != null;

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(_button(label));
  await tester.pump();
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('관문: 값이 차는 만큼 다음 단계', () {
    testWidgets('빈 DB → 환영 (쉼터·동기화는 아직)', (tester) async {
      final e = UiEnv();
      await _pump(tester, e);
      await _arrive(tester, WelcomeScreen);

      expect(find.byType(AutoSync), findsNothing);
      expect(find.byType(RestScreen), findsNothing);
      await end(tester, e);
    });

    testWidgets('만 14세 확인이 있으면 → 나', (tester) async {
      final e = UiEnv();
      await _fill(tester, e, OnboardingStep.me);
      await _pump(tester, e);
      await _arrive(tester, MeScreen);
      expect(find.byType(AutoSync), findsNothing);
      await end(tester, e);
    });

    testWidgets('닉네임까지 있으면 → 출발 동네', (tester) async {
      final e = UiEnv();
      await _fill(tester, e, OnboardingStep.home);
      await _pump(tester, e);
      await _arrive(tester, HomePickScreen);
      expect(find.byType(AutoSync), findsNothing);
      await end(tester, e);
    });

    testWidgets('출발 동네까지 있으면 → 권한', (tester) async {
      final e = UiEnv();
      await _fill(tester, e, OnboardingStep.permission);
      await _pump(tester, e);
      await _arrive(tester, PermissionScreen);
      expect(find.byType(AutoSync), findsNothing);
      await end(tester, e);
    });

    testWidgets('다 차 있으면 → 쉼터 (AutoSync와 함께)', (tester) async {
      final e = UiEnv();
      await e.seed(tester);
      await _pump(tester, e);
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);

      expect(find.byType(RestScreen), findsOneWidget);
      expect(find.byType(AutoSync), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      await end(tester, e);
    });

    testWidgets('단계가 바뀌면 0.25초 크로스페이드: 도중에는 앞뒤 화면이 함께 있다', (tester) async {
      final e = UiEnv();
      await _pump(tester, e);
      await _arrive(tester, WelcomeScreen);
      final switcher = find.descendant(
        of: find.byType(StartGate),
        matching: find.byType(AnimatedSwitcher),
      );
      expect(tester.widget<AnimatedSwitcher>(switcher).duration, const Duration(milliseconds: 250));

      await tester.tap(_button('만 14세 이상이에요'));
      await settle(tester, () => find.byType(MeScreen).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(MeScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(MeScreen), findsOneWidget);
      await end(tester, e);
    });
  });

  group('① 환영', () {
    testWidgets('앱 이름·소개·주 버튼 하나만 있고 [아니요]는 없다', (tester) async {
      final e = UiEnv();
      await _pump(tester, e);
      await _arrive(tester, WelcomeScreen);

      expect(find.text('두발: 여행하는 예술가'), findsOneWidget);
      expect(find.text('걸은 만큼 내 화가가 실제 명소로 여행해요'), findsOneWidget);
      expect(find.byType(GameButton), findsOneWidget);
      expect(find.text('만 14세 이상이에요'), findsOneWidget);
      expect(find.textContaining('아니요'), findsNothing);
      await end(tester, e);
    });

    testWidgets('배경은 앱 하늘 그리기를 밤 단계로 고정해 쓴다 (달이 뜬 밤하늘)', (tester) async {
      final e = UiEnv();
      await _pump(tester, e);
      await _arrive(tester, WelcomeScreen);

      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SkyPainter),
      );
      final painter = paint.painter! as SkyPainter;
      expect(painter.sky, skyLookOf(const SkyMix(SkyPhase.night, SkyPhase.night, 0), rules));
      expect(painter.sky.stars, 1.0);
      expect(painter.celestial.body, SkyBody.moon);
      await end(tester, e);
    });

    testWidgets('버튼을 누르면 확인 시각과 설치 번호가 기기 DB에 남고 → 나', (tester) async {
      final e = UiEnv();
      await _pump(tester, e);
      await _arrive(tester, WelcomeScreen);
      expect(await tester.runAsync(() => ProfileService(e.db).row()), isNull);

      await _tapButton(tester, '만 14세 이상이에요');
      await _arrive(tester, MeScreen);

      final r = await _profile(tester, e);
      expect(r.ageConfirmedAt, e.now.millisecondsSinceEpoch);
      expect(r.installId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect([r.nickname, r.look, r.homeLat, r.onboardedAt], everyElement(isNull));
      await end(tester, e);
    });

    testWidgets('확인 전에는 권한을 묻지 않고 설치 번호·동기화 상태도 없다', (tester) async {
      final e = UiEnv();
      final notice = _FakeNotification(true);
      await _pump(tester, e, extra: [notificationPermissionProvider.overrideWithValue(notice)]);
      await _arrive(tester, WelcomeScreen);
      await tester.pump(const Duration(seconds: 2));

      expect(e.source.permissionRequests, 0);
      expect(notice.requests, 0);
      expect(await tester.runAsync(() => ProfileService(e.db).row()), isNull);
      expect(await tester.runAsync(() => e.db.select(e.db.syncState).get()), isEmpty);
      await end(tester, e);
    });
  });

  group('② 나', () {
    Future<void> openMe(WidgetTester tester, UiEnv e, {double height = 844}) async {
      await _fill(tester, e, OnboardingStep.me);
      await _pump(tester, e, height: height);
      await _arrive(tester, MeScreen);
    }

    testWidgets('닉네임이 비거나 1자면 버튼이 꺼지고 테라코타 안내가 나온다', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);
      final hint = find.text('${rules.nicknameMin}~${rules.nicknameMax}자로 지어 주세요');

      expect(_enabled(tester, '이 모습으로'), isFalse);
      expect(hint, findsOneWidget);
      // 빨간색이 아니라 테라코타
      expect(tester.widget<Text>(hint).style!.color, Palette.terracotta);

      await tester.enterText(find.byType(TextField), '가');
      await tester.pump();
      expect(_enabled(tester, '이 모습으로'), isFalse);
      expect(hint, findsOneWidget);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(_enabled(tester, '이 모습으로'), isFalse);
      await end(tester, e);
    });

    testWidgets('2자 이상이면 버튼이 켜지고 안내가 사라진다', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);

      await tester.enterText(find.byType(TextField), '가나');
      await tester.pump();
      expect(_enabled(tester, '이 모습으로'), isTrue);
      expect(find.textContaining('자로 지어 주세요'), findsNothing);

      // 앞뒤 공백을 자르면 1자인 것은 아직 안 된다
      await tester.enterText(find.byType(TextField), ' 가 ');
      await tester.pump();
      expect(_enabled(tester, '이 모습으로'), isFalse);
      await end(tester, e);
    });

    testWidgets('입력은 config 최대 글자 수까지만 들어간다', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);
      expect(tester.widget<TextField>(find.byType(TextField)).maxLength, rules.nicknameMax);

      await tester.enterText(find.byType(TextField), '가나다라마바사아자차카타');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '가나다라마바사아자차');
      expect(_enabled(tester, '이 모습으로'), isTrue);
      await end(tester, e);
    });

    testWidgets('머리 모양 6칸과 머리색 견본 10개, 안내 한 줄 (직접 고르기 칸은 아직 없다)', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);

      for (var i = 1; i <= 6; i++) {
        expect(find.byKey(ValueKey('hair-$i')), findsOneWidget);
        expect(find.descendant(of: find.byKey(ValueKey('hair-$i')), matching: find.text('$i')),
            findsOneWidget);
      }
      expect(find.byKey(const ValueKey('hair-7')), findsNothing);
      for (final s in hairSwatches) {
        expect(find.byKey(ValueKey('swatch-${s.id}')), findsOneWidget);
      }
      expect(hairSwatches, hasLength(10));
      expect(find.text('얼굴·피부·옷은 나중에 꾸미기에서 바꿀 수 있어요'), findsOneWidget);
      expect(find.textContaining('직접'), findsNothing);
      await end(tester, e);
    });

    testWidgets('견본 이름이 접근성 label이고 고른 견본에는 체크가 붙는다', (tester) async {
      final handle = tester.ensureSemantics();
      final e = UiEnv();
      await openMe(tester, e);

      for (final s in hairSwatches) {
        expect(find.bySemanticsLabel(s.name), findsOneWidget, reason: s.name);
      }
      Finder check(int id) => find.descendant(
          of: find.byKey(ValueKey('swatch-$id')), matching: find.byIcon(Icons.check));
      // 처음에는 견본 1
      expect(check(1), findsOneWidget);
      expect(check(7), findsNothing);

      await tester.tap(find.byKey(const ValueKey('swatch-7')));
      await tester.pump();
      expect(check(7), findsOneWidget);
      expect(check(1), findsNothing);
      handle.dispose();
      await end(tester, e);
    });

    testWidgets('고른 머리 모양은 미리보기와 선택 표시에 반영된다', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);

      Color fill(int i) => (tester
              .widget<Container>(find.descendant(
                  of: find.byKey(ValueKey('hair-$i')), matching: find.byType(Container)))
              .decoration! as BoxDecoration)
          .color!;
      expect(fill(1), Palette.terracotta);
      await tester.tap(find.byKey(const ValueKey('hair-4')));
      await tester.pump();
      expect(fill(4), Palette.terracotta);
      expect(fill(1), Palette.paper);
      await end(tester, e);
    });

    testWidgets('"이 모습으로"를 누르면 닉네임(공백 자름)과 look JSON이 저장되고 → 출발 동네', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);

      await tester.enterText(find.byType(TextField), ' 화가 ');
      await tester.tap(find.byKey(const ValueKey('hair-4')));
      await tester.tap(find.byKey(const ValueKey('swatch-7')));
      await tester.pump();
      await _tapButton(tester, '이 모습으로');
      await _arrive(tester, HomePickScreen);

      final r = await _profile(tester, e);
      expect(r.nickname, '화가');
      expect(Look.fromJson(jsonDecode(r.look!) as Map<String, dynamic>),
          const Look(hair: 4, hairColor: SwatchHairColor(7)));
      // 앞 단계 기록은 그대로
      expect((r.ageConfirmedAt, r.installId), (t0.millisecondsSinceEpoch, '1' * 32));
      await end(tester, e);
    });

    testWidgets('아무것도 안 고르면 기본 모습(머리 1, 견본 1)이 저장된다', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);

      await tester.enterText(find.byType(TextField), '화가');
      await tester.pump();
      await _tapButton(tester, '이 모습으로');
      await _arrive(tester, HomePickScreen);

      final r = await _profile(tester, e);
      expect(Look.fromJson(jsonDecode(r.look!) as Map<String, dynamic>), Look.initial);
      await end(tester, e);
    });

    testWidgets('꺼진 버튼을 눌러도 저장되지 않는다', (tester) async {
      final e = UiEnv();
      await openMe(tester, e);

      await tester.tap(_button('이 모습으로'));
      await tester.pump(const Duration(milliseconds: 100));
      expect((await _profile(tester, e)).nickname, isNull);
      expect(find.byType(MeScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('작은 화면(높이 568)에서도, 키보드(300)가 올라와도 넘치지 않는다', (tester) async {
      final e = UiEnv();
      await openMe(tester, e, height: 568);
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(MeScreen), findsOneWidget);
      await end(tester, e);
    });
  });

  group('③ 출발 동네', () {
    final sidos = sidoList(sigungu);
    Sigungu byLabel(String label) => sigungu.singleWhere((s) => s.label == label);

    Future<void> openHome(WidgetTester tester, UiEnv e, {double height = 844}) async {
      await _fill(tester, e, OnboardingStep.home);
      await _pump(tester, e, height: height);
      await _arrive(tester, HomePickScreen);
    }

    testWidgets('처음에는 이정표 "출발 동네", 시·도 칩 16개, 안내, 꺼진 버튼', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);

      expect(sidos, hasLength(16));
      for (final s in sidos) {
        expect(find.text(s), findsOneWidget, reason: '칩 $s');
      }
      expect(find.text('출발 동네'), findsOneWidget);
      expect(find.text('동네 이름으로 찾기'), findsOneWidget);
      expect(find.text('지금 사는 곳이 아니어도 괜찮아요. 위치 정보는 쓰지 않아요'), findsOneWidget);
      expect(_enabled(tester, '여기서 출발'), isFalse);
      // 시·도를 안 골랐으니 목록은 없다
      expect(find.byKey(const ValueKey('sigungu-11110')), findsNothing);
      await end(tester, e);
    });

    testWidgets('칩을 누르면 그 시·도의 시·군·구가 이름(name)으로 나온다', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);

      await tester.tap(find.text('서울'));
      await tester.pump();
      expect(find.text('종로구'), findsOneWidget);
      expect(find.text('서울 종로구'), findsNothing);
      expect(find.byKey(const ValueKey('sigungu-11110')), findsOneWidget);
      // 다른 시·도의 구는 없다
      expect(find.text('수원시'), findsNothing);

      // 다른 칩을 누르면 그 시·도로 바뀐다
      await tester.tap(find.text('경기'));
      await tester.pump();
      expect(find.text('수원시'), findsOneWidget);
      expect(find.text('종로구'), findsNothing);

      // 같은 칩을 다시 누르면 목록이 닫힌다
      await tester.tap(find.text('경기'));
      await tester.pump();
      expect(find.text('수원시'), findsNothing);
      await end(tester, e);
    });

    testWidgets('목록에서 고르면 이정표에 label이 뜨고, 고른 줄이 강조되며, 버튼이 켜진다', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);
      final jung = byLabel('서울 중구');

      await tester.tap(find.text('서울'));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('sigungu-${jung.id}')));
      await tester.pump();

      // 이정표: 시·도를 붙인 이름
      expect(find.text('서울 중구'), findsOneWidget);
      expect(find.text('출발 동네'), findsNothing);
      expect(_enabled(tester, '여기서 출발'), isTrue);
      // 고른 줄: 체크와 굵은 글자
      final row = find.byKey(ValueKey('sigungu-${jung.id}'));
      expect(find.descendant(of: row, matching: find.byIcon(Icons.check)), findsOneWidget);
      final name = tester.widget<Text>(find.descendant(of: row, matching: find.text('중구')));
      expect(name.style!.fontWeight, FontWeight.w700);
      final other = find.byKey(const ValueKey('sigungu-11110'));
      expect(find.descendant(of: other, matching: find.byIcon(Icons.check)), findsNothing);
      await end(tester, e);
    });

    testWidgets('검색 "수원" → 칩이 사라지고 전국 결과(label) → 고르면 이정표·버튼 → 저장', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);
      final suwon = byLabel('경기 수원시');

      await tester.enterText(find.byType(TextField), '수원');
      await tester.pump();
      expect(find.text('서울'), findsNothing);
      expect(find.text('경기'), findsNothing);
      expect(find.text('경기 수원시'), findsOneWidget);
      expect(_enabled(tester, '여기서 출발'), isFalse);

      await tester.tap(find.text('경기 수원시'));
      await tester.pump();
      // 이정표와 목록 줄 두 곳
      expect(find.text('경기 수원시'), findsNWidgets(2));
      expect(_enabled(tester, '여기서 출발'), isTrue);

      await _tapButton(tester, '여기서 출발');
      await _arrive(tester, PermissionScreen);

      final r = await _profile(tester, e);
      expect((r.homeId, r.homeName, r.homeLat, r.homeLng),
          (suwon.id, '경기 수원시', suwon.lat, suwon.lng));
      // 앞 단계 값은 그대로
      expect(r.nickname, '화가');
      await end(tester, e);
    });

    testWidgets('같은 이름의 구는 검색해도 시·도를 붙여 가린다 ("서울중구"는 하나)', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);

      await tester.enterText(find.byType(TextField), '중구');
      await tester.pump();
      expect(find.text('서울 중구'), findsOneWidget);
      expect(find.text('부산 중구'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '서울중구');
      await tester.pump();
      expect(find.text('서울 중구'), findsOneWidget);
      expect(find.text('부산 중구'), findsNothing);
      await end(tester, e);
    });

    testWidgets('없는 동네는 안내만, 검색어를 지우면 칩이 돌아온다', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);

      await tester.enterText(find.byType(TextField), '없는동네');
      await tester.pump();
      expect(find.text('찾는 동네가 없어요'), findsOneWidget);
      expect(find.text('서울'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('찾는 동네가 없어요'), findsNothing);
      expect(find.text('서울'), findsOneWidget);
      expect(find.text('제주'), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('공백뿐인 검색어는 검색이 아니다 (칩이 그대로)', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(find.text('서울'), findsOneWidget);
      expect(find.text('찾는 동네가 없어요'), findsNothing);
      await end(tester, e);
    });

    testWidgets('한 시·군·구만 있는 세종도 고를 수 있다 (이정표는 "세종")', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);

      await tester.tap(find.text('세종'));
      await tester.pump();
      await tester.tap(find.text('세종시'));
      await tester.pump();
      expect(find.text('세종'), findsNWidgets(2));
      expect(_enabled(tester, '여기서 출발'), isTrue);
      await end(tester, e);
    });

    testWidgets('꺼진 버튼을 눌러도 저장되지 않는다', (tester) async {
      final e = UiEnv();
      await openHome(tester, e);

      await tester.tap(_button('여기서 출발'));
      await tester.pump(const Duration(milliseconds: 100));
      expect((await _profile(tester, e)).homeLat, isNull);
      expect(find.byType(HomePickScreen), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('작은 화면에서 긴 목록(경기)을 펴고 키보드가 올라와도 넘치지 않는다', (tester) async {
      final e = UiEnv();
      await openHome(tester, e, height: 568);
      await tester.tap(find.text('경기'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await end(tester, e);
    });
  });

  group('④ 권한', () {
    Future<void> openPermission(
      WidgetTester tester,
      UiEnv e, {
      List<Override> extra = const [],
    }) async {
      await _fill(tester, e, OnboardingStep.permission);
      await _pump(tester, e, extra: extra);
      await _arrive(tester, PermissionScreen);
    }

    Finder allow() => _button('허용하기');

    testWidgets('걸음(필수)·알림(선택) 두 줄과 이유, 꺼진 "쉼터로 가기". 화면이 떠도 아직 묻지 않는다',
        (tester) async {
      final e = UiEnv();
      final notice = _FakeNotification(true);
      await openPermission(tester, e,
          extra: [notificationPermissionProvider.overrideWithValue(notice)]);

      expect(find.text('걸음'), findsOneWidget);
      expect(find.text('알림'), findsOneWidget);
      expect(find.text('필수'), findsOneWidget);
      expect(find.text('선택'), findsOneWidget);
      expect(find.text('걸은 만큼 여행하려면 걸음 기록이 필요해요'), findsOneWidget);
      expect(find.text('도착·방명록 기회 같은 소식만, 하루 ${rules.notificationDailyMax}개까지'),
          findsOneWidget);
      expect(allow(), findsNWidgets(2));
      expect(_enabled(tester, '쉼터로 가기'), isFalse);
      // 위치 권한 줄은 없다
      expect(find.textContaining('위치'), findsNothing);
      expect(e.source.permissionRequests, 0);
      expect(notice.requests, 0);
      await end(tester, e);
    });

    testWidgets('걸음을 허용하면 줄에 허용됨이 뜨고 "쉼터로 가기"가 켜진다', (tester) async {
      final e = UiEnv();
      await openPermission(tester, e);

      await tester.tap(allow().first);
      await tester.pump();
      await tester.pump();
      expect(e.source.permissionRequests, 1);
      expect(find.text('허용됨'), findsOneWidget);
      // 걸음 줄 버튼은 사라지고 알림 줄 버튼만 남는다
      expect(allow(), findsOneWidget);
      expect(_enabled(tester, '쉼터로 가기'), isTrue);
      await end(tester, e);
    });

    group('걸음 센서 권한 (안드로이드 ACTIVITY_RECOGNITION): health 권한 다음에 이어서 묻는다', () {
      /// 지금 앱 실행 중 센서 권한을 거부당했다고 적혀 있는가
      bool denied(WidgetTester tester) =>
          ProviderScope.containerOf(tester.element(find.byType(PermissionScreen)))
              .read(liveDeniedProvider);

      testWidgets('걸음 "허용하기" 하나로 health 다음에 센서 권한도 묻고, 둘 다 허용되면 갈 수 있다', (tester) async {
        final e = UiEnv();
        e.live.permitted = false;
        await openPermission(tester, e);
        expect(e.live.permissionRequests, 0);

        await tester.tap(allow().first);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 1);
        expect(e.live.permissionRequests, 1);
        expect(find.text('허용됨'), findsOneWidget);
        expect(_enabled(tester, '쉼터로 가기'), isTrue);
        expect(denied(tester), isFalse);
        await end(tester, e);
      });

      testWidgets('센서 권한을 거부해도 걸음 줄은 허용됨이고 다음으로 갈 수 있다 (거부는 기억해 둔다)', (tester) async {
        final e = UiEnv();
        e.live
          ..permitted = false
          ..grantOnRequest = false;
        await openPermission(tester, e);

        await tester.tap(allow().first);
        await tester.pump();
        await tester.pump();
        expect(e.live.permissionRequests, 1);
        expect(find.text('허용됨'), findsOneWidget);
        expect(_button('설정에서 켜기'), findsNothing);
        expect(_enabled(tester, '쉼터로 가기'), isTrue);
        expect(denied(tester), isTrue);
        await end(tester, e);
      });

      testWidgets('health를 거부하면 센서 권한은 묻지 않고, 나중에 허용되면 그때 묻는다', (tester) async {
        final e = UiEnv();
        e.live.permitted = false;
        e.source.granted = false;
        await openPermission(tester, e);

        await tester.tap(allow().first);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 1);
        expect(e.live.permissionRequests, 0);

        e.source.granted = true;
        await tester.tap(_button('설정에서 켜기'));
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 2);
        expect(e.live.permissionRequests, 1);
        expect(_enabled(tester, '쉼터로 가기'), isTrue);
        await end(tester, e);
      });

      testWidgets('이미 센서 권한이 있으면(iOS 포함) 다시 묻지 않는다', (tester) async {
        final e = UiEnv();
        await openPermission(tester, e);

        await tester.tap(allow().first);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 1);
        expect(e.live.permissionRequests, 0);
        expect(_enabled(tester, '쉼터로 가기'), isTrue);
        expect(denied(tester), isFalse);
        await end(tester, e);
      });

      testWidgets('센서 권한을 묻다가 예외가 나도 걸음 줄은 허용됨이다 (거부로 적지 않는다)', (tester) async {
        final live = _ThrowingLive();
        final e = UiEnv(live: live);
        await openPermission(tester, e);

        await tester.tap(allow().first);
        await tester.pump();
        await tester.pump();
        expect(live.permissionRequests, 1);
        expect(find.text('허용됨'), findsOneWidget);
        expect(_enabled(tester, '쉼터로 가기'), isTrue);
        expect(denied(tester), isFalse);
        await end(tester, e);
      });
    });

    testWidgets('걸음을 거부하면 "설정에서 켜기"가 나오고 다음으로 못 간다', (tester) async {
      final e = UiEnv();
      e.source.granted = false;
      await openPermission(tester, e);

      await tester.tap(allow().first);
      await tester.pump();
      await tester.pump();
      expect(e.source.permissionRequests, 1);
      expect(_button('설정에서 켜기'), findsOneWidget);
      expect(find.text('허용됨'), findsNothing);
      // 걸음 줄의 "허용하기"는 "설정에서 켜기"로 바뀌었다
      expect(allow(), findsOneWidget);
      expect(_enabled(tester, '쉼터로 가기'), isFalse);

      await tester.tap(_button('쉼터로 가기'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect((await _profile(tester, e)).onboardedAt, isNull);
      expect(find.byType(PermissionScreen), findsOneWidget);

      // 안드로이드 쪽(iOS가 아닌 쪽): "설정에서 켜기"는 앱 설정을 열지 않고 요청을 다시 부른다.
      // 설정에서 켠 뒤 다시 누르면 통과한다
      e.source.granted = true;
      await tester.tap(_button('설정에서 켜기'));
      await tester.pump();
      await tester.pump();
      expect(e.source.permissionRequests, 2);
      expect(e.appSettings.appOpens, 0);
      expect(find.text('허용됨'), findsOneWidget);
      expect(_button('설정에서 켜기'), findsNothing);
      expect(_enabled(tester, '쉼터로 가기'), isTrue);
      await end(tester, e);
    });

    group('iOS: "설정에서 켜기"는 앱 설정을 열고, 돌아오면 다시 확인한다', () {
      final iosFix = [stepFixOpensSettingsProvider.overrideWithValue(true)];

      /// 걸음을 거부한 상태(설정에서 켜기가 나온 상태)까지
      Future<void> openDenied(WidgetTester tester, UiEnv e) async {
        e.source.granted = false;
        await openPermission(tester, e, extra: iosFix);
        await tester.tap(allow().first);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 1);
        expect(_button('설정에서 켜기'), findsOneWidget);
      }

      testWidgets('버튼은 앱 설정을 열기만 하고 권한은 다시 묻지 않는다', (tester) async {
        final e = UiEnv();
        await openDenied(tester, e);

        await tester.tap(_button('설정에서 켜기'));
        await tester.pump();
        await tester.pump();
        expect(e.appSettings.appOpens, 1);
        expect(e.appSettings.noticeOpens, 0);
        expect(e.source.permissionRequests, 1);
        expect(_button('설정에서 켜기'), findsOneWidget);
        expect(_enabled(tester, '쉼터로 가기'), isFalse);
        await end(tester, e);
      });

      testWidgets('설정에서 켜고 돌아오면 다시 확인해서 허용됨으로 바뀌고 다음으로 갈 수 있다', (tester) async {
        final e = UiEnv();
        await openDenied(tester, e);
        await tester.tap(_button('설정에서 켜기'));
        await tester.pump();

        e.source.granted = true;
        _leaveAndReturn(tester);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 2);
        expect(e.appSettings.appOpens, 1);
        expect(find.text('허용됨'), findsOneWidget);
        expect(_button('설정에서 켜기'), findsNothing);
        expect(_enabled(tester, '쉼터로 가기'), isTrue);

        // 허용된 뒤에 또 다녀와도 다시 묻지 않는다
        _leaveAndReturn(tester);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 2);
        await end(tester, e);
      });

      testWidgets('켜지 않고 돌아오면 다시 확인해도 그대로 "설정에서 켜기"이고, 또 열 수 있다', (tester) async {
        final e = UiEnv();
        await openDenied(tester, e);
        await tester.tap(_button('설정에서 켜기'));
        await tester.pump();

        _leaveAndReturn(tester);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 2);
        expect(_button('설정에서 켜기'), findsOneWidget);
        expect(_enabled(tester, '쉼터로 가기'), isFalse);

        // 한 번 돌아온 뒤에는 설정을 다시 열 때까지 확인하지 않는다
        _leaveAndReturn(tester);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 2);
        await tester.tap(_button('설정에서 켜기'));
        await tester.pump();
        expect(e.appSettings.appOpens, 2);
        await end(tester, e);
      });

      testWidgets('설정을 열지 않았으면 앱을 다녀와도 다시 묻지 않는다', (tester) async {
        final e = UiEnv();
        await openDenied(tester, e);

        e.source.granted = true;
        _leaveAndReturn(tester);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 1);
        expect(e.appSettings.appOpens, 0);
        expect(_button('설정에서 켜기'), findsOneWidget);
        await end(tester, e);
      });

      testWidgets('설정을 열지 못해도 앱이 죽지 않고, 돌아와도 다시 확인하지 않는다', (tester) async {
        final e = UiEnv();
        e.appSettings.fail = true;
        await openDenied(tester, e);

        await tester.tap(_button('설정에서 켜기'));
        await tester.pump();
        await tester.pump();
        expect(e.appSettings.appOpens, 1);

        e.source.granted = true;
        _leaveAndReturn(tester);
        await tester.pump();
        await tester.pump();
        expect(e.source.permissionRequests, 1);
        expect(_button('설정에서 켜기'), findsOneWidget);
        expect(find.byType(PermissionScreen), findsOneWidget);
        await end(tester, e);
      });
    });

    testWidgets('건강 앱에 물어보다 예외가 나면 거부로 본다 (앱이 죽지 않는다)', (tester) async {
      final source = _ThrowingSource();
      final e = UiEnv(source: source);
      await openPermission(tester, e);

      await tester.tap(allow().first);
      await tester.pump();
      await tester.pump();
      expect(source.permissionRequests, 1);
      expect(_button('설정에서 켜기'), findsOneWidget);
      expect(_enabled(tester, '쉼터로 가기'), isFalse);
      await end(tester, e);
    });

    testWidgets('알림을 거부(자리표시는 늘 거부)하면 안내 한 줄이 뜨고 그대로 진행할 수 있다', (tester) async {
      final e = UiEnv();
      await openPermission(tester, e);

      await tester.tap(allow().last);
      await tester.pump();
      await tester.pump();
      expect(find.text('설정 → 알림에서 언제든 켤 수 있어요'), findsOneWidget);
      // 알림 줄 버튼이 안내로 바뀌었다 (걸음 줄 "허용하기"만 남는다)
      expect(allow(), findsOneWidget);
      // 걸음을 허용하면 알림을 거부한 채로도 갈 수 있다
      expect(_enabled(tester, '쉼터로 가기'), isFalse);
      await tester.tap(allow());
      await tester.pump();
      await tester.pump();
      expect(_enabled(tester, '쉼터로 가기'), isTrue);
      expect(e.source.permissionRequests, 1);
      await end(tester, e);
    });

    testWidgets('알림을 허용하면 허용됨이 뜬다 (걸음과 별개)', (tester) async {
      final e = UiEnv();
      final notice = _FakeNotification(true);
      await openPermission(tester, e,
          extra: [notificationPermissionProvider.overrideWithValue(notice)]);

      await tester.tap(allow().last);
      await tester.pump();
      await tester.pump();
      expect(notice.requests, 1);
      expect(e.source.permissionRequests, 0);
      expect(find.text('허용됨'), findsOneWidget);
      expect(find.text('설정 → 알림에서 언제든 켤 수 있어요'), findsNothing);
      // 걸음은 아직이라 못 간다
      expect(_enabled(tester, '쉼터로 가기'), isFalse);
      await end(tester, e);
    });

    testWidgets('"쉼터로 가기" → onboardedAt 저장 → 쉼터와 AutoSync', (tester) async {
      final e = UiEnv();
      await openPermission(tester, e);
      expect(await tester.runAsync(() => e.db.select(e.db.syncState).get()), isEmpty);

      await tester.tap(allow().first);
      await tester.pump();
      await tester.pump();
      await _tapButton(tester, '쉼터로 가기');
      await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);

      expect((await _profile(tester, e)).onboardedAt, e.now.millisecondsSinceEpoch);
      expect(find.byType(PermissionScreen), findsNothing);
      expect(find.byType(AutoSync), findsOneWidget);
      // 동기화는 이제 시작됐다
      await settle(tester, () => false, tries: 6);
      expect(await tester.runAsync(() => e.db.select(e.db.syncState).get()), isNotEmpty);
      await end(tester, e);
    });

    testWidgets('"쉼터로 가기" → 첫 여정 "내 동네 스케치"가 정해지고, 쉼터에 알림 점과 말풍선이 뜬다', (tester) async {
      final e = UiEnv();
      await openPermission(tester, e);
      // 권한 단계까지는 여정이 없다
      expect(await tester.runAsync(() => e.db.select(e.db.journeys).get()), isEmpty);

      await tester.tap(allow().first);
      await tester.pump();
      await tester.pump();
      await _tapButton(tester, '쉼터로 가기');
      await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);

      // 출발 동네(_fill이 고른 첫 시·군·구)에서 config 범위(firstSketchKm) 안의 가상 목적지로 가는 여정
      final home = sigungu.first;
      final j = (await tester.runAsync(() => e.db.select(e.db.journeys).getSingle()))!;
      expect(j.destId, sketchId);
      expect(j.status, JourneyStatus.active);
      expect((j.originLat, j.originLng), (home.lat, home.lng));
      expect(haversineKm(home.latLng, LatLng(j.destLat!, j.destLng!), rules.earthRadiusKm),
          inInclusiveRange(rules.firstSketchMinKm - 1e-6, rules.firstSketchMaxKm + 1e-6));
      expect(j.startUtc, e.now.millisecondsSinceEpoch);

      // 쉼터: 상태 알약, 출발하기의 알림 점, 말풍선
      expect(find.textContaining('쉬는 중 · 내 동네 스케치까지 '), findsOneWidget);
      expect(find.byKey(const ValueKey('depart-dot')), findsOneWidget);
      expect(find.byKey(const ValueKey('first-sketch-bubble')), findsOneWidget);
      expect(find.textContaining('첫 그림을 그리러 가요. ${home.label}에서 '), findsOneWidget);
      await end(tester, e);
    });

    testWidgets('이미 여정이 있으면 "쉼터로 가기"가 스케치를 새로 정하지 않는다', (tester) async {
      final e = UiEnv();
      await openPermission(tester, e);
      await tester.runAsync(() => placeAt(e.db, nearGyeongbok, t0));

      await tester.tap(allow().first);
      await tester.pump();
      await tester.pump();
      await _tapButton(tester, '쉼터로 가기');
      await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);

      expect(await tester.runAsync(() => e.db.select(e.db.journeys).get()), hasLength(1));
      expect(find.byKey(const ValueKey('first-sketch-bubble')), findsNothing);
      expect(find.byKey(const ValueKey('depart-dot')), findsNothing);
      await end(tester, e);
    });
  });

  group('처음부터 끝까지', () {
    testWidgets('환영 → 나 → 출발 동네 → 권한 → 쉼터: 권한은 마지막 단계 버튼에서만 묻는다', (tester) async {
      final e = UiEnv();
      final notice = _FakeNotification(false);
      await _pump(tester, e, extra: [notificationPermissionProvider.overrideWithValue(notice)]);
      await _arrive(tester, WelcomeScreen);

      void noAsking() {
        expect(e.source.permissionRequests, 0);
        expect(notice.requests, 0);
        expect(find.byType(AutoSync), findsNothing);
      }

      noAsking();
      await _tapButton(tester, '만 14세 이상이에요');
      await _arrive(tester, MeScreen);
      noAsking();

      await tester.enterText(find.byType(TextField), '나그네');
      await tester.tap(find.byKey(const ValueKey('hair-3')));
      await tester.tap(find.byKey(const ValueKey('swatch-5')));
      await tester.pump();
      await _tapButton(tester, '이 모습으로');
      await _arrive(tester, HomePickScreen);
      noAsking();

      await tester.enterText(find.byType(TextField), '수원');
      await tester.pump();
      await tester.tap(find.text('경기 수원시'));
      await tester.pump();
      await _tapButton(tester, '여기서 출발');
      await _arrive(tester, PermissionScreen);
      noAsking();
      // 시작 흐름 동안 동기화 상태가 만들어지지 않았다
      expect(await tester.runAsync(() => e.db.select(e.db.syncState).get()), isEmpty);

      await tester.tap(find.widgetWithText(GameButton, '허용하기').first);
      await tester.pump();
      await tester.pump();
      expect(e.source.permissionRequests, 1);
      await _tapButton(tester, '쉼터로 가기');
      await settle(tester, () => find.byType(RestScreen).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester, () => find.textContaining('쉬는 중').evaluate().isNotEmpty);
      expect(find.byType(AutoSync), findsOneWidget);

      final r = await _profile(tester, e);
      final suwon = sigungu.singleWhere((s) => s.label == '경기 수원시');
      expect(r.ageConfirmedAt, e.now.millisecondsSinceEpoch);
      expect(r.installId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(r.nickname, '나그네');
      expect(Look.fromJson(jsonDecode(r.look!) as Map<String, dynamic>),
          const Look(hair: 3, hairColor: SwatchHairColor(5)));
      expect((r.homeId, r.homeName, r.homeLat, r.homeLng),
          (suwon.id, '경기 수원시', suwon.lat, suwon.lng));
      expect(r.onboardedAt, e.now.millisecondsSinceEpoch);
      expect((r.linkConsentAt, r.guestbookConsentAt), (null, null));
      // 쉼터의 출발 동네도 같은 열에서 읽는다
      final snap = (await tester.runAsync(() => e.svc.snapshot(e.now)))!;
      expect(snap.home!.name, '경기 수원시');
      // 첫 여정은 그 동네의 내 동네 스케치
      expect(snap.journey!.dest.id, sketchId);
      expect(snap.position, suwon.latLng);
      expect(find.textContaining('첫 그림을 그리러 가요. 경기 수원시에서 '), findsOneWidget);
      await end(tester, e);
    });
  });
}
