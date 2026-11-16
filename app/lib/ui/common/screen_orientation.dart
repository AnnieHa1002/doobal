import 'package:flutter/services.dart';

import '../../domain/screen_rules.dart';

/// 세로 고정 (config ui.orientation.others portrait)
const portraitOnly = [DeviceOrientation.portraitUp];

/// [screen] 화면에서 돌릴 수 있는 방향: config ui.orientation.landscape에 있으면 세로·가로, 아니면 세로만
/// (16장 11/13: 가로 화면은 걷는 중만)
List<DeviceOrientation> orientationsFor(ScreenRules rules, String screen) =>
    rules.landscapeScreens.contains(screen)
        ? const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
        : portraitOnly;

/// [screen] 화면의 방향으로 잠근다 (iOS Info.plist·안드로이드는 모든 방향을 열어 두고 앱이 잠근다)
Future<void> lockOrientation(ScreenRules rules, String screen) =>
    SystemChrome.setPreferredOrientations(orientationsFor(rules, screen));
