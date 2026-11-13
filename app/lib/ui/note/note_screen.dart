import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/db/app_db.dart' show PostStatus;
import '../../domain/time_kst.dart';
import '../../domain/walk_history.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
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

/// 걷기 기록 (캔버스 6-3, 16장 11/13): 물감 길을 날짜별로, 최신순. 날짜 줄은 그날 걸음·거리,
/// 그 아래 물감 길 줄을 누르면 그 물감 길의 걷기 기록(3-3)을 본다.
/// 걷기 리포트 줄·날짜 줄의 하루 카드는 T10 몫이라 아직 없다
class _WalksTab extends ConsumerWidget {
  const _WalksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(trailHistoryProvider).value;
    if (history == null) return const SizedBox();
    if (history.trails.isEmpty) {
      return const Center(child: Text('아직 걷기 기록이 없어요', style: AppText.bodySub));
    }
    // 날짜 제목과 그 날의 물감 길을 한 줄로 펴서 늘어놓는다 (String = 날짜 제목)
    final items = <Object>[
      for (final g in groupByKstDay(history.trails, (t) => t.start)) ...[g.day, ...g.items],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, i) => switch (items[i]) {
        final String day => _DayHeader(day, history.days[day]),
        final PaintTrailView t => _TrailRow(t),
        _ => throw StateError('알 수 없는 걷기 기록 줄'),
      },
    );
  }
}

/// 날짜 줄: 날짜와 그날 걸음·거리
class _DayHeader extends StatelessWidget {
  const _DayHeader(this.day, this.totals);

  final String day;
  final ({int steps, double distanceM})? totals;

  @override
  Widget build(BuildContext context) {
    final t = totals;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(formatMonthDay(dayFromKey(day)), style: context.display(15)),
          if (t != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${formatInt(t.steps)}보 · ${formatKm(t.distanceM / 1000)}',
                style: AppText.bodySub,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 물감 길 한 줄: 시작 시각, ‘물감 길 n km’ (캔버스 6-3)
class _TrailRow extends StatelessWidget {
  const _TrailRow(this.trail);

  final PaintTrailView trail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        child: GestureDetector(
          key: ValueKey('trail-${trail.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => WalkRecordScreen(start: trail.start, end: trail.end),
          )),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.ink, width: InkLine.panel),
            ),
            // 시각·걸음은 왼쪽, 거리·화살표는 오른쪽 끝. 글자 크기를 키워 한 줄에 안 들어가면
            // 줄 전체가 줄어든다 (들어가면 줄 너비만큼 그대로 펴진다)
            child: LayoutBuilder(
              builder: (context, box) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 오른쪽 거리와 8pt 이상 떨어진다
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 시각 칸은 56pt가 최소다 (글자가 커지면 시각 + 8pt까지 넓어진다)
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 56),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  formatKstClock(trail.start),
                                  style: context.display(15),
                                ),
                              ),
                            ),
                            Text('물감 길', style: AppText.body),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatKm(trail.trailM / 1000),
                            style: AppText.bodySub,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: Palette.ink),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
