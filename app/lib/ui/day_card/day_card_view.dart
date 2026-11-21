import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart' as rive;

import '../../app/providers.dart';
import '../../app/report_providers.dart';
import '../../domain/day_card.dart';
import '../../domain/geo.dart';
import '../../domain/landmark.dart';
import '../../domain/paint_pattern_rules.dart';
import '../../domain/rules.dart';
import '../../domain/scene.dart' show SceneLook, sceneLook;
import '../../domain/sketch.dart';
import '../../domain/spirit_look.dart';
import '../../domain/time_kst.dart';
import '../../domain/trail_layout.dart';
import '../album/painting_share.dart' show capturePng;
import '../common/format.dart';
import '../common/framed_painting.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../common/trail_pattern_paint.dart';
import '../scene/scene_art.dart' show SceneArtHost;
import '../scene/scene_art_painter.dart' show SceneArtPainter;
import '../scene/scene_painter.dart' show SceneMode, ScenePass;
import '../scene/spirit_character.dart';
import 'walk_report_screen.dart';

// 하루 카드 엽서 (캔버스 2-3 DayCardV D안)와 공유 엽서 (2-4). 16장 11/19 하루 카드 개편: 종이·테이프 대신
// 디자인 시스템 카드, 위 장면(걸은 날 = 걷는 중 층 그림 + 칠한 물감 색 길 + 옆면 정령 / 쉬어 간 날 = 밤 장면에
// 잠든 정령 / 도착한 날 = 받은 그림 + 정면 정령)에 날짜 소인, 아래 문장 한 줄·여정 막대·칩 3·주간 점.
// 값은 config report.card (domain/day_card_rules.dart). 무늬는 T17b 뒤에 더한다 (지금은 색만)

/// 걷기 리포트 막대의 다른 날 (캔버스 2-3·6-4 연두, 걷기 리포트가 쓴다)
const dayBarOther = Color(0xFFB7BE86);

/// 카드 뒤를 어둡게 (캔버스 2-3)
const _scrim = Color(0x8C1E1611);

/// 공유 이미지 바탕 (캔버스 2-4)
const _shareBackground = Color(0xFFEADFC8);

/// 여정 막대 바탕·지난 진행 (캔버스 --card-deep·--wood)
const _cardDeep = Color(0xFFE4D6BC);
const _wood = Color(0xFF8C6F4E);

/// 주간 점의 다른 날 (캔버스 rgba(86,101,58,.55))
const _dotOther = Color(0x8C56653A);

/// 소인 테두리·바탕 (캔버스 rgba(62,44,34,.75)·rgba(251,246,236,.6))
const _postmarkLine = Color(0xBF3E2C22);
const _postmarkFill = Color(0x99FBF6EC);

/// 공유 이미지 틀의 크기 (캔버스 2-4 판 360×450 = 4:5). 내보낼 때는 config report.shareImagePx 폭에 맞춰 키운다
const shareFrameWidth = 360.0;

/// 엽서 장면 설계 크기 (캔버스 2-3 카드 폭 342 × 장면 188, 2-4 공유 324 × 200). 좁은 화면은 비율대로 줄인다
const _cardScene = Size(342, 188);
const _shareScene = Size(324, 200);

/// 카드 폭 (캔버스 342 = 390 − 좌우 24)
const _cardWidth = 342.0;

const _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

/// '월' … '일'
String weekdayShort(String day) => _weekdayShort[dayFromKey(day).weekday - 1];

/// '수요일'
String weekdayLong(String day) => '${weekdayShort(day)}요일';

/// 카드 날이 달력 어제인가 (05:00 전에 연 그저께 카드·노트 다시 보기는 아니다)
bool isYesterdayCard(DayCard c, DateTime now) =>
    c.range.single && c.range.to == addDays(kstDayKey(now), -1);

/// 하루 카드 제목: 어제면 ‘어제’, 아니면 그 날짜(‘11월 18일’), 여러 날이면 ‘지난 n일’
String dayCardTitle(DayCard c, DateTime now) {
  if (!c.range.single) return '지난 ${c.range.days}일';
  return isYesterdayCard(c, now) ? '어제' : formatMonthDay(dayFromKey(c.range.to));
}

/// 문장 위 날짜 줄 (캔버스 dTitle): ‘어제 · 11월 18일 수요일’, 날짜 카드면 ‘11월 18일 수요일’,
/// 여러 날이면 ‘지난 3일 · 11월 12일 ~ 14일’
String dayCardDateLine(DayCard c, DateTime now) {
  if (!c.range.single) return '${dayCardTitle(c, now)} · ${dayRangeLabel(c.range)}';
  final date = '${formatMonthDay(dayFromKey(c.range.to))} ${weekdayLong(c.range.to)}';
  return isYesterdayCard(c, now) ? '어제 · $date' : date;
}

/// ‘11월 12일 ~ 14일’, 달이 다르면 ‘10월 30일 ~ 11월 2일’
String dayRangeLabel(DayRange r) {
  final a = dayFromKey(r.from);
  final b = dayFromKey(r.to);
  return a.month == b.month && a.year == b.year
      ? '${formatMonthDay(a)} ~ ${b.day}일'
      : '${formatMonthDay(a)} ~ ${formatMonthDay(b)}';
}

/// 소인 아래 작은 글: 하루면 요일(‘수요일’), 여러 날이면 날 수(‘3일’)
String postmarkSub(DayCard c) => c.range.single ? weekdayLong(c.range.to) : '${c.range.days}일';

/// 여정 막대 위 글 (캔버스 jName·jLeft): 도착이면 ‘경복궁 · 은 액자’·‘첫 방문’,
/// 아니면 ‘경복궁까지’·‘12.4km 남음’(다가가지 않았으면 ‘12.4km 그대로’). 여정이 없으면 null
(String, String)? journeyLabels(DayCard c, CardSentences t) {
  final j = c.story.journey;
  if (j == null) return null;
  if (j.arrived) {
    final frame = j.frame;
    final visit = j.visitNo;
    return (
      frame == null ? j.destName : '${j.destName} · ${frameName(frame)} 액자',
      visit == null ? '' : (visit <= 1 ? '첫 방문' : '$visit번째 방문'),
    );
  }
  String km(double v) => v.toStringAsFixed(t.kmDigits);
  final still = km(j.deltaKm) == km(0);
  return ('${j.destName}까지', '${km(j.remainingKm)}km ${still ? '그대로' : '남음'}');
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

/// 화면 가득 하루 카드: 어둡게 한 뒤 위 오른쪽 닫기 ×, 가운데 엽서 (캔버스 2-3).
/// 장면 왼쪽 위 공유 버튼을 누르면 화면 밖에 공유 엽서(2-4)를 그려 config report.shareImagePx PNG로 떠서
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

  /// 공유 엽서의 정령·장면이 그려질 준비가 됐는가
  var _spiritReady = false;
  var _sceneReady = false;

  Future<void> _share() async {
    if (_sharing) return;
    final rules = ref.read(rulesProvider).value;
    if (rules == null) return;
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _sharing = true;
      _spiritReady = false;
      _sceneReady = false;
    });
    try {
      // 정령(Rive 한 프레임)·장면 그림이 다 그려진 뒤에 뜬다. 못 읽으면 2초 뒤 그것 없이.
      // 기다림은 화면 그리기(프레임)마다 본다 (시계 타이머를 쓰지 않는다)
      final waited = Stopwatch()..start();
      var after = 0;
      while (mounted && after < 3) {
        if ((_spiritReady && _sceneReady) || waited.elapsedMilliseconds > 2000) after++;
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
    final shareable = rules != null && dayCardShareable(widget.card, rules.report.card);
    final shareHeight = rules == null
        ? shareFrameWidth * 5 / 4
        : shareFrameWidth * rules.report.shareImageHeightPx / rules.report.shareImageWidthPx;
    return LayoutBuilder(builder: (context, box) {
      final cardW = math.min(_cardWidth, box.maxWidth - 48);
      return Stack(
        children: [
          // 공유 엽서는 화면 밖에 그린다 (공유할 때만)
          if (_sharing && shareable)
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
                  onSceneReady: () => _sceneReady = true,
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
                      child: rules == null
                          ? const SizedBox.shrink()
                          : DayCardPanel(
                              key: ValueKey(
                                  'day-card-${widget.card.range.from}-${widget.card.range.to}'),
                              card: widget.card,
                              now: now,
                              rules: rules,
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

/// 나타날 때 아래 14pt에서 올라오며 보인다 (0.4초, 동작 줄이기면 바로, 캔버스 .up)
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// 디자인 시스템 카드 (캔버스: 바탕 --card, 잉크 1.8 테두리, 둥근 [radius], 아래 옅은 그림자 + [lift]면 뜬 그림자)
class _PostcardFrame extends StatelessWidget {
  const _PostcardFrame({required this.radius, required this.child, this.lift = true});

  final double radius;
  final bool lift;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Palette.card,
          border: Border.all(color: Palette.ink, width: InkLine.panel),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            const BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow)),
            if (lift) const BoxShadow(color: Color(0x38000000), offset: Offset(0, 14), blurRadius: 28),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - InkLine.panel),
          child: child,
        ),
      );
}

/// 하루 엽서 (캔버스 2-3 D안): 장면(소인·공유 버튼) · 날짜 줄 · 문장 한 줄 · 여정 막대 · 칩 · 주간 점 · 자세히 보기.
/// 쉬어 간 날(0보)은 밤 장면에 잠든 정령, 칩·공유 없음 (config report.card.chips.rest·share.excludeOn)
class DayCardPanel extends StatelessWidget {
  const DayCardPanel({
    super.key,
    required this.card,
    required this.now,
    required this.rules,
    required this.painting,
    required this.spirit,
    required this.onShare,
    required this.onDetail,
    this.shareButtonKey,
    this.sharing = false,
  });

  final DayCard card;
  final DateTime now;
  final Rules rules;
  final Landmark? painting;
  final SpiritLook spirit;
  final VoidCallback onShare;
  final VoidCallback onDetail;
  final Key? shareButtonKey;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final r = rules.report.card;
    final line = dayCardSentence(card, r.sentences, yesterday: isYesterdayCard(card, now));
    final chips = dayCardChips(card, r);
    final journey = journeyLabels(card, r.sentences);
    final shareable = dayCardShareable(card, r);
    return Semantics(
      container: true,
      label: '${dayCardTitle(card, now)} 하루 카드',
      child: _PostcardFrame(
        radius: 22,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Palette.ink, width: InkLine.panel)),
              ),
              child: AspectRatio(
                aspectRatio: _cardScene.width / _cardScene.height,
                child: PostcardScene(
                  card: card,
                  rules: rules,
                  painting: painting,
                  spirit: spirit,
                  design: _cardScene,
                  share: shareable
                      ? _ShareButton(key: shareButtonKey, sharing: sharing, onTap: onShare)
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(dayCardDateLine(card, now),
                      style: const TextStyle(fontSize: 12, height: 16 / 12, color: Palette.subInk)),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    key: const ValueKey('day-card-line'),
                    style: const TextStyle(
                      fontSize: 18,
                      height: 26 / 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: Palette.ink,
                    ),
                  ),
                  if (journey != null || !r.hideJourneyBarWithoutJourney) ...[
                    const SizedBox(height: 10),
                    _JourneyBar(card: card, labels: journey),
                  ],
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _Chips(chips),
                  ],
                  const SizedBox(height: 10),
                  WeekDots(week: card.week, hollowRest: r.restDayHollow),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 10, 4),
                child: TextButton(
                  key: const ValueKey('day-card-detail'),
                  onPressed: onDetail,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Palette.terracottaDeep,
                  ),
                  child: const Text('자세히 보기 ›',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 장면 왼쪽 위 공유 버튼 (캔버스: 44 동그라미, 잉크 1.4, 바탕 rgba(251,246,236,.9))
class _ShareButton extends StatelessWidget {
  const _ShareButton({super.key, required this.sharing, required this.onTap});

  final bool sharing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '이미지로 공유',
        child: GestureDetector(
          key: const ValueKey('day-card-share'),
          behavior: HitTestBehavior.opaque,
          onTap: sharing ? null : onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xE6FBF6EC),
              shape: BoxShape.circle,
              border: Border.all(color: Palette.ink, width: InkLine.pill),
            ),
            child: sharing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Palette.ink),
                  )
                : const Icon(Icons.ios_share, size: 18, color: Palette.ink),
          ),
        ),
      );
}

/// 여정 막대 (캔버스: 위 이름·남은 거리 12, 아래 6pt 막대 = 지난 진행 나무색 + 카드 날 진행 테라코타)
class _JourneyBar extends StatelessWidget {
  const _JourneyBar({required this.card, required this.labels});

  final DayCard card;
  final (String, String)? labels;

  @override
  Widget build(BuildContext context) {
    final j = card.story.journey;
    final (name, left) = labels ?? ('', '');
    const style = TextStyle(fontSize: 12, height: 16 / 12, color: Palette.subInk);
    return Semantics(
      label: '$name $left',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(left,
                    style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                key: const ValueKey('day-card-journey-bar'),
                height: 6,
                child: LayoutBuilder(builder: (context, box) {
                  final before = (j?.beforeRatio ?? 0) * box.maxWidth;
                  final delta = (j?.deltaRatio ?? 0) * box.maxWidth;
                  return Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: _cardDeep)),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: before,
                        child: const ColoredBox(
                            key: ValueKey('journey-before'), color: _wood),
                      ),
                      Positioned(
                        left: before,
                        top: 0,
                        bottom: 0,
                        width: delta,
                        child: const ColoredBox(
                            key: ValueKey('journey-delta'), color: Palette.terracotta),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 칩 3 (캔버스: 13pt, 알약, 바탕 종이·옅은 선, 값 굵게 + 이름 옅게)
class _Chips extends StatelessWidget {
  const _Chips(this.chips, {this.fontSize = 13, this.pad = const EdgeInsets.symmetric(horizontal: 10, vertical: 5)});

  final List<CardChipText> chips;
  final double fontSize;
  final EdgeInsets pad;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in chips)
            Container(
              padding: pad,
              decoration: BoxDecoration(
                color: Palette.paper,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Palette.line),
              ),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: c.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' ${c.label}', style: const TextStyle(color: Palette.subInk)),
                ]),
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.35,
                  color: Palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      );
}

/// 이번 주 점 7개 (캔버스 D안 dots, config report.card.weekDots): 걸은 날은 걸음만큼 큰 점
/// (지름 = 8 + 걸음 ÷ 그 주 최댓값 × 12, 반올림), 카드 날은 테라코타 + 잉크 고리, 다른 날은 옅은 이끼,
/// 쉰 날(0보)·아직 안 온 날은 빈 점선 동그라미 8pt
class WeekDots extends StatelessWidget {
  const WeekDots({super.key, required this.week, this.hollowRest = true});

  final List<WeekBar> week;
  final bool hollowRest;

  @override
  Widget build(BuildContext context) {
    final most = week.fold(0, (m, b) => (b.steps ?? 0) > m ? b.steps! : m);
    final aria = week
        .map((b) => '${weekdayShort(b.day)} ${switch (b.steps) {
              null => '아직',
              0 => '쉼',
              final s => '${formatInt(s)}보',
            }}')
        .join(', ');
    return Semantics(
      label: '이번 주 걸음: $aria',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final b in week)
                SizedBox(
                  width: 30,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 22,
                        child: Center(child: _dot(b, most)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        weekdayShort(b.day),
                        style: TextStyle(
                          fontSize: 11,
                          height: 13 / 11,
                          color: b.inCard ? Palette.ink : Palette.subInk,
                          fontWeight: b.inCard ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(WeekBar b, int most) {
    final steps = b.steps ?? 0;
    final walked = steps > 0 && most > 0;
    final d = walked ? (8 + steps / most * 12).roundToDouble() : 8.0;
    return SizedBox(
      key: ValueKey('week-dot-${b.day}'),
      width: d,
      height: d,
      child: CustomPaint(
        painter: _DotPainter(
          fill: walked ? (b.inCard ? Palette.terracotta : _dotOther) : null,
          ring: walked && b.inCard,
          hollow: !walked && hollowRest,
        ),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  const _DotPainter({required this.fill, required this.ring, required this.hollow});

  final Color? fill;
  final bool ring;
  final bool hollow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (fill case final f?) canvas.drawCircle(c, r, Paint()..color = f);
    if (ring) {
      // outline 1.5 잉크, 2pt 띄움 (캔버스 outline-offset 2px)
      canvas.drawCircle(
          c,
          r + 2 + 0.75,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Palette.ink);
    }
    if (hollow) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Palette.lineDashed;
      const dashes = 8;
      final rr = r - 0.75;
      for (var i = 0; i < dashes; i++) {
        final a = i * 2 * math.pi / dashes;
        canvas.drawArc(Rect.fromCircle(center: c, radius: rr), a, math.pi / dashes, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.fill != fill || old.ring != ring || old.hollow != hollow;
}

/// 엽서 위 장면 ([design] 크기로 짜고 상자에 맞춰 줄인다): 걸은 날은 걷는 중 층 그림(낮)에 카드 날 칠한 물감 색
/// 구간을 걸은 차례로 길에 깔고 옆면 정령, 쉬어 간 날은 같은 그림의 밤 장면에 잠든 정령, 그림 받은 날은 받은 그림에
/// 정면 정령. 오른쪽 위 소인, 왼쪽 위 [share] 버튼(있으면). 정령은 첫 장면에 멈춘다 (config report.card.scene)
class PostcardScene extends ConsumerWidget {
  const PostcardScene({
    super.key,
    required this.card,
    required this.rules,
    required this.painting,
    required this.spirit,
    required this.design,
    this.share,
    this.postmarkSize = 58,
    this.renderer,
    this.onSpiritReady,
    this.onSceneReady,
  });

  final DayCard card;
  final Rules rules;
  final Landmark? painting;
  final SpiritLook spirit;
  final Size design;
  final Widget? share;
  final double postmarkSize;

  /// 정령 그리기 (공유 엽서는 Flutter 그리기, [SpiritCharacter.riveFactory])
  final rive.Factory? renderer;
  final VoidCallback? onSpiritReady;
  final VoidCallback? onSceneReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landmarks = ref.watch(landmarksProvider).value ?? const <Landmark>[];
    final here = card.story.position ??
        ref.watch(snapshotProvider.select((s) => s.value?.position)) ??
        (landmarks.isEmpty ? null : landmarks.first.latLng);
    final painting = this.painting;
    final r = rules.report.card;
    final W = design.width;
    final H = design.height;
    // 장면 자리 (캔버스 2-3 D안 342×188 비율): 길 y 0.846, 걸은 정령 발 x 0.637·키 0.49,
    // 잠든 정령 발 x 0.5, 그림 받은 날 정령 발 오른쪽 아래·키 0.425
    final pathY = H * 159 / 188;
    final stage = rules.screen.spirit;
    late final Widget scene;
    late final Widget figure;
    if (painting != null) {
      // 받은 그림을 장면 크기에 꽉 채운다 (4:3을 가운데로 잘라, 캔버스 342×256 top −34)
      scene = Semantics(
        label: '그날 얻은 그림: ${painting.name}',
        child: ClipRect(
          child: OverflowBox(
            maxWidth: W,
            maxHeight: W * 3 / 4,
            child: SizedBox(
              key: ValueKey('day-card-painting-${painting.id}'),
              width: W,
              height: W * 3 / 4,
              child: painting.id == sketchId ? const FirstPackFace() : PaintingFace(landmark: painting),
            ),
          ),
        ),
      );
      figure = _CardSpirit(
        look: spirit,
        foot: Offset(W - 51, H - 1),
        figureHeight: H * 80 / 188,
        pose: stage.poseOf('arrival'),
        expression: 1,
        renderer: renderer,
        onReady: onSpiritReady,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => onSceneReady?.call());
    } else {
      final rested = card.rested;
      final look = here == null ? null : _sceneLook(here, landmarks, rested);
      scene = look == null
          ? const ColoredBox(color: Palette.paper)
          : _SceneBand(
              look: look,
              rules: rules,
              design: design,
              pathY: pathY,
              figureHeight: H * 92 / 188,
              distanceM: card.actualM,
              onReady: onSceneReady,
            );
      figure = Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TrailPainter(
                strokes: rested ? const [] : card.story.strokes,
                colorOf: (id) => Color(rules.paintColor.hexOf(id) | 0xFF000000),
                pathY: pathY,
                endX: W * 196 / 342,
                k: H / 188,
                art: trailArtOrNone(ref.watch(trailArtProvider), rules.paintPattern.defaultId),
                trail: rules.mapTrail,
                patterns: rules.paintPattern,
              ),
            ),
          ),
          // 잠든 자세(옆으로 눕기)는 몸이 발 디딤점보다 위에 떠 있어 길에 눕게 내려 둔다 (캔버스 잠든 정령 +12)
          _CardSpirit(
            look: spirit,
            foot: Offset(rested ? W * 0.5 : W * 217 / 342, rested ? pathY + H * 22 / 188 : pathY),
            figureHeight: H * 92 / 188,
            pose: _poseNamed(stage.poses, rested ? r.restPose : r.walkedPose),
            speed: rested ? 0 : 1,
            mirrored: !rested && stage.flips('walking'),
            expression: rested ? 4 : 1,
            renderer: renderer,
            onReady: onSpiritReady,
          ),
        ],
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox.fromSize(
        size: design,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: scene),
            Positioned.fill(child: ExcludeSemantics(child: figure)),
            Positioned(
              right: 12,
              top: 12,
              child: _Postmark(
                day: dayCardPostmark(card, r),
                sub: postmarkSub(card),
                size: postmarkSize,
              ),
            ),
            if (share case final s?) Positioned(left: 8, top: 8, child: s),
          ],
        ),
      ),
    );
  }

  /// 장면 시각: 걸은 날은 카드 끝날 한낮, 쉬어 간 날은 그날 밤 (config report.card.scene.rest.timePhase).
  /// 해 뜨고 지는 시각은 자리마다 다르니 그 시간대가 되는 시각을 찾는다 (없으면 23:30)
  SceneLook _sceneLook(LatLng at, List<Landmark> landmarks, bool rested) {
    final start = kstDayStartUtc(card.range.to);
    SceneLook lookAt(double hour) => sceneLook(
        start.add(Duration(minutes: (hour * 60).round())), at, false, landmarks, rules);
    if (!rested) return lookAt(12);
    final want = rules.report.card.restTimePhase;
    for (final h in const [23.5, 22.0, 21.0, 2.0, 12.0, 19.0, 6.0]) {
      final l = lookAt(h);
      if (l.phase.name == want) return l;
    }
    return lookAt(23.5);
  }
}

/// config 자세 이름 → poseChoice (틀린 이름이면 멈춘다)
int _poseNamed(Map<String, int> poses, String name) =>
    poses[name] ?? (throw FormatException('report.card.scene: 모르는 정령 자세 $name'));

/// 걷는 중 층 그림 한 장면 (멈춘 채): 후경·뒤 줄·들판·길을 세로 화면 배치 그대로, 길이 [pathY]에 오고
/// 장면 크기가 정령 키 [figureHeight]에 맞게 (걷는 중 화면과 같은 정령:장면 비율) 줄여 그린다.
/// 그림은 화면 폭보다 넓게 이어 그린다. 그림을 다 읽으면 [onReady]
class _SceneBand extends StatelessWidget {
  const _SceneBand({
    required this.look,
    required this.rules,
    required this.design,
    required this.pathY,
    required this.figureHeight,
    required this.distanceM,
    this.onReady,
  });

  final SceneLook look;
  final Rules rules;
  final Size design;
  final double pathY;
  final double figureHeight;
  final double distanceM;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    return SceneArtHost(
      look: look,
      mode: SceneMode.walking,
      size: design,
      builder: (context, art, _) {
        if (art == null) return ColoredBox(color: Color(look.sky.horizon));
        WidgetsBinding.instance.addPostFrameCallback((_) => onReady?.call());
        final portrait = art.data['portrait'] as Map<String, dynamic>;
        double n(String k) => (portrait[k] as num).toDouble();
        // 세로 배치의 배율 = 정령 키 ÷ figureHeight, 아래 기준이라 높이로 길 자리를 맞춘다
        final s = figureHeight / n('figureHeight');
        final layout = Size(n('width') * s, pathY + (n('height') - n('pathY')) * s);
        return CustomPaint(
          size: design,
          painter: SceneArtPainter(
            art: art,
            look: look,
            mode: SceneMode.walking,
            distanceM: distanceM,
            rules: rules,
            onSea: false,
            pass: ScenePass.background,
            elapsed: 0,
            seed: 'daycard',
            layoutSize: layout,
          ),
        );
      },
    );
  }
}

/// 길 위 물감 색 구간 (캔버스 strokesB): 왼쪽 끝에서 [endX](정령 뒷발)까지 걸은 차례로, 거리만큼 나눠
/// 굵기 12 진하게 + 18 옅게 두 번 칠한 붓 선. 그 아래 연필 점선 길 (캔버스 #8c6f4e 1.6, 3·6 점선, 70%).
/// 무늬(T17b): 기본 방울 구간은 붓 선 그대로, 무늬 구간은 지도와 같은 무늬 타일·끝([paintTrailRun], 크기·숫자 규칙은
/// 지도 값 × [k]). 무늬 그림이 없는 구간은 기본 방울 = 붓 선 (config paintPattern.missingArt drawAsDefault).
/// 붓 선과 무늬가 바뀌는 곳도 끝 1개 + 여백 8pt (붓 선의 둥근 끝이 그 끝)
class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.strokes,
    required this.colorOf,
    required this.pathY,
    required this.endX,
    required this.k,
    required this.art,
    required this.trail,
    required this.patterns,
  });

  final List<PaintStroke> strokes;
  final Color Function(String colorId) colorOf;
  final double pathY;
  final double endX;

  /// 설계 188pt에 대한 배율 (선 굵기·물결)
  final double k;

  /// 읽어 둔 무늬 그림
  final TrailArt art;

  /// 무늬 크기·테두리 (config mapTrail.paint)와 숫자 규칙 (mapTrail.patterns)
  final MapTrailRules trail;
  final PaintPatternRules patterns;

  /// 붓 선 굵기 (진한 속·옅은 번짐, 설계 pt)
  static const _core = 12.0;
  static const _wash = 18.0;

  Path _wave(double x0, double x1) {
    final y = pathY;
    return Path()
      ..moveTo(x0, y)
      ..cubicTo(x0 + (x1 - x0) * .33, y - 4 * k, x0 + (x1 - x0) * .66, y + 5 * k, x1, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 연필 점선 길
    final pencil = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * k
      ..color = _wood.withValues(alpha: .7);
    final line = Path()
      ..moveTo(-4, pathY)
      ..cubicTo(size.width * .18, pathY - 8 * k, size.width * .35, pathY + 6 * k, size.width * .53, pathY)
      ..cubicTo(size.width * .7, pathY - 6 * k, size.width * .88, pathY - 6 * k, size.width + 4, pathY);
    for (final m in line.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9 * k) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3 * k, m.length)), pencil);
      }
    }
    final total = strokes.fold(0.0, (s, p) => s + p.meters);
    if (total <= 0) return;
    const start = -6.0;
    final drawn = [for (final p in strokes) art.drawn(p.patternId)];
    if (drawn.any((id) => id != art.defaultId)) {
      _paintPatterns(canvas, drawn, start, total);
      return;
    }
    var x = start;
    for (final p in strokes) {
      final x1 = x + (endX - start) * p.meters / total;
      _brush(canvas, _wave(x, x1), colorOf(p.colorId));
      x = x1;
    }
  }

  void _brush(Canvas canvas, Path path, Color color) {
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _wash * k
          ..color = color.withValues(alpha: .22));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _core * k
          ..color = color.withValues(alpha: .88));
  }

  /// 무늬가 섞인 날: 구간마다 같은 물결을 점으로 펴서 한 줄로 놓고([layoutTrailRun]), 기본 방울 덩어리는 붓 선,
  /// 무늬 덩어리는 무늬 타일·끝
  void _paintPatterns(Canvas canvas, List<String> drawn, double start, double total) {
    final pieces = <TrailPiece>[];
    var x = start;
    for (final (i, p) in strokes.indexed) {
      final x1 = x + (endX - start) * p.meters / total;
      final points = <(double, double)>[];
      for (final m in _wave(x, x1).computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 2) {
          final o = m.getTangentForOffset(d)!.position;
          points.add((o.dx, o.dy));
        }
        final end = m.getTangentForOffset(m.length)!.position;
        points.add((end.dx, end.dy));
      }
      pieces.add(TrailPiece(points, colorId: p.colorId, patternId: drawn[i]));
      x = x1;
    }
    final layout = layoutTrailRun(pieces, trailLayoutRules(trail, patterns), k: k);
    // 붓 선 덩어리: 무늬와 맞닿는 쪽은 둥근 끝(굵기 반)까지 넣어 앞 무늬 끝 + 여백 8pt를 지킨다
    final ends = layout.pieceEnds;
    final half = _core / 2 * k;
    for (final (gi, g) in layout.groups.indexed) {
      if (g.patternId != art.defaultId) continue;
      final from = g.afterSwitch ? g.from + patterns.switchGapPt * k + half : g.from;
      final to = gi < layout.groups.length - 1 ? g.to - half : g.to;
      for (var i = 0; i < ends.length; i++) {
        final a = math.max(i == 0 ? 0.0 : ends[i - 1], from);
        final b = math.min(ends[i], to);
        if (b > a) _brush(canvas, _slice(layout.line, a, b), colorOf(pieces[i].colorId));
      }
    }
    // 엽서는 낮 장면만 물감 구간이 있다 (쉬어 간 날 밤 장면은 구간 없음) → 낮 테두리
    paintTrailRun(canvas, layout, art, trailPaintStyle(trail, patterns, k: k, night: false), colorOf,
        skip: {art.defaultId});
  }

  /// 줄 [line]의 [a]~[b](px) 부분
  static Path _slice(TrailPolyline line, double a, double b) {
    final first = line.at(a);
    final out = Path()..moveTo(first.x, first.y);
    for (var d = a + 2; d < b; d += 2) {
      final p = line.at(d);
      out.lineTo(p.x, p.y);
    }
    final last = line.at(b);
    return out..lineTo(last.x, last.y);
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.strokes != strokes ||
      old.pathY != pathY ||
      old.endX != endX ||
      old.k != k ||
      !identical(old.art, art) ||
      !identical(old.trail, trail) ||
      !identical(old.patterns, patterns);
}

/// 엽서 정령: 발 [foot]·키 [figureHeight] (600 캔버스의 머리 위 y150~발바닥 y440 잣대, 걷는 중과 같은 놓기).
/// 걸은 날은 [speed] 1로 걷는다 (캔버스 D안도 걷는 정령이 통통 움직인다). config ‘옆면 걷기 첫 장면’은 공유 이미지가
/// 뜨는 한 장면으로 읽었다: v11 워터마크 판은 만든 뒤 처음 몇 초 첫 모습에 머물러 그 자리에서 멈추면 그 모습에 갇힐 수 있어
/// (docs/트랙/정령v11_T17a.md) 카드에서는 멈추지 않는다
class _CardSpirit extends StatelessWidget {
  const _CardSpirit({
    required this.look,
    required this.foot,
    required this.figureHeight,
    required this.pose,
    this.speed = 0,
    this.mirrored = false,
    this.expression = 0,
    this.renderer,
    this.onReady,
  });

  final SpiritLook look;
  final Offset foot;
  final double figureHeight;
  final int pose;
  final double speed;
  final bool mirrored;
  final int expression;
  final rive.Factory? renderer;
  final VoidCallback? onReady;

  @override
  Widget build(BuildContext context) {
    final k = figureHeight / (440 - 150);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: foot.dx - 300 * k,
          top: foot.dy - 440 * k,
          width: 600 * k,
          height: 600 * k,
          child: IgnorePointer(
            child: SpiritCharacter(
              key: const ValueKey('day-card-spirit'),
              look: look,
              speed: speed,
              pose: pose,
              mirrored: mirrored,
              expression: expression,
              riveFactory: renderer,
              onReady: onReady == null ? null : (_) => onReady!(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 날짜 소인 (캔버스: 지름 58 점선 동그라미 1.6, −8°, 반투명 바탕, 날짜 14 굵게 + 아래 11 옅게).
/// 여러 날은 글이 길어 옆으로 늘어난 알약
class _Postmark extends StatelessWidget {
  const _Postmark({required this.day, required this.sub, this.size = 58});

  final String day;
  final String sub;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '소인 $day $sub',
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: -8 * math.pi / 180,
          child: MediaQuery.withNoTextScaling(
            child: CustomPaint(
              painter: const _DashedStadiumPainter(),
              child: Container(
                key: const ValueKey('day-card-postmark'),
                constraints: BoxConstraints(minWidth: size, minHeight: size, maxHeight: size),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(day,
                        style: TextStyle(
                          fontSize: size * 14 / 58,
                          height: 17 / 14,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                    Text(sub,
                        style: TextStyle(fontSize: size * 11 / 58, height: 13 / 11, color: Palette.subInk)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedStadiumPainter extends CustomPainter {
  const _DashedStadiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect.deflate(.8), Radius.circular(size.height / 2));
    canvas.drawRRect(rrect, Paint()..color = _postmarkFill);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _postmarkLine;
    for (final m in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedStadiumPainter old) => false;
}

/// 공유 엽서 (캔버스 2-4, 360×450 = 4:5): 바탕 위 엽서(장면 + 소인, 문장 한 줄, 칩 3) + 아래 발자국 ‘DOOBAL’.
/// 버튼 없음. 정령은 Flutter 그리기로 (이미지에 담기게)
class DayCardShareImage extends ConsumerWidget {
  const DayCardShareImage({
    super.key,
    required this.card,
    required this.now,
    required this.painting,
    required this.spirit,
    this.onSpiritReady,
    this.onSceneReady,
  });

  final DayCard card;
  final DateTime now;
  final Landmark? painting;
  final SpiritLook spirit;
  final VoidCallback? onSpiritReady;
  final VoidCallback? onSceneReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider).value;
    if (rules == null) return const ColoredBox(color: _shareBackground);
    final r = rules.report.card;
    final line = dayCardSentence(card, r.sentences, yesterday: isYesterdayCard(card, now));
    final chips = dayCardChips(card, r);
    return MediaQuery(
      // 공유 이미지는 늘 같은 모양으로 (기기 글자 크기와 상관없이)
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Semantics(
        image: true,
        label: '공유 이미지',
        child: ColoredBox(
          color: _shareBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: Column(
              children: [
                SizedBox(
                  width: _shareScene.width,
                  child: _PostcardFrame(
                    radius: 20,
                    lift: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: const BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: Palette.ink, width: InkLine.panel)),
                          ),
                          child: SizedBox(
                            height: _shareScene.height,
                            child: PostcardScene(
                              card: card,
                              rules: rules,
                              painting: painting,
                              spirit: spirit,
                              design: Size(_shareScene.width - 2 * InkLine.panel, _shareScene.height),
                              postmarkSize: 56,
                              renderer: rive.Factory.flutter,
                              onSpiritReady: onSpiritReady,
                              onSceneReady: onSceneReady,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                line,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 24 / 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                  color: Palette.ink,
                                ),
                              ),
                              if (chips.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _Chips(chips,
                                    fontSize: 12,
                                    pad: const EdgeInsets.symmetric(horizontal: 9, vertical: 4)),
                              ],
                            ],
                          ),
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
