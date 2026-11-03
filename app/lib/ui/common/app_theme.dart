import 'package:flutter/material.dart';

import '../../domain/display_font.dart';
import 'app_text.dart';
import 'palette.dart';

/// 앱 테마: 종이 바탕, 본문 고운 돋움, 고른 표시 글꼴([DisplayType])
ThemeData doobalTheme(DisplayFont font) => ThemeData(
      fontFamily: bodyFont,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Palette.terracotta,
        primary: Palette.terracotta,
        surface: Palette.paper,
        onSurface: Palette.ink,
      ),
      scaffoldBackgroundColor: Palette.paper,
      extensions: [DisplayType(font)],
    );
