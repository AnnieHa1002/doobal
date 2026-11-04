import 'package:flutter/material.dart';

import 'app_text.dart';
import 'palette.dart';

/// 앱 테마: 종이 바탕, Pretendard
ThemeData doobalTheme() => ThemeData(
      fontFamily: bodyFont,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Palette.terracotta,
        primary: Palette.terracotta,
        surface: Palette.paper,
        onSurface: Palette.ink,
      ),
      scaffoldBackgroundColor: Palette.paper,
    );
