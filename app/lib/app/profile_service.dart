import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/db/app_db.dart';
import '../domain/look.dart';
import '../domain/onboarding.dart';
import '../domain/profile.dart';
import '../domain/sigungu.dart';

/// 나의 정보에 보이는 닉네임과 모습
class Me {
  const Me(this.nickname, this.look);

  final String nickname;
  final Look look;
}

/// 닉네임이 비어 있을 때(시작 흐름을 끝내면 늘 있어서 거의 안 쓴다) 보이는 이름
const _fallbackNickname = '화가';

/// 프로필(1행)의 시작 흐름 값을 읽고 쓴다. 걸음·여정은 SyncService, 이쪽은 사용자 자신의 정보.
/// 쓰기는 id = 1 행에 넣거나 갱신하고 건드리지 않는 열은 그대로 둔다 (기기 기록 전체 삭제만 예외)
class ProfileService {
  ProfileService(this.db, {String Function()? makeInstallId})
      : _makeInstallId = makeInstallId ?? newInstallId;

  final AppDb db;
  final String Function() _makeInstallId;

  Future<ProfileRow?> row() =>
      (db.select(db.profile)..where((t) => t.id.equals(1))).getSingleOrNull();

  /// 닉네임과 모습 (나의 정보). 비었거나 읽을 수 없으면 기본값
  Future<Me> me() async {
    final r = await row();
    var look = Look.initial;
    final raw = r?.look;
    if (raw != null) {
      try {
        look = Look.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // 깨진 값은 기본 모습으로 보여 준다
      }
    }
    return Me(r?.nickname ?? _fallbackNickname, look);
  }

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

  /// 이 기기의 기록을 모두 지운다 (계정 삭제의 기기 쪽). 표는 그대로 두고 행만 비워서
  /// 시작 흐름이 처음부터 다시 돈다. 표를 하나하나 적지 않고 allTables를 돌아서 새 표도 따라 지운다.
  /// TODO(M5·M6): 서버(Auth·Firestore)의 계정·방명록과 알림 구독 삭제는 서버가 생기면 여기서 함께 부른다
  Future<void> deleteAllLocal() => db.transaction(() async {
        for (final t in db.allTables) {
          await db.delete(t).go();
        }
      });

  Future<void> _write(ProfileCompanion c) => db.into(db.profile).insertOnConflictUpdate(c);
}
