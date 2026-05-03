import 'package:flutter_test/flutter_test.dart';

import 'package:smart_learning_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartLearningApp());
    expect(find.byType(SmartLearningApp), findsOneWidget);
  });
}
