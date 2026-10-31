import 'package:flutter/foundation.dart' show debugPrint;

/// 백업 문자열을 서버에 두고 받아 오는 곳 (users/{uid}/backup/state 1문서). 테스트는 가짜를 쓴다
abstract class BackupStore {
  /// [uid]의 백업을 [text]로 덮어쓴다
  Future<void> save(String uid, String text);

  /// [uid]의 백업. 없으면 null
  Future<String?> load(String uid);
}

/// 자리표시: 메모리에만 둔다 (앱을 끄면 사라진다). M5에서 Firestore로 바꾼다
class PlaceholderBackupStore implements BackupStore {
  final _texts = <String, String>{};

  @override
  Future<void> save(String uid, String text) async {
    debugPrint('백업 저장(자리표시): ${text.length}자');
    _texts[uid] = text;
  }

  @override
  Future<String?> load(String uid) async => _texts[uid];
}
