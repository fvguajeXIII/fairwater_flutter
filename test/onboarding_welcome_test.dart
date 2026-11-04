import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fairwater/screens/onboarding_page.dart';
import 'package:fairwater/theme/app_theme.dart';

void main() {
  testWidgets('Welcome screen uses the shared water pattern', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const OnboardingPage(),
      ),
    );

    expect(find.byType(WaterPatternBackground), findsOneWidget);
    expect(find.byKey(const Key('welcome-contrast-overlay')), findsNothing);

    final title = tester.widget<Text>(
      find.text('Da oggi la tua acqua\nla offre il bar.'),
    );
    expect(title.style?.color, AppColors.ink);

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(find.text('Da oggi la tua acqua\nla offre il bar.'), findsNothing);
    expect(find.text("Come bere un bicchiere d'acqua."), findsOneWidget);
    expect(find.byType(WaterPatternBackground), findsOneWidget);
  });
}
