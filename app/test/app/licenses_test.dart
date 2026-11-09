import 'dart:io';

import 'package:doobal/app/licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('글꼴 라이선스: Pretendard가 저작권 줄과 OFL 1.1 전문으로 등록된다', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    expect(fontLicenses.keys, ['Pretendard']);
    for (final name in fontLicenses.keys) {
      final e = entries.singleWhere((e) => e.packages.contains(name));
      final text = e.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('Kil Hyung-jin'));
      expect(text, contains('SIL Open Font License, Version 1.1'));
      // 고지 한 줄이 아니라 전문 (머리말·조건·끝 면책까지)
      expect(text, contains('PREAMBLE'));
      expect(text, contains('CONDITIONS'));
      expect(text, contains('OTHER DEALINGS IN THE FONT SOFTWARE.'));
    }
  });

  test('pubspec에 적은 글꼴 파일이 모두 있다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final assets = RegExp(r'asset: (assets/fonts/\S+\.ttf)').allMatches(pubspec).map((m) => m[1]!);
    // Pretendard Regular·SemiBold·Bold
    expect(assets, hasLength(3));
    for (final path in assets) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
