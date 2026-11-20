import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/palette.dart';
import '../scene/scene_view.dart';

/// 걷기 탭 길가 방명록 표지판 크기 (캔버스 3-1: 80×104pt, 판에 ‘방명록’ 14pt)
const _signW = 80.0;
const _signH = 104.0;
const _boardH = 40.0;
const _postW = 8.0;

/// 표지판과 화면 오른쪽 끝 사이 최소 여백
const _edge = 4.0;

/// 판 색 (캔버스 --sign·--wood)
const _board = Color(0xFFE9D3A8);
const _wood = Color(0xFF8A6A4A);

/// 방명록을 쓸 수 있을 때 걷기 탭 길가에 서는 표지판 (16장 11/18·11/19, config guestbook.sign, 캔버스 3-1).
/// 장면과 같이 흐르지 않고 화면에 고정돼 정령 오른쪽 길가에 선다: 왼쪽 끝 = 화면 폭 × [screenX]
/// (좁은 폰에서는 화면 안 4pt까지만, 11/20 폰 360pt), 기둥 발 = 정령 발과 같은 길 높이.
/// 걷는 중·쉬는 중 모두, 누르면 방명록 쓰기
class GuestbookRoadSign extends StatelessWidget {
  const GuestbookRoadSign({super.key, required this.spot, required this.screenX, required this.onTap});

  final SceneCompanionSpot spot;
  final double screenX;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = math.min(spot.size.width * screenX, math.max(0.0, spot.size.width - _signW - _edge));
    final foot = spot.spiritFoot.dy;
    return Stack(
      children: [
        Positioned(
          left: left,
          top: foot - _signH,
          width: _signW,
          height: _signH,
          child: Semantics(
            button: true,
            label: '길가 표지판: 방명록 남기기',
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('road-signpost'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const CustomPaint(painter: _SignPainter(), child: _SignLabel()),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignLabel extends StatelessWidget {
  const _SignLabel();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: _boardH,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              '방명록',
              maxLines: 1,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Palette.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// 나무 기둥과 오른쪽이 뾰족한 판 (잉크 1.8 선)
class _SignPainter extends CustomPainter {
  const _SignPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = InkLine.panel
      ..strokeJoin = StrokeJoin.round
      ..color = Palette.ink;
    final post = Rect.fromLTWH(size.width / 2 - _postW / 2, _boardH - 4, _postW, size.height - _boardH + 4);
    canvas
      ..drawRect(post, Paint()..color = _wood)
      ..drawRect(post, ink);
    final board = Path()
      ..moveTo(2, 4)
      ..lineTo(size.width - 14, 4)
      ..lineTo(size.width - 2, _boardH / 2 + 2)
      ..lineTo(size.width - 14, _boardH)
      ..lineTo(2, _boardH)
      ..close();
    canvas
      ..drawPath(board, Paint()..color = _board)
      ..drawPath(board, ink);
  }

  @override
  bool shouldRepaint(_SignPainter old) => false;
}
