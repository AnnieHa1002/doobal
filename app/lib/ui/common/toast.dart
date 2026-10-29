import 'package:flutter/material.dart';

/// 토스트가 떠 있는 시간 (UI 명세 2.5초)
const toastDuration = Duration(milliseconds: 2500);

/// 아래 큰 버튼을 가리지 않게 띄운다. 위쪽 카드 토스트는 나중에 바꾼다
void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: toastDuration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ));
}
