import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:doobal/ui/scene/spirit_character.dart';
import 'package:rive/rive.dart' as rive;
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
 TestWidgetsFlutterBinding.ensureInitialized();
 await rive.RiveNative.init();
 SpiritCharacter.renderer=rive.Factory.flutter;
 await testMain();
}
