// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_social_app/screens/auth/login_screen.dart' as auth_login;

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: auth_login.LoginScreen()));
    expect(find.text('Login'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Login'), findsOneWidget);
  });
}
