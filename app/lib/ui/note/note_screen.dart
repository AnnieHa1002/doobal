import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/session.dart';
import '../../domain/time_kst.dart';
import '../../domain/walk_history.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
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
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.terracotta : Palette.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.ink, width: 2.5),
          ),
          child: Text(
            label,
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

/// 내 방명록: 남긴 방명록(장소·숫자 태그, 받은 하트) 목록.
/// TODO: 방명록 저장이 생기면(방명록 작업) 목록을 연결한다. 그때까지는 빈 상태만 보인다
class _GuestbookTab extends StatelessWidget {
  const _GuestbookTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('아직 남긴 방명록이 없어요', style: AppText.bodySub));
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
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    formatKstClock(session.start),
                    style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(child: Text('${formatInt(session.steps)}보', style: AppText.body)),
                Text(formatKm(session.distanceM / 1000, digits: 2), style: AppText.bodySub),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Palette.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
