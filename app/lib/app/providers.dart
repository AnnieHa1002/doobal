import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_settings_opener.dart';
import '../data/backup_store.dart';
import '../data/config_loader.dart';
import '../data/db/app_db.dart';
import '../data/landmark_loader.dart';
import '../data/live_steps.dart';
import '../data/map_loader.dart';
import '../data/milestone_loader.dart';
import '../data/notice_loader.dart';
import '../data/notification_permission.dart';
import '../data/notifier.dart';
import '../data/painting_sharer.dart';
import '../data/palette_loader.dart';
import '../data/prop_loader.dart';
import '../data/sigungu_loader.dart';
import '../data/step_source.dart';
import '../data/theme_loader.dart';
import '../domain/camp_theme.dart';
import '../domain/landmark.dart';
import '../domain/look.dart';
import '../domain/look_palette.dart';
import '../domain/map_land.dart';
import '../domain/map_projection.dart';
import '../domain/map_regions.dart';
import '../domain/moderation.dart';
import '../domain/notification_policy.dart';
import '../domain/onboarding.dart';
import '../domain/prop.dart';
import '../domain/rules.dart';
import '../domain/session.dart';
import '../domain/sigungu.dart';
import '../domain/walk_history.dart';
import 'backup_runner.dart';
import 'backup_service.dart';
import 'notification_service.dart';
import 'profile_service.dart';
import 'stats_service.dart';
import 'sync_service.dart';

final rulesProvider = FutureProvider<Rules>((ref) => loadRules());

final landmarksProvider = FutureProvider<List<Landmark>>((ref) => loadLandmarks());

/// 소품 MVP 27개 (props.json)
final propsProvider = FutureProvider<List<Prop>>((ref) => loadProps());

/// 방명록 걸음 숫자 (milestones.json)
final milestonesProvider = FutureProvider<List<int>>((ref) => loadMilestones());

/// 쉼터 테마 (themes/camp.json)
final campThemeProvider = FutureProvider<CampTheme>((ref) => loadCampTheme());

/// 지도 위경도 → 캔버스 px (assets/map/ui_map_projection_v01.json)
final mapProjectionProvider = FutureProvider<MapProjection>((ref) => loadMapProjection());

/// 지도 시도 경계 (assets/map/ui_map_regions_v01.svg)
final mapRegionsProvider = FutureProvider<List<MapRegion>>((ref) => loadMapRegions());

/// 시·군·구 (sigungu.json). 출발 동네 고르기
final sigunguProvider = FutureProvider<List<Sigungu>>((ref) => loadSigungu());

/// 머리색 견본 (palette.json hair.swatches)
final hairSwatchesProvider = FutureProvider<List<HairSwatch>>((ref) => loadHairSwatches());

/// 머리·피부 색 규칙 (palette.json hair·skin). 꾸미기와 나의 정보 초상이 읽는다
final lookPaletteProvider = FutureProvider<LookPalette>((ref) => loadLookPalette());

/// 지금 시각(UTC). 화면과 서비스는 DateTime.now()를 직접 부르지 않고 이걸 쓴다. 테스트에서 바꾼다
final clockProvider = Provider<DateTime Function()>((ref) => () => DateTime.now().toUtc());

/// 1분마다 새로 나오는 지금 시각. 쉼터처럼 가만히 있는 화면의 하늘이 시간을 따라가게 한다
final minuteClockProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream<DateTime>.periodic(const Duration(minutes: 1), (_) => clock());
});

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb(driftDatabase(name: 'doobal'));
  ref.onDispose(db.close);
  return db;
});

final stepSourceProvider = Provider<StepSource>((ref) => HealthStepSource());

/// 기기 걸음 센서. 걷는 중 화면의 실시간 걸음에만 쓴다 (진행·보상은 stepSourceProvider의 health 값)
final liveStepsProvider = Provider<LiveSteps>((ref) => const PedometerLiveSteps());

/// 이번 앱 실행 중 기기 걸음 센서 권한을 거부당했는가. 거부하면 걷는 중 화면이 다시 묻지 않는다.
/// 메모리에만 두어서 앱을 다시 켜면 처음부터 다시 물을 수 있다
class LiveDenied extends Notifier<bool> {
  @override
  bool build() => false;

  bool get denied => state;

  void set(bool denied) => state = denied;
}

final liveDeniedProvider = NotifierProvider<LiveDenied, bool>(LiveDenied.new);

/// 휴대폰 설정 앱 열기 (권한을 거부한 사용자를 설정으로 보낸다)
final appSettingsOpenerProvider =
    Provider<AppSettingsOpener>((ref) => const PlatformAppSettingsOpener());

/// 시작 흐름에서 걸음 권한을 거부한 사용자를 앱 설정으로 보내는가 (false면 권한 요청을 다시 부른다).
/// iOS만 보낸다. HealthKit은 한 번 답한 뒤에는 권한 창을 다시 띄우지 않아서 다시 물어도 소용이 없고,
/// 안드로이드는 Health Connect 권한이 앱 정보가 아니라 Health Connect 화면에서 관리되고
/// 그 창은 요청을 다시 부르면 (두 번 거부하기 전까지) 다시 뜬다
final stepFixOpensSettingsProvider = Provider<bool>((ref) => Platform.isIOS);

/// 그림 공유 시트 (share_plus)
final paintingSharerProvider =
    Provider<PaintingSharer>((ref) => const SharePlusPaintingSharer());

/// 방명록 금칙어 중 혐오·성적 표현 목록. 첫 실행에는 앱에 넣은 시작 목록을 쓴다.
/// TODO(M5): Firestore config/moderation에서 받은 목록으로 바꾼다
final extraBlockedWordsProvider = Provider<List<String>>((ref) => starterWords);

/// M6에서 flutter_local_notifications로 바꾼다 (지금은 늘 거부로 답하는 자리표시)
final notificationPermissionProvider =
    Provider<NotificationPermission>((ref) => const PlaceholderNotificationPermission());

/// 지금 알림 권한이 허용돼 있는가. 모르면 null (설정 화면의 권한 줄). 권한을 다시 물은 뒤에는 invalidate 한다
final notificationGrantedProvider = FutureProvider.autoDispose<bool?>(
    (ref) => ref.watch(notificationPermissionProvider).isGranted());

/// 알림 종류별 우선순위와 문구 (notifications.json)
final noticeCatalogProvider = FutureProvider<NoticeCatalog>((ref) => loadNoticeCatalog());

/// 시스템 알림을 띄우는 곳. M6에서 flutter_local_notifications로 바꾼다 (지금은 아무것도 안 띄우는 자리표시)
final systemNotifierProvider = Provider<SystemNotifier>((ref) => PlaceholderNotifier());

/// 앱이 앞에 있는가 (알림 판단이 앞이면 화면 안 표시만 하려고 읽는다). AutoSync가 lifecycle에 따라 바꾼다.
/// 앞에서 시작한다. TODO(M6): 백그라운드 동기화는 앱 화면 없이 도니까 거기서는 false로 덮어쓴다
class AppForeground extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool foreground) => state = foreground;
}

final appForegroundProvider = NotifierProvider<AppForeground, bool>(AppForeground.new);

/// 알림 판단(어떤 알림을 보내거나 예약할지)과 알림 기록·켜고 끄기
final notificationServiceProvider = FutureProvider<NotificationService>((ref) async {
  return NotificationService(
    db: ref.watch(dbProvider),
    rules: await ref.watch(rulesProvider.future),
    catalog: await ref.watch(noticeCatalogProvider.future),
    notifier: ref.watch(systemNotifierProvider),
    inForeground: () => ref.read(appForegroundProvider),
  );
});

/// 설정 화면의 알림 켜고 끄기. 바꾼 뒤에는 invalidate 해서 다시 읽는다
final noticeSettingsProvider = FutureProvider.autoDispose<NoticeSettings>((ref) async {
  return (await ref.watch(notificationServiceProvider.future)).settings();
});

/// 백업 문자열을 서버에 두고 받아 오는 곳. M5에서 Firestore(users/{uid}/backup/state)로 바꾼다
/// (지금은 메모리에만 두는 자리표시)
final backupStoreProvider = Provider<BackupStore>((ref) => PlaceholderBackupStore());

/// 계정을 연결한 사용자의 uid. 연결하지 않았으면 null. 백업은 계정을 연결한 사용자만 한다
/// (익명 uid는 앱을 지우면 다시 찾을 수 없다). M5에서 Firebase Auth로 바꾼다.
/// 계정 연결이 아직 없어서 늘 null이고, 그래서 자동 백업은 일어나지 않는다
final backupUidProvider = Provider<String?>((ref) => null);

/// 로컬 DB ↔ 백업 문자열
final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  return BackupService(ref.watch(dbProvider), await ref.watch(rulesProvider.future));
});

/// 자동 백업 (동기화·도착·백그라운드에서 AutoSync가 부른다). 마지막 백업 시각을 메모리에 들고 있어서
/// 앱이 도는 동안 하나만 둔다
final backupRunnerProvider = FutureProvider<BackupRunner>((ref) async {
  return BackupRunner(
    service: await ref.watch(backupServiceProvider.future),
    store: ref.watch(backupStoreProvider),
    rules: await ref.watch(rulesProvider.future),
    uid: () => ref.read(backupUidProvider),
  );
});

/// 프로필(사용자 자신의 정보) 읽기·쓰기. 걸음·여정이 아니라서 SyncService와 따로 둔다
final profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService(ref.watch(dbProvider)));

/// 시작 흐름에서 지금 보여 줄 단계. 단계를 마칠 때마다 invalidate 해서 다음 단계를 읽는다
final onboardingStepProvider =
    FutureProvider<OnboardingStep>((ref) => ref.watch(profileServiceProvider).step());

/// 나의 정보·노트가 읽는 모음 쿼리 (읽기만)
final statsServiceProvider = Provider<StatsService>((ref) => StatsService(ref.watch(dbProvider)));

/// 나의 정보의 닉네임·모습. 화면을 열 때마다 다시 읽는다
final meProvider = FutureProvider.autoDispose<Me>((ref) => ref.watch(profileServiceProvider).me());

/// 최근 14일의 하루 걸음 (나의 정보 막대). 동기화·삭제로 상태가 바뀌면 snapshotProvider와 함께 새로 읽는다
final recentDaysProvider = FutureProvider.autoDispose<List<DayBar>>((ref) async {
  final snap = await ref.watch(snapshotProvider.future);
  return ref.watch(statsServiceProvider).recentDays(snap.today);
});

/// 감지된 걷기 전부, 최신순 (노트의 걷기 기록)
final walkSessionsProvider = FutureProvider.autoDispose<List<WalkSession>>((ref) async {
  await ref.watch(snapshotProvider.future);
  return ref.watch(statsServiceProvider).walkSessions();
});

/// 디버그용 거리 배수 (개발자 화면에서 1·10·100배). 여정 진행 거리에만 곱한다.
/// 메모리에만 두어서 앱을 다시 켜면 1배로 돌아온다. 디버그 빌드가 아니면 읽지 않는다
class DebugDistanceScale extends Notifier<double> {
  @override
  double build() => 1.0;

  void set(double scale) => state = scale;
}

final debugDistanceScaleProvider =
    NotifierProvider<DebugDistanceScale, double>(DebugDistanceScale.new);

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  // 배수를 바꾸면 서비스를 새로 만들어서, 그것을 읽는 상태도 함께 새로 읽는다
  final distanceScale = kDebugMode ? ref.watch(debugDistanceScaleProvider) : 1.0;
  final rules = await ref.watch(rulesProvider.future);
  final landmarks = await ref.watch(landmarksProvider.future);
  final props = await ref.watch(propsProvider.future);
  final milestones = await ref.watch(milestonesProvider.future);
  // 첫 여정 '내 동네 스케치'의 목적지가 바다에 떨어지지 않게 지도 경계로 땅을 판정한다
  final projection = await ref.watch(mapProjectionProvider.future);
  final regions = await ref.watch(mapRegionsProvider.future);
  return SyncService(
    db: ref.watch(dbProvider),
    source: ref.watch(stepSourceProvider),
    rules: rules,
    allowedSources: Platform.isIOS ? rules.allowedSourcesIos : rules.allowedSourcesAndroid,
    landmarks: {for (final l in landmarks) l.id: l},
    props: props,
    milestones: milestones,
    onLand: (p, island) => onIsland(p, island, projection, regions),
    distanceScale: distanceScale,
    notificationService: await ref.watch(notificationServiceProvider.future),
  );
});

/// 지금 상태. 동기화·여정 시작 뒤에 invalidate 한다
final snapshotProvider = FutureProvider<Snapshot>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.snapshot(ref.read(clockProvider)());
});

/// 지도 화면의 값 (다녀온 명소·지나온 길·위치). 상태가 바뀌면 snapshotProvider와 함께 새로 읽는다
final mapDataProvider = FutureProvider<MapData>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.mapData(ref.read(clockProvider)());
});

/// 지금 자리에서 그 명소까지의 거리와 일수 (지도 카드)
final journeyPreviewProvider =
    FutureProvider.autoDispose.family<JourneyPreview, String>((ref, destId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.preview(destId, ref.read(clockProvider)());
});

/// 도착 화면의 값 (여정 하나). 한 번 읽으면 그대로라 상태가 바뀌어도 다시 읽지 않는다
final arrivalViewProvider =
    FutureProvider.autoDispose.family<ArrivalView, String>((ref, journeyId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.arrivalView(journeyId);
});

/// 화집 벽 4칸. 건 뒤에는 invalidate 한다
final wallProvider = FutureProvider.autoDispose<List<String?>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.wall();
});

/// 얻은 그림 전부 (화집·그림 상세). 도착해서 상태가 바뀌면 새로 읽는다
final paintingsProvider = FutureProvider.autoDispose<List<OwnedPaintingView>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.paintings();
});

/// 얻은 소품 id (화집 소품 탭)
final ownedPropIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.ownedPropIds();
});

/// 그림 하나의 방문 기록 (그림 상세)
final visitsProvider =
    FutureProvider.autoDispose.family<List<VisitView>, String>((ref, landmarkId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  await ref.watch(snapshotProvider.future);
  return svc.visits(landmarkId);
});

/// 방명록 기회 하나 (쓰기 화면, 도착 화면의 방명록 쓰기 버튼). 열려 있지 않으면 null.
/// 글을 쓴 뒤에는 invalidate 해서 다시 읽는다
final guestbookTicketProvider =
    FutureProvider.autoDispose.family<GuestbookTicket?, String>((ref, ticketId) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.guestbookTicket(ticketId, ref.read(clockProvider)());
});

/// 내가 쓴 방명록 글, 최신순 (노트의 내 방명록). 글을 쓴 뒤에는 invalidate 해서 다시 읽는다
final myPostsProvider = FutureProvider.autoDispose<List<GuestbookPostView>>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.myPosts();
});

/// 방명록 동의를 이미 했는가. 쓰기 화면의 동의 줄을 처음에만 보여 주려고 읽는다
final guestbookConsentProvider = FutureProvider.autoDispose<bool>((ref) async {
  final svc = await ref.watch(syncServiceProvider.future);
  return svc.guestbookConsented();
});
