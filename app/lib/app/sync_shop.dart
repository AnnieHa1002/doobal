part of 'sync_service.dart';

// 상점·배 (M4.5). 상점 일의 동기화는 이 파일에 둔다 (병렬 개발 때 sync_service.dart 본문이 부딪히지 않게)

extension ShopSync on SyncService {
  /// 동기화 끝에 새로 얻은 보상 배를 더하고 돌려준다 (섬 도착, boats.json islandArrival).
  /// 아직 판정하지 않는다
  Future<List<Boat>> _unlockBoats(DateTime now) async => const [];
}
