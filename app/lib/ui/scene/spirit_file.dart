import 'package:flutter/foundation.dart';
import 'package:rive/rive.dart' as rive;

import 'spirit_character.dart';

/// 정령 riv(`spirit_v36.riv` 11.8MB)를 그리기(Factory)마다 한 번 읽어 여러 정령이 같이 쓴다 (정령 계약 7장).
/// 컨트롤러(아트보드·상태 머신·뷰 모델 인스턴스)는 정령마다 따로 만든다.
/// 앱 기본 그리기는 앱 시작 때 [SpiritCharacter.preload]로 읽어 끝까지 두고, 다른 그리기(하루 카드 공유 이미지의 Flutter 그리기)는
/// 쓰는 정령이 하나도 없으면 놓는다 (전처럼 다 쓰면 dispose)
abstract final class SpiritFile {
  static final _shared = <rive.Factory, _Shared>{};

  /// 앱이 끝날 때까지 두는 그리기 ([preload])
  static final _keep = <rive.Factory>{};

  /// 실제로 파일을 읽는 함수 (시험이 바꿔 읽기 횟수를 세거나 실패를 낸다)
  @visibleForTesting
  static Future<rive.File?> Function(rive.Factory) read = _readAsset;

  /// 실제로 읽은 횟수 (시험용)
  @visibleForTesting
  static int reads = 0;

  static Future<rive.File?> _readAsset(rive.Factory factory) async {
    await rive.RiveNative.init();
    return rive.File.asset(SpiritCharacter.asset, riveFactory: factory);
  }

  /// [factory]로 미리 읽기 시작해 앱이 끝날 때까지 둔다 (앱 시작 때 [SpiritCharacter.preload]가 기본 그리기로).
  /// 기다리지 않는다 (실패하면 정령이 처음 뜰 때 다시 읽는다)
  static void preload(rive.Factory factory) {
    _keep.add(factory);
    _shared[factory] ??= _start(factory);
  }

  /// 정령 하나가 [factory] 파일을 빌린다. 다 쓰면 받은 Future로 [release].
  /// 읽기에 실패하면(파일 없음·rive_native 없음) Future가 오류로 끝나고, 다음에 빌리는 정령이 다시 읽는다
  static Future<rive.File> acquire(rive.Factory factory) {
    final shared = _shared[factory] ??= _start(factory);
    shared.users++;
    return shared.file;
  }

  /// [acquire]로 빌린 것을 돌려준다. 그 그리기를 쓰는 정령이 없고 [preload]한 것이 아니면 파일을 놓는다
  static void release(rive.Factory factory, Future<rive.File> file) {
    final shared = _shared[factory];
    // 이미 실패해 비운 것 (그사이 새로 읽은 것은 건드리지 않는다)
    if (shared == null || !identical(shared.file, file)) return;
    shared.users--;
    if (shared.users > 0 || _keep.contains(factory)) return;
    _shared.remove(factory);
    shared.file.then<void>((f) => f.dispose(), onError: (Object _) {});
  }

  /// 지금 들고 있는 그리기인지 (시험용)
  @visibleForTesting
  static bool holds(rive.Factory factory) => _shared.containsKey(factory);

  /// 들고 있는 것을 모두 잊는다 (시험용, dispose하지 않음)
  @visibleForTesting
  static void reset() {
    _shared.clear();
    _keep.clear();
    reads = 0;
    read = _readAsset;
  }

  static _Shared _start(rive.Factory factory) {
    reads++;
    final file = Future.sync(() => read(factory))
        .then((f) => f ?? (throw StateError('정령 파일을 읽지 못했어요')));
    final shared = _Shared(file);
    // 실패하면 비워서 다음 정령이 다시 읽게 한다 (전처럼 정령마다 다시 시도)
    file.then<void>((_) {}, onError: (Object _) {
      if (identical(_shared[factory], shared)) _shared.remove(factory);
    });
    return shared;
  }
}

class _Shared {
  _Shared(this.file);
  final Future<rive.File> file;
  int users = 0;
}
