import 'dart:io';

import 'package:doobal/app/licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('글꼴 라이선스: 네 글꼴(개구·동글·고운 바탕·고운 돋움)이 저작권·OFL 고지와 함께 등록된다', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    expect(fontLicenses.keys, ['Gaegu', 'Dongle', 'Gowun Batang', 'Gowun Dodum']);
    for (final name in fontLicenses.keys) {
      final e = entries.singleWhere((e) => e.packages.contains(name));
      final text = e.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('Copyright 20'));
      expect(text, contains('The $name Project Authors'));
      expect(text, contains('SIL Open Font License, Version 1.1'));
    }
  });

  test('pubspec에 적은 글꼴 파일이 모두 있다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)').allMatches(pubspec).map((m) => m[1]!);
    // 개구 Bold·동글 Bold·고운 바탕 Regular·Bold·고운 돋움 Regular
    expect(assets, hasLength(5));
    for (final path in assets) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
