import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

/// 사진첩에 저장한 결과
enum SaveOutcome { saved, denied, failed }

/// 그림 PNG를 기기 사진첩에 저장하는 곳 (그림 크게 보기의 저장, 16장 11/10). 테스트는 FakePaintingSaver를 쓴다
abstract class PaintingSaver {
  /// [png]를 [name](확장자 없이)으로 사진첩에 넣는다. 권한이 없으면 한 번 묻는다
  Future<SaveOutcome> save(Uint8List png, String name);
}

/// gal로 저장한다. 안드로이드 10 이상·iOS 14 이상은 사진 추가 권한만 쓴다
class GalPaintingSaver implements PaintingSaver {
  const GalPaintingSaver();

  @override
  Future<SaveOutcome> save(Uint8List png, String name) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) return SaveOutcome.denied;
      await Gal.putImageBytes(png, name: name);
      return SaveOutcome.saved;
    } on GalException catch (e) {
      debugPrint('그림 저장 실패: ${e.type}');
      return e.type == GalExceptionType.accessDenied ? SaveOutcome.denied : SaveOutcome.failed;
    } catch (e) {
      debugPrint('그림 저장 실패: $e');
      return SaveOutcome.failed;
    }
  }
}

/// [FakePaintingSaver]가 받은 부름 하나
class SavedPainting {
  const SavedPainting(this.png, this.name);

  final Uint8List png;
  final String name;
}

class FakePaintingSaver implements PaintingSaver {
  /// 받은 부름, 부른 순서대로
  final calls = <SavedPainting>[];

  /// 돌려줄 결과
  SaveOutcome outcome = SaveOutcome.saved;

  @override
  Future<SaveOutcome> save(Uint8List png, String name) async {
    calls.add(SavedPainting(png, name));
    return outcome;
  }
}
