import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'services/auth_service.dart';
import 'services/biometric_auth_service.dart';
import 'services/login_preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E73C6),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 20,
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final loginPreferencesService = LoginPreferencesService();
    final biometricAuthService = BiometricAuthService();

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
          return FutureBuilder(
            future: loginPreferencesService.load(),
            builder: (context, preferencesSnapshot) {
              if (preferencesSnapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingScreen();
              }

              final preferences =
                  preferencesSnapshot.data ??
                  const LoginPreferences(
                    rememberMe: false,
                    biometricEnabled: false,
                    savedEmail: '',
                  );

              if (!preferences.rememberMe || !preferences.biometricEnabled) {
                return const HomePage();
              }

              return _BiometricGate(
                biometricAuthService: biometricAuthService,
              );
            },
          );
        }

        return const LoginPage();
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 64, color: Color(0xFF1E73C6)),
              const SizedBox(height: 16),
              Text(
                _isChecking ? 'Verifica biometrica in corso...' : 'Sblocca con biometria',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Usa impronta digitale o Face ID per accedere a FairWater.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!_isChecking)
                FilledButton(
                  onPressed: _unlock,
                  child: const Text('Riprova'),
                ),
            ],
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
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Errore di inizializzazione Firebase:\n$message',
            textAlign: TextAlign.center,
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
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Firebase non è ancora configurato correttamente.\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
