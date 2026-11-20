import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_service.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/badge.dart' as stamp;
import '../../domain/rules.dart';
import '../../domain/spirit_look.dart';
import '../../domain/time_kst.dart';
import '../../domain/walk_history.dart';
import '../common/app_text.dart';
import '../common/big_number.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/ink_card.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../album/album_stamps.dart';
import '../decorate/decorate_screen.dart';
import '../note/note_screen.dart';
import '../settings/settings_screen.dart';
import 'nickname_sheet.dart';
import '../scene/spirit_character.dart';

/// 걸음 막대 영역의 높이와, 걸음이 0인 날도 남기는 막대의 최소 높이
const _chartHeight = 96.0;
const _barMinHeight = 4.0;

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 나의 정보 = 아래 탭 ‘나’의 처음 화면 (16장 11/18 ⑥·11/19, 캔버스 9-1): 프로필(정령·닉네임 연필·꾸미기),
/// 숫자 카드 4개, 최근 14일 걸음 막대, 도장(16장 11/19 ③, 화집에서 옮겨 옴), 목록 줄 노트(내 방명록·걷기 기록)·설정.
/// 차례는 config ui.tabs.me(profile·records·badges·customize·nickname·note·settings). 탭 처음 화면이라 뒤로 버튼이 없다.
/// 출발 동네 바꾸기는 없다 (가안). 나 탭에는 새 소식 점이 없어(ui.tabs.dots.me 비었음) 보이면 새 도장을 본 것으로 둔다
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _marking = false;

  /// 안 본 도장이 있고 이 화면이 보이면(탭이 숨으면 TickerMode가 꺼진다) 본 것으로 적는다
  void _seeStamps(Snapshot snap) {
    if (_marking || snap.unseenBadges <= 0 || !TickerMode.valuesOf(context).enabled) return;
    _marking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final svc = await ref.read(syncServiceProvider.future);
        await svc.markBadgesSeen();
        if (mounted) ref.invalidate(snapshotProvider);
      } finally {
        _marking = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(snapshotProvider).value;
    final me = ref.watch(meProvider).value;
    final spirit = ref.watch(spiritLookProvider);
    final bars = ref.watch(recentDaysProvider).value;
    final rules = ref.watch(rulesProvider).value;
    final ready = snap != null && me != null && bars != null && rules != null;
    if (snap != null) _seeStamps(snap);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('나의 정보'),
            Expanded(child: ready ? _content(context, snap, me, spirit, bars, rules) : const SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    Snapshot snap,
    Me me,
    SpiritLook spirit,
    List<DayBar> bars,
    Rules rules,
  ) {
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileCard(
            me: me,
            spirit: spirit,
            onDecorate: () => push(const DecorateScreen()),
            onNickname: () => showNicknameSheet(context, current: me.nickname, rules: rules),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  key: const ValueKey('stat-steps'),
                  value: formatInt(snap.todaySteps),
                  label: '오늘 걸음',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  key: const ValueKey('stat-km'),
                  value: snap.totalKm.toStringAsFixed(1),
                  unit: 'km',
                  label: '누적 거리',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  key: const ValueKey('stat-paintings'),
                  value: formatInt(snap.paintingsCount),
                  label: '모은 그림',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  key: const ValueKey('stat-fund'),
                  value: snap.fundKm.toStringAsFixed(1),
                  unit: 'km',
                  label: '여행 경비',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DaysCard(bars: bars, today: snap.today),
          const SizedBox(height: 20),
          const _Stamps(),
          const SizedBox(height: 16),
          InkCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LinkRow(
                  key: const ValueKey('me-note'),
                  title: '노트',
                  sub: '내 방명록 · 걷기 기록',
                  onTap: () => push(const NoteScreen()),
                ),
                const Divider(height: 1, thickness: 1, color: _rowLine),
                _LinkRow(
                  key: const ValueKey('me-settings'),
                  title: '설정',
                  sub: '계정 · 걸음 데이터 · 알림',
                  onTap: () => push(const SettingsScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 위: 캐릭터 초상, 닉네임, 보조 버튼 `꾸미기`
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.me,
    required this.spirit,
    required this.onDecorate,
    required this.onNickname,
  });

  final Me me;
  final SpiritLook spirit;
  final VoidCallback onDecorate;

  /// 닉네임 옆 연필: 닉네임 바꾸기 시트
  final VoidCallback onNickname;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      child: Row(
        children: [
          Container(
            key: const ValueKey('portrait'),
            width: 88,
            height: 88,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Palette.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.ink, width: InkLine.panel),
            ),
            // 쉼터·꾸미기와 같은 정령
            child: SpiritStanding(look: spirit, share: 0.72, footAt: 0.92),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        me.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle(context),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: '닉네임 바꾸기',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const ValueKey('nickname-edit'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onNickname,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.edit_outlined, size: 20, color: Palette.subInk),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 너비 120pt는 글자 크기를 키우면 같이 넓어진다 (칸이 모자라면 칸만큼에서 멈춘다)
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(120),
                  child: GameButton(
                    label: '꾸미기',
                    kind: GameButtonKind.secondary,
                    onPressed: onDecorate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 숫자 카드: 큰 숫자 40 + 라벨 12
class _StatCard extends StatelessWidget {
  const _StatCard({super.key, required this.value, required this.label, this.unit});

  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BigNumber(value, unit: unit, alignment: Alignment.centerLeft),
          const SizedBox(height: 4),
          Text(label, style: AppText.label),
        ],
      ),
    );
  }
}

/// 최근 14일 막대 그래프: 가장 높은 날이 꽉 차고, 오늘은 테라코타, 나머지는 이끼색
class _DaysCard extends StatelessWidget {
  const _DaysCard({required this.bars, required this.today});

  final List<DayBar> bars;
  final String today;

  @override
  Widget build(BuildContext context) {
    final most = bars.fold(0, (m, b) => b.steps > m ? b.steps : m);
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('최근 14일', style: AppText.cardTitle(context)),
          const SizedBox(height: 12),
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in bars)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _bar(b, most),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final b in bars)
                Expanded(
                  // 14칸이라 칸이 좁다. 글자 크기를 키워 요일 글자가 칸보다 커지면 칸에 맞게 줄인다
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _weekdayLabels[dayFromKey(b.day).weekday - 1],
                      textAlign: TextAlign.center,
                      style: b.day == today
                          ? context.display(12)
                          : AppText.label,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(DayBar b, int most) {
    final height = most == 0
        ? _barMinHeight
        : _barMinHeight + (_chartHeight - _barMinHeight) * b.steps / most;
    return Semantics(
      label: '${formatMonthDay(dayFromKey(b.day))} ${formatInt(b.steps)}보',
      child: Container(
        key: ValueKey('bar-${b.day}'),
        height: height,
        decoration: BoxDecoration(
          color: b.steps == 0
              ? Palette.ink.withValues(alpha: 0.15)
              : b.day == today
                  ? Palette.terracotta
                  : Palette.moss,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.ink, width: 1.5),
        ),
      ),
    );
  }
}

/// 도장 (16장 11/19 ③, 화집 도장 탭을 옮겨 옴): 제목 `도장` + 받은 수, 묶음별 카드(받은 도장만 진하게, 못 받은 도장은
/// 흐린 빈 고리와 조건 글). 도장 목록은 그림·소품과 달리 ‘가진 것만’이 아니다(16장 11/20은 배낭 줄)
class _Stamps extends ConsumerWidget {
  const _Stamps();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeCatalogProvider).value?.badges;
    final owned = ref.watch(ownedBadgesProvider).value;
    // 읽어 오는 동안은 비워 둔다
    if (badges == null || owned == null) return const SizedBox.shrink();
    final got = badges.where((b) => owned.containsKey(b.id)).length;
    return Column(
      key: const ValueKey('me-stamps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('도장', style: AppText.cardTitle(context))),
            Text('$got / ${badges.length}', key: const ValueKey('me-stamps-count'), style: AppText.label),
          ],
        ),
        StampSections(sections: stamp.badgeSections(badges), owned: owned),
      ],
    );
  }
}

/// 목록 줄 사이 선 (캔버스 9-1 #E3D6BE)
const _rowLine = Color(0xFFE3D6BE);

/// 나 탭 목록 줄 (캔버스 9-1): 이름 14 + 옅은 설명 12 + 화살표, 높이 52 이상
class _LinkRow extends StatelessWidget {
  const _LinkRow({super.key, required this.title, required this.sub, required this.onTap});

  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $sub',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Palette.ink)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sub,
                    textAlign: TextAlign.right,
                    style: AppText.label,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Palette.subInk),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
