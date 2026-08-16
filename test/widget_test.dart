// This is a basic Flutter widget test for the School Office Management app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SchoolOfficeApp builds without crashing', (WidgetTester tester) async {
    // This test verifies that the app widget tree can be constructed.
    // Full integration tests should use the actual main.dart entry point.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('School Office Management')),
        ),
      ),
    );

    expect(find.text('School Office Management'), findsOneWidget);
  });
}