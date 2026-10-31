import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/auto_sync.dart';
import 'app/licenses.dart';
import 'ui/common/app_text.dart';
import 'ui/common/palette.dart';
import 'ui/start/start_gate.dart';

void main() {
  registerFontLicenses();
  runApp(const ProviderScope(child: DoobalApp()));
}

class DoobalApp extends StatelessWidget {
  const DoobalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '두발',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: bodyFont,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.terracotta,
          primary: Palette.terracotta,
          surface: Palette.paper,
          onSurface: Palette.ink,
        ),
        scaffoldBackgroundColor: Palette.paper,
      ),
      home: const StartGate(),
    );
  }
}
