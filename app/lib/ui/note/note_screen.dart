import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/day_card.dart' show cardToday;
import '../../app/sync_service.dart';
import '../../data/db/app_db.dart' show PostStatus;
import '../../domain/time_kst.dart';
import '../../domain/walk_history.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../day_card/day_card_view.dart' show DayCardPage;
import '../day_card/walk_report_screen.dart';
import '../guestbook/guestbook_tag.dart';
import '../walk_record/walk_record_screen.dart';

/// 노트: `내 방명록`과 `걷기 기록` 두 탭 (UI 명세 11장)
class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({super.key});

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('노트'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _Tab(
                      '내 방명록',
                      const ValueKey('tab-guestbook'),
                      _tab == 0,
                      () => setState(() => _tab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Tab(
                      '걷기 기록',
                      const ValueKey('tab-walks'),
                      _tab == 1,
                      () => setState(() => _tab = 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _tab == 0 ? const _GuestbookTab() : const _WalksTab()),
          ],
        ),
      ),
    );
  }
}

/// 탭 하나 (화집의 탭과 같은 모양)
class _Tab extends StatelessWidget {
  const _Tab(this.label, Key key, this.selected, this.onTap) : super(key: key);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // 44pt가 최소 높이다. 글자 크기를 키워 탭 이름이 줄바꿈되면 같이 커진다
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.terracotta : Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ink, width: InkLine.panel),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.display(16, color: selected ? Palette.paper : Palette.ink),
          ),
        ),
      ),
    );
  }
}

/// 내 방명록: 내가 쓴 글을 최신순으로. 카드마다 장소·숫자 태그, 날짜, 받은 하트, 본문,
/// 서버에 못 올린 글이면 안내. 하트는 서버의 내 글(guestbook where uid == 나)에서 읽고,
/// 연결이 안 되면 기기에 남은 마지막 값, 그것도 없으면 하트 없이 보인다
class _GuestbookTab extends ConsumerWidget {
  const _GuestbookTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(myPostsProvider).value;
    final hearts = ref.watch(myHeartsProvider).value ?? const <String, int>{};
    if (posts == null) return const SizedBox();
    if (posts.isEmpty) {
      return const Center(child: Text('아직 남긴 방명록이 없어요', style: AppText.bodySub));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: posts.length,
      itemBuilder: (context, i) => _PostCard(posts[i], hearts[posts[i].ticketId]),
    );
  }
}

/// 서버에 올리지 못한 글 밑에 붙는 한 줄. 올린 글(sent)은 없다.
/// 문구는 가안: rejected는 서버가 받지 않은 글(올린 뒤 금칙어 문서가 바뀌었을 때 등)이라 고쳐 쓰는 곳이 아직 없다
String? _statusLine(PostStatus status) => switch (status) {
      PostStatus.pending => '연결되면 올라가요',
      PostStatus.rejected => '올리지 못했어요',
      PostStatus.sent => null,
    };

/// 내가 쓴 글 하나: 위에 태그와 날짜(오른쪽에 받은 하트), 본문, 아래에 상태 한 줄
class _PostCard extends StatelessWidget {
  const _PostCard(this.post, this.hearts);

  final GuestbookPostView post;

  /// 받은 하트. 모르면 null (서버에 없는 글·오프라인)
  final int? hearts;

  @override
  Widget build(BuildContext context) {
    final status = _statusLine(post.status);
    final hearts = this.hearts;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: ValueKey('post-${post.ticketId}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.ink, width: InkLine.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 태그는 왼쪽, 날짜는 오른쪽. 글자가 커져서 한 줄에 안 들어가면 날짜가 아래로 내려간다
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                GuestbookTagPill(guestbookPostTag(post), color: Palette.paper),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatMonthDay(kstDateTime(post.createdAt)), style: AppText.label),
                    if (hearts != null) ...[
                      const SizedBox(width: 8),
                      // ♥ 글자는 기기에 따라 빨간 이모지로 그려져서 아이콘으로 그린다 (손 확인 11/9)
                      Semantics(
                        label: '받은 하트 ${formatInt(hearts)}',
                        child: Row(
                          key: ValueKey('hearts-${post.ticketId}'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite, size: 14, color: Palette.terracotta),
                            const SizedBox(width: 2),
                            Text(
                              formatInt(hearts),
                              style: context.display(14, color: Palette.terracotta),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.text, style: AppText.body.copyWith(height: 1.4)),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(status, style: AppText.label),
            ],
          ],
        ),
      ),
    );
  }
}

/// 걷기 기록 (캔버스 6-3, 16장 11/13): 맨 위 ‘걷기 리포트 ›’(6-4), 그 아래 날짜마다 날짜 줄(그날 걸음·거리,
/// 누르면 그날 하루 카드 2-3)과 그날 물감 길 줄(누르면 그 물감 길의 걷기 기록 3-3), 최신순.
/// 날짜는 걸음이 있었던 날과 물감 길이 있는 날 중 하루 카드가 생긴 날만이다: 그날 줄은 다음 날 새벽 5시
/// (config report.dayStartHour, 하루 카드와 같은 경계 [cardToday]) 뒤에 생긴다 (캔버스 6-3, 16장 11/16 Annie).
/// 그래서 오늘 줄은 없고, 새벽 0~5시에는 어제 줄도 아직 없다. 줄이 있으면 늘 그날 카드를 연다
class _WalksTab extends ConsumerWidget {
  const _WalksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(trailHistoryProvider).value;
    final rules = ref.watch(rulesProvider).value;
    if (history == null || rules == null) return const SizedBox();
    final trailsByDay = {
      for (final g in groupByKstDay(history.trails, (t) => t.start)) g.day: g.items,
    };
    // 하루 카드가 있는 마지막 날 (카드 어제)
    final lastCard = addDays(cardToday(ref.watch(clockProvider)(), rules.report), -1);
    final days = [
      for (final d in {...history.days.keys, ...trailsByDay.keys})
        if (d.compareTo(lastCard) <= 0) d,
    ]..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) {
      return const Center(child: Text('아직 걷기 기록이 없어요', style: AppText.bodySub));
    }
    // 맨 위 리포트 줄, 그 아래 날짜마다 카드 하나 (날짜 줄 + 그날 물감 길 줄, 캔버스 6-3)
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: days.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return const _ReportRow();
        final day = days[i - 1];
        return Padding(
          padding: const EdgeInsets.only(top: _cardGap),
          child: _DayCard(
            day: day,
            totals: history.days[day],
            trails: trailsByDay[day] ?? const [],
            onTap: () => Navigator.of(context).push(DayCardPage.route(day)),
          ),
        );
      },
    );
  }
}

/// 걷기 기록 줄 사이 (캔버스 6-3 gap 8)
const _cardGap = 8.0;

/// 줄 안 왼쪽·오른쪽 여백 (캔버스 6-3 14)
const _rowInset = 14.0;

/// 날짜 하나의 카드: 날짜 줄과 그날 물감 길 줄 (종이색 카드, 테두리 없이 모서리 16, 캔버스 6-3)
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.totals, required this.trails, this.onTap});

  final String day;
  final ({int steps, double distanceM})? totals;
  final List<PaintTrailView> trails;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('day-card-$day'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Palette.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DayHeader(day, totals, onTap: onTap),
          for (final t in trails) _TrailRow(t),
        ],
      ),
    );
  }
}

/// 한 줄: [left] 묶음은 왼쪽, [right] 묶음은 오른쪽 끝. 글자 크기를 키워 한 줄에 안 들어가면 줄 전체가
/// 줄어든다 (들어가면 줄 너비만큼 그대로 펴진다). 두 묶음 사이는 [gap] 이상 떨어진다
Widget _fitRow({required List<Widget> left, required List<Widget> right, double gap = 8}) {
  Widget group(List<Widget> items) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, c) in items.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            c,
          ],
        ],
      );
  return LayoutBuilder(
    builder: (context, box) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(padding: EdgeInsets.only(right: gap), child: group(left)),
            group(right),
          ],
        ),
      ),
    ),
  );
}

/// 맨 위 ‘걷기 리포트 ›’ 줄 (잉크 바탕, 캔버스 6-3)
class _ReportRow extends StatelessWidget {
  const _ReportRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        child: GestureDetector(
          key: const ValueKey('walk-report-row'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const WalkReportScreen())),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Palette.ink,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(child: Text('걷기 리포트', style: context.display(15, color: Palette.card))),
                const Icon(Icons.chevron_right, color: Palette.card),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 날짜 줄: 날짜(옅게)·그날 걸음·거리 (‘4월 14일  7,912보  5.6km ›’, 캔버스 6-3).
/// [onTap]이 있으면 그날 하루 카드를 연다 (오른쪽 화살표)
class _DayHeader extends StatelessWidget {
  const _DayHeader(this.day, this.totals, {this.onTap});

  final String day;
  final ({int steps, double distanceM})? totals;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    final date = formatMonthDay(dayFromKey(day));
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: _rowInset, vertical: 10),
      alignment: Alignment.centerLeft,
      child: _fitRow(gap: 10, left: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 70),
          child: Text(date, style: const TextStyle(fontSize: 13, color: Palette.subInk)),
        ),
        if (t != null)
          Text('${formatInt(t.steps)}보', style: context.display(14, weight: FontWeight.w600)),
      ], right: [
        if (t != null)
          Text(formatKmShort(t.distanceM), style: const TextStyle(fontSize: 13, color: Palette.ink)),
        if (onTap != null) const Icon(Icons.chevron_right, size: 20, color: Palette.ink),
      ]),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$date 하루 카드',
      child: GestureDetector(
        key: ValueKey('day-$day'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      ),
    );
  }
}

/// 물감 길 한 줄 (날짜 카드 안, 위에 점선): 붓 아이콘, 시작 시각 ‘오전 8:05’, ‘물감 길 1.2km’, 화살표 (캔버스 6-3)
class _TrailRow extends StatelessWidget {
  const _TrailRow(this.trail);

  final PaintTrailView trail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: ValueKey('trail-${trail.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => WalkRecordScreen(start: trail.start, end: trail.end),
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _rowInset),
          child: CustomPaint(
            painter: const _DashedTopLine(),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.centerLeft,
              child: _fitRow(left: [
                const CustomPaint(size: Size(22, 10), painter: _BrushIcon()),
                Text(
                  formatKstClockAmPm(trail.start),
                  style: const TextStyle(fontSize: 13, color: Palette.subInk),
                ),
              ], right: [
                Text(
                  '물감 길 ${formatKmShort(trail.trailM)}',
                  style: const TextStyle(fontSize: 13, color: Palette.ink),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Palette.subInk),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 줄 위 1pt 점선 (캔버스 6-3 border-top 1px dashed --line)
class _DashedTopLine extends CustomPainter {
  const _DashedTopLine();

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(Offset(x, 0.5), Offset(math.min(x + _dash, size.width), 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedTopLine oldDelegate) => false;
}

/// 붓 아이콘 22×10: 넓은 옅은 획 위에 좁은 진한 획 (캔버스 6-3 SVG: #C97B54 40% 굵기 7, #B5603A 80% 굵기 3)
class _BrushIcon extends CustomPainter {
  const _BrushIcon();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    for (final (color, width) in const [(Color(0x66C97B54), 7.0), (Color(0xCCB5603A), 3.0)]) {
      canvas.drawLine(
        Offset(2, y),
        Offset(size.width - 2, y),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BrushIcon oldDelegate) => false;
}
