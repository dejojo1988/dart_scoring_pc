import 'package:flutter_test/flutter_test.dart';
import 'package:dart_scoring_pc/app.dart';

void main() {
  testWidgets('Dart Scoring App startet ohne Crash', (WidgetTester tester) async {
    await tester.pumpWidget(const DartScoringApp());

    expect(find.text('Dart Scoring PC'), findsOneWidget);
  });
}