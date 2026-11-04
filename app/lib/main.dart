import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/auto_sync.dart';
import 'app/licenses.dart';
import 'ui/common/app_theme.dart';
import 'ui/start/start_gate.dart';

void main() {
  registerFontLicenses();
  runApp(const ProviderScope(child: DoobalApp()));
}

/// 앱
class DoobalApp extends StatelessWidget {
  const DoobalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '두발',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: doobalTheme(),
      home: const StartGate(),
    );
  }
}
