import 'package:flutter/material.dart';

import '../common/palette.dart';

/// 입력 칸 모서리와 카드 모서리 (UI 명세 공통: 큰 버튼과 같은 12pt)
const startRadius = 12.0;

/// 시작 ②③의 틀: 위는 장면 자리, 아래는 카드. 키보드가 올라와 좁아지면 장면이 줄고,
/// 카드는 화면보다 길어지면 스크롤한다
class StartLayout extends StatelessWidget {
  const StartLayout({super.key, required this.top, required this.children});

  /// 위쪽 장면 자리. 남는 높이를 다 받는다 (0까지 줄어들 수 있다)
  final Widget top;

  /// 카드 안 내용 (세로로 쌓고 가로는 꽉 채운다)
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) => Column(
          children: [
            Expanded(child: SafeArea(bottom: false, child: top)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: StartCard(children: children),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 잉크 테두리 카드 바탕 (카드색)
BoxDecoration startCardDecoration() => BoxDecoration(
      color: Palette.card,
      borderRadius: BorderRadius.circular(startRadius),
      border: Border.all(color: Palette.ink, width: 2.5),
    );

/// 잉크 테두리 카드. 내용이 길면 안에서 스크롤한다
class StartCard extends StatelessWidget {
  const StartCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: startCardDecoration(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

/// 카드 안 작은 제목 (머리 모양·머리색처럼)
class StartLabel extends StatelessWidget {
  const StartLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink),
    );
  }
}

/// 카드 안 안내 한 줄 (보조 잉크색)
class StartNote extends StatelessWidget {
  const StartNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: Palette.subInk));
  }
}

/// 잉크 테두리 입력 칸 모양 (카드 위에서 종이색 바탕)
InputDecoration startInputDecoration({required String hint, Widget? prefix}) {
  OutlineInputBorder border(double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(startRadius),
        borderSide: BorderSide(color: Palette.ink, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Palette.subInk),
    prefixIcon: prefix,
    counterText: '',
    filled: true,
    fillColor: Palette.paper,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(2.5),
    enabledBorder: border(2.5),
    focusedBorder: border(3.5),
  );
}
