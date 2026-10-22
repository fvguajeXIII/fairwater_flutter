import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/admin_login_page.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/onboarding_page.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/biometric_auth_service.dart';
import 'services/login_preferences_service.dart';
import 'services/onboarding_service.dart';
import 'services/refill_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Inizializza notifiche solo su mobile/desktop, non su web
    if (!kIsWeb) {
      await RefillNotificationService.instance.initialize();
    }
    runApp(const MyApp());
  } catch (e) {
    runApp(_BootstrapErrorApp(message: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FairWater',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
      routes: {
        '/admin-login': (context) => const AdminLoginPage(),
        '/admin-dashboard': (context) => const AdminDashboardPage(),
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/onboarding': (context) => const OnboardingPage(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _onboardingCompletedInSession = false;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final loginPreferencesService = LoginPreferencesService();
    final biometricAuthService = BiometricAuthService();
    final adminService = AdminService();

    return StreamBuilder(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return _AuthErrorScreen(message: snapshot.error.toString());
        }

        if (snapshot.data != null) {
          return FutureBuilder<bool>(
            future: OnboardingService().isCompleted(),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const _LoadingScreen();
              }

              if (onboardingSnapshot.data == false) {
                return OnboardingPage(
                  onExistingAccount: () =>
                      setState(() => _onboardingCompletedInSession = true),
                );
              }

              // Verifica se l'utente è un admin
              return FutureBuilder<bool>(
                future: adminService.isUserAdmin(),
                builder: (context, adminSnapshot) {
                  if (adminSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const _LoadingScreen();
                  }

                  // Se è admin, vai alla dashboard admin
                  if (adminSnapshot.data == true) {
                    return const AdminDashboardPage();
                  }

                  // Altrimenti carica le preferenze per il login biometrico
                  return FutureBuilder(
                    future: loginPreferencesService.load(),
                    builder: (context, preferencesSnapshot) {
                      if (preferencesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const _LoadingScreen();
                      }

                      final preferences =
                          preferencesSnapshot.data ??
                          const LoginPreferences(
                            rememberMe: false,
                            biometricEnabled: false,
                            savedEmail: '',
                          );

                      if (!preferences.rememberMe ||
                          !preferences.biometricEnabled) {
                        return const HomePage();
                      }

                      return _BiometricGate(
                        biometricAuthService: biometricAuthService,
                      );
                    },
                  );
                },
              );
            },
          );
        }

        return FutureBuilder<bool>(
          future: OnboardingService().isCompleted(),
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            return onboardingSnapshot.data == true ||
                    _onboardingCompletedInSession
                ? const LoginPage()
                : OnboardingPage(
                    onExistingAccount: () =>
                        setState(() => _onboardingCompletedInSession = true),
                  );
          },
        );
      },
    );
  }
}

class _BiometricGate extends StatefulWidget {
  const _BiometricGate({required this.biometricAuthService});

  final BiometricAuthService biometricAuthService;

  @override
  State<_BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<_BiometricGate> {
  bool _isChecking = true;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    final authenticated = await widget.biometricAuthService.authenticate();
    if (!mounted) return;
    setState(() {
      _isUnlocked = authenticated;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnlocked) {
      return const HomePage();
    }

    return Scaffold(
      body: WaterBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: AppDecorations.glassCard(radius: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WaterBottleBadge(size: 92),
                  const SizedBox(height: 18),
                  Text(
                    _isChecking
                        ? 'Verifica biometrica in corso...'
                        : 'Sblocca con biometria',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Usa impronta digitale o Face ID per rientrare nella tua esperienza FairWater.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_isChecking)
                    const CircularProgressIndicator()
                  else
                    FilledButton(
                      onPressed: _unlock,
                      child: const Text('Riprova'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: WaterBackdrop(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaterBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppDecorations.glassCard(),
              child: Text(
                'Errore di inizializzazione Firebase:\n$message',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: WaterBackdrop(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AppDecorations.glassCard(),
                child: Text(
                  'Firebase non e ancora configurato correttamente.\n$message',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
