import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/guestbook.dart';
import '../../domain/journey.dart' show Frame;
import '../../domain/screen_rules.dart';
import '../../domain/sketch.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/frame_style.dart';
import '../album/painting_viewer.dart';
import '../common/framed_painting.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../guestbook/guestbook_write_screen.dart';
import '../map/map_screen.dart';
import '../scene/spirit_character.dart';
import '../tabs/home_tab.dart';
import '../walk_record/walk_record_screen.dart';

/// 그림이 번지는 시간, 그다음 액자가 나타나는 시간
/// 도착 카드 맨 아래 AI 표기 (캔버스 3-2 문구 그대로)
const arrivalAiNote = 'AI 그림 · 손 보정';

const _paintingDuration = Duration(milliseconds: 1500);
const _frameDuration = Duration(milliseconds: 400);

/// 번지기 시작할 때의 흐림 정도 (blur sigma)
const _maxBlur = 14.0;
const _frameThickness = 12.0;

/// 액자 오른쪽 아래에 선 작은 정령 자리 (캔버스 3-2 ‘웃는 내 정령’ 56×90, 액자에서 오른쪽 28·아래 18 밖으로)
const _spiritBox = Size(56, 90);
const _spiritOut = Offset(28, 18);

/// 도착: 그림이 종이에 먹이 번지듯 나타나고, 이어서 액자와 이름이 붙고, 방문·거리·날짜·걸음 카드가 나온다.
/// 내 동네 스케치는 '첫 그림'(첫 여행 짐 꾸러미)이 나무 액자에 낀 채로 번지고(액자 단계·등급 라벨 없음),
/// 카드에는 제목·이름·거리·날짜·걸음만 나온다.
/// 버튼은 주 "방명록 쓰기"(이 도착의 기회가 열려 있을 때만 켜진다)와 보조 "다음 목적지".
/// "화집에 걸기"는 없다: 그림은 화집 일기에 저절로 들어간다 (11/4).
/// 닫기 (시스템 뒤로도 같다): 도착을 본 것으로 적고 그 도착으로 끝난 물감 길의 걷기 기록으로 바꾼 뒤,
/// 걷기 기록을 닫으면 쉼터 탭 (config ui.tabs.arrival·walk.arrivalFlow 도착 → 걷기 기록 → 쉼터, 16장 11/18 ⑤).
/// 앱 없이 걸어 도착했으면(물감 길 없음) 바로 쉼터 탭. 화면은 지금 탭 안에서 열린다 (AutoSync, 탭 바가 남는다).
/// 걸어도 탭은 저절로 바뀌지 않는다 (16장 11/18)
class ArrivalScreen extends ConsumerStatefulWidget {
  const ArrivalScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  ConsumerState<ArrivalScreen> createState() => _ArrivalScreenState();
}

class _ArrivalScreenState extends ConsumerState<ArrivalScreen> {
  var _leaving = false;

  /// 도착을 본 것으로 적고 상태를 새로 읽는다 (이 화면이 정리되기 전에 끝낸다)
  Future<void> _markShown() async {
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.markArrivalShown(widget.journeyId);
    } catch (e) {
      debugPrint('도착 화면 확인 기록 실패: $e');
    }
    if (mounted) ref.invalidate(snapshotProvider);
  }

  /// 이 도착으로 끝난 물감 길. 못 읽으면 null (걷기 기록 없이 쉼터로)
  Future<({DateTime start, DateTime end})?> _arrivalTrail() async {
    try {
      final svc = await ref.read(syncServiceProvider.future);
      return await svc.arrivalTrail(widget.journeyId);
    } catch (e) {
      debugPrint('도착 물감 길 읽기 실패: $e');
      return null;
    }
  }

  /// 닫기: 걷기 기록(그 물감 길이 있으면) → 쉼터 탭
  Future<void> _close() async {
    if (_leaving) return;
    _leaving = true;
    final trail = await _arrivalTrail();
    await _markShown();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (trail == null) {
      backToRest(ref, navigator);
      return;
    }
    await navigator.pushReplacement(MaterialPageRoute<void>(
      builder: (_) => WalkRecordScreen(start: trail.start, end: trail.end, closeToRest: true),
    ));
  }

  /// 다음 목적지: 지도로 바꿔 연다 (지도에서 뒤로 가면 이 탭 처음 화면, 출발하기는 쉼터 탭)
  Future<void> _next() async {
    if (_leaving) return;
    _leaving = true;
    await _markShown();
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => const MapScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(arrivalViewProvider(widget.journeyId));
    final data = view.value;
    return PopScope(
      // 시스템 뒤로도 닫기와 같다 (걷기 기록 → 쉼터 탭)
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CornerButton(
                    icon: Icons.close,
                    label: '닫기',
                    size: 44,
                    onPressed: _close,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: data != null
                      ? _ArrivalBody(key: ValueKey(data.journeyId), view: data, onNext: _next)
                      : view.hasError
                          ? const Center(child: Text('도착 정보를 불러오지 못했어요'))
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrivalBody extends ConsumerStatefulWidget {
  const _ArrivalBody({super.key, required this.view, required this.onNext});

  final ArrivalView view;
  final VoidCallback onNext;

  @override
  ConsumerState<_ArrivalBody> createState() => _ArrivalBodyState();
}

class _ArrivalBodyState extends ConsumerState<_ArrivalBody> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _painting;
  late final Animation<double> _frame;

  /// 그림이 다 나타나면 정령이 기뻐한다 (palette paintingGet 행복 + joy, 정령 계약 4장)
  SpiritCue? _cue;

  @override
  void initState() {
    super.initState();
    final total = _paintingDuration + _frameDuration;
    final split = _paintingDuration.inMilliseconds / total.inMilliseconds;
    _controller = AnimationController(vsync: this, duration: total)
      ..addStatusListener(_onAnimation)
      ..forward();
    _painting =
        CurvedAnimation(parent: _controller, curve: Interval(0, split, curve: Curves.easeOut));
    _frame = CurvedAnimation(parent: _controller, curve: Interval(split, 1, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnimation(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final c = ref.read(spiritPaletteProvider).value?.cues.of('paintingGet');
    if (c != null) setState(() => _cue = c.withTrigger('joy'));
  }

  /// 액자 오른쪽 아래 작은 정령 (도착 자세 = config screens.arrival). 누르지 않는다 (그림 누르기는 크게 보기)
  Widget _spirit() {
    final rules = ref.watch(rulesProvider).value;
    return Positioned(
      right: -_spiritOut.dx,
      bottom: -_spiritOut.dy,
      width: _spiritBox.width,
      height: _spiritBox.height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: SpiritStanding(
            key: const ValueKey('arrival-spirit'),
            look: ref.watch(spiritLookProvider),
            // 몸 키가 상자 높이의 약 90% (상자 폭 56의 1.45배)
            share: 1.45,
            footAt: 0.97,
            pose: rules?.screen.spirit.poseOf('arrival'),
            cue: _cue,
            cues: ref.watch(spiritPaletteProvider).value?.cues,
          ),
        ),
      ),
    );
  }

  /// 이 도착의 방명록 기회로 쓰기 화면을 연다
  void _write(GuestbookTicket ticket) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GuestbookWriteScreen(ticketId: ticket.id)));

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    // 이 도착의 기회가 열려 있을 때만 켠다 (이미 썼거나 다음 여정을 시작해 닫혔으면 흐리게)
    final ticket = ref.watch(guestbookTicketProvider(arrivalTicketId(v.journeyId))).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _paintingAndFrame(v),
                const SizedBox(height: 16),
                _infoCard(v),
                if (v.regionProp != null) ...[
                  const SizedBox(height: 12),
                  _propCard(v),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GameButton(label: '방명록 쓰기', onPressed: ticket == null ? null : () => _write(ticket)),
        const SizedBox(height: 8),
        GameButton(
            label: '다음 목적지', kind: GameButtonKind.secondary, onPressed: widget.onNext),
      ],
    );
  }

  /// 그림을 누르면 그림 크게 보기 (16장 11/10, 도착은 한 장만)
  Widget _openBigOnTap(ArrivalView v, Widget painting) => Semantics(
        button: true,
        label: '그림 크게 보기',
        child: GestureDetector(
          key: const ValueKey('arrival-open-big'),
          behavior: HitTestBehavior.opaque,
          onTap: () => openPaintingViewer(context, [
            BigPainting(
              landmark: v.dest,
              frame: v.isFirstPack ? Frame.wood : v.newFrame,
              isFirstPack: v.isFirstPack,
            ),
          ], 0),
          child: painting,
        ),
      );

  /// 그림은 번지며 나타나고(투명 → 불투명, 흐림 → 또렷), 끝나면 액자와 이름이 나타난다
  Widget _paintingAndFrame(ArrivalView v) {
    final firstPack = v.isFirstPack;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final blur = (1 - _painting.value) * _maxBlur;
        Widget face =
            firstPack ? const FirstPackFace() : PaintingFace(landmark: v.dest, label: v.dest.name);
        if (blur > 0.01) {
          face = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal),
            child: face,
          );
        }
        return Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: _openBigOnTap(v, AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(frameInset(_frameThickness)),
                        child: ClipRect(
                          child: Opacity(
                            key: const ValueKey('arrival-painting'),
                            opacity: _painting.value,
                            child: face,
                          ),
                        ),
                      ),
                      if (firstPack)
                        // 첫 그림은 처음부터 나무 액자 (나중에 붙는 액자 단계가 없다)
                        FrameBorder(
                          key: const ValueKey('arrival-first-pack-frame'),
                          color: frameColors[Frame.wood]!,
                          thickness: _frameThickness,
                        )
                      else
                        Opacity(
                          key: const ValueKey('arrival-frame'),
                          opacity: _frame.value,
                          child: FrameBorder(
                            color: frameColors[v.newFrame]!,
                            thickness: _frameThickness,
                          ),
                        ),
                      _spirit(),
                    ],
                  ),
                )),
              ),
            ),
            if (!firstPack) ...[
              const SizedBox(height: 8),
              Opacity(
                key: const ValueKey('arrival-frame-label'),
                opacity: _frame.value,
                child: Text(
                  frameLabel(v.newFrame),
                  style: context.display(16),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _infoCard(ArrivalView v) {
    const body = TextStyle(fontSize: 14, color: Palette.ink);
    // 첫 그림은 액자 등급·몇 번째 방문·재방문 줄이 없다
    final firstPack = v.isFirstPack;
    final revisit =
        firstPack ? null : revisitLine(v.visitNo, v.prevFrame, v.newFrame, v.prevBestKm);
    return _Card(
      key: const ValueKey('arrival-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstPack ? firstPackLabel : v.dest.name,
            style: context.display(18),
          ),
          const SizedBox(height: 4),
          // 명소는 몇 번째 방문, 첫 그림은 그림 이름
          Text(
            firstPack ? firstPackName : '${v.visitNo}번째 방문',
            style: context.display(14),
          ),
          const SizedBox(height: 8),
          Text('이번 여정 ${formatKm(v.journeyKm)}', style: body),
          const SizedBox(height: 2),
          Wrap(
            spacing: 12,
            children: [
              Text(formatMonthDay(kstDate(v.arrivedAt)), style: body),
              Text('그날 걸음 ${formatInt(v.daySteps)}보', style: body),
            ],
          ),
          if (revisit != null) ...[
            const SizedBox(height: 8),
            Text(
              revisit,
              key: const ValueKey('arrival-revisit'),
              style: context.display(14, color: v.frameUp ? Palette.terracotta : Palette.subInk),
            ),
          ],
          // 그림이 AI로 그린 뒤 손으로 고친 것임을 알린다 (캔버스 3-2 카드 맨 아래, 11pt 보조 잉크)
          const SizedBox(height: 8),
          Text(
            arrivalAiNote,
            key: const ValueKey('arrival-ai-note'),
            style: const TextStyle(fontSize: 11, color: Palette.subInk),
          ),
        ],
      ),
    );
  }

  /// 권역을 채워서 받은 소품 카드
  Widget _propCard(ArrivalView v) {
    final prop = v.regionProp!;
    return _Card(
      key: const ValueKey('arrival-prop'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.paper,
              shape: BoxShape.circle,
              border: Border.all(color: Palette.ink, width: InkLine.panel),
            ),
            child: Text(
              prop.name.substring(0, 1),
              // 40pt 동그라미 안이라 글자 배율 상한을 둔다
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: badgeMaxTextScale),
              style: context.display(18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${regionLabels[v.dest.region] ?? v.dest.region} 완성',
                  style: context.display(14, color: Palette.terracotta),
                ),
                Text(
                  prop.name,
                  style: context.display(16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      child: child,
    );
  }
}
