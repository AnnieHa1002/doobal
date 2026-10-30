import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../domain/look.dart';
import '../domain/onboarding.dart';
import '../domain/profile.dart';
import '../domain/sigungu.dart';

/// 프로필(1행)의 시작 흐름 값을 읽고 쓴다. 걸음·여정은 SyncService, 이쪽은 사용자 자신의 정보.
/// 모든 쓰기는 id = 1 행에 넣거나 갱신하고, 건드리지 않는 열은 그대로 둔다
class ProfileService {
  ProfileService(this.db, {String Function()? makeInstallId})
      : _makeInstallId = makeInstallId ?? newInstallId;

  final AppDb db;
  final String Function() _makeInstallId;

  Future<ProfileRow?> row() =>
      (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();

  /// 지금 보여 줄 시작 단계
  Future<OnboardingStep> step() async {
    final r = await row();
    return onboardingStepOf(
      ageConfirmedAt: r?.ageConfirmedAt,
      nickname: r?.nickname,
      homeLat: r?.homeLat,
      onboardedAt: r?.onboardedAt,
    );
  }

  /// 만 14세 확인을 적는다: 확인 시각과 설치 번호. 이미 있으면 덮어쓰지 않는다.
  /// 이 기기에만 남고 서버·백업에 넣지 않는다 (M5 명세)
  Future<void> confirmAge(DateTime now) => db.transaction(() async {
        final r = await row();
        await _write(ProfileCompanion(
          id: const Value(1),
          ageConfirmedAt: Value(r?.ageConfirmedAt ?? now.toUtc().millisecondsSinceEpoch),
          installId: Value(r?.installId ?? _makeInstallId()),
        ));
      });

  /// 닉네임(검사를 거친 값)과 모습
  Future<void> saveMe(String nickname, Look look) => _write(ProfileCompanion(
        id: const Value(1),
        nickname: Value(nickname),
        look: Value(jsonEncode(look.toJson())),
      ));

  /// 출발 동네: id, 이름(시·도를 붙인 label), 대표 좌표
  Future<void> saveHome(Sigungu s) => _write(ProfileCompanion(
        id: const Value(1),
        homeId: Value(s.id),
        homeName: Value(s.label),
        homeLat: Value(s.lat),
        homeLng: Value(s.lng),
      ));

  /// 권한 단계까지 마쳤다고 적는다 (이제 쉼터로 간다)
  Future<void> finishOnboarding(DateTime now) => _write(ProfileCompanion(
        id: const Value(1),
        onboardedAt: Value(now.toUtc().millisecondsSinceEpoch),
      ));

  Future<void> _write(ProfileCompanion c) => db.into(db.profile).insertOnConflictUpdate(c);
}
