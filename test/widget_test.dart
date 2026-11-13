import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Auth screen renders initially', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const IdeasBoardApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Login'), findsNWidgets(2));
    expect(find.text('Create a new account'), findsOneWidget);
  });
}
