import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

/// 그림 PNG를 공유 시트로 내보내는 곳. 테스트는 FakePaintingSharer를 쓴다
abstract class PaintingSharer {
  /// [png]를 [fileName]으로, 글 [text]와 함께 공유 시트에 올린다.
  /// [origin]은 iPad에서 시트가 뜰 자리(누른 버튼의 화면 좌표)
  Future<void> share({
    required Uint8List png,
    required String fileName,
    required String text,
    Rect? origin,
  });
}

/// share_plus로 연다. 못 열면 예외가 나니 부르는 쪽에서 잡는다
class SharePlusPaintingSharer implements PaintingSharer {
  const SharePlusPaintingSharer();

  @override
  Future<void> share({
    required Uint8List png,
    required String fileName,
    required String text,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        // XFile.fromData의 name은 웹 말고는 쓰이지 않아서 파일 이름은 fileNameOverrides로도 준다
        files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ),
    );
  }
}

/// [FakePaintingSharer]가 받은 부름 하나
class SharedPainting {
  const SharedPainting(this.png, this.fileName, this.text, this.origin);

  final Uint8List png;
  final String fileName;
  final String text;
  final Rect? origin;
}

class FakePaintingSharer implements PaintingSharer {
  /// 받은 부름, 부른 순서대로
  final calls = <SharedPainting>[];

  /// true면 공유할 때 예외를 던진다 (공유 시트를 못 여는 기기를 흉내 낼 때)
  bool fail = false;

  @override
  Future<void> share({
    required Uint8List png,
    required String fileName,
    required String text,
    Rect? origin,
  }) async {
    calls.add(SharedPainting(png, fileName, text, origin));
    if (fail) throw StateError('공유 시트를 열 수 없다');
  }
}
