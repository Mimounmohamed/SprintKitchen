import 'package:flutter_test/flutter_test.dart';
import 'package:caisse/main.dart';

void main() {
  testWidgets('HubScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verify brand and primary action exist
    expect(find.text('SPRINTKITCHEN'), findsWidgets);
    expect(find.text('HUB'), findsWidgets);
    expect(find.text('OUVRIR LA CAISSE POS'), findsOneWidget);
  });
}
