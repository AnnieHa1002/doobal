import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auto_sync.dart' show scaffoldMessengerKey;
import '../../app/paint_trail_controller.dart';
import '../../domain/paint_trail.dart' show PaintTrailEnd;
import '../common/toast.dart';

/// 물감 길 판정(PaintTrailController)을 앱 뼈대가 떠 있는 동안 살려 둔다 (StartGate가 탭 뼈대 위에 둔다).
/// 걸어도·물감 길이 끝나도 화면(탭)은 바꾸지 않는다 (16장 11/18 ⑤, 11/16 쉼터↔걷는 중 6규칙을 대신함):
/// 걷는 중이면 걷기 탭 아이콘의 발자국이 움직인다 (탭 바).
/// 걸음이 멈춰 물감 길이 끝나면 토스트 `물감 길 n km를 그렸어요` 한 줄 (도착으로 끝났으면 도착 화면이 맡아 없다)
class PaintTrailHost extends ConsumerStatefulWidget {
  const PaintTrailHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PaintTrailHost> createState() => _PaintTrailHostState();
}

class _PaintTrailHostState extends ConsumerState<PaintTrailHost> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(paintTrailProvider, (prev, next) {
      if (prev?.active == true && !next.active) _onEnded(next);
    });
  }

  /// 물감 길이 끝났다: 토스트 한 줄. 도착으로 끝났으면 도착 화면이 맡는다
  void _onEnded(PaintTrailState s) {
    if (s.endedBy == PaintTrailEnd.arrived) return;
    final km = s.endedKm;
    final messenger = scaffoldMessengerKey.currentState;
    if (km == null || messenger == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queueToastOn(messenger, paintTrailEndedToast(km));
    });
  }

  @override
  Widget build(BuildContext context) {
    // 물감 길 판정을 앱 뼈대가 있는 동안 살려 둔다
    ref.watch(paintTrailProvider.select((s) => s.active));
    return widget.child;
  }
}

/// 물감 길이 끝났을 때의 토스트 (캔버스 2-2): `물감 길 2.0km를 그렸어요`
String paintTrailEndedToast(double km) => '물감 길 ${km.toStringAsFixed(1)}km를 그렸어요';
