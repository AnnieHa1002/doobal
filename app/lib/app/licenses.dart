import 'package:flutter/foundation.dart';

/// 앱에 넣은 글꼴의 저작권·라이선스 고지 (각 글꼴 파일 name 표의 문구 그대로).
/// 설정 → 오픈소스 라이선스(showLicensePage)에 패키지 라이선스와 함께 나온다.
/// TODO: OFL 1.1 전문(OFL.txt)도 함께 넣는다
const fontLicenses = {
  'Gaegu': 'Copyright 2018 The Gaegu Project Authors',
  'Dongle': 'Copyright 2021 The Dongle Project Authors (https://github.com/yangheeryu/Dongle)',
  'Gowun Batang': 'Copyright 2021 The Gowun Batang Project Authors '
      '(https://github.com/yangheeryu/Gowun-Batang)',
  'Gowun Dodum': 'Copyright 2021 The Gowun Dodum Project Authors '
      '(https://github.com/yangheeryu/Gowun-Dodum)',
};

const _ofl = 'This Font Software is licensed under the SIL Open Font License, Version 1.1. '
    'This license is available with a FAQ at: https://scripts.sil.org/OFL';

/// 금칙어 정규식의 출처 고지 (moderation.json 규칙 L01~L62). 패키지는 쓰지 않고 정규식만 데이터로
/// 옮겼다 (M2~M6 명세 v0.10)
const _profanityFilterLicense = r'''MIT License

Copyright (c) 2023 XimYa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

/// main에서 한 번 부른다
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['korean_profanity_filter'], _profanityFilterLicense);
    for (final MapEntry(key: name, value: copyright) in fontLicenses.entries) {
      yield LicenseEntryWithLineBreaks([name], '$copyright\n\n$_ofl');
    }
  });
}
