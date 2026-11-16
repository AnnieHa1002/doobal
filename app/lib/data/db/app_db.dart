import 'package:drift/drift.dart';

import '../../domain/guestbook.dart' show TicketKind;
import '../../domain/journey.dart' show Frame;
import '../../domain/notification_policy.dart' show NoticeKind;
import '../../domain/paint_trail.dart' show PaintTrailEnd;

part 'app_db.g.dart';

// M1 범위 (M1 명세 5장) + 스키마 2 (M3: 그림·소품, 여정의 끝) + 스키마 3 (프로필: 출발 동네)
// + 스키마 4 (화집 벽) + 스키마 5 (새 그림 표시) + 스키마 6 (프로필: 시작 흐름)
// + 스키마 7 (첫 여정 '내 동네 스케치': 가상 목적지) + 스키마 8 (방명록 쓸 기회·쓴 글)
// + 스키마 9 (알림 기록·알림 켜고 끄기) + 스키마 10 (복원한 하루 요약 지키기: 동기화 상태 열)
// + 스키마 11 (본격 걷기: 앱 걷기 창·이동 거리·럭 장부) + 스키마 13 (길 위 이벤트·도장, 화집 벽 표 삭제)
// + 스키마 15 (동행·상점 보관함·상점 사용 기록·얻은 배, 프로필: 고른 배)
// + 스키마 16 (물감 길: 앱 걷기 창 → 물감 길, 보너스·앱 걷기 이동 거리 열 → 물감 길 거리)
// + 스키마 17 (하루 카드: 보여 준 마지막 날)
// + 스키마 18 (물감 색·물감 모으기: 물감 보관·주운 물감 통, 물감 길의 칠한 색, 프로필: 고른 물감).
// 시각은 모두 UTC 정수
// (epoch ms, 걸음은 epoch 분), 날짜 계산만 kstDayKey로 한다.
// 행 클래스는 domain 이름과 겹치지 않게 ~Row로 둔다

/// 분 단위 걸음. 모든 계산의 원본
@DataClassName('StepMinuteRow')
class StepMinutes extends Table {
  IntColumn get minuteUtc => integer()();
  IntColumn get steps => integer()();

  @override
  Set<Column> get primaryKey => {minuteUtc};
}

/// 하루 요약. distanceM은 실제로 걸은 거리(걸음 × 보폭)이고 상점 효과는 안 들어 있다 (이름을 바꾸지 않았다).
/// shopM은 상점 효과, travelM = distanceM + shopM은 여정·경비·도착 예정일이 쓰는 여행 거리(스키마 11),
/// trailM은 물감 길 안의 실제 거리(스키마 16, 럭 덤·리포트), coins는 그날 번 럭
@DataClassName('DaySummaryRow')
class DaySummaries extends Table {
  TextColumn get day => text()();
  IntColumn get steps => integer()();
  RealColumn get distanceM => real()();
  IntColumn get countedSessions => integer()();
  RealColumn get shopM => real().withDefault(const Constant(0.0))();
  RealColumn get travelM => real().withDefault(const Constant(0.0))();
  RealColumn get trailM => real().withDefault(const Constant(0.0))();
  IntColumn get coins => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {day};
}

/// 걷기 구간. distanceM은 실제 거리 (걷기 1번 인정은 동행 이야기 횟수·도장에 쓴다)
@DataClassName('WalkSessionRow')
class WalkSessions extends Table {
  IntColumn get startUtc => integer()();
  IntColumn get endUtc => integer()();
  IntColumn get steps => integer()();
  RealColumn get distanceM => real()();
  RealColumn get runRatio => real()();
  BoolColumn get qualified => boolean()();
  BoolColumn get counted => boolean()();

  @override
  Set<Column> get primaryKey => {startUtc};
}

enum JourneyStatus { active, arrived, stopped }

@DataClassName('JourneyRow')
class Journeys extends Table {
  TextColumn get id => text()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  TextColumn get destId => text()();
  IntColumn get startUtc => integer()();
  RealColumn get fundKm => real()();
  RealColumn get totalEffectiveKm => real()();
  TextColumn get status => textEnum<JourneyStatus>()();
  IntColumn get arrivedUtc => integer().nullable()();

  /// 여정이 끝난 곳: 도착이면 목적지, 멈춤이면 멈춘 지점. 진행 중이면 null
  RealColumn get endLat => real().nullable()();
  RealColumn get endLng => real().nullable()();

  /// 멈춘 시각 (도착은 arrivedUtc)
  IntColumn get endedUtc => integer().nullable()();

  /// 도착 화면에 쓸 값 (도착한 여정만): 몇 번째 방문, 도착 전·후 액자
  IntColumn get visitNo => integer().nullable()();
  TextColumn get prevFrame => textEnum<Frame>().nullable()();
  TextColumn get newFrame => textEnum<Frame>().nullable()();

  /// 도착 화면을 보여 줬는지. 앱 밖에서 도착하면 다음 실행 때 먼저 보여 준다
  BoolColumn get arrivalShown => boolean().withDefault(const Constant(false))();

  /// 가상 목적지의 좌표 (destId가 'sketch'인 첫 여정만). 명소 여정은 null
  RealColumn get destLat => real().nullable()();
  RealColumn get destLng => real().nullable()();

  /// 물감 길 동안 센서 걸음 × 보폭으로 센 실제 걸은 거리(m) 누적 (스키마 13, 길 위 이벤트의 칸 기준).
  /// 화면이 꺼진 동안 따라잡은 걸음은 들고(스키마 16), 경비로 더한 거리·배 환산·상점 효과·물감 길 밖 걸음은
  /// 들어 있지 않다. 진행 거리와는 따로다
  RealColumn get eventM => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 얻은 그림. 명소마다 한 점 (MVP는 첫 방문). 다시 도착하면 방문 수와 액자만 바뀐다.
/// seen이 false면 배낭에 새 그림 표시 (처음 얻을 때만 false, 옛 행은 본 것으로 둔다).
/// landmarkId가 'sketch'인 행은 첫 그림(첫 여행 짐 꾸러미): visits 1과 도착 시각만 뜻이 있다.
/// frame은 필수 열이라 wood를 넣는다 (화면의 나무 액자와 같고, 등급 계산에는 쓰지 않는다)
@DataClassName('PaintingOwnedRow')
class PaintingsOwned extends Table {
  TextColumn get landmarkId => text()();
  IntColumn get visits => integer()();
  TextColumn get frame => textEnum<Frame>()();

  /// 가장 멀리서 걸어 온 환산 거리(km)
  RealColumn get bestKm => real()();
  IntColumn get firstArrivedUtc => integer()();
  IntColumn get lastArrivedUtc => integer()();
  BoolColumn get seen => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {landmarkId};
}

/// 얻은 소품. seen이 false면 배낭에 새 소품 표시
@DataClassName('PropOwnedRow')
class PropsOwned extends Table {
  TextColumn get propId => text()();
  IntColumn get unlockedUtc => integer()();
  BoolColumn get seen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {propId};
}

/// 1행. fundedUntilUtc = 어디까지 경비에 넣었는지 (다시 동기화해도 두 번 넣지 않게)
@DataClassName('TravelFundRow')
class TravelFund extends Table {
  IntColumn get id => integer()();
  RealColumn get km => real()();
  IntColumn get fundedUntilUtc => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 1행
@DataClassName('SyncStateRow')
class SyncState extends Table {
  IntColumn get id => integer()();
  IntColumn get lastFetchedUtc => integer().nullable()();
  TextColumn get firstRecordDay => text()();
  IntColumn get installUtc => integer()();

  /// 백업을 복원한 기기에서, 복원한 하루 요약의 마지막 날 (한국 날짜 키 'YYYY-MM-DD').
  /// 이 날까지의 하루 요약은 건강 앱에서 다시 계산한 값이 복원값보다 작으면 복원값을 지킨다
  /// (새 기기의 건강 앱에는 그 기록이 없을 수 있다). 복원한 적이 없으면 null.
  /// 이 기기에만 두는 값이라 백업에 넣지 않는다
  TextColumn get restoreFloorDay => text().nullable()();

  /// 앱이 살아 있던 마지막 시각 (epoch ms). 살아 있는 동안 config sync.aliveSaveSec마다와 백그라운드로
  /// 갈 때 적는다. 다음 실행에서 끝나지 않은 물감 길을 이 시각에서 닫는다. 이 기기에만 두는 값
  IntColumn get lastAliveUtc => integer().nullable()();

  /// 다음 동기화가 하루 요약을 이 날(한국 날짜 키)부터 다시 계산한다 (스키마 16: 거리 규칙이 바뀐 옛 날).
  /// 다시 계산하면 null로 지운다. 이 기기에만 두는 값
  TextColumn get recomputeFromDay => text().nullable()();

  /// 상점의 새 상품을 마지막으로 본 시각 (epoch ms, 스키마 19, 16장 11/13 수레 점·11/16 Annie ‘저장’).
  /// 이 뒤에 얻은 기본 소품의 색 소품이 새 상품이다. null이면 설치 시각([installUtc])으로 본다 (첫날 점 없음).
  /// 이 기기에만 두는 값 (백업에 넣지 않는 표)
  IntColumn get shopSeenUtc => integer().nullable()();

  /// 그날 날씨 (스키마 20, 16장 11/16 ‘날씨는 그날 하루 하나’): 한국 날짜 키 'YYYY-MM-DD'와 getWeather의 kind
  /// (clear·cloudy·rain·snow). 그날 처음 물감 길이 열릴 때 받아 두고 그날은 다시 묻지 않는다 (앱을 껐다 켜도).
  /// 받지 못했으면 그대로 둔다 (다음 물감 길에서 다시). 이 기기에만 두는 값 (백업에 넣지 않는 표)
  TextColumn get weatherDay => text().nullable()();
  TextColumn get weatherKind => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 1행(id = 1). 시작 흐름이 채우는 값(만 14세 확인·설치 번호·닉네임·모습·출발 동네·권한 단계 끝)과
/// 계정 동의 시각. 채우기 전에는 행이 없거나 열이 null (단계는 onboardingStepProvider가 가린다).
/// 확인·동의 시각은 이 기기에만 두고 서버·백업에 넣지 않는다 (M5 명세)
@DataClassName('ProfileRow')
class Profile extends Table {
  IntColumn get id => integer()();

  /// 사용자가 고른 출발 동네: 시·군·구 이름(label)과 대표 좌표, 시·군·구 id
  TextColumn get homeName => text().nullable()();
  RealColumn get homeLat => real().nullable()();
  RealColumn get homeLng => real().nullable()();
  TextColumn get homeId => text().nullable()();

  /// 만 14세 확인을 누른 시각 (epoch ms). 이게 있어야 설치 번호를 만들고 권한을 묻는다
  IntColumn get ageConfirmedAt => integer().nullable()();

  /// 설치 번호 (16바이트 hex 32자). 만 14세 확인 때 한 번 만든다
  TextColumn get installId => text().nullable()();
  TextColumn get nickname => text().nullable()();

  /// 모습 JSON (domain/look.dart의 Look)
  TextColumn get look => text().nullable()();

  /// 시작 흐름의 마지막(권한) 단계를 마친 시각 (epoch ms)
  IntColumn get onboardedAt => integer().nullable()();

  /// 계정 연결·방명록 동의 시각 (epoch ms). 쓰는 곳은 M5에서 붙인다
  IntColumn get linkConsentAt => integer().nullable()();
  IntColumn get guestbookConsentAt => integer().nullable()();

  /// 고른 배 (boats.json id, 스키마 15). null이면 기본 배 (shop.json defaultBoat)
  TextColumn get boatId => text().nullable()();

  /// 쉼터 배낭 ‘물감’ 탭에서 고른 물감 색 id (스키마 18, 스키마 v10.5 Profile.paintColorId).
  /// null이면 기본 물감. 고른 색을 다 쓰면 null로 돌아간다
  TextColumn get paintColorId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 방명록 쓸 기회. 도착(id 'a:<여정 id>')은 여정마다, 걸음 숫자(id 'm:<숫자>')는 숫자마다 하나다.
/// scope는 쓰는 자리: 명소 id, 첫 여정이면 'sketch', 걸음이면 'steps:<숫자>'.
/// 열린 기회 = usedUtc·closedUtc가 둘 다 null. 글을 쓰면 usedUtc, 때가 지나면(다음 여정 시작·
/// 걸음 숫자 기회의 500보) closedUtc. openedUtc는 알림이 뜬 시각인데 알림(M6)이 아직 없어서
/// 기회를 발견한 동기화 시각이다
@DataClassName('GuestbookTicketRow')
class GuestbookTickets extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<TicketKind>()();
  TextColumn get scope => text()();
  IntColumn get openedUtc => integer()();
  IntColumn get usedUtc => integer().nullable()();
  IntColumn get closedUtc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 방명록 전송 상태. 쓰기만 하는 지금은 늘 pending이고, 서버로 보내는 건 M5에서 한다
enum PostStatus { pending, sent, rejected }

/// 내가 쓴 방명록 글. 기회 하나에 글 하나(ticketId가 키). 글 본문 열 이름은 Table의 text()와
/// 겹치지 않게 body다
@DataClassName('GuestbookPostRow')
class GuestbookPosts extends Table {
  TextColumn get ticketId => text()();
  TextColumn get scope => text()();
  TextColumn get body => text()();
  IntColumn get createdUtc => integer()();
  TextColumn get status => textEnum<PostStatus>()();

  @override
  Set<Column> get primaryKey => {ticketId};
}

/// 알림 기록 상태: sent는 시스템 알림을 지금 보냈다, scheduled는 atUtc에 뜨도록 예약해 뒀다
/// (그 시각이 지났으면 울린 것으로 본다), cancelled는 예약을 취소했다(앱을 다시 열었거나 더 높은 걸로
/// 바꿨다), inApp은 앱이 켜져 있어서 화면 안 표시만 했다, dropped는 고르지 못했다
/// (꺼진 종류·우선순위에서 밀림·하루 최대에 막힘)
enum NoticeStatus { sent, scheduled, cancelled, inApp, dropped }

/// 알림 기록. 후보 하나가 어떻게 됐는지 한 줄씩 남긴다. atUtc는 보낸 시각, 예약이면 뜨기로 한 시각,
/// 나머지 상태는 판정한 시각. refKey는 그 일을 가리키는 값(N1은 기회 id, N2·N4는 여정 id, N5는 빈 값).
/// 하루 최대는 sent·scheduled(취소 빼고)를 atUtc의 한국 날짜로 세고, 같은 (kind, refKey)로는 다시 알리지 않는다
@DataClassName('NotificationLogRow')
class NotificationLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<NoticeKind>()();
  TextColumn get refKey => text()();
  IntColumn get atUtc => integer()();
  TextColumn get status => textEnum<NoticeStatus>()();
}

/// 알림 켜고 끄기 1행(id = 1). 전체와 종류별 다섯. 행이 없으면 모두 켠 것이다
@DataClassName('NotificationSettingsRow')
class NotificationSettings extends Table {
  IntColumn get id => integer()();
  BoolColumn get allOn => boolean().withDefault(const Constant(true))();
  BoolColumn get n1On => boolean().withDefault(const Constant(true))();
  BoolColumn get n2On => boolean().withDefault(const Constant(true))();
  BoolColumn get n3On => boolean().withDefault(const Constant(true))();
  BoolColumn get n4On => boolean().withDefault(const Constant(true))();
  BoolColumn get n5On => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// 물감 길 (스키마 16, 옛 앱 걷기 창 AppWalks를 대신): 앱이 앞에 있을 때 걸으면 저절로 열리고
/// ([startUtc] = 그 첫 걸음의 분), 걸음이 멈추면(idle, 마지막 걸음 분의 끝) 또는 앱이 끝나면(appEnded,
/// 다음 실행에서 마지막으로 살아 있던 시각) 닫힌다 ([startUtc, endUtc), epoch ms).
/// endUtc가 null이면 열려 있다 (앱이 살아 있는 동안은 지금까지로 센다)
@DataClassName('PaintTrailRow')
///
/// 칠한 색은 [PaintTrailColors] (스키마 20, 그전 18~19는 이 표의 color_id·color_end_utc 두 열)
class PaintTrails extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get startUtc => integer()();
  IntColumn get endUtc => integer().nullable()();
  TextColumn get endReason => textEnum<PaintTrailEnd>().nullable()();
}

/// 물감 길 색 구간 (스키마 20, 스키마 v10.7 PaintTrailColors, 16장 11/16 ‘물감 길 하나에 색 구간 여럿’):
/// 물감 길 [trailId]를 [fromUtc](epoch ms)부터 [colorId]로 칠했다. 구간 끝은 같은 물감 길의 다음 줄 fromUtc
/// (없으면 물감 길 끝). 물감 길을 열 때 한 줄(그때 칠할 물감), 걷는 중에 배낭에서 바꾸면 한 줄, 고른 색을 다 쓰면
/// 기본 물감 한 줄. 줄이 없는 물감 길은 기본 물감 (스키마 18 전 물감 길)
@DataClassName('PaintTrailColorRow')
class PaintTrailColors extends Table {
  IntColumn get trailId => integer()();
  IntColumn get fromUtc => integer()();
  TextColumn get colorId => text()();

  @override
  Set<Column> get primaryKey => {trailId, fromUtc};
}

/// 스키마 18~19의 물감 길 열을 옮길 때 다 쓴 뒤 구간의 색 = 기본 물감 id (config paintColor.default.id,
/// 스키마 v10.5 basic). 마이그레이션은 config를 읽지 못해 여기 둔다
const migrationBasicPaintId = 'basic';

/// 럭 장부 행의 종류: earn은 걸어서 번 것(하루 한 행, 다시 계산하면 덮어쓴다), ad는 광고 보상,
/// spend는 쓴 것, gift는 첫 선물 (ad·spend·gift는 한 번 쓰고 고치지 않는다)
enum CoinKind { earn, ad, spend, gift }

/// 럭 장부. day는 한국 날짜, amount는 늘어난 만큼 양수(spend도 양수로 두고 kind로 가린다), refId는
/// 그 일을 가리키는 값 (광고 id·산 물건 등)
@DataClassName('CoinLedgerRow')
class CoinLedger extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get day => text()();
  TextColumn get kind => textEnum<CoinKind>()();
  IntColumn get amount => integer()();
  TextColumn get refId => text().nullable()();
}

/// 길 위 이벤트 한 칸 (스키마 13). 여정(journeyId)의 k번째 칸(2km마다)을 넘는 그 자리에서 한 줄을 만들고,
/// 한 번 만들면 다시 계산하지 않는다. praiseText는 빈칸을 채운 칭찬 문구의 스냅샷이고, 풍경 문구는 id로
/// events.json에서 찾는다. progressPct는 그때의 여정 진행률(%, 다음 칸의 '기준을 넘었나' 비교용),
/// atUtc는 만든 시각(걷기 기록이 그 걷기 시간대의 줄을 찾는다), terrain·season은 장면 값(night는 낮밤)
@DataClassName('JourneyEventRow')
class JourneyEvents extends Table {
  TextColumn get journeyId => text()();
  IntColumn get k => integer()();
  TextColumn get terrain => text()();
  TextColumn get season => text()();
  BoolColumn get night => boolean()();
  TextColumn get sceneTextId => text()();
  TextColumn get praiseId => text()();
  TextColumn get praiseText => text()();
  RealColumn get progressPct => real().withDefault(const Constant(0.0))();
  IntColumn get atUtc => integer()();

  @override
  Set<Column> get primaryKey => {journeyId, k};
}

/// 받은 도장 (스키마 13). 한 번 받으면 지우지 않는다. seen이 false면 배낭에 새 도장 표시
@DataClassName('BadgeOwnedRow')
class BadgesOwned extends Table {
  TextColumn get badgeId => text()();
  IntColumn get atUtc => integer()();
  BoolColumn get seen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {badgeId};
}

/// 만난 동행 (스키마 15, companions.json id마다 한 줄). 처음 만날 때 만든다.
/// metJourneyId·metK는 만남이 일어난 칸 (같은 칸에서 두 번 만나지 않게), walksTogether는 함께 인정된 걷기 1번 수,
/// chapter는 열린 장(0 = 프롤로그, 끝은 config companions.chapters), readChapter는 읽은 장
@DataClassName('CompanionRow')
class Companions extends Table {
  TextColumn get companionId => text()();
  IntColumn get metUtc => integer()();
  TextColumn get metJourneyId => text().nullable()();
  IntColumn get metK => integer().nullable()();
  IntColumn get walksTogether => integer().withDefault(const Constant(0))();
  IntColumn get chapter => integer().withDefault(const Constant(0))();
  IntColumn get readChapter => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {companionId};
}

/// 함께 걷는 동행이 바뀐 기록 (스키마 15). startUtc부터 다음 줄 앞까지 그 동행과 걷는다 (null은 혼자 걷기).
/// 걸음 기록이 늦게 들어와도 '그 걷기 1번을 시작할 때 누구와 걸었나'가 같게 나오도록 지금 값만 두지 않는다.
/// 지금 함께 걷는 동행은 마지막 줄이다 (줄이 없으면 혼자)
@DataClassName('CompanionStintRow')
class CompanionStints extends Table {
  IntColumn get startUtc => integer()();
  TextColumn get companionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {startUtc};
}

/// 상점 보관함 (스키마 15): 산 뒤 아직 안 쓴 여행 효과 (shop.json id마다 한 줄, 한도 config shop.maxHoldPerItem)
@DataClassName('ShopInventoryRow')
class ShopInventory extends Table {
  TextColumn get itemId => text()();
  IntColumn get count => integer()();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// 여행 효과를 쓴 기록 (스키마 15). day는 한국 날짜, km은 여행 거리에 더한 양(하루 상한 config shop.dailyEffectCapKm),
/// paintTrailId는 열린 물감 길이 끝날 때까지 듣는 효과(순풍)의 물감 길 (스키마 16, 옛 appWalkId)
@DataClassName('ShopUseRow')
class ShopUses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemId => text()();
  TextColumn get day => text()();
  TextColumn get journeyId => text()();
  IntColumn get paintTrailId => integer().nullable()();
  RealColumn get km => real().withDefault(const Constant(0.0))();
}

/// 얻은 배 (스키마 15). 기본 배는 줄이 없어도 가진 것으로 본다. colors는 고른 색 JSON
/// (상점 배 6척만 3구역, 16장 11/4), 고른 적 없으면 null
@DataClassName('BoatOwnedRow')
class BoatsOwned extends Table {
  TextColumn get boatId => text()();
  IntColumn get atUtc => integer()();
  TextColumn get colors => text().nullable()();

  @override
  Set<Column> get primaryKey => {boatId};
}

/// 하루 카드 상태 1행(id = 1, 스키마 17, M1 명세 v0.5 ⑥ ReportState). lastShownDay는 하루 카드로 보여 주고
/// 닫은 마지막 날(한국 날짜 키 'YYYY-MM-DD'). 행이 없으면 첫 기록일(설치한 날) 전날로 본다
/// (처음 설치한 날에는 카드가 없다). 백업에 넣는다 (새 기기에서 본 카드를 다시 띄우지 않게)
@DataClassName('ReportStateRow')
class ReportState extends Table {
  IntColumn get id => integer()();
  TextColumn get lastShownDay => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 물감 보관 (스키마 18, 스키마 v10.5 PaintStock): 물감 색 id마다 가진 통 수(0~config paintColor.stock.maxTubesPerColor)와
/// 남은 거리 remainM(m). 기본 물감은 무제한이라 줄이 없다. firstGotAt·lastGotAt은 그 색 통을 처음·마지막으로 주운 시각
/// (배낭 ‘최근’ 칸), seen이 false면 배낭에 새 색 표시. 남은 거리가 0이 되면 통 수도 0 (줄은 남는다)
@DataClassName('PaintStockRow')
class PaintStock extends Table {
  TextColumn get colorId => text()();
  IntColumn get tubes => integer()();
  RealColumn get remainM => real()();
  IntColumn get firstGotAt => integer()();
  IntColumn get lastGotAt => integer()();
  BoolColumn get seen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {colorId};
}

/// 주운 물감 통 (스키마 18): 물감 길 trailId의 dropNo번째 방울에서 나온 통 하나. 방울 보상은 물감 길·방울 번호로
/// 정하는 무작위라 같은 방울을 다시 넘겨도 이 키로 한 번만 받는다. 통 수(가진 통)는 이 줄을 주운 차례로 쓴 것으로 센다
@DataClassName('PaintTubeRow')
class PaintTubes extends Table {
  IntColumn get trailId => integer()();
  IntColumn get dropNo => integer()();
  TextColumn get colorId => text()();
  RealColumn get amountM => real()();
  IntColumn get atUtc => integer()();

  @override
  Set<Column> get primaryKey => {trailId, dropNo};
}

@DriftDatabase(
  tables: [
    StepMinutes,
    DaySummaries,
    WalkSessions,
    Journeys,
    TravelFund,
    SyncState,
    PaintingsOwned,
    PropsOwned,
    Profile,
    GuestbookTickets,
    GuestbookPosts,
    NotificationLog,
    NotificationSettings,
    PaintTrails,
    CoinLedger,
    JourneyEvents,
    BadgesOwned,
    Companions,
    CompanionStints,
    ShopInventory,
    ShopUses,
    BoatsOwned,
    ReportState,
    PaintStock,
    PaintTubes,
    PaintTrailColors,
  ],
)
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 20;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // 앞 판의 일부 표만 흉내 낸 DB(시험)에서도 돌게, 표가 있는지·열이 없는지 본다
          Future<bool> hasTable(String table) async => (await customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
                variables: [Variable.withString(table)],
              ).get())
                  .isNotEmpty;
          Future<bool> lacks(String table, String column) async =>
              await hasTable(table) &&
              (await customSelect(
                'SELECT name FROM pragma_table_info(?) WHERE name = ?',
                variables: [Variable.withString(table), Variable.withString(column)],
              ).get())
                  .isEmpty;
          if (from < 2) {
            await m.addColumn(journeys, journeys.endLat);
            await m.addColumn(journeys, journeys.endLng);
            await m.addColumn(journeys, journeys.endedUtc);
            await m.addColumn(journeys, journeys.visitNo);
            await m.addColumn(journeys, journeys.prevFrame);
            await m.addColumn(journeys, journeys.newFrame);
            await m.addColumn(journeys, journeys.arrivalShown);
            await m.createTable(paintingsOwned);
            await m.createTable(propsOwned);
            // 1에서 도착한 여정은 그림 기록이 없다. 도착 화면을 띄우지 않는다
            await customStatement("UPDATE journeys SET arrival_shown = 1 WHERE status = 'arrived'");
          }
          if (from < 3) {
            await m.createTable(profile);
          }
          // 4에서 만들던 화집 벽 표(wall_slots)는 13에서 없앴다 (아래)
          // 2에서 새로 만든 그림 표는 지금 정의라 seen 열이 이미 있다. 2~4에서 올라올 때만 더한다
          // (옛 행은 기본값 true, 곧 본 것)
          if (from >= 2 && from < 5) await m.addColumn(paintingsOwned, paintingsOwned.seen);
          // 2 이하에서 올라올 때는 위 createTable(profile)이 지금 정의라 새 열이 이미 있다.
          // 3~5에서 올라올 때만 더한다
          if (from >= 3 && from < 6) {
            await m.addColumn(profile, profile.homeId);
            await m.addColumn(profile, profile.ageConfirmedAt);
            await m.addColumn(profile, profile.installId);
            await m.addColumn(profile, profile.nickname);
            await m.addColumn(profile, profile.look);
            await m.addColumn(profile, profile.onboardedAt);
            await m.addColumn(profile, profile.linkConsentAt);
            await m.addColumn(profile, profile.guestbookConsentAt);
          }
          // 여정 표는 1부터 있었고 다시 만든 적이 없어서 어디서 올라와도 열을 더한다
          if (from < 7) {
            await m.addColumn(journeys, journeys.destLat);
            await m.addColumn(journeys, journeys.destLng);
          }
          if (from < 8) {
            await m.createTable(guestbookTickets);
            await m.createTable(guestbookPosts);
          }
          if (from < 9) {
            await m.createTable(notificationLog);
            await m.createTable(notificationSettings);
          }
          // 동기화 상태 표는 1부터 있었고 다시 만든 적이 없어서 어디서 올라와도 열을 더한다
          if (from < 10) await m.addColumn(syncState, syncState.restoreFloorDay);
          // 하루 요약·걷기 구간·동기화 상태 표는 1부터 있었고 다시 만든 적이 없어서 어디서 올라와도 열을 더한다.
          // 옛 하루에는 앱 걷기가 없었으니 이동 거리 = 실제 거리 (보너스·앱 걷기 이동 거리·럭은 기본값 0)
          // (11에서 더한 보너스·앱 걷기 이동 거리 열과 앱 걷기 표는 16에서 물감 길로 바꿨다. 옛 정의라 SQL로 둔다)
          if (from < 11) {
            await customStatement(
                'ALTER TABLE day_summaries ADD COLUMN bonus_m REAL NOT NULL DEFAULT 0.0');
            await m.addColumn(daySummaries, daySummaries.shopM);
            await m.addColumn(daySummaries, daySummaries.travelM);
            await customStatement(
                'ALTER TABLE day_summaries ADD COLUMN walk_travel_m REAL NOT NULL DEFAULT 0.0');
            await m.addColumn(daySummaries, daySummaries.coins);
            await customStatement(
                'ALTER TABLE walk_sessions ADD COLUMN bonus_m REAL NOT NULL DEFAULT 0.0');
            await m.addColumn(syncState, syncState.lastAliveUtc);
            await customStatement('CREATE TABLE IF NOT EXISTS app_walks ('
                'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, start_utc INTEGER NOT NULL, '
                'end_utc INTEGER NULL, end_reason TEXT NULL)');
            await m.createTable(coinLedger);
            await customStatement('UPDATE day_summaries SET travel_m = distance_m');
          }
          // 14: 글꼴을 Pretendard 하나로 해서 고른 글꼴 열(12에서 더함)을 지운다
          final fontColumn = await customSelect(
                  "SELECT name FROM pragma_table_info('profile') WHERE name = 'display_font'")
              .get();
          if (fontColumn.isNotEmpty) {
            await customStatement('ALTER TABLE profile DROP COLUMN display_font');
          }
          // 13: 길 위 이벤트·도장. 여정 표는 어디서 올라와도 열을 더한다. 화집 벽 표는 더 안 써서 지운다
          // (없는 DB에서도 안전하게)
          if (from < 13) {
            await m.addColumn(journeys, journeys.eventM);
            await m.createTable(journeyEvents);
            await m.createTable(badgesOwned);
            await customStatement('DROP TABLE IF EXISTS wall_slots');
          }
          // 15: 동행·상점·배. 2 이하에서 올라올 때는 위 createTable(profile)이 지금 정의라 열이 이미 있다.
          // 상점 사용 기록은 15 정의(app_walk_id)로 만들고 16에서 이름을 바꾼다
          if (from < 15) {
            if (from >= 3) await m.addColumn(profile, profile.boatId);
            await m.createTable(companions);
            await m.createTable(companionStints);
            await m.createTable(shopInventory);
            await customStatement('CREATE TABLE IF NOT EXISTS shop_uses ('
                'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, item_id TEXT NOT NULL, '
                'day TEXT NOT NULL, journey_id TEXT NOT NULL, app_walk_id INTEGER NULL, '
                'km REAL NOT NULL DEFAULT 0.0)');
            await m.createTable(boatsOwned);
          }
          // 16: 물감 길 (M1 명세 v0.5 ⑦). 앱 걷기 창을 물감 길로 옮기고(번호 그대로, finish → idle),
          // 보너스 열을 지우고 물감 길 거리 열을 더한다. 여행 거리 = 실제 + 상점으로 바로 고치고,
          // 물감 길 거리·럭은 다음 동기화가 가장 이른 하루 요약부터 다시 계산한다 (recomputeFromDay)
          if (from < 16) {
            // 앞 판의 일부 표만 흉내 낸 DB(시험)에서도 돌게 표·열이 있을 때만 고친다
            Future<bool> has(String table, [String? column]) async => (await customSelect(
                  column == null
                      ? "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?"
                      : 'SELECT name FROM pragma_table_info(?) WHERE name = ?',
                  variables: [
                    Variable.withString(table),
                    if (column != null) Variable.withString(column),
                  ],
                ).get())
                .isNotEmpty;
            await m.createTable(paintTrails);
            if (await has('app_walks')) {
              await customStatement(
                  'INSERT INTO paint_trails (id, start_utc, end_utc, end_reason) '
                  "SELECT id, start_utc, end_utc, CASE end_reason WHEN 'finish' THEN 'idle' "
                  'ELSE end_reason END FROM app_walks');
              await customStatement('DROP TABLE app_walks');
            }
            if (await has('day_summaries')) {
              for (final column in const ['bonus_m', 'walk_travel_m']) {
                if (await has('day_summaries', column)) {
                  await customStatement('ALTER TABLE day_summaries DROP COLUMN $column');
                }
              }
              if (!await has('day_summaries', 'trail_m')) {
                await m.addColumn(daySummaries, daySummaries.trailM);
              }
              if (await has('day_summaries', 'shop_m') && await has('day_summaries', 'travel_m')) {
                await customStatement('UPDATE day_summaries SET travel_m = distance_m + shop_m');
              }
            }
            if (await has('walk_sessions', 'bonus_m')) {
              await customStatement('ALTER TABLE walk_sessions DROP COLUMN bonus_m');
            }
            if (await has('shop_uses', 'app_walk_id')) {
              await customStatement(
                  'ALTER TABLE shop_uses RENAME COLUMN app_walk_id TO paint_trail_id');
            }
            if (await has('sync_state')) {
              await m.addColumn(syncState, syncState.recomputeFromDay);
              if (await has('day_summaries')) {
                await customStatement('UPDATE sync_state SET recompute_from_day = '
                    '(SELECT MIN(day) FROM day_summaries)');
              }
            }
          }
          // 17: 하루 카드 (M1 명세 v0.5 ⑥). 행은 만들지 않는다: 없으면 첫 기록일 전날로 보니
          // 이미 쓰던 기기는 다음에 열 때 밀린 날(최대 config report.maxMergeDays) 카드가 한 번 뜬다
          if (from < 17) {
            await m.createTable(reportState);
            // 이미 쓰던 기기 표시: 날 없는 행 하나. ReportService가 첫 카드를 어제 1장으로 본다
            // (16장 11/15 ②, 이전: 첫 기록일부터 최대 ‘지난 30일’ 한 장). 새로 설치한 기기는 행이 없다
            await into(reportState).insert(const ReportStateCompanion(id: Value(1)));
          }
          // 18: 물감 색·물감 모으기 (M1 v0.7, 스키마 v10.5). 2 이하에서 올라올 때는 위 createTable(profile)이 지금
          // 정의라 새 열이 이미 있어 건너뛴다. 18의 물감 길 색 두 열(color_id·color_end_utc)은 20에서 표로 옮겨서
          // 여기서는 더하지 않는다 (옛 물감 길은 칠한 색이 없어 기본 물감이다)
          if (from < 18) {
            await m.createTable(paintStock);
            await m.createTable(paintTubes);
            // 표가 있고 열이 없을 때만 더한다
            if (await lacks('profile', 'paint_color_id')) {
              await m.addColumn(profile, profile.paintColorId);
            }
          }
          // 19: 상점 새 상품을 본 시각 (수레 점, 16장 11/16 Annie). 이미 쓰던 기기는 올린 순간에 점이 생기지 않게
          // 지금까지 얻은 소품의 마지막 시각(없으면 설치 시각)을 본 시각으로 둔다
          if (from < 19 && await hasTable('sync_state')) {
            if (await lacks('sync_state', 'shop_seen_utc')) {
              await m.addColumn(syncState, syncState.shopSeenUtc);
            }
            await customStatement(await hasTable('props_owned')
                ? 'UPDATE sync_state SET shop_seen_utc = '
                    'COALESCE((SELECT MAX(unlocked_utc) FROM props_owned), install_utc)'
                : 'UPDATE sync_state SET shop_seen_utc = install_utc');
          }
          // 20: 물감 길 하나에 색 구간 여럿 (16장 11/16 물감 세 가지 ③, 스키마 v10.7) + 그날 날씨 (①).
          // 18~19의 두 열(연 때 색·다 쓴 시각)을 구간 줄 둘(그 색 → 기본 물감)로 옮기고 열을 지운다
          if (from < 20) {
            await m.createTable(paintTrailColors);
            if (await hasTable('paint_trails') && !await lacks('paint_trails', 'color_id')) {
              // 연 순간에 이미 다 썼으면(다 쓴 시각 ≤ 시작) 처음부터 기본 물감
              await customStatement(
                  'INSERT OR IGNORE INTO paint_trail_colors (trail_id, from_utc, color_id) '
                  'SELECT id, start_utc, CASE WHEN color_end_utc IS NOT NULL AND color_end_utc <= start_utc '
                  'THEN ? ELSE color_id END FROM paint_trails WHERE color_id IS NOT NULL',
                  [migrationBasicPaintId]);
              await customStatement(
                  'INSERT OR IGNORE INTO paint_trail_colors (trail_id, from_utc, color_id) '
                  'SELECT id, color_end_utc, ? FROM paint_trails '
                  'WHERE color_id IS NOT NULL AND color_end_utc IS NOT NULL AND color_end_utc > start_utc',
                  [migrationBasicPaintId]);
              await customStatement('ALTER TABLE paint_trails DROP COLUMN color_end_utc');
              await customStatement('ALTER TABLE paint_trails DROP COLUMN color_id');
            }
            if (await lacks('sync_state', 'weather_day')) {
              await m.addColumn(syncState, syncState.weatherDay);
              await m.addColumn(syncState, syncState.weatherKind);
            }
          }
        },
      );
}
