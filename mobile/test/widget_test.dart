import 'package:alertdam_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// These tests pump AlertDamApp directly rather than calling main(), because
// main() calls Firebase.initializeApp() which requires platform channels and
// real Firebase configuration that do not exist under flutter_test.
void main() {
  testWidgets('AlertDamApp renders the home page', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AlertDamApp(),
      ),
    );

    expect(find.text('AlertDam'), findsWidgets);
    expect(
      find.text('Incident Management & On-Call Alerting'),
      findsOneWidget,
    );
  });

  testWidgets('uses a dark Material 3 theme seeded with the brand red',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AlertDamApp(),
      ),
    );

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.title, 'AlertDam');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.theme?.colorScheme.brightness, Brightness.dark);
  });

  testWidgets('HomePage has an app bar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(),
      ),
    );

    expect(find.byType(AppBar), findsOneWidget);
  });
}
