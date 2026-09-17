import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgeta/screens/app_settings_preview_screen.dart';

void main() {
  testWidgets('App notifications screen renders expected content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppNotificationsScreen()));

    expect(find.text('App notifications'), findsOneWidget);
    expect(find.text('Budgeta'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.textContaining('This app has not posted any'), findsOneWidget);
  });

  testWidgets('App permissions screen renders expected content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppPermissionsScreen()));

    expect(find.text('App permissions'), findsOneWidget);
    expect(find.text('Budgeta'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
  });
}
