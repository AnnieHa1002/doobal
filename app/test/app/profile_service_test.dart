import 'dart:convert';

import 'package:doobal/app/profile_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/display_font.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/journey.dart' show Frame;
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/onboarding.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

final _at = DateTime.utc(2026, 11, 18, 0, 30);
final _later = DateTime.utc(2026, 11, 19, 8);

/// 부를 때마다 다른 번호를 돌려주는 설치 번호 만들기 (a, b, c ...)
String Function() _ids() {
  var n = 0;
  return () => String.fromCharCode('a'.codeUnitAt(0) + n++) * 32;
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDb db;
  late ProfileService svc;

  setUp(() {
    db = AppDb(NativeDatabase.memory());
    svc = ProfileService(db, makeInstallId: _ids());
  });
  tearDown(() => db.close());

  test('프로필이 비어 있으면 행이 없고 단계는 환영', () async {
    expect(await svc.row(), isNull);
    expect(await svc.step(), OnboardingStep.welcome);
  });

  group('표시 글꼴 (16장 11/3)', () {
    test('고른 적 없으면 기본 개구', () async {
      expect(await svc.displayFont(), DisplayFont.gaegu);
    });

    test('고르면 이름으로 적고 다시 읽으면 그 글꼴, 닉네임 같은 다른 열은 그대로', () async {
      await svc.saveMe('화가', Look.initial);
      await svc.saveDisplayFont(DisplayFont.dongle);
      expect(await svc.displayFont(), DisplayFont.dongle);
      final r = (await svc.row())!;
      expect((r.displayFont, r.nickname), ('dongle', '화가'));
      await svc.saveDisplayFont(DisplayFont.batang);
      expect(await svc.displayFont(), DisplayFont.batang);
    });

    test('모르는 이름이 적혀 있으면 기본 개구', () async {
      await db.into(db.profile).insert(
          const ProfileCompanion(id: Value(1), displayFont: Value('comic')));
      expect(await svc.displayFont(), DisplayFont.gaegu);
    });
  });

  group('confirmAge', () {
    test('확인 시각(UTC epoch ms)과 설치 번호를 적고 다음 단계는 나', () async {
      await svc.confirmAge(_at);
      final r = (await svc.row())!;
      expect(r.id, 1);
      expect(r.ageConfirmedAt, _at.millisecondsSinceEpoch);
      expect(r.installId, 'a' * 32);
      // 다른 열은 건드리지 않는다
      expect([r.nickname, r.look, r.homeId, r.homeLat, r.onboardedAt], everyElement(isNull));
      expect(await svc.step(), OnboardingStep.me);
    });

    test('이미 있으면 덮어쓰지 않는다 (시각도 번호도 처음 그대로)', () async {
      await svc.confirmAge(_at);
      await svc.confirmAge(_later);
      final r = (await svc.row())!;
      expect(r.ageConfirmedAt, _at.millisecondsSinceEpoch);
      expect(r.installId, 'a' * 32);
    });

    test('로컬 시각을 넣어도 UTC로 적는다', () async {
      await svc.confirmAge(_at.toLocal());
      expect((await svc.row())!.ageConfirmedAt, _at.millisecondsSinceEpoch);
    });

    test('번호 만들기를 안 넣으면 진짜 임의 번호 (hex 32자)', () async {
      await ProfileService(db).confirmAge(_at);
      expect((await svc.row())!.installId, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('나중에 닉네임·출발 동네를 적어도 확인 기록은 그대로다', () async {
      await svc.confirmAge(_at);
      await svc.saveMe('화가', Look.initial);
      await svc.saveHome(sigungu.first);
      await svc.finishOnboarding(_later);
      await svc.confirmAge(_later);
      final r = (await svc.row())!;
      expect((r.ageConfirmedAt, r.installId), (_at.millisecondsSinceEpoch, 'a' * 32));
      expect(r.nickname, '화가');
    });
  });

  group('saveMe', () {
    test('닉네임과 모습(JSON)을 적고 다음 단계는 출발 동네', () async {
      await svc.confirmAge(_at);
      const look = Look(eyes: 'cat', body: SwatchBodyColor(7));
      await svc.saveMe('나그네', look);
      final r = (await svc.row())!;
      expect(r.nickname, '나그네');
      expect(Look.fromJson(jsonDecode(r.look!) as Map<String, dynamic>), look);
      expect(await svc.step(), OnboardingStep.home);
      // 확인 기록은 그대로
      expect(r.installId, 'a' * 32);
    });

    test('다시 적으면 바뀐다', () async {
      await svc.saveMe('하나', Look.initial);
      await svc.saveMe('둘', const Look(body: CustomBodyColor('#102030')));
      final r = (await svc.row())!;
      expect(r.nickname, '둘');
      expect((jsonDecode(r.look!) as Map<String, dynamic>)['body'],
          {'kind': 'custom', 'hex': '#102030'});
    });
  });

  group('saveLook', () {
    /// 가진 소품 기록을 직접 넣는다
    Future<void> own(Iterable<String> ids) => db.batch((b) => b.insertAll(db.propsOwned, [
          for (final id in ids) PropsOwnedCompanion.insert(propId: id, unlockedUtc: 1),
        ]));

    Future<Look> stored() async =>
        Look.fromJson(jsonDecode((await svc.row())!.look!) as Map<String, dynamic>);

    test('모습(JSON)만 바꾸고 닉네임·출발 동네 같은 다른 열은 그대로 둔다', () async {
      await svc.confirmAge(_at);
      await svc.saveMe('나그네', Look.initial);
      await svc.saveHome(sigungu.first);
      await own(['hat_02', 'bag_02']);
      final look = Look.initial
          .copyWith(
            eyes: 'bean',
            nose: 'wide',
            brows: 'thin',
            mouth: 'tongue',
            body: const CustomBodyColor('#C08060'),
          )
          .withSlot('hat', 'hat_02')
          .withSlot('bag', 'bag_02')
          .withSlot('hand', null)
          .withTint('hat_02', const SwatchBodyColor(4));
      await svc.saveLook(look);
      expect(await stored(), look);
      final r = (await svc.row())!;
      expect(r.nickname, '나그네');
      expect((r.homeName, r.installId), (sigungu.first.label, 'a' * 32));
      expect((await svc.me()).look, look);
    });

    test('프로필 행이 아직 없어도 적는다', () async {
      await svc.saveLook(Look.initial.copyWith(eyes: 'sleepy'));
      expect((await stored()).eyes, 'sleepy');
    });

    test('다시 저장하면 바뀐다', () async {
      await own(['hat_02']);
      await svc.saveLook(Look.initial.withSlot('hat', 'hat_02'));
      await svc.saveLook(Look.initial.withSlot('hat', null));
      expect((await stored()).slots['hat'], isNull);
    });

    test('기본 소품은 얻은 기록이 없어도 끼울 수 있다', () async {
      expect(await db.select(db.propsOwned).get(), isEmpty);
      await svc.saveLook(Look.initial);
      expect((await stored()).slots, defaultSlots);
    });

    test('안 가진 소품은 거절하고 아무것도 적지 않는다', () async {
      await svc.saveMe('나그네', Look.initial);
      final before = (await svc.row())!.look;
      await expectLater(
        svc.saveLook(Look.initial.withSlot('hat', 'hat_03')),
        throwsStateError,
      );
      expect((await svc.row())!.look, before);
      // 여러 칸 중 하나만 안 가졌어도 거절
      await own(['hand_02']);
      await expectLater(
        svc.saveLook(Look.initial.withSlot('hand', 'hand_02').withSlot('shoe', 'shoe_02')),
        throwsStateError,
      );
      expect((await svc.row())!.look, before);
    });

    test('얻은 소품이면 끼운다 (거절은 안 가진 것만)', () async {
      await own(['hat_03']);
      await svc.saveLook(Look.initial.withSlot('hat', 'hat_03'));
      expect((await stored()).slots['hat'], 'hat_03');
    });

    test('옷은 비울 수 없다 (거절)', () async {
      final noCloth = Look(slots: {...defaultSlots, 'cloth': null});
      await expectLater(svc.saveLook(noCloth), throwsStateError);
      expect(await svc.row(), isNull);
    });
  });

  group('saveHome', () {
    final suwon = sigungu.singleWhere((s) => s.label == '경기 수원시');

    test('id·이름(label)·대표 좌표를 적고 다음 단계는 권한', () async {
      await svc.confirmAge(_at);
      await svc.saveMe('화가', Look.initial);
      await svc.saveHome(suwon);
      final r = (await svc.row())!;
      expect((r.homeId, r.homeName, r.homeLat, r.homeLng),
          (suwon.id, '경기 수원시', suwon.lat, suwon.lng));
      expect(await svc.step(), OnboardingStep.permission);
      expect(r.nickname, '화가');
    });

    test('SyncService가 같은 열에서 출발 동네를 읽는다', () async {
      await svc.saveHome(suwon);
      final sync = SyncService(
        db: db,
        source: FakeStepSource(),
        rules: rules,
        allowedSources: const [],
        landmarks: const {},
        props: props,
      );
      final home = (await sync.home())!;
      expect(home.name, '경기 수원시');
      expect(home.latLng, LatLng(suwon.lat, suwon.lng));
    });

    test('SyncService.setHome(디버그 화면 전용)은 이름·좌표만 바꾸고 homeId는 그대로 둔다', () async {
      final sync = SyncService(
        db: db,
        source: FakeStepSource(),
        rules: rules,
        allowedSources: const [],
        landmarks: const {},
        props: props,
      );
      await svc.saveHome(suwon);
      await sync.setHome('중구', testHome);
      final r = (await svc.row())!;
      // 디버그 화면의 임시 고르기라 id는 갱신하지 않는다
      expect((r.homeName, r.homeId), ('중구', suwon.id));
    });
  });

  group('finishOnboarding', () {
    test('끝낸 시각을 적고 단계는 끝', () async {
      await svc.confirmAge(_at);
      await svc.saveMe('화가', Look.initial);
      await svc.saveHome(sigungu.first);
      expect(await svc.step(), OnboardingStep.permission);
      await svc.finishOnboarding(_later);
      expect((await svc.row())!.onboardedAt, _later.millisecondsSinceEpoch);
      expect(await svc.step(), OnboardingStep.done);
    });
  });

  test('동의 시각 열(linkConsentAt·guestbookConsentAt)은 시작 흐름이 건드리지 않는다', () async {
    await svc.confirmAge(_at);
    await svc.saveMe('화가', Look.initial);
    await svc.saveHome(sigungu.first);
    await svc.finishOnboarding(_later);
    final r = (await svc.row())!;
    expect((r.linkConsentAt, r.guestbookConsentAt), (null, null));
  });

  group('me', () {
    test('저장한 닉네임과 모습을 돌려준다', () async {
      const look = Look(mouth: 'flat', body: SwatchBodyColor(5));
      await svc.saveMe('나그네', look);
      final me = await svc.me();
      expect(me.nickname, '나그네');
      expect(me.look, look);
    });

    test('폰에 저장된 옛 사람형 모습은 기본 얼굴·크림으로 읽고 소품 칸은 살린다', () async {
      await db.into(db.profile).insert(ProfileCompanion.insert(
            id: const Value(1),
            nickname: const Value('옛 화가'),
            look: const Value('{"hair":4,"hairColor":{"kind":"swatch","i":3},"eyes":3,'
                '"slots":{"hat":"hat_02","hand":null}}'),
          ));
      final me = await svc.me();
      expect(me.nickname, '옛 화가');
      expect(me.look, Look.initial.withSlot('hat', 'hat_02'));
      expect(me.look.body, const SwatchBodyColor(1));
      expect(me.look.slots['hand'], isNull);
    });

    test('옛 {hair, hairColor}만 있는 모습도 기본 모습으로 읽는다', () async {
      await db.into(db.profile).insert(ProfileCompanion.insert(
            id: const Value(1),
            nickname: const Value('옛 화가'),
            look: const Value('{"hair":4,"hairColor":{"kind":"swatch","i":3}}'),
          ));
      expect((await svc.me()).look, Look.initial);
    });

    test('아직 없거나 모습이 깨졌으면 기본값', () async {
      var me = await svc.me();
      expect((me.nickname, me.look), ('화가', Look.initial));
      await db.into(db.profile).insert(ProfileCompanion.insert(
            id: const Value(1),
            nickname: const Value('둘'),
            look: const Value('{깨진 값'),
          ));
      me = await svc.me();
      expect((me.nickname, me.look), ('둘', Look.initial));
    });
  });

  group('deleteAllLocal', () {
    test('모든 표의 행을 지우고 시작 단계는 처음(환영)으로 돌아간다', () async {
      await svc.confirmAge(_at);
      await svc.saveMe('화가', Look.initial);
      await svc.saveHome(sigungu.first);
      await svc.finishOnboarding(_later);
      final sync = SyncService(
        db: db,
        source: FakeStepSource(),
        rules: rules,
        allowedSources: const [],
        landmarks: const {},
        props: props,
      );
      await sync.sync(_at);
      await db.into(db.paintingsOwned).insert(PaintingsOwnedCompanion.insert(
            landmarkId: 'kr001',
            visits: 1,
            frame: Frame.wood,
            bestKm: 1,
            firstArrivedUtc: 1,
            lastArrivedUtc: 1,
          ));
      await db.into(db.wallSlots)
          .insert(WallSlotsCompanion.insert(slot: const Value(0), landmarkId: 'kr001'));
      expect(await svc.step(), OnboardingStep.done);

      await svc.deleteAllLocal();

      for (final t in db.allTables) {
        expect(await db.select(t).get(), isEmpty, reason: t.actualTableName);
      }
      expect(await svc.row(), isNull);
      expect(await svc.step(), OnboardingStep.welcome);
    });

    test('지운 뒤에도 처음처럼 다시 쓸 수 있다', () async {
      await svc.confirmAge(_at);
      await svc.deleteAllLocal();
      await svc.confirmAge(_later);
      final r = (await svc.row())!;
      expect(r.ageConfirmedAt, _later.millisecondsSinceEpoch);
      // 설치 번호도 새로 만든다
      expect(r.installId, 'b' * 32);
    });
  });
}
