import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/profile_service.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/look_palette.dart';
import '../../domain/time_kst.dart';
import '../../domain/walk_history.dart';
import '../common/app_text.dart';
import '../common/big_number.dart';
import '../common/figure_painter.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/ink_card.dart';
import '../common/palette.dart';
import '../common/screen_header.dart';
import '../decorate/decorate_screen.dart';

/// 걸음 막대 영역의 높이와, 걸음이 0인 날도 남기는 막대의 최소 높이
const _chartHeight = 96.0;
const _barMinHeight = 4.0;

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 동행 도감의 칸 힌트. 퐁·휴·심 박사 순이고, 이름은 만나기 전이라 숨긴다 (UI 명세 6장).
/// TODO(M4): 동행 데이터(companions.json)와 만남 기록이 생기면 만난 동행은 이름·그림으로 바꾼다
const _companionHints = ['바닷가를 걷다 보면…', '도시를 걷다 보면…', '산길을 걷다 보면…'];

/// 나의 정보: 프로필, 숫자 카드 4개, 최근 14일 걸음 막대, 동행 도감 (UI 명세 11장)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(snapshotProvider).value;
    final me = ref.watch(meProvider).value;
    final palette = ref.watch(lookPaletteProvider).value;
    final bars = ref.watch(recentDaysProvider).value;
    final ready = snap != null && me != null && palette != null && bars != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('나의 정보'),
            Expanded(child: ready ? _content(context, snap, me, palette, bars) : const SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    Snapshot snap,
    Me me,
    LookPalette palette,
    List<DayBar> bars,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileCard(
            me: me,
            painter: figureOf(me.look, palette),
            onDecorate: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const DecorateScreen())),
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
          const SizedBox(height: 12),
          const _CompanionCard(),
        ],
      ),
    );
  }
}

/// 위: 캐릭터 초상, 닉네임, 보조 버튼 `꾸미기`
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.me, required this.painter, required this.onDecorate});

  final Me me;
  final FigurePainter painter;
  final VoidCallback onDecorate;

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
              border: Border.all(color: Palette.ink, width: 2.5),
            ),
            child: CustomPaint(painter: painter),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.cardTitle,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
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
          const Text('최근 14일', style: AppText.cardTitle),
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
                  child: Text(
                    _weekdayLabels[dayFromKey(b.day).weekday - 1],
                    textAlign: TextAlign.center,
                    style: b.day == today
                        ? AppText.label.copyWith(fontWeight: FontWeight.w800, color: Palette.ink)
                        : AppText.label,
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

/// 동행 도감: 만난 동행 자리. 지금은 3칸 모두 실루엣과 지형 힌트
class _CompanionCard extends StatelessWidget {
  const _CompanionCard();

  @override
  Widget build(BuildContext context) {
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('동행 도감', style: AppText.cardTitle),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _companionHints.length; i++)
                Expanded(
                  child: _CompanionSlot(key: ValueKey('companion-$i'), hint: _companionHints[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 아직 못 만난 동행: 어두운 실루엣과 힌트 한 줄 (이름은 숨긴다)
class _CompanionSlot extends StatelessWidget {
  const _CompanionSlot({super.key, required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Palette.ink.withValues(alpha: 0.12),
            border: Border.all(color: Palette.ink.withValues(alpha: 0.35), width: 2),
          ),
          child: Icon(Icons.person, size: 32, color: Palette.ink.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(hint, textAlign: TextAlign.center, style: AppText.label),
        ),
      ],
    );
  }
}
