import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/app_text.dart';
import '../common/confirm_sheet.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';

/// 걸을 거리(km): 지금 자리에서 그 명소까지 [totalKm]에서, 경비를 더하면 [fundKm]를 뺀다 (0 아래로는 안 간다)
double walkKmAfterFund(double totalKm, double fundKm, {required bool useFund}) =>
    useFund ? math.max(0.0, totalKm - fundKm) : totalKm;

String _km(double km) => formatKmShort(km * 1000);

/// 4-2 시트 하나 (11/4): `○○(으)로 바꿀까요?` + 설명 줄 + 경비 체크칸 + `걸을 거리 n km` + 취소/바꾸기.
/// 예전의 시트 두 번 이어 뜨기(바꾸기 확인 → 경비 묻기)를 하나로 합쳤다.
/// [walkedKm]가 있으면(여정 중에 바꿀 때) `걸은 n km는 넘어가지 않아요.` 줄이 붙고 버튼은 `바꾸기`,
/// 없으면(여정 없이 처음 출발) 제목이 `○○(으)로 출발할까요?`, 버튼이 `출발하기`다.
/// [fundKm]이 0이면 경비 칸이 없다. [totalKm]는 지금 자리에서 그 명소까지의 거리 (아직 모르면 null:
/// 걸을 거리 줄을 뺀다). 체크 기본값은 켜짐.
/// 바꾸기·출발하기를 누르면 경비를 더할지(true/false), 취소하거나 시트 밖을 눌러 닫으면 null
Future<bool?> showDestSheet(
  BuildContext context, {
  required String destName,
  required double fundKm,
  double? walkedKm,
  double? totalKm,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.card,
    barrierColor: Palette.ink.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      side: BorderSide(color: Palette.ink, width: InkLine.panel),
    ),
    builder: (context) => _DestSheet(
      destName: destName,
      fundKm: fundKm,
      walkedKm: walkedKm,
      totalKm: totalKm,
    ),
  );
}

class _DestSheet extends StatefulWidget {
  const _DestSheet({required this.destName, required this.fundKm, this.walkedKm, this.totalKm});

  final String destName;
  final double fundKm;
  final double? walkedKm;
  final double? totalKm;

  @override
  State<_DestSheet> createState() => _DestSheetState();
}

class _DestSheetState extends State<_DestSheet> {
  var _useFund = true;

  @override
  Widget build(BuildContext context) {
    final change = widget.walkedKm != null;
    final total = widget.totalKm;
    final hasFund = widget.fundKm > 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: const ValueKey('dest-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 글자 크기를 키워 길어지면 글만 스크롤하고 버튼은 늘 보인다
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      change ? '${widget.destName}(으)로 바꿀까요?' : '${widget.destName}(으)로 출발할까요?',
                      style: context.display(18),
                    ),
                    if (change) ...[
                      const SizedBox(height: 8),
                      Text(
                        '걸은 ${_km(widget.walkedKm!)}는 넘어가지 않아요.',
                        key: const ValueKey('dest-sheet-walked'),
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Palette.ink),
                      ),
                    ],
                    if (hasFund) ...[
                      const SizedBox(height: 12),
                      _fundRow(context),
                    ],
                    if (total != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '걸을 거리 ${_km(walkKmAfterFund(total, widget.fundKm, useFund: hasFund && _useFund))}',
                        key: const ValueKey('dest-sheet-total'),
                        style: context.display(14, color: Palette.subInk),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: '취소',
                    kind: GameButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GameButton(
                    label: change ? '바꾸기' : '출발하기',
                    onPressed: () => Navigator.of(context).pop(!hasFund || _useFund),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 경비 체크칸: `경비 3.2km 더하기` + 이벤트 없음 아이콘 (경비로 가는 구간에는 길 위 이벤트가 없다)
  Widget _fundRow(BuildContext context) {
    return Semantics(
      checked: _useFund,
      child: InkWell(
        key: const ValueKey('dest-sheet-fund'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _useFund = !_useFund),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Palette.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.subInk, width: InkLine.pill),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _useFund ? Palette.ink : Palette.card,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Palette.ink, width: InkLine.panel),
                ),
                child: _useFund
                    ? const Icon(Icons.check, size: 16, color: Palette.card)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('경비 ${_km(widget.fundKm)} 더하기', style: context.display(14)),
              ),
              const SizedBox(width: 8),
              const NoEventIcon(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이벤트 없음 아이콘 20pt: 빗금 친 이정표 (그림 에셋이 나오기 전 자리표시, 글 없음).
/// 화면 읽기에는 ‘경비로 가는 구간에는 이벤트가 없어요’로 읽힌다
class NoEventIcon extends StatelessWidget {
  const NoEventIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '경비로 가는 구간에는 이벤트가 없어요',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.signpost_outlined, size: 18, color: Palette.subInk),
            Transform.rotate(
              angle: -math.pi / 4,
              child: Container(width: 22, height: InkLine.pill, color: Palette.subInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// 여정 멈추기 확인. 멈추기 = true, 취소 = false. [capKm]는 여행 경비 상한
Future<bool?> showStopSheet(BuildContext context, double capKm) => showConfirmSheet(
      context,
      '여기서 멈춰요. 다음 여정은 멈춘 자리에서 출발하고, 그동안 걸은 거리는 여행 경비로 모아 둬요 '
      '(최대 ${formatKm(capKm, digits: capKm % 1 == 0 ? 0 : 1)}).',
      '멈추기',
      '취소',
    );
