import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/confirm_sheet.dart';
import '../common/format.dart';
import '../common/palette.dart';

/// 목적지 바꾸기 확인. 바꾸기 = true, 취소 = false
Future<bool?> showChangeSheet(BuildContext context) =>
    showConfirmSheet(context, '지금 자리에서 다시 출발해요. 액자 거리는 새로 세요.', '바꾸기', '취소');

/// 여행 경비 쓰기 묻기. 더하기 = true, 아껴 두기 = false.
/// 경비로 가는 구간에 길 위 이벤트가 없다는 것은 글 대신 옆의 이벤트 없음 아이콘으로 (UI 명세 v3 7장, 11/3)
Future<bool?> showFundSheet(BuildContext context, double fundKm) => showConfirmSheet(
      context,
      '경비 ${formatKm(fundKm)}를 더할까요?',
      '더하기',
      '아껴 두기',
      trailing: const NoEventIcon(),
    );

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
