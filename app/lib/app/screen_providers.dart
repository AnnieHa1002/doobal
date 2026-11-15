import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 화면 세부(T11)·쉼터 정령 자세(T5)가 쓰는 무작위. 시험은 고정 값으로 바꿔 끼운다

/// [count]개 중 하나(0부터)를 고른다
typedef PickOne = int Function(int count);

/// 정령 만들기에서 처음 골라져 있는 여행복 시작 색(props cloth_02.startColors 4색 중 무작위, 16장 11/15 A안)
final startClothPickProvider = Provider<PickOne>((ref) {
  final random = Random();
  return random.nextInt;
});

/// 쉼터 정령 자세 바꾸기(config character.rive.restSwap)의 무작위: 다음 자세·간격
final restSwapRandomProvider = Provider<Random>((ref) => Random());
