// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mychessapp/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(ChessApp());

    // The provided test checks for a counter application, which is not relevant to the chess app. 
    // You might want to modify or write new tests specific to your application's functionality.
  });
}
