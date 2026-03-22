import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:location_ringer/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LocationRingerApp());

    // Verify that the title is there.
    expect(find.text('Location Ringer'), findsOneWidget);
  });
}
