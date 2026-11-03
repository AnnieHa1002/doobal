import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/auto_sync.dart';
import 'app/licenses.dart';
import 'app/providers.dart';
import 'domain/display_font.dart';
import 'ui/common/app_theme.dart';
import 'ui/start/start_gate.dart';

void main() {
  registerFontLicenses();
  runApp(const ProviderScope(child: DoobalApp()));
}

/// 앱. 설정에서 고른 표시 글꼴을 테마(DisplayType)로 내려보낸다
class DoobalApp extends ConsumerWidget {
  const DoobalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final font = ref.watch(displayFontProvider).value ?? DisplayFont.gaegu;
    return MaterialApp(
      title: '두발',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: doobalTheme(font),
      home: const StartGate(),
    );
  }
}
