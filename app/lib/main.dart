import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/auto_sync.dart';
import 'app/licenses.dart';
import 'app/server_link.dart';
import 'app/server_providers.dart';
import 'data/firebase_backend.dart';
import 'ui/common/app_theme.dart';
import 'ui/common/screen_orientation.dart';
import 'ui/scene/spirit_character.dart';
import 'ui/start/start_gate.dart';
import 'ui/walking/paint_trail_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 고정, 걷는 중만 가로 (16장 11/13, 걷는 중 화면이 열 때 풀고 닫을 때 다시 잠근다)
  await SystemChrome.setPreferredOrientations(portraitOnly);
  registerFontLicenses();
  // 정령 riv(11.8MB)는 여기서 한 번 읽기 시작해 앱이 끝날 때까지 모든 정령이 같이 쓴다 (정령 계약 7장, 기다리지 않음)
  SpiritCharacter.preload();
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
