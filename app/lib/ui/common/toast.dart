import 'package:flutter/material.dart';

/// 토스트가 떠 있는 시간 (UI 명세 2.5초)
const toastDuration = Duration(milliseconds: 2500);

/// 아래 큰 버튼을 가리지 않게 띄운다. 위쪽 카드 토스트는 나중에 바꾼다
void showToast(BuildContext context, String text) =>
    showToastOn(ScaffoldMessenger.of(context), text);

/// 화면 밖(AutoSync)에서는 BuildContext가 없어서 메신저로 띄운다. 떠 있던 토스트는 지운다
void showToastOn(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(_toast(text));
}

/// 떠 있는 토스트를 지우지 않고 그 뒤에 이어서 띄운다 (같은 때 생긴 다른 소식을 덮지 않게)
void queueToastOn(ScaffoldMessengerState messenger, String text) =>
    messenger.showSnackBar(_toast(text));

SnackBar _toast(String text) => SnackBar(
      content: Text(text),
      duration: toastDuration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    );
