import 'package:flutter/widgets.dart';

import '../common/confirm_sheet.dart';
import '../common/format.dart';

/// 목적지 바꾸기 확인. 바꾸기 = true, 취소 = false
Future<bool?> showChangeSheet(BuildContext context) =>
    showConfirmSheet(context, '지금 자리에서 다시 출발해요. 액자 거리는 새로 세요.', '바꾸기', '취소');

/// 여행 경비 쓰기 묻기. 더하기 = true, 아껴 두기 = false
Future<bool?> showFundSheet(BuildContext context, double fundKm) => showConfirmSheet(
      context,
      '경비 ${formatKm(fundKm)}를 더할까요? (경비로 가는 구간에는 이벤트가 없어요)',
      '더하기',
      '아껴 두기',
    );

/// 여정 멈추기 확인. 멈추기 = true, 취소 = false. [capKm]는 여행 경비 상한
Future<bool?> showStopSheet(BuildContext context, double capKm) => showConfirmSheet(
      context,
      '여기서 멈춰요. 다음 여정은 멈춘 자리에서 출발하고, 그동안 걸은 거리는 여행 경비로 모아 둬요 '
      '(최대 ${formatKm(capKm, digits: capKm % 1 == 0 ? 0 : 1)}).',
      '멈추기',
      '취소',
    );
