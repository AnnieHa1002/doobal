import 'package:flutter/material.dart';

import 'app_text.dart';
import 'screen_header.dart';

/// 뒤로 버튼 + 제목 + 가운데 안내 한 줄만 있는 화면 (아직 내용이 없는 화면)
class NoticePage extends StatelessWidget {
  const NoticePage({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(title),
            Expanded(child: Center(child: Text(message, style: AppText.bodySub))),
          ],
        ),
      ),
    );
  }
}
