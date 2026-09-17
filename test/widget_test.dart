import 'package:flutter_test/flutter_test.dart';
import 'package:ai_companion/main.dart';

void main() {
  testWidgets('AI Companion home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AICompanionApp());

    expect(find.text('AI Companion'), findsOneWidget);
    expect(find.text('Hello! 👋'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.text('Chat with AI'), findsOneWidget);
    expect(find.text('My Documents'), findsOneWidget);
    expect(find.text('Voice Assistant'), findsOneWidget);
  });
}
