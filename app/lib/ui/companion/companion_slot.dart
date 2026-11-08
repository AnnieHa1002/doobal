import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/companion_providers.dart';
import '../rest/rest_slots.dart';
import 'companion_art.dart';
import 'companion_screen.dart';

/// 쉼터에서 동행 화면으로 (불 옆 동행, 캔버스 2-2 → 7-1)
void openCompanions(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CompanionScreen()));

/// 쉼터 불 옆 동행 자리. 함께 걷는 동행이 있고 쉼터에 와 앉았을 때만 선다 (혼자·첫날·늦게 오는 중이면 빈자리).
/// 안 읽은 장이 있으면 알림 점 (M4, 11/6 Annie)
final companionRestSlotProvider = Provider.autoDispose<RestObjectSlot?>((ref) {
  final view = ref.watch(companionsViewProvider).value;
  final walking = view?.metById(view.walkingWith)?.companion;
  if (walking == null || !ref.watch(companionSeatedProvider)) return null;
  return RestObjectSlot(
    art: (_) => CompanionRestArt(companion: walking),
    onTap: openCompanions,
    notice: ref.watch(unreadStoryProvider),
  );
});
