import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fairwater/screens/login_page.dart';
import 'package:fairwater/theme/app_theme.dart';

void main() {
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
}
