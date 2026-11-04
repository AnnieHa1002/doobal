import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/sync_service.dart';
import '../../domain/diary.dart';
import '../../domain/sketch.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/format.dart';
import '../common/framed_painting.dart';
import '../common/palette.dart';

/// 일기가 비었을 때(아직 아무 그림도 받지 않았을 때)의 한 줄. 가안
const diaryEmptyLine = '첫 그림을 받으면 여기에 붙어요';

/// 마스킹테이프 그림 3종 (256×64)
const _tapes = [
  'assets/ui/ui_tape_01_v01_clean.png',
  'assets/ui/ui_tape_02_v01_clean.png',
  'assets/ui/ui_tape_03_v01_clean.png',
];

/// 줄 없는 메모지 (600×600, 가장자리 60px은 늘리지 않는다). 1/3 크기로 그려 모서리가 20pt
const _notePaper = 'assets/ui/ui_note_paper_plain_9s60_v01_clean.png';

/// 사진 폭 (명세 200pt). 좁은 화면에서는 줄 폭의 55%까지만
const _photoWidth = 200.0;
const _photoShare = 0.55;

/// 화집 그림 탭의 일기 (UI 명세 10장, 16장 11/2): 얻은 그림을 최신순으로 붙인 여행 일기장.
/// 달이 바뀌면 머리줄, 항목 하나 = 사진 + 메모, 사진과 메모는 항목마다 좌우를 번갈아 둔다.
/// 재방문도 그날 새 항목이다. 항목을 누르면 [onOpen](그림 상세, 명소 id)
List<Widget> diarySlivers(
  BuildContext context,
  List<DiaryEntry> entries, {
  required ValueChanged<String> onOpen,
}) {
  if (entries.isEmpty) {
    return const [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Text(
            diaryEmptyLine,
            key: ValueKey('diary-empty'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Palette.subInk),
          ),
        ),
      ),
    ];
  }
  final children = <Widget>[];
  String? month;
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final m = diaryMonthLabel(e.arrivedAt);
    if (m != month) {
      month = m;
      children.add(_MonthHeader(m, key: ValueKey('diary-month-$m')));
    }
    children.add(DiaryItem(
      key: ValueKey('diary-${e.journeyId}'),
      entry: e,
      photoLeft: i.isEven,
      onTap: () => onOpen(e.dest.id),
    ));
  }
  return [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    ),
  ];
}

/// 달 머리줄: 표시 글꼴 18 + 아래 잉크 점선
class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.display(18)),
          const SizedBox(height: 4),
          const SizedBox(
            height: InkLine.pill,
            width: double.infinity,
            child: CustomPaint(painter: _DottedLinePainter()),
          ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  const _DottedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.ink
      ..strokeWidth = size.height;
    const dash = 3.0;
    const gap = 3.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      final y = size.height / 2;
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) => false;
}

/// 일기 항목 하나: 사진(액자 등급색 테두리, 위에 마스킹테이프, 살짝 기울임) + 메모
class DiaryItem extends StatelessWidget {
  const DiaryItem({
    super.key,
    required this.entry,
    required this.photoLeft,
    required this.onTap,
  });

  final DiaryEntry entry;

  /// 사진을 왼쪽에 두는가 (아니면 오른쪽)
  final bool photoLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = diaryLookOf(entry.journeyId);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: LayoutBuilder(builder: (context, box) {
            final photoW = math.min(_photoWidth, box.maxWidth * _photoShare);
            final photo = SizedBox(width: photoW, child: _Photo(entry: entry, look: look));
            final memo = Expanded(child: _Memo(entry: entry));
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: photoLeft
                  ? [photo, const SizedBox(width: 12), memo]
                  : [memo, const SizedBox(width: 12), photo],
            );
          }),
        ),
      ),
    );
  }
}

/// 사진: 4:3 그림 + 받은 액자 등급색 6pt 테두리, 위 모서리에 테이프 1~2장 (−6~6°), 사진도 −2~2°
class _Photo extends StatelessWidget {
  const _Photo({required this.entry, required this.look});

  final DiaryEntry entry;
  final DiaryLook look;

  @override
  Widget build(BuildContext context) {
    final tapeAsset = _tapes[look.tapeColor];
    Widget tape(double turnDeg) => Transform.rotate(
          angle: turnDeg * math.pi / 180,
          child: Image.asset(
            tapeAsset,
            width: 56,
            height: 14,
            fit: BoxFit.fill,
            cacheWidth: 256,
            errorBuilder: (context, error, stack) => const SizedBox(width: 56, height: 14),
          ),
        );
    return Padding(
      // 테이프가 사진 위로 삐져나오는 자리
      padding: const EdgeInsets.only(top: 8),
      child: Transform.rotate(
        angle: look.photoTurnDeg * math.pi / 180,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: entry.isFirstPack
                    ? const FramedPainting.firstPack()
                    : FramedPainting(landmark: entry.dest, frame: entry.newFrame),
              ),
              if (look.twoTapes) ...[
                Positioned(left: -6, top: -8, child: tape(look.tapeTurnDeg - 20)),
                Positioned(right: -6, top: -8, child: tape(20 - look.tapeTurnDeg)),
              ] else
                Positioned(
                  left: 0,
                  right: 0,
                  top: -8,
                  child: Center(child: tape(look.tapeTurnDeg)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 메모 (줄 없는 메모지 그림): 날짜(요일) / 명소 이름 / n번째 방문 /
/// 이번 여정 km · 그날 걸음 / 액자 (재방문으로 올랐으면 ‘나무 → 은’). 첫 그림은 제목과 받기까지의 한 줄
class _Memo extends StatelessWidget {
  const _Memo({required this.entry});

  final DiaryEntry entry;

  static const _line = TextStyle(fontSize: 13, height: 1.4, color: Palette.ink);
  static const _sub = TextStyle(fontSize: 13, height: 1.4, color: Palette.subInk);

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final lines = e.isFirstPack
        ? [
            Text('$firstPackLabel · $firstPackName', style: context.display(15)),
            const SizedBox(height: 2),
            Text(firstPackLine(e), style: _line),
          ]
        : [
            Text(diaryDateLabel(e.arrivedAt), style: _sub),
            Text(e.dest.name, style: context.display(15)),
            Text('${e.visitNo}번째 방문', style: _line),
            Text(
              '이번 여정 ${formatKmShort(e.journeyKm * 1000)} · 그날 ${formatInt(e.daySteps)}보',
              style: _line,
            ),
            Text(
              e.frameUp
                  ? '${frameName(e.prevFrame!)} → ${frameName(e.newFrame)}'
                  : frameLabel(e.newFrame),
              style: _sub,
            ),
          ];
    return Container(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_notePaper),
          centerSlice: Rect.fromLTRB(60, 60, 540, 540),
          scale: 3,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
    );
  }
}

/// 첫 그림 메모 한 줄: `4월 1일 · 서울 종로구에서 0.6km · 860보 · 14분 걸려 받았어요`
/// (출발 동네를 모르면 그 말을, 걸음 분이 없으면 걸음을 뺀다)
String firstPackLine(DiaryEntry e) => [
      formatMonthDay(kstDate(e.arrivedAt)),
      '${e.fromName == null ? '' : '${e.fromName}에서 '}${formatKmShort(e.journeyKm * 1000)}',
      if (e.walkSteps > 0) '${formatInt(e.walkSteps)}보',
      '${walkedForLabel(e.arrivedAt.difference(e.startedAt))} 걸려 받았어요',
    ].join(' · ');
