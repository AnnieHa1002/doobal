import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/palette.dart';

/// 어디서 쓰는 글인지 알리는 태그 글: 도착이면 "경복궁 도착"(첫 여정은 "내 동네 스케치 도착"),
/// 걸음 숫자면 "12,345보". 쓰기 화면과 노트의 내 방명록이 같이 쓴다
String guestbookTagText({int? milestone, String? placeName}) =>
    milestone != null ? '${formatInt(milestone)}보' : '$placeName 도착';

/// 쓸 수 있는 기회의 태그 글
String guestbookTag(GuestbookTicket t) =>
    guestbookTagText(milestone: t.milestone, placeName: t.placeName);

/// 쓴 글의 태그 글
String guestbookPostTag(GuestbookPostView p) =>
    guestbookTagText(milestone: p.milestone, placeName: p.placeName);

/// 글을 쓴 때를 지금에서 거꾸로 (방명록 읽기 카드): 1분이 안 되면 '방금', 'n분 전', 'n시간 전',
/// 'n일 전'(30일 전까지), 그보다 오래면 한국 날짜 '11월 3일'. 시계가 어긋나 미래면 '방금'
String formatAgo(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return '방금';
  if (d.inHours < 1) return '${d.inMinutes}분 전';
  if (d.inDays < 1) return '${d.inHours}시간 전';
  if (d.inDays <= 30) return '${d.inDays}일 전';
  return formatMonthDay(kstDate(then));
}

/// 어디서 쓰는지 알리는 알약 (잉크 2px 테두리, 바탕은 카드색이고 카드 안에서는 [color]로 바꾼다)
class GuestbookTagPill extends StatelessWidget {
  const GuestbookTagPill(this.text, {super.key, this.color = Palette.card});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.ink, width: InkLine.pill),
      ),
      child: Text(
        text,
        style: context.display(14),
      ),
    );
  }
}
