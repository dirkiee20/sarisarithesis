import 'package:flutter_test/flutter_test.dart';
import 'package:sarisari_owner/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SariSariOwnerApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SariSariOwnerApp), findsOneWidget);
  });
}
