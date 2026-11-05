part of 'sync_service.dart';

// 동행 (M4). 동행 일의 동기화는 이 파일에 둔다 (병렬 개발 때 sync_service.dart 본문이 부딪히지 않게)

extension CompanionSync on SyncService {
  /// 동기화 끝에 동행 일을 처리한다 (함께 걷기 세기, 새 장 열기, 완결 소품).
  /// 돌려주는 것은 이번에 새로 생긴 알림 후보(N3). 아직 만남이 없어서 할 일이 없다
  Future<List<NoticeCandidate>> _syncCompanions(DateTime now) async => const [];

  /// 도장 조건이 읽는 값: 만난 동행 수, 이야기를 끝까지 연 동행 수
  Future<({int met, int finales})> _companionBadgeFacts() async {
    final rows = await db.select(db.companions).get();
    return (
      met: rows.length,
      finales: rows.where((r) => r.chapter >= rules.companionChapters).length,
    );
  }
}
