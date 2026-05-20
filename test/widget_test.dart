import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voicenote/app/app.dart';

void main() {
  testWidgets('App shows splash then login form', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('voicenote'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Dang nhap'), findsOneWidget);
  });
}

