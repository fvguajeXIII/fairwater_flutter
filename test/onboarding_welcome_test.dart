import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fairwater/screens/onboarding_page.dart';
import 'package:fairwater/theme/app_theme.dart';

void main() {
  testWidgets('Welcome screen shows the FairWater bottle image', (
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

    final image = tester.widget<Image>(
      find.byKey(const Key('welcome-bottle-image')),
    );
    expect((image.image as AssetImage).assetName, 'assets/welcome_bottle.jpeg');
    expect(image.fit, BoxFit.cover);
    expect(find.byKey(const Key('welcome-contrast-overlay')), findsOneWidget);

    final title = tester.widget<Text>(
      find.text('Da oggi la tua acqua\nla offre il bar.'),
    );
    expect(title.style?.color, Colors.white);

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(find.text('Da oggi la tua acqua\nla offre il bar.'), findsNothing);
    expect(find.text("Come bere un bicchiere d'acqua."), findsOneWidget);
    expect(find.byKey(const Key('welcome-bottle-image')), findsOneWidget);
  });
}
