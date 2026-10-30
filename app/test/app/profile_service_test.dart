import 'dart:convert';

import 'package:doobal/app/profile_service.dart';
import 'package:doobal/app/sync_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/step_source.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/onboarding.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
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
      const look = Look(hair: 4, hairColor: SwatchHairColor(7));
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
      await svc.saveMe('둘', const Look(hair: 2, hairColor: CustomHairColor('#102030')));
      final r = (await svc.row())!;
      expect(r.nickname, '둘');
      expect((jsonDecode(r.look!) as Map<String, dynamic>)['hair'], 2);
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
}
