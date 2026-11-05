import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 쉼터 장면에 끼우는 물건 하나 (행상 수레·불 옆 동행). 자리와 크기는 테마(camp_wide.json)가 정한다
class RestObjectSlot {
  const RestObjectSlot({required this.art, required this.onTap, this.label, this.notice = false});

  /// 그림. 테마의 artW×artH 상자를 채운다
  final WidgetBuilder art;
  final void Function(BuildContext context) onTap;

  /// 이름표. 없으면 테마의 이름
  final String? label;

  /// 오른쪽 위 알림 점
  final bool notice;
}

/// 럭 보석 자리. 숫자는 쉼터가 그린다 (첫날도 '0')
class RestGemSlot {
  const RestGemSlot({this.art, this.onTap});

  /// 보석 그림. 없으면 자리표시
  final WidgetBuilder? art;

  /// 없으면 눌리지 않는다
  final void Function(BuildContext context)? onTap;
}

/// 쉼터가 다른 트랙에 열어 둔 자리. T4b는 [cart]·[gem], T2b는 [companion]을 채운다.
/// 쉼터 코드는 고치지 않고 [restSlotsProvider]에서 각 트랙의 프로바이더를 읽으면 된다
class RestSlots {
  const RestSlots({this.cart, this.companion, this.gem = const RestGemSlot()});

  /// 행상 수레. 없으면 그 자리는 빈 땅이다
  final RestObjectSlot? cart;

  /// 불 옆 동행. 없으면 빈자리다 (첫날)
  final RestObjectSlot? companion;
  final RestGemSlot gem;
}

final restSlotsProvider = Provider<RestSlots>((ref) => const RestSlots());
