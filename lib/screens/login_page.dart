import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/login_preferences_service.dart';
import '../theme/app_theme.dart';

InputDecoration _fieldDeco(String hint, IconData icon) => InputDecoration(
  hintText: hint,
  prefixIcon: Icon(icon, size: 20, color: AppColors.ocean),
);

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _showLogin(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => const _LoginSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaterBackdrop(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/login.jpg', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.deepOcean.withValues(alpha: 0.26),
                    AppColors.deepOcean.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LoginBrandHero(),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppDecorations.glassCard(radius: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Riempila di buone abitudini.',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'FairWater trasforma ogni refill in un gesto visibile per te, la community e l accesso all acqua.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _showLogin(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.deepOcean,
                              ),
                              child: const Text('Accedi'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Nuovo su FairWater?',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                ),
                                child: const Text(
                                  'Crea account',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBrandHero extends StatelessWidget {
  const _LoginBrandHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WaterBottleBadge(size: 76),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            'Borraccia. Refill. Impatto.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'L app che fa scorrere\nla tua identita acqua.',
          style: TextStyle(
            fontSize: 34,
            height: 1.02,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _LoginSheet extends StatefulWidget {
  const _LoginSheet();

  @override
  State<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<_LoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final LoginPreferencesService _loginPreferencesService =
      LoginPreferencesService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _isSubmitting = false;
  bool _rememberMe = false;
  bool _useBiometric = false;
  bool _biometricAvailable = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _authSubscription = _authService.authStateChanges().listen((user) {
      if (user == null || !mounted) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final preferences = await _loginPreferencesService.load();
    final biometricAvailable =
        !kIsWeb && await _biometricAuthService.isBiometricAvailable();

    if (!mounted) return;

    setState(() {
      _rememberMe = preferences.rememberMe;
      _useBiometric =
          biometricAvailable &&
          preferences.rememberMe &&
          preferences.biometricEnabled;
      _biometricAvailable = biometricAvailable;
      if (preferences.savedEmail.isNotEmpty) {
        _emailCtrl.text = preferences.savedEmail;
      }
    });
  }

  Future<void> _saveLoginPreferences({String? email}) {
    return _loginPreferencesService.save(
      rememberMe: _rememberMe,
      biometricEnabled: _useBiometric && _biometricAvailable,
      email: email ?? _emailCtrl.text,
    );
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() => _isSubmitting = true);

    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );

      await _saveLoginPreferences();

      if (navigator.canPop()) {
        navigator.pop();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseLoginMessage(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accesso non riuscito. Riprova tra qualche istante.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isSubmitting) {
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() => _isSubmitting = true);

    try {
      await _authService.signInWithGoogle();
      await _saveLoginPreferences(email: _authService.currentUser?.email);
      if (navigator.canPop()) {
        navigator.pop();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'sign_in_canceled') {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseGoogleMessage(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Accesso con Google non riuscito. Riprova tra qualche istante.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final isAppleAvailable =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.48,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.58, 0.78, 0.95],
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FEFF), Color(0xFFEAFBFF)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + viewInsets),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2EAF1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                const WaterBottleBadge(size: 58, showGlow: false),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bentornato',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Accedi e continua il tuo ritmo di refill.',
                        style: TextStyle(
                          color: AppColors.slate.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD9EDF3)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDeco('Email', Icons.alternate_email_rounded),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Inserisci una email';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                          return 'Email non valida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: _fieldDeco('Password', Icons.lock_outline_rounded)
                          .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.slate,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Inserisci la password';
                        }
                        if (v.length < 6) return 'Almeno 6 caratteri';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _login,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Accedi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _PreferenceTile(
              title: 'Ricordami',
              subtitle: 'Mantieni pronta la tua email per il prossimo accesso.',
              leading: Icons.bookmark_added_rounded,
              trailing: Checkbox(
                value: _rememberMe,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                          if (!_rememberMe) {
                            _useBiometric = false;
                          }
                        });
                      },
              ),
            ),
            if (_biometricAvailable) ...[
              const SizedBox(height: 10),
              _PreferenceTile(
                title: 'Accesso biometrico',
                subtitle: _rememberMe
                    ? 'Sblocca FairWater con impronta o Face ID.'
                    : 'Attiva prima "Ricordami".',
                leading: Icons.fingerprint_rounded,
                trailing: Switch(
                  value: _useBiometric,
                  onChanged: !_rememberMe || _isSubmitting
                      ? null
                      : (value) => setState(() => _useBiometric = value),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Oppure entra con',
                    style: TextStyle(color: AppColors.slate.withValues(alpha: 0.9)),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (isAppleAvailable) ...[
                  Expanded(
                    child: _SocialBtn(
                      label: 'Apple',
                      dark: true,
                      iconWidget: const Icon(Icons.apple, size: 20),
                      onTap: _isSubmitting
                          ? null
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Accesso con Apple non ancora disponibile.',
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _SocialBtn(
                    label: 'Google',
                    dark: false,
                    iconWidget: const Icon(Icons.g_mobiledata, size: 24),
                    onTap: _isSubmitting ? null : _signInWithGoogle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                child: const Text('Non hai ancora un account? Registrati'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9EDF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(leading, color: AppColors.ocean),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn({
    required this.label,
    required this.dark,
    required this.iconWidget,
    required this.onTap,
  });

  final String label;
  final bool dark;
  final Widget iconWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: dark ? AppColors.ink : Colors.white,
        side: BorderSide(
          color: dark ? AppColors.ink : const Color(0xFFD8EAF0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme(
            data: IconThemeData(color: dark ? Colors.white : AppColors.ink),
            child: iconWidget,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: dark ? Colors.white : AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _residenceCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  bool _obscure = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _residenceCtrl.dispose();
    _phoneCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _authService.registerWithProfile(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
        residence: _residenceCtrl.text,
        phone: _phoneCtrl.text,
        referralCode: _referralCtrl.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrazione completata con successo.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseRegisterMessage(e))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registrazione non riuscita. Controlla la connessione e riprova.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WaterBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                decoration: BoxDecoration(
                  gradient: AppDecorations.heroGradient,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const WaterBottleBadge(size: 64, showGlow: false),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Crea il tuo profilo acqua',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Un account, una borraccia, un impatto che cresce refill dopo refill.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.86),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppDecorations.glassCard(radius: 30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Dati essenziali'),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameCtrl,
                                  decoration: _fieldDeco(
                                    'Nome',
                                    Icons.person_outline_rounded,
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Obbligatorio'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameCtrl,
                                  decoration: _fieldDeco(
                                    'Cognome',
                                    Icons.person_outline_rounded,
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Obbligatorio'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _fieldDeco(
                              'Email per il login',
                              Icons.alternate_email_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Inserisci una email';
                              }
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v)) {
                                return 'Email non valida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: _fieldDeco(
                              'Password',
                              Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.slate,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Inserisci la password';
                              }
                              if (v.length < 6) return 'Almeno 6 caratteri';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscure,
                            decoration: _fieldDeco(
                              'Conferma password',
                              Icons.verified_user_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Conferma la password';
                              }
                              if (v != _passCtrl.text) {
                                return 'Le password non corrispondono';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _residenceCtrl,
                            decoration: _fieldDeco(
                              'Residenza (citta, provincia)',
                              Icons.location_on_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Inserisci la residenza'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          _sectionLabel('Dettagli opzionali'),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _fieldDeco(
                              'Numero di telefono',
                              Icons.phone_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              if (!RegExp(r'^[0-9()+\-\s]{6,}$').hasMatch(v)) {
                                return 'Numero non valido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _referralCtrl,
                            decoration: _fieldDeco(
                              'Codice referral',
                              Icons.card_giftcard_outlined,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _register,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text('Crea account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sectionLabel(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.ocean,
    letterSpacing: 0.3,
  ),
);

String _firebaseLoginMessage(FirebaseAuthException exception) {
  switch (exception.code) {
    case 'invalid-email':
      return 'L indirizzo email non e valido.';
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Email o password non corretti.';
    case 'user-disabled':
      return 'Questo account e stato disabilitato.';
    case 'too-many-requests':
      return 'Troppi tentativi. Riprova piu tardi.';
    case 'network-request-failed':
      return 'Connessione assente o instabile.';
    default:
      return exception.message ?? 'Accesso non riuscito.';
  }
}

String _firebaseRegisterMessage(FirebaseAuthException exception) {
  switch (exception.code) {
    case 'email-already-in-use':
      return 'Questa email e gia registrata.';
    case 'invalid-email':
      return 'L indirizzo email non e valido.';
    case 'weak-password':
      return 'La password e troppo debole.';
    case 'network-request-failed':
      return 'Connessione assente o instabile.';
    default:
      return exception.message ?? 'Registrazione non riuscita.';
  }
}

String _firebaseGoogleMessage(FirebaseAuthException exception) {
  switch (exception.code) {
    case 'account-exists-with-different-credential':
      return 'Esiste gia un account con questa email e un altro metodo di accesso.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
    case 'sign_in_canceled':
      return 'Accesso con Google annullato.';
    case 'network-request-failed':
      return 'Connessione assente o instabile.';
    case 'missing-google-id-token':
      return 'Configurazione Google incompleta. Controlla SHA-1 e file Firebase.';
    case 'google-platform-error':
      return 'Errore del servizio Google sul dispositivo. Controlla configurazione e Google Play Services.';
    default:
      return exception.message ?? 'Accesso con Google non riuscito.';
  }
}
