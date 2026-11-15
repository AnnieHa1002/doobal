import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;

import '../../app/providers.dart';
import '../../app/report_providers.dart';
import '../../domain/day_card.dart';
import '../../domain/landmark.dart';
import '../../domain/sketch.dart';
import '../../domain/spirit_look.dart';
import '../../domain/time_kst.dart';
import '../album/painting_share.dart' show capturePng;
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/framed_painting.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../scene/spirit_character.dart';
import '../scene/spirit_controller.dart' show SpiritMotion;
import 'walk_report_screen.dart';

// 하루 카드 (캔버스 2-3)와 공유 이미지 (2-4). 카드 종이·테이프는 화집 메모지·테이프 재질을 다시 쓴다
// (16장 11/13: 새 그림 없음).

/// 줄 없는 메모지 (600×600, 가장자리 60px은 늘리지 않는다). 1/3 크기로 그려 모서리가 20pt (화집 일기와 같다)
const _notePaper = 'assets/ui/ui_note_paper_plain_9s60_v01_clean.png';
const _tape = 'assets/ui/ui_tape_01_v01_clean.png';

/// 막대의 다른 날 (캔버스 2-3·6-4 연두)
const dayBarOther = Color(0xFFB7BE86);

/// 카드 뒤를 어둡게 (캔버스 2-3)
const _scrim = Color(0x8C1E1611);

/// 그림을 붙이는 폴라로이드 바탕 (캔버스 2-3)
const _polaroid = Color(0xFFFFFDF7);

/// 공유 이미지 바탕 (캔버스 2-4)
const _shareBackground = Color(0xFFEADFC8);

/// 공유 이미지 틀의 크기 (캔버스 2-4 판 360×450 = 4:5). 내보낼 때는 config report.shareImagePx 폭에 맞춰 키운다
const shareFrameWidth = 360.0;

const _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

/// '월' … '일'
String weekdayShort(String day) => _weekdayShort[dayFromKey(day).weekday - 1];

/// '수요일'
String weekdayLong(String day) => '${weekdayShort(day)}요일';

/// 하루 카드 제목: 하루 카드는 어제면 ‘어제’, 아니면 그 날짜(‘11월 18일’), 여러 날이면 ‘지난 n일’
String dayCardTitle(DayCard c, DateTime now) {
  if (!c.range.single) return '지난 ${c.range.days}일';
  return c.range.to == addDays(kstDayKey(now), -1) ? '어제' : formatMonthDay(dayFromKey(c.range.to));
}

/// 제목 위 작은 줄: ‘어제’면 ‘11월 18일 수요일’, 날짜 제목이면 ‘수요일’, 여러 날이면 ‘11월 12일 ~ 14일’
String dayCardSub(DayCard c, DateTime now) {
  if (!c.range.single) return dayRangeLabel(c.range);
  final day = c.range.to;
  return dayCardTitle(c, now) == '어제'
      ? '${formatMonthDay(dayFromKey(day))} ${weekdayLong(day)}'
      : weekdayLong(day);
}

/// 걸음이 0인 카드(‘쉬어 간 날’, 16장 11/15)의 글 한 줄. 문구는 가안(기획이 다듬음):
/// 여러 날이면 ‘지난 n일 동안 쉬어 갔어요’, 어제면 ‘어제는 푹 쉬었어요’, 날짜 카드면 ‘이날은 푹 쉬었어요’
String restedLine(DayCard c, DateTime now) {
  if (!c.range.single) return '지난 ${c.range.days}일 동안 쉬어 갔어요';
  return dayCardTitle(c, now) == '어제' ? '어제는 푹 쉬었어요' : '이날은 푹 쉬었어요';
}

/// ‘11월 12일 ~ 14일’, 달이 다르면 ‘10월 30일 ~ 11월 2일’
String dayRangeLabel(DayRange r) {
  final a = dayFromKey(r.from);
  final b = dayFromKey(r.to);
  return a.month == b.month && a.year == b.year
      ? '${formatMonthDay(a)} ~ ${b.day}일'
      : '${formatMonthDay(a)} ~ ${formatMonthDay(b)}';
}

/// 가장 많이 걸은 날: 7일 안이면 요일(‘월 8,350보’), 더 길면 날짜(‘11월 12일 8,350보’)
String bestDayLabel(DayCard c, {bool unit = true}) {
  final best = c.best;
  if (best == null) return '-';
  final when = c.range.days <= 7 ? weekdayShort(best.day) : formatMonthDay(dayFromKey(best.day));
  return '$when ${formatInt(best.steps)}${unit ? '보' : ''}';
}

/// 카드의 숫자 칸 (이름표, 값). 하루면 걸음·거리·물감 길·물감 방울, 여러 날이면 걸음·거리·하루 평균·가장 많이 걸은 날.
/// [share]면 공유 이미지 글 (걸음에 ‘보’ 없이, ‘물감 방울’ 대신 ‘방울’, 캔버스 2-4)
List<(String, String)> dayCardStats(DayCard c, {bool share = false}) {
  final steps = share ? formatInt(c.steps) : '${formatInt(c.steps)}보';
  final km = formatKmShort(c.actualM);
  if (c.range.single) {
    return [
      ('걸음', steps),
      ('거리', km),
      ('물감 길', formatKmShort(c.trailM)),
      (share ? '방울' : '물감 방울', '${formatInt(c.drops)}개'),
    ];
  }
  return [
    ('걸음', steps),
    ('거리', km),
    ('하루 평균', share ? formatInt(c.avgSteps) : '${formatInt(c.avgSteps)}보'),
    (share ? '가장 많은 날' : '가장 많이 걸은 날', bestDayLabel(c, unit: !share)),
  ];
}

/// 카드에 붙일 그림: 카드 날들에 얻은 그림 중 마지막 (첫 그림이면 [firstPackLandmark])
Landmark? cardPainting(DayCard c, Map<String, Landmark> landmarks) {
  for (final id in c.paintings.reversed) {
    if (id == sketchId) return firstPackLandmark;
    if (landmarks[id] case final l?) return l;
  }
  return null;
}

/// 공유 파일 이름 (확장자 포함)
String dayCardFileName(DayCard c) => c.range.single
    ? 'doobal_${c.range.to}.png'
    : 'doobal_${c.range.from}_${c.range.to}.png';

/// 공유 글. TODO: 문구는 가안이다 (기획 확정 전)
String dayCardShareText(DayCard c, DateTime now) => c.range.single
    ? '두발 · ${formatMonthDay(dayFromKey(c.range.to))} ${formatInt(c.steps)}보'
    : '두발 · ${dayCardTitle(c, now)} ${formatInt(c.steps)}보';

/// 화면 가득 하루 카드: 어둡게 한 뒤 위 오른쪽 닫기 ×, 가운데 카드 (캔버스 2-3).
/// 공유 아이콘을 누르면 화면 밖에 공유 이미지 틀(2-4)을 그려 config report.shareImagePx PNG로 떠서
/// 휴대폰 공유 창에 올린다. ‘자세히 보기 ›’는 걷기 리포트 (6-4)
class DayCardOverlay extends ConsumerStatefulWidget {
  const DayCardOverlay({super.key, required this.card, required this.onClose});

  final DayCard card;
  final VoidCallback onClose;

  @override
  ConsumerState<DayCardOverlay> createState() => _DayCardOverlayState();
}

class _DayCardOverlayState extends ConsumerState<DayCardOverlay> {
  final _shareKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  var _sharing = false;

  /// 공유 틀의 정령이 그려질 준비가 됐는가
  var _spiritReady = false;

  Future<void> _share() async {
    if (_sharing) return;
    final rules = ref.read(rulesProvider).value;
    if (rules == null) return;
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _sharing = true;
      _spiritReady = false;
    });
    try {
      // 정령(Rive 한 프레임)과 그림이 다 그려진 뒤에 뜬다. 정령을 못 읽으면 2초 뒤 정령 없이.
      // 기다림은 화면 그리기(프레임)마다 본다 (시계 타이머를 쓰지 않는다)
      final waited = Stopwatch()..start();
      var after = 0;
      while (mounted && after < 3) {
        if (_spiritReady || waited.elapsedMilliseconds > 2000) after++;
        SchedulerBinding.instance.scheduleFrame();
        await SchedulerBinding.instance.endOfFrame;
      }
      if (!mounted) return;
      final png = await capturePng(
        _shareKey,
        pixelRatio: rules.report.shareImageWidthPx / shareFrameWidth,
      );
      if (png == null || png.isEmpty) throw StateError('하루 카드를 이미지로 만들지 못했다');
      await ref.read(paintingSharerProvider).share(
            png: png,
            fileName: dayCardFileName(widget.card),
            text: dayCardShareText(widget.card, ref.read(clockProvider)()),
            origin: origin,
          );
    } catch (e) {
      debugPrint('하루 카드 공유 실패: $e');
      if (mounted) showToast(context, '공유하지 못했어요');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider).value;
    final landmarks = ref.watch(landmarksProvider).value ?? const [];
    final spirit = ref.watch(spiritLookProvider);
    final now = ref.watch(clockProvider)();
    final painting = cardPainting(widget.card, {for (final l in landmarks) l.id: l});
    final shareHeight = rules == null
        ? shareFrameWidth * 5 / 4
        : shareFrameWidth * rules.report.shareImageHeightPx / rules.report.shareImageWidthPx;
    return LayoutBuilder(builder: (context, box) {
      final cardW = math.min(330.0, box.maxWidth - 60);
      return Stack(
        children: [
          // 공유 이미지 틀은 화면 밖에 그린다 (공유할 때만)
          if (_sharing && !widget.card.rested)
            Positioned(
              left: -box.maxWidth - shareFrameWidth,
              top: 0,
              width: shareFrameWidth,
              height: shareHeight,
              child: RepaintBoundary(
                key: _shareKey,
                child: DayCardShareImage(
                  card: widget.card,
                  now: now,
                  painting: painting,
                  spirit: spirit,
                  onSpiritReady: () => _spiritReady = true,
                ),
              ),
            ),
          const Positioned.fill(child: ModalBarrier(color: _scrim, dismissible: false)),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 56, 0, 24),
                  child: _PopIn(
                    child: SizedBox(
                      width: cardW,
                      child: DayCardPanel(
                        key: ValueKey('day-card-${widget.card.range.from}-${widget.card.range.to}'),
                        card: widget.card,
                        now: now,
                        painting: painting,
                        spirit: spirit,
                        shareButtonKey: _shareButtonKey,
                        sharing: _sharing,
                        onShare: _share,
                        onDetail: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const WalkReportScreen()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + 4,
            right: 10,
            child: Semantics(
              button: true,
              label: '닫기',
              child: GestureDetector(
                key: const ValueKey('day-card-close'),
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.close, size: 24, color: Palette.card),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// 나타날 때 아래 16pt에서 올라오며 보인다 (0.45초, 동작 줄이기면 바로)
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// 메모지 종이 + 위 가운데 테이프, 살짝 기운 카드 (하루 카드·공유 이미지)
class _Paper extends StatelessWidget {
  const _Paper({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -1 * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: padding,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_notePaper),
                centerSlice: Rect.fromLTRB(60, 60, 540, 540),
                scale: 3,
              ),
            ),
            child: child,
          ),
          Positioned(
            top: -11,
            left: 0,
            right: 0,
            child: Center(child: _TapeStrip(width: 74, turnDeg: -3)),
          ),
        ],
      ),
    );
  }
}

class _TapeStrip extends StatelessWidget {
  const _TapeStrip({required this.width, required this.turnDeg});

  final double width;
  final double turnDeg;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: turnDeg * math.pi / 180,
        child: Image.asset(
          _tape,
          width: width,
          height: 22,
          fit: BoxFit.fill,
          cacheWidth: 256,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stack) => SizedBox(width: width, height: 22),
        ),
      );
}

/// 그림 하나 (첫 그림이면 짐 꾸러미)
Widget _paintingFace(Landmark l) =>
    l.id == sketchId ? const FirstPackFace() : PaintingFace(landmark: l);

/// 폴라로이드에 붙인 그림 + 오른쪽 아래 밖에 정령 (그림 받은 날)
class _PolaroidWithSpirit extends StatelessWidget {
  const _PolaroidWithSpirit({
    required this.painting,
    required this.spirit,
    required this.width,
    required this.pad,
    required this.spiritSize,
    required this.spiritOffset,
    this.shadow = true,
    this.onSpiritReady,
    this.renderer,
  });

  final Landmark painting;
  final SpiritLook spirit;
  final double width;
  final EdgeInsets pad;
  final Size spiritSize;

  /// 정령이 폴라로이드 오른쪽·아래 밖으로 나간 만큼
  final Offset spiritOffset;
  final bool shadow;
  final VoidCallback? onSpiritReady;
  final rive.Factory? renderer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: spiritOffset.dx, bottom: spiritOffset.dy),
      child: Transform.rotate(
        angle: 1.5 * math.pi / 180,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: pad,
              decoration: BoxDecoration(
                color: _polaroid,
                border: Border.all(color: Palette.line),
                boxShadow: shadow
                    ? const [BoxShadow(color: Palette.shadow, offset: Offset(0, 2), blurRadius: 4)]
                    : null,
              ),
              child: SizedBox(
                key: ValueKey('day-card-painting-${painting.id}'),
                width: width,
                height: width * 3 / 4,
                child: Semantics(
                  label: '그날 얻은 그림: ${painting.name}',
                  child: _paintingFace(painting),
                ),
              ),
            ),
            const Positioned(left: -18, top: -6, child: _TapeStrip(width: 52, turnDeg: -38)),
            Positioned(
              right: -spiritOffset.dx,
              bottom: -spiritOffset.dy,
              width: spiritSize.width,
              height: spiritSize.height,
              child: _Spirit(spirit, onReady: onSpiritReady, renderer: renderer),
            ),
          ],
        ),
      ),
    );
  }
}

/// 꾸민 정령 (쉼터와 같은 정령, 서 있기). [sleeping]이면 잠든 자세(쉬어 간 날 카드, 쉼터 밤과 같은 자세 4)
class _Spirit extends StatelessWidget {
  const _Spirit(this.look, {this.onReady, this.renderer, this.sleeping = false});

  final SpiritLook look;
  final VoidCallback? onReady;
  final rive.Factory? renderer;
  final bool sleeping;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SpiritStanding(
          look: look,
          share: 0.92,
          footAt: 0.97,
          riveFactory: renderer,
          onReady: onReady == null && !sleeping
              ? null
              : (c) {
                  if (sleeping) c.play(SpiritMotion.sleep);
                  onReady?.call();
                },
        ),
      );
}

/// 하루 카드 종이 (캔버스 2-3): 날짜·제목·공유 아이콘, 그림(있으면)과 정령, 숫자 2×2, 이번 주 막대, 자세히 보기.
/// 걸음이 0이면 ‘쉬어 간 날’ 카드(16장 11/15): 공유 아이콘·숫자 대신 잠든 정령과 글 한 줄, 막대·자세히 보기는 그대로
class DayCardPanel extends StatelessWidget {
  const DayCardPanel({
    super.key,
    required this.card,
    required this.now,
    required this.painting,
    required this.spirit,
    required this.onShare,
    required this.onDetail,
    this.shareButtonKey,
    this.sharing = false,
  });

  final DayCard card;
  final DateTime now;
  final Landmark? painting;
  final SpiritLook spirit;
  final VoidCallback onShare;
  final VoidCallback onDetail;
  final Key? shareButtonKey;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final title = dayCardTitle(card, now);
    final stats = dayCardStats(card);
    final painting = this.painting;
    final rested = card.rested;
    return Semantics(
      container: true,
      label: '$title 하루 카드',
      child: _Paper(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: LayoutBuilder(builder: (context, box) {
          final pw = (box.maxWidth * 0.78).floorToDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dayCardSub(card, now),
                            style: const TextStyle(fontSize: 13, color: Palette.subInk)),
                        const SizedBox(height: 2),
                        Text(title, style: context.display(22).copyWith(height: 1.25)),
                      ],
                    ),
                  ),
                  if (!rested) Transform.translate(
                    offset: const Offset(6, -6),
                    child: Semantics(
                      button: true,
                      label: '이미지로 공유',
                      child: GestureDetector(
                        key: const ValueKey('day-card-share'),
                        behavior: HitTestBehavior.opaque,
                        onTap: sharing ? null : onShare,
                        child: SizedBox(
                          // 공유 창이 iPad에서 뜰 자리를 이 상자로 잰다
                          key: shareButtonKey,
                          width: 44,
                          height: 44,
                          child: sharing
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Palette.ink),
                                )
                              : const Icon(Icons.ios_share, size: 22, color: Palette.ink),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: painting != null
                    ? _PolaroidWithSpirit(
                        painting: painting,
                        spirit: spirit,
                        width: pw - 16,
                        pad: const EdgeInsets.fromLTRB(8, 8, 8, 22),
                        spiritSize: const Size(76, 91),
                        spiritOffset: const Offset(26, 30),
                      )
                    : SizedBox(width: 110, height: 131, child: _Spirit(spirit, sleeping: rested)),
              ),
              const SizedBox(height: 12),
              if (rested)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    restedLine(card, now),
                    key: const ValueKey('day-card-rested'),
                    textAlign: TextAlign.center,
                    style: context.display(17).copyWith(height: 1.35),
                  ),
                )
              else
                _StatGrid(stats),
              const SizedBox(height: 12),
              const Text('이번 주', style: AppText.label),
              const SizedBox(height: 6),
              WeekBars(week: card.week, height: 84, barMaxHeight: 64, barMaxWidth: 26, minBar: 6),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  key: const ValueKey('day-card-detail'),
                  onPressed: onDetail,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: Palette.terracottaDeep,
                  ),
                  child: const Text('자세히 보기 ›',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// 숫자 2×2 칸 (바탕 종이색, 이름표 12·값 18)
class _StatGrid extends StatelessWidget {
  const _StatGrid(this.stats);

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    Widget cell((String, String) s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Palette.paper,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.$1, style: AppText.label),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  s.$2,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );
    return Column(
      children: [
        for (var row = 0; row < stats.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: cell(stats[row])),
              const SizedBox(width: 6),
              Expanded(child: row + 1 < stats.length ? cell(stats[row + 1]) : const SizedBox()),
            ],
          ),
        ],
      ],
    );
  }
}

/// 이번 주 7일 막대 (월~일): 카드 날은 테라코타, 다른 날은 연두, 걸음이 없거나 아직 안 온 날은 점선 바닥.
/// 막대 높이 = max([minBar], 걸음 ÷ 그 주 최댓값 × [barMaxHeight])
class WeekBars extends StatelessWidget {
  const WeekBars({
    super.key,
    required this.week,
    required this.height,
    required this.barMaxHeight,
    required this.barMaxWidth,
    required this.minBar,
    this.gap = 6,
    this.labelSize = 11,
    this.highlightLabels = true,
  });

  final List<WeekBar> week;
  final double height;
  final double barMaxHeight;
  final double barMaxWidth;
  final double minBar;
  final double gap;
  final double labelSize;

  /// 카드 날의 요일 글자를 진하게 (공유 이미지는 모두 옅게)
  final bool highlightLabels;

  @override
  Widget build(BuildContext context) {
    final most = week.fold(0, (m, b) => (b.steps ?? 0) > m ? b.steps! : m);
    final aria = week
        .map((b) =>
            '${weekdayShort(b.day)} ${b.steps == null ? '아직' : '${formatInt(b.steps!)}보'}')
        .join(', ');
    return Semantics(
      label: '이번 주 걸음 막대: $aria',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, b) in week.indexed) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 글자가 커져도 넘치지 않게 요일 글자를 뺀 높이 안에서 막대를 줄인다
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) => Align(
                            alignment: Alignment.bottomCenter,
                            child: _bar(b, most, math.min(barMaxHeight, box.maxHeight)),
                          ),
                        ),
                      ),
                      SizedBox(height: gap * 2 / 3),
                      Text(
                        weekdayShort(b.day),
                        style: TextStyle(
                          fontSize: labelSize,
                          color: highlightLabels && b.inCard ? Palette.ink : Palette.subInk,
                          fontWeight:
                              highlightLabels && b.inCard ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(WeekBar b, int most, double maxHeight) {
    final steps = b.steps ?? 0;
    if (steps <= 0 || most <= 0) {
      return SizedBox(
        key: ValueKey('week-bar-${b.day}'),
        width: barMaxWidth,
        height: 1.5,
        child: const CustomPaint(painter: _DashPainter()),
      );
    }
    return Container(
      key: ValueKey('week-bar-${b.day}'),
      width: barMaxWidth,
      height: math.min(maxHeight, math.max(minBar, (steps / most * maxHeight).roundToDouble())),
      decoration: BoxDecoration(
        color: b.inCard ? Palette.terracotta : dayBarOther,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(2)),
      ),
    );
  }
}

/// 점선 바닥 (걸음이 없거나 아직 안 온 날)
class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.lineDashed
      ..strokeWidth = size.height;
    const dash = 3.0;
    for (var x = 0.0; x < size.width; x += dash * 2) {
      canvas.drawLine(Offset(x, size.height / 2),
          Offset(math.min(x + dash, size.width), size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

/// 공유 이미지 틀 (캔버스 2-4, 360×450 = 4:5): 바탕 위 카드(제목·작은 줄, 그림 + 정령 또는 정령,
/// 숫자 4칸 한 줄, 7일 막대) + 아래 발자국 ‘DOOBAL’. 버튼 없음. 정령은 Flutter 그리기로 (이미지에 담기게)
class DayCardShareImage extends StatelessWidget {
  const DayCardShareImage({
    super.key,
    required this.card,
    required this.now,
    required this.painting,
    required this.spirit,
    this.onSpiritReady,
  });

  final DayCard card;
  final DateTime now;
  final Landmark? painting;
  final SpiritLook spirit;
  final VoidCallback? onSpiritReady;

  @override
  Widget build(BuildContext context) {
    final painting = this.painting;
    final single = card.range.single;
    // 그림 받은 날은 명소 이름이 제목, 아니면 날짜 (여러 날이면 ‘지난 n일’)
    final title = painting != null
        ? painting.name
        : single
            ? formatMonthDay(dayFromKey(card.range.to))
            : dayCardTitle(card, now);
    final sub = single
        ? (painting != null
            ? '${formatMonthDay(dayFromKey(card.range.to))} ${weekdayLong(card.range.to)}'
            : weekdayLong(card.range.to))
        : dayRangeLabel(card.range);
    final stats = dayCardStats(card, share: true);
    return MediaQuery(
      // 공유 이미지는 늘 같은 모양으로 (기기 글자 크기와 상관없이)
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        image: true,
        label: '공유 이미지',
        child: ColoredBox(
          color: _shareBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
            child: Column(
              children: [
                SizedBox(
                  width: 316,
                  child: _Paper(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.display(19)),
                            ),
                            const SizedBox(width: 8),
                            Text(sub, style: AppText.label),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: painting != null
                              ? _PolaroidWithSpirit(
                                  painting: painting,
                                  spirit: spirit,
                                  width: 184,
                                  pad: const EdgeInsets.fromLTRB(6, 6, 6, 16),
                                  spiritSize: const Size(62, 74),
                                  spiritOffset: const Offset(30, 22),
                                  shadow: false,
                                  onSpiritReady: onSpiritReady,
                                  renderer: rive.Factory.flutter,
                                )
                              : SizedBox(
                                  width: 120,
                                  height: 143,
                                  child: _Spirit(spirit,
                                      onReady: onSpiritReady, renderer: rive.Factory.flutter),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final (i, s) in stats.indexed) ...[
                              if (i > 0) const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(s.$1,
                                          style: const TextStyle(
                                              fontSize: 11, color: Palette.subInk)),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        s.$2,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Palette.ink,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        WeekBars(
                          week: card.week,
                          height: 52,
                          barMaxHeight: 36,
                          barMaxWidth: 22,
                          minBar: 5,
                          gap: 5,
                          highlightLabels: false,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_walk, size: 18, color: Palette.subInk),
                      SizedBox(width: 6),
                      Text(
                        'DOOBAL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Palette.subInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 노트 날짜 줄에서 여는 그날 하루 카드 (같은 카드, × → 노트). 본 날로 적지 않는다
class DayCardPage extends ConsumerWidget {
  const DayCardPage({super.key, required this.day});

  final String day;

  /// 노트 위에 투명하게 올린다
  static Route<void> route(String day) => PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, _, _) => DayCardPage(day: day),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(dayCardOfProvider(day)).value;
    return Material(
      type: MaterialType.transparency,
      child: card == null
          ? const ModalBarrier(color: _scrim, dismissible: false)
          : DayCardOverlay(card: card, onClose: () => Navigator.of(context).maybePop()),
    );
  }
}
