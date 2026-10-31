import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/guestbook.dart';
import '../../domain/journey.dart' show Frame;
import '../../domain/sketch.dart';
import '../../domain/time_kst.dart';
import '../album/album_screen.dart';
import '../common/app_text.dart' show badgeMaxTextScale;
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/frame_style.dart';
import '../common/framed_painting.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../guestbook/guestbook_write_screen.dart';
import '../map/map_screen.dart';

/// 그림이 번지는 시간, 그다음 액자가 나타나는 시간
const _paintingDuration = Duration(milliseconds: 1500);
const _frameDuration = Duration(milliseconds: 400);

/// 번지기 시작할 때의 흐림 정도 (blur sigma)
const _maxBlur = 14.0;
const _frameThickness = 12.0;

/// 도착: 그림이 종이에 먹이 번지듯 나타나고, 이어서 액자와 이름이 붙고, 방문·거리·날짜·걸음 카드가 나온다.
/// 내 동네 스케치는 '첫 그림'(첫 여행 짐 꾸러미)이 나무 액자에 낀 채로 번지고(액자 단계·등급 라벨 없음),
/// 카드에는 제목·이름·거리·날짜·걸음만 나온다.
/// 버튼은 주 "방명록 쓰기"(이 도착의 기회가 열려 있을 때만 켜진다)와 보조 "화집에 걸기"·"다음 목적지".
/// 닫은 뒤 본 것으로 적는 건 AutoSync가 한다
class ArrivalScreen extends ConsumerWidget {
  const ArrivalScreen({super.key, required this.journeyId});

  final String journeyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(arrivalViewProvider(journeyId));
    final data = view.value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CornerButton(
                  icon: Icons.arrow_back,
                  label: '뒤로',
                  size: 44,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: data != null
                    ? _ArrivalBody(key: ValueKey(data.journeyId), view: data)
                    : view.hasError
                        ? const Center(child: Text('도착 정보를 불러오지 못했어요'))
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrivalBody extends ConsumerStatefulWidget {
  const _ArrivalBody({super.key, required this.view});

  final ArrivalView view;

  @override
  ConsumerState<_ArrivalBody> createState() => _ArrivalBodyState();
}

class _ArrivalBodyState extends ConsumerState<_ArrivalBody> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _painting;
  late final Animation<double> _frame;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final total = _paintingDuration + _frameDuration;
    final split = _paintingDuration.inMilliseconds / total.inMilliseconds;
    _controller = AnimationController(vsync: this, duration: total)..forward();
    _painting =
        CurvedAnimation(parent: _controller, curve: Interval(0, split, curve: Curves.easeOut));
    _frame = CurvedAnimation(parent: _controller, curve: Interval(split, 1, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 벽의 첫 빈 칸에 걸고 화집을 연다. 벽이 가득 차 있으면 바꿀 칸을 고르는 모드로 연다
  Future<void> _hang() async {
    if (_busy) return;
    _busy = true;
    try {
      final id = widget.view.dest.id;
      final svc = await ref.read(syncServiceProvider.future);
      final slot = await svc.hangOnWall(id);
      if (!mounted) return;
      ref.invalidate(wallProvider);
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AlbumScreen(hangLandmarkId: slot == null ? id : null),
      ));
    } on StateError catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      _busy = false;
    }
  }

  /// 이 도착의 방명록 기회로 쓰기 화면을 연다
  void _write(GuestbookTicket ticket) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GuestbookWriteScreen(ticketId: ticket.id)));

  void _next() => Navigator.of(context)
      .pushReplacement(MaterialPageRoute<void>(builder: (_) => const MapScreen()));

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
        GameButton(label: '화집에 걸기', kind: GameButtonKind.secondary, onPressed: _hang),
        const SizedBox(height: 8),
        GameButton(label: '다음 목적지', kind: GameButtonKind.secondary, onPressed: _next),
      ],
    );
  }

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
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
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
                    ],
                  ),
                ),
              ),
            ),
            if (!firstPack) ...[
              const SizedBox(height: 8),
              Opacity(
                key: const ValueKey('arrival-frame-label'),
                opacity: _frame.value,
                child: Text(
                  frameLabel(v.newFrame),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Palette.ink,
                  ),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
          ),
          const SizedBox(height: 4),
          // 명소는 몇 번째 방문, 첫 그림은 그림 이름
          Text(
            firstPack ? firstPackName : '${v.visitNo}번째 방문',
            style: body.copyWith(fontWeight: FontWeight.w600),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: v.frameUp ? Palette.terracotta : Palette.subInk,
              ),
            ),
          ],
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
              border: Border.all(color: Palette.ink, width: 2),
            ),
            child: Text(
              prop.name.substring(0, 1),
              // 40pt 동그라미 안이라 글자 배율 상한을 둔다
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: badgeMaxTextScale),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Palette.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${regionLabels[v.dest.region] ?? v.dest.region} 완성',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Palette.terracotta,
                  ),
                ),
                Text(
                  prop.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Palette.ink,
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
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: child,
    );
  }
}
