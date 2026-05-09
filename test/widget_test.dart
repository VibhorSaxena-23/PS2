import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flexicurl_client_mobile/src/core/theme/app_theme.dart';
import 'package:flexicurl_client_mobile/src/features/splash/presentation/splash_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Splash screen renders FlexiCurl branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const SplashPage(),
      ),
    );
    await tester.pump(); // trigger first frame

    expect(find.text('FlexiCurl'), findsOneWidget);
    expect(find.text('Find Flexicurl Nearby!'), findsOneWidget);
  });
}
