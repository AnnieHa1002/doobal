import 'package:flutter/foundation.dart';

/// 앱에 넣은 글꼴의 저작권·라이선스 고지 (각 글꼴 파일 name 표의 문구 그대로).
/// 설정 → 오픈소스 라이선스(showLicensePage)에 패키지 라이선스와 함께 나온다.
/// TODO: OFL 1.1 전문(OFL.txt)도 함께 넣는다
const fontLicenses = {
  'Gowun Batang': 'Copyright 2021 The Gowun Batang Project Authors '
      '(https://github.com/yangheeryu/Gowun-Batang)',
  'Gowun Dodum': 'Copyright 2021 The Gowun Dodum Project Authors '
      '(https://github.com/yangheeryu/Gowun-Dodum)',
};

const _ofl = 'This Font Software is licensed under the SIL Open Font License, Version 1.1. '
    'This license is available with a FAQ at: https://scripts.sil.org/OFL';

/// main에서 한 번 부른다
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: copyright) in fontLicenses.entries) {
      yield LicenseEntryWithLineBreaks([name], '$copyright\n\n$_ofl');
    }
  });
}
