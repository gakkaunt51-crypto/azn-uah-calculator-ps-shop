import 'package:flutter_test/flutter_test.dart';
import 'package:azn_uah_calculator/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AznApp());
    expect(find.text('AZN → UAH'), findsOneWidget);
  });
}
