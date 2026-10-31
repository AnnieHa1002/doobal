import 'dart:io';

import 'package:doobal/app/licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('글꼴 라이선스: 두 글꼴이 OFL 고지와 함께 등록된다', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    for (final name in fontLicenses.keys) {
      final e = entries.singleWhere((e) => e.packages.contains(name));
      final text = e.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('Copyright 2021'));
      expect(text, contains('SIL Open Font License, Version 1.1'));
    }
  });

  test('pubspec에 적은 글꼴 파일이 모두 있다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)').allMatches(pubspec).map((m) => m[1]!);
    expect(assets, hasLength(3));
    for (final path in assets) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
