import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doobal/main.dart';

void main() {
  testWidgets('앱이 뜬다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DoobalApp()));
    expect(find.text('두발'), findsOneWidget);
  });
}
