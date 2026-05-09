import 'package:flutter_test/flutter_test.dart';

import 'package:quran_player/main.dart';

void main() {
  testWidgets('Home page renders title and CTA', (WidgetTester tester) async {
    await tester.pumpWidget(const QuranPlayerApp());

    expect(find.text('Quran Player'), findsOneWidget);
    expect(find.text('Welcome to Quran Player'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });
}
