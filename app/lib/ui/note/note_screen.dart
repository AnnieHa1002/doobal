import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/db/app_db.dart' show PostStatus;
import '../../domain/session.dart';
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
            border: Border.all(color: Palette.ink, width: 2.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? Palette.paper : Palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 내 방명록: 내가 쓴 글을 최신순으로. 카드마다 장소·숫자 태그, 본문, 날짜, 서버에 못 올린 글이면 안내.
/// TODO(M5): 받은 하트를 카드에 붙인다 (지금은 서버가 없어서 표시하지 않는다)
class _GuestbookTab extends ConsumerWidget {
  const _GuestbookTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(myPostsProvider).value;
    if (posts == null) return const SizedBox();
    if (posts.isEmpty) {
      return const Center(child: Text('아직 남긴 방명록이 없어요', style: AppText.bodySub));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: posts.length,
      itemBuilder: (context, i) => _PostCard(posts[i]),
    );
  }
}

/// 서버에 아직 못 올린 글 밑에 붙는 한 줄. 올린 글(sent)·거절된 글(rejected)은 M5에서 정한다
/// TODO(M5): 문구는 가안
String? _statusLine(PostStatus status) => switch (status) {
      PostStatus.pending => '연결되면 올라가요',
      PostStatus.sent || PostStatus.rejected => null,
    };

/// 내가 쓴 글 하나: 위에 태그와 날짜, 본문, 아래에 상태 한 줄
class _PostCard extends StatelessWidget {
  const _PostCard(this.post);

  final GuestbookPostView post;

  @override
  Widget build(BuildContext context) {
    final status = _statusLine(post.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: ValueKey('post-${post.ticketId}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.ink, width: 2.5),
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
                Text(formatMonthDay(kstDateTime(post.createdAt)), style: AppText.label),
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

/// 걷기 기록: 감지된 걷기를 날짜별로, 최신순. 한 줄을 누르면 그 걷기의 걷기 기록을 다시 본다
class _WalksTab extends ConsumerWidget {
  const _WalksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(walkSessionsProvider).value;
    if (sessions == null) return const SizedBox();
    if (sessions.isEmpty) {
      return const Center(child: Text('아직 감지된 걷기가 없어요', style: AppText.bodySub));
    }
    // 날짜 제목과 그 날의 걷기를 한 줄로 펴서 늘어놓는다 (String = 날짜 제목)
    final items = <Object>[
      for (final g in groupSessionsByDay(sessions)) ...[g.day, ...g.sessions],
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, i) => switch (items[i]) {
        final String day => _DayHeader(day),
        final WalkSession s => _WalkRow(s),
        _ => throw StateError('알 수 없는 걷기 기록 줄'),
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.day);

  final String day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        formatMonthDay(dayFromKey(day)),
        style: AppText.body.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 걷기 한 줄: 시작 시각, 걸음, 거리
class _WalkRow extends StatelessWidget {
  const _WalkRow(this.session);

  final WalkSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        child: GestureDetector(
          key: ValueKey('walk-${session.start.millisecondsSinceEpoch}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => WalkRecordScreen(
              start: session.start,
              end: session.end,
              ratioBefore: null,
              review: true,
            ),
          )),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Palette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.ink, width: 2.5),
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
                                  formatKstClock(session.start),
                                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            Text('${formatInt(session.steps)}보', style: AppText.body),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatKm(session.distanceM / 1000, digits: 2),
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
