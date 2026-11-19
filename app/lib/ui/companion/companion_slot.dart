import 'package:flutter/material.dart';

import 'companion_screen.dart';

/// 동행 화면으로 (걷기 탭의 동행을 누르면, 16장 11/18·캔버스 7-1 메모 ‘들어옴 = 걷기 탭의 동행’). 지금 탭 안에서 열린다
void openCompanions(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CompanionScreen()));
