import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/palette.dart';
import 'guestbook_tag.dart';

/// 방명록 읽기 (5-2): 같은 장소·같은 걸음 숫자에서 남긴 글. 쓰기 화면에서 `남기기`를 누르면 이어진다.
/// 위에 장소(도착) 또는 걸음 숫자, 아래에 글 카드.
/// 서버(M5)가 아직 없어서 자리표시 화면이다: 내가 방금 쓴 글 1개([ticketId]의 글)만 보인다.
/// TODO(M5): 서버가 생기면 같은 장소·숫자의 다른 여행자 글 5개, `다른 5개 보기`, 하트, 신고를 붙인다
/// (11/4 Annie: 서버 뒤로 미룸). 뒤로는 들어온 곳(쉼터·도착 화면)
class GuestbookReadScreen extends ConsumerWidget {
  const GuestbookReadScreen({super.key, required this.ticketId});

  /// 방금 쓴 글의 기회 번호
  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(myPostsProvider);
    final post = posts.value?.where((p) => p.ticketId == ticketId).firstOrNull;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CornerButton(
                    icon: Icons.arrow_back,
                    label: '뒤로',
                    size: 44,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  if (post != null)
                    Expanded(
                      child: Text(
                        _title(post),
                        key: const ValueKey('guestbook-read-title'),
                        style: context.display(22),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (post != null) _card(context, post),
            ],
          ),
        ),
      ),
    );
  }

  /// 도착 글은 장소 이름, 걸음 숫자 글은 `12,345보 지점`
  String _title(GuestbookPostView p) =>
      p.milestone != null ? '${formatInt(p.milestone!)}보 지점' : p.placeName ?? '';

  Widget _card(BuildContext context, GuestbookPostView p) {
    return Container(
      key: const ValueKey('guestbook-read-post'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GuestbookTagPill(guestbookPostTag(p)),
              Text(
                '내가 방금 쓴 글 · ${formatMonthDay(kstDate(p.createdAt))}',
                style: const TextStyle(fontSize: 13, color: Palette.subInk),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.text, style: const TextStyle(fontSize: 15, height: 1.6, color: Palette.ink)),
        ],
      ),
    );
  }
}
