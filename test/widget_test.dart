import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fairwater/firebase_options.dart';
import 'package:fairwater/screens/login_page.dart';
import 'package:fairwater/screens/onboarding_page.dart';
import 'package:fairwater/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  test('Theme uses the FairWater identity color', () {
    expect(AppColors.ocean, const Color(0xFF2D7FE0));
    expect(AppTheme.light.colorScheme.primary, const Color(0xFF2D7FE0));
  });

  testWidgets('Login page renders primary entry points', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginPage(),
      ),
    );

    expect(find.text('Accedi'), findsOneWidget);
    expect(find.text('Crea account'), findsOneWidget);
  });

  testWidgets('Onboarding shows optional profile photo step', (
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

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Mario');
    await tester.enterText(find.byType(TextFormField).at(1), 'Rossi');
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Milano');
    await tester.enterText(find.byType(TextFormField).at(1), '3331234567');
    await tester.enterText(find.byType(TextFormField).at(2), 'INVITO');
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'mario@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(find.text('Foto profilo (facoltativa)'), findsOneWidget);
  });
}
