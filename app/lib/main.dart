import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/auto_sync.dart';
import 'app/licenses.dart';
import 'app/server_link.dart';
import 'app/server_providers.dart';
import 'data/firebase_backend.dart';
import 'ui/common/app_theme.dart';
import 'ui/start/start_gate.dart';
import 'ui/walking/paint_trail_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  // 서버(Firebase)는 빌드 때 고른다 (firebase_backend.dart의 DOOBAL_SERVER). 끄거나 실패하면 서버 없이 돈다
  final server = await startServer();
  runApp(ProviderScope(
    overrides: [if (server != null) serverBackendProvider.overrideWithValue(server)],
    child: const DoobalApp(),
  ));
}

/// 앱
class DoobalApp extends StatelessWidget {
  const DoobalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '두발',
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorObservers: [topRouteObserver],
      debugShowCheckedModeBanner: false,
      theme: doobalTheme(),
      home: const ServerLink(child: StartGate()),
    );
  }
}
