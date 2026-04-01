import 'package:flutter_test/flutter_test.dart';
import 'package:naijapulse/core/di/injection_container.dart';
import 'package:naijapulse/main.dart';

void main() {
  testWidgets('App shows loading and then shell', (WidgetTester tester) async {
    await InjectionContainer.reset();
    await tester.pumpWidget(const MyApp());
    expect(find.text('Loading your newsroom...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('NaijaPulse'), findsOneWidget);
    expect(find.text('Top Stories'), findsOneWidget);
    expect(find.text('Public Pulse'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
