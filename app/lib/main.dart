import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/debug/debug_screen.dart';

void main() {
  runApp(const ProviderScope(child: DoobalApp()));
}

// 색은 기준 문서 9장. 글꼴(Gowun Batang·Dodum)은 화면을 만들 때 넣는다
const _paper = Color(0xFFF2E8D5);
const _ink = Color(0xFF3E2C22);
const _terracotta = Color(0xFFA4502F);

class DoobalApp extends StatelessWidget {
  const DoobalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '두발',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _terracotta,
          primary: _terracotta,
          surface: _paper,
          onSurface: _ink,
        ),
        scaffoldBackgroundColor: _paper,
      ),
      // M2에서 쉼터로 바꾼다
      home: const DebugScreen(),
    );
  }
}
