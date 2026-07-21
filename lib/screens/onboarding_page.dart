import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.onExistingAccount});

  final VoidCallback? onExistingAccount;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  final _authService = AuthService();
  final _onboardingService = OnboardingService();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _residence = TextEditingController();
  final _phone = TextEditingController();
  final _referral = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  static const _stepCount = 5;

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in [
      _firstName,
      _lastName,
      _residence,
      _phone,
      _referral,
      _email,
      _password,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    if (_step >= 2 &&
        !(_formKeys[_step - 2].currentState?.validate() ?? false)) {
      return;
    }
    if (_step == _stepCount - 1) {
      await _register();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_step == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openLogin() async {
    await _onboardingService.complete();
    if (!mounted) return;
    if (widget.onExistingAccount != null) {
      widget.onExistingAccount!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _register() async {
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accetta i termini per continuare.')),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _authService.registerWithProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
        residence: _residence.text,
        phone: _phone.text,
        referralCode: _referral.text,
      );
      await _onboardingService.complete();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Benvenuto in FairWater!')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_registrationMessage(error))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrazione non riuscita. Riprova.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _step == _stepCount - 1;
    return Scaffold(
      body: WaterBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    if (_step > 0)
                      IconButton(
                        tooltip: 'Indietro',
                        onPressed: _submitting ? null : _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                    else
                      const WaterBottleBadge(size: 46, showGlow: false),
                    const Spacer(),
                    Text(
                      '${_step + 1} di $_stepCount',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: (_step + 1) / _stepCount,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) => setState(() => _step = value),
                  children: [
                    const _IntroStep(),
                    const _ImpactStep(),
                    _IdentityStep(
                      formKey: _formKeys[0],
                      firstName: _firstName,
                      lastName: _lastName,
                    ),
                    _DetailsStep(
                      formKey: _formKeys[1],
                      residence: _residence,
                      phone: _phone,
                      referral: _referral,
                    ),
                    _AccountStep(
                      formKey: _formKeys[2],
                      email: _email,
                      password: _password,
                      confirmPassword: _confirmPassword,
                      obscurePassword: _obscurePassword,
                      acceptedTerms: _acceptedTerms,
                      onTogglePassword: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      onTermsChanged: (value) =>
                          setState(() => _acceptedTerms = value ?? false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _next,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(isLastStep ? 'Crea il mio account' : 'Continua'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _submitting ? null : _openLogin,
                      child: const Text('Ho già un account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({required this.eyebrow, required this.title, required this.body, required this.child});
  final String eyebrow;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: const TextStyle(color: AppColors.ocean, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.slate)),
        const SizedBox(height: 30),
        child,
      ],
    ),
  );
}

class _IntroStep extends StatelessWidget {
  const _IntroStep();
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Benvenuto',
    title: 'La tua acqua,\nil tuo impatto.',
    body: 'FairWater rende ogni refill semplice da tracciare e trasforma una buona abitudine in un risultato visibile.',
    child: Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppDecorations.heroGradient, borderRadius: BorderRadius.circular(36)),
      child: const Stack(alignment: Alignment.center, children: [
        Icon(Icons.water_drop_rounded, size: 132, color: Color(0x55FFFFFF)),
        WaterBottleBadge(size: 104, showGlow: false),
      ]),
    ),
  );
}

class _ImpactStep extends StatelessWidget {
  const _ImpactStep();
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Come funziona',
    title: 'Tre gesti. Una nuova abitudine.',
    body: 'Trova un punto FairWater, scansiona il QR e guarda crescere il tuo contributo.',
    child: const Column(children: [
      _Benefit(icon: Icons.location_on_rounded, title: 'Trova', body: 'Scopri i punti refill vicini a te.'),
      SizedBox(height: 12),
      _Benefit(icon: Icons.qr_code_scanner_rounded, title: 'Scansiona', body: 'Registra il refill in pochi secondi.'),
      SizedBox(height: 12),
      _Benefit(icon: Icons.insights_rounded, title: 'Misura', body: 'Segui bottiglie evitate e impatto.'),
    ]),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon; final String title; final String body;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: AppDecorations.glassCard(radius: 22),
    child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: AppColors.ocean)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 3), Text(body)])),
    ]),
  );
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({required this.formKey, required this.firstName, required this.lastName});
  final GlobalKey<FormState> formKey; final TextEditingController firstName; final TextEditingController lastName;
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Il tuo profilo', title: 'Come ti chiami?', body: 'Usiamo questi dati per personalizzare la tua esperienza FairWater.',
    child: Form(key: formKey, child: Column(children: [
      TextFormField(controller: firstName, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.givenName], decoration: _decoration('Nome', Icons.person_outline_rounded), validator: _required),
      const SizedBox(height: 14),
      TextFormField(controller: lastName, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.familyName], decoration: _decoration('Cognome', Icons.badge_outlined), validator: _required),
    ])),
  );
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({required this.formKey, required this.residence, required this.phone, required this.referral});
  final GlobalKey<FormState> formKey; final TextEditingController residence; final TextEditingController phone; final TextEditingController referral;
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Quasi fatto', title: 'Dove vivi?', body: 'La città ci aiuta a mostrarti punti refill e iniziative più rilevanti.',
    child: Form(key: formKey, child: Column(children: [
      TextFormField(controller: residence, textCapitalization: TextCapitalization.words, decoration: _decoration('Città e provincia', Icons.location_on_outlined), validator: _required),
      const SizedBox(height: 14),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber], decoration: _decoration('Telefono (facoltativo)', Icons.phone_outlined), validator: (value) => value != null && value.trim().isNotEmpty && !RegExp(r'^[0-9()+\-\s]{6,}$').hasMatch(value) ? 'Numero non valido' : null),
      const SizedBox(height: 14),
      TextFormField(controller: referral, decoration: _decoration('Codice invito (facoltativo)', Icons.card_giftcard_outlined)),
    ])),
  );
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({required this.formKey, required this.email, required this.password, required this.confirmPassword, required this.obscurePassword, required this.acceptedTerms, required this.onTogglePassword, required this.onTermsChanged});
  final GlobalKey<FormState> formKey; final TextEditingController email; final TextEditingController password; final TextEditingController confirmPassword; final bool obscurePassword; final bool acceptedTerms; final VoidCallback onTogglePassword; final ValueChanged<bool?> onTermsChanged;
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Sicurezza', title: 'Crea il tuo accesso', body: 'Scegli email e password. I tuoi dati restano protetti nel tuo account.',
    child: Form(key: formKey, child: Column(children: [
      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: _decoration('Email', Icons.alternate_email_rounded), validator: (value) => value == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim()) ? 'Inserisci un’email valida' : null),
      const SizedBox(height: 14),
      TextFormField(controller: password, obscureText: obscurePassword, autofillHints: const [AutofillHints.newPassword], decoration: _decoration('Password', Icons.lock_outline_rounded).copyWith(suffixIcon: IconButton(onPressed: onTogglePassword, icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))), validator: (value) => value == null || value.length < 6 ? 'Usa almeno 6 caratteri' : null),
      const SizedBox(height: 14),
      TextFormField(controller: confirmPassword, obscureText: obscurePassword, decoration: _decoration('Conferma password', Icons.verified_user_outlined), validator: (value) => value != password.text ? 'Le password non corrispondono' : null),
      const SizedBox(height: 16),
      CheckboxListTile(value: acceptedTerms, onChanged: onTermsChanged, controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text('Accetto Termini e Privacy', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Necessario per creare l’account.')),
    ])),
  );
}

InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, color: AppColors.ocean));
String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obbligatorio' : null;

String _registrationMessage(FirebaseAuthException error) => switch (error.code) {
  'email-already-in-use' => 'Questa email è già registrata.',
  'invalid-email' => 'L’indirizzo email non è valido.',
  'weak-password' => 'Scegli una password più sicura.',
  'network-request-failed' => 'Connessione assente o instabile.',
  _ => error.message ?? 'Registrazione non riuscita.',
};
