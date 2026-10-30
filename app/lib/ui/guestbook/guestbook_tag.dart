import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
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
        border: Border.all(color: Palette.ink, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink),
      ),
    );
  }
}
