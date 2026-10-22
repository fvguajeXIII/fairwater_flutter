import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/address_search_service.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../services/refill_notification_service.dart';
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
  AuthService? _authService;
  final _onboardingService = OnboardingService();
  final _imagePicker = ImagePicker();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _residence = TextEditingController();
  final _phone = TextEditingController();
  final _referral = TextEditingController();
  final _addressSearchController = TextEditingController();
  final _birthDate = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _emailConfirmed = false;
  bool _completionConfirmed = false;
  bool _emailVerificationPressed = false;
  bool _isSearchingAddress = false;
  String? _addressSearchError;
  List<AddressSuggestion> _addressResults = [];
  AddressDetails? _selectedAddress;
  String _addressSessionToken = '';
  Timer? _addressSearchDebounce;
  final _addressSearchService = AddressSearchService();

  AuthService get _activeAuthService => _authService ??= AuthService();
  bool _emailVerificationSent = false;
  XFile? _selectedProfileImage;
  Uint8List? _selectedProfileImageBytes;
  String? _createdProfileUid;
  String _createdProfileEmail = '';
  String _createdProfileName = '';
  String _createdProfileResidence = '';
  String _createdProfilePhone = '';

  static const _stepCount = 6;

  @override
  void initState() {
    super.initState();
    _addressSearchController.addListener(_onAddressChanged);
    _addressSessionToken = _newAddressSessionToken();
  }

  @override
  void dispose() {
    _addressSearchDebounce?.cancel();
    _addressSearchController.removeListener(_onAddressChanged);
    _pageController.dispose();
    for (final controller in [
      _firstName,
      _lastName,
      _residence,
      _phone,
      _referral,
      _addressSearchController,
      _email,
      _password,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 3) {
      final query = _addressSearchController.text.trim();
      if (_selectedAddress == null && query.isNotEmpty) {
        if (_addressResults.isEmpty) {
          await _searchAddress(query);
        }
        if (_selectedAddress == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Seleziona un indirizzo valido.')),
            );
          }
          return;
        }
      }
      _residence.text = _selectedAddress?.formattedAddress ?? query;
    }
    if (_step >= 2 &&
        _step < _stepCount - 1 &&
        !(_formKeys[_step - 2].currentState?.validate() ?? false)) {
      return;
    }
    if (_step == 4) {
      await _register();
      return;
    }
    if (_step == _stepCount - 1) {
      await _finishOnboarding();
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
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _onAddressChanged() {
    final query = _addressSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _addressResults = [];
        _addressSearchError = null;
        _selectedAddress = null;
      });
      return;
    }
    if (_selectedAddress?.formattedAddress == query) {
      return;
    }
    _selectedAddress = null;
    _addressSearchDebounce?.cancel();
    _addressSearchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchAddress(query),
    );
  }

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _addressResults = [];
        _addressSearchError = null;
        _isSearchingAddress = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSearchingAddress = true;
      _addressSearchError = null;
    });
    try {
      final results = await _addressSearchService.autocomplete(
        query: query,
        sessionToken: _addressSessionToken,
      );
      if (!mounted || _addressSearchController.text.trim() != query) return;
      setState(() {
        _addressResults = results;
        _isSearchingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressResults = [];
        _addressSearchError = 'Impossibile cercare l indirizzo ora.';
        _isSearchingAddress = false;
      });
    }
  }

  Future<void> _selectAddressSuggestion(AddressSuggestion suggestion) async {
    _addressSearchDebounce?.cancel();
    if (!mounted) return;
    setState(() {
      _isSearchingAddress = true;
      _addressSearchError = null;
    });
    try {
      final details = await _addressSearchService.details(
        placeId: suggestion.placeId,
        sessionToken: _addressSessionToken,
      );
      if (!mounted) return;
      setState(() {
        _selectedAddress = details;
        _addressResults = [];
        _addressSearchController.text = details.formattedAddress;
        _residence.text = details.formattedAddress;
        _addressSessionToken = _newAddressSessionToken();
        _isSearchingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressSearchError = 'Selezione indirizzo non disponibile.';
        _isSearchingAddress = false;
      });
    }
  }

  Future<void> _pickBirthDate(BuildContext context) async {
    final initialDate = _birthDate.text.isEmpty
        ? DateTime.now().subtract(const Duration(days: 365 * 25))
        : DateTime.tryParse(_birthDate.text) ??
              DateTime.now().subtract(const Duration(days: 365 * 25));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _birthDate.text = formatted;
      });
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 900,
      );
      if (selectedImage == null) {
        return;
      }
      final imageBytes = await selectedImage.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedProfileImage = selectedImage;
        _selectedProfileImageBytes = imageBytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile selezionare la foto profilo.'),
        ),
      );
    }
  }

  Future<void> _confirmEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _emailVerificationSent = true;
        _emailVerificationPressed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email di verifica inviata. Controlla la tua casella.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non riesco ad inviare l’email di verifica.'),
        ),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (_step == _stepCount - 1 && !_emailVerificationPressed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conferma la tua email per continuare.')),
      );
      return;
    }
    setState(() => _completionConfirmed = true);
    await _onboardingService.complete();
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).pushReplacementNamed('/home');
  }

  Future<void> _addToWallet() async {
    final walletUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://www.apple.com/wallet/'
        : 'https://pay.google.com/gp/w/home';
    final uri = Uri.parse(walletUrl);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Non riesco ad aprire il wallet sul dispositivo.'),
      ),
    );
  }

  String _newAddressSessionToken() =>
      DateTime.now().microsecondsSinceEpoch.toString();

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
      final credential = await _activeAuthService.registerWithProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        password: _password.text,
        residence: _residence.text,
        phone: _phone.text,
        referralCode: _referral.text,
        photoBase64: _selectedProfileImageBytes == null
            ? null
            : base64Encode(_selectedProfileImageBytes!),
        birthDate: _birthDate.text.isEmpty ? null : _birthDate.text,
      );
      if (!mounted) return;
      final user = credential.user;
      if (user != null) {
        try {
          await user.sendEmailVerification();
        } catch (_) {}
      }
      setState(() {
        _createdProfileUid = user?.uid;
        _createdProfileEmail = (user?.email ?? _email.text).trim();
        _createdProfileName = '${_firstName.text} ${_lastName.text}'.trim();
        _createdProfileResidence = _residence.text.trim();
        _createdProfilePhone = _phone.text.trim();
        _emailVerificationSent = user != null;
      });
      if (_birthDate.text.isNotEmpty) {
        await RefillNotificationService.instance.scheduleBirthdayNotification(
          birthDate: _birthDate.text,
          userName: _createdProfileName.isNotEmpty
              ? _createdProfileName
              : _firstName.text.trim(),
        );
      }
      await _pageController.animateToPage(
        _stepCount - 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      setState(() => _step = _stepCount - 1);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Benvenuto in FairWater!')));
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_registrationMessage(error))));
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
    final content = SafeArea(
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
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  )
                else
                  const WaterBottleBadge(size: 46, showGlow: false),
                const Spacer(),
                Text(
                  '${_step + 1} di $_stepCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 8),
                    ],
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
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.30),
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
                  addressSearchController: _addressSearchController,
                  phone: _phone,
                  referral: _referral,
                  addressResults: _addressResults,
                  isSearchingAddress: _isSearchingAddress,
                  addressSearchError: _addressSearchError,
                  selectedAddress: _selectedAddress,
                  onSelectAddress: _selectAddressSuggestion,
                ),
                _AccountStep(
                  formKey: _formKeys[2],
                  email: _email,
                  password: _password,
                  confirmPassword: _confirmPassword,
                  obscurePassword: _obscurePassword,
                  acceptedTerms: _acceptedTerms,
                  selectedPhotoBytes: _selectedProfileImageBytes,
                  selectedPhotoName: _selectedProfileImage?.name,
                  birthDate: _birthDate,
                  onPickBirthDate: () => _pickBirthDate(context),
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onTermsChanged: (value) =>
                      setState(() => _acceptedTerms = value ?? false),
                  onPickPhoto: _pickProfilePhoto,
                ),
                _CompletionStep(
                  uid: _createdProfileUid,
                  fullName: _createdProfileName,
                  email: _createdProfileEmail,
                  residence: _createdProfileResidence,
                  phone: _createdProfilePhone,
                  emailConfirmed: _emailConfirmed,
                  emailVerificationSent: _emailVerificationSent,
                  onEmailConfirmedChanged: (value) =>
                      setState(() => _emailConfirmed = value ?? false),
                  onConfirmEmail: _confirmEmail,
                  onAddToWallet: _addToWallet,
                  onFinish: _finishOnboarding,
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
                    onPressed:
                        _submitting ||
                            (isLastStep &&
                                !_completionConfirmed &&
                                !_emailVerificationPressed)
                        ? null
                        : _next,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isLastStep ? 'Vai all’app' : 'Continua'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _submitting ? null : _openLogin,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Ho già un account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: 'Borraccia FairWater con QR code',
            child: Image.asset(
              'assets/welcome_bottle.jpeg',
              key: const Key('welcome-bottle-image'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          const DecoratedBox(
            key: Key('welcome-contrast-overlay'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xC7001424),
                  Color(0x73001424),
                  Color(0xC7001424),
                ],
                stops: [0, 0.52, 1],
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.child,
    this.onImageBackground = true,
  });
  final String eyebrow;
  final String title;
  final String body;
  final Widget child;
  final bool onImageBackground;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: onImageBackground
                ? const Color(0xFFB9E1FF)
                : AppColors.ocean,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            shadows: onImageBackground
                ? const [Shadow(color: Colors.black87, blurRadius: 10)]
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: onImageBackground ? Colors.white : null,
            shadows: onImageBackground
                ? const [Shadow(color: Colors.black87, blurRadius: 14)]
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: onImageBackground
                ? Colors.white.withValues(alpha: 0.94)
                : AppColors.slate,
            fontWeight: onImageBackground ? FontWeight.w600 : null,
            shadows: onImageBackground
                ? const [Shadow(color: Colors.black87, blurRadius: 10)]
                : null,
          ),
        ),
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
    title: 'Da oggi la tua acqua\nla offre il bar.',
    body:
        'Riempi la borraccia nei bar partner, accumula punti e trasforma ogni refill in acqua potabile per chi non ne ha.',
    onImageBackground: true,
    child: const SizedBox.shrink(),
  );
}

class _ImpactStep extends StatelessWidget {
  const _ImpactStep();
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Come funziona',
    title: "Come bere un bicchiere d'acqua.",
    body:
        'Trova il locale direttamente in app, scansiona il QR al banco, riempi la tua borraccia.',
    child: const Column(
      children: [
        _Benefit(
          icon: Icons.location_on_rounded,
          title: 'Trova',
          body: 'Scopri i punti refill vicini a te.',
        ),
        SizedBox(height: 12),
        _Benefit(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scansiona',
          body: 'Registra il refill in pochi secondi.',
        ),
        SizedBox(height: 12),
        _Benefit(
          icon: Icons.insights_rounded,
          title: 'Riempi',
          body: 'Tutte le volte che vuoi.',
        ),
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: AppDecorations.glassCard(radius: 22),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.mist,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppColors.ocean),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.formKey,
    required this.firstName,
    required this.lastName,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Il tuo profilo',
    title: 'Come ti chiami?',
    body: 'Usiamo questi dati per personalizzare la tua esperienza FairWater.',
    child: Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: firstName,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            decoration: _decoration('Nome', Icons.person_outline_rounded),
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: lastName,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            decoration: _decoration('Cognome', Icons.badge_outlined),
            validator: _required,
          ),
        ],
      ),
    ),
  );
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.formKey,
    required this.residence,
    required this.addressSearchController,
    required this.phone,
    required this.referral,
    required this.addressResults,
    required this.isSearchingAddress,
    required this.addressSearchError,
    required this.selectedAddress,
    required this.onSelectAddress,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController residence;
  final TextEditingController addressSearchController;
  final TextEditingController phone;
  final TextEditingController referral;
  final List<AddressSuggestion> addressResults;
  final bool isSearchingAddress;
  final String? addressSearchError;
  final AddressDetails? selectedAddress;
  final ValueChanged<AddressSuggestion> onSelectAddress;
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Quasi fatto',
    title: 'Dove vivi?',
    body:
        'Cerca il tuo indirizzo e selezionalo per compilare automaticamente la posizione.',
    child: Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: addressSearchController,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Cerca indirizzo', Icons.search_rounded)
                .copyWith(
                  suffixIcon: isSearchingAddress
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : selectedAddress != null
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ocean,
                        )
                      : null,
                ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Seleziona un indirizzo'
                : null,
          ),
          if (addressSearchError != null) ...[
            const SizedBox(height: 8),
            Text(
              addressSearchError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (addressResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: AppDecorations.glassCard(radius: 18),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: addressResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = addressResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(suggestion.label),
                    subtitle: Text(
                      suggestion.secondaryText.isNotEmpty
                          ? suggestion.secondaryText
                          : suggestion.mainText,
                    ),
                    onTap: () => onSelectAddress(suggestion),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: _decoration(
              'Telefono (facoltativo)',
              Icons.phone_outlined,
            ),
            validator: (value) =>
                value != null &&
                    value.trim().isNotEmpty &&
                    !RegExp(r'^[0-9()+\-\s]{6,}$').hasMatch(value)
                ? 'Numero non valido'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: referral,
            decoration: _decoration(
              'Codice invito (facoltativo)',
              Icons.card_giftcard_outlined,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.formKey,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.obscurePassword,
    required this.acceptedTerms,
    required this.selectedPhotoBytes,
    required this.selectedPhotoName,
    required this.birthDate,
    required this.onPickBirthDate,
    required this.onTogglePassword,
    required this.onTermsChanged,
    required this.onPickPhoto,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final bool obscurePassword;
  final bool acceptedTerms;
  final Uint8List? selectedPhotoBytes;
  final String? selectedPhotoName;
  final TextEditingController birthDate;
  final VoidCallback onPickBirthDate;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onTermsChanged;
  final VoidCallback onPickPhoto;
  @override
  Widget build(BuildContext context) => _StepShell(
    eyebrow: 'Sicurezza',
    title: 'Crea il tuo accesso',
    body:
        'Scegli email e password. Puoi aggiungere anche una foto profilo facoltativa.',
    child: Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: _decoration('Email', Icons.alternate_email_rounded),
            validator: (value) =>
                value == null ||
                    !RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(value.trim())
                ? 'Inserisci un’email valida'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: password,
            obscureText: obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            decoration: _decoration('Password', Icons.lock_outline_rounded)
                .copyWith(
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
            validator: (value) => value == null || value.length < 6
                ? 'Usa almeno 6 caratteri'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmPassword,
            obscureText: obscurePassword,
            decoration: _decoration(
              'Conferma password',
              Icons.verified_user_outlined,
            ),
            validator: (value) =>
                value != password.text ? 'Le password non corrispondono' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: birthDate,
            readOnly: true,
            decoration: _decoration(
              'Data di nascita',
              Icons.cake_outlined,
            ).copyWith(suffixIcon: const Icon(Icons.calendar_today_rounded)),
            onTap: onPickBirthDate,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.glassCard(radius: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: onPickPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Foto profilo (facoltativa)'),
                ),
                if (selectedPhotoBytes != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      selectedPhotoBytes!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedPhotoName ?? 'Foto selezionata',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: acceptedTerms,
            onChanged: onTermsChanged,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Accetto Termini e Privacy',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Necessario per creare l’account.'),
          ),
        ],
      ),
    ),
  );
}

class _CompletionStep extends StatelessWidget {
  const _CompletionStep({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.residence,
    required this.phone,
    required this.emailConfirmed,
    required this.emailVerificationSent,
    required this.onEmailConfirmedChanged,
    required this.onConfirmEmail,
    required this.onAddToWallet,
    required this.onFinish,
  });

  final String? uid;
  final String fullName;
  final String email;
  final String residence;
  final String phone;
  final bool emailConfirmed;
  final bool emailVerificationSent;
  final ValueChanged<bool?> onEmailConfirmedChanged;
  final VoidCallback onConfirmEmail;
  final VoidCallback onAddToWallet;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final qrPayload = uid == null || uid!.isEmpty
        ? 'fairwater://guest'
        : 'fairwater://customer/$uid';
    return _StepShell(
      eyebrow: 'Profilo pronto',
      title: 'Il tuo profilo è pronto',
      body:
          'Qui trovi la tua scheda completa, il QR unico e il pulsante per aggiungerlo al wallet.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: AppDecorations.glassCard(radius: 28),
            child: Column(
              children: [
                Text(
                  fullName.isNotEmpty ? fullName : 'Nuovo utente FairWater',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  email.isNotEmpty ? email : 'Email non disponibile',
                  style: const TextStyle(color: AppColors.slate),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (residence.isNotEmpty)
                      _InfoPill(
                        label: residence,
                        icon: Icons.location_on_outlined,
                      ),
                    if (phone.isNotEmpty)
                      _InfoPill(label: phone, icon: Icons.phone_outlined),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ocean.withValues(alpha: .14),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'QR di ricarica',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      QrImageView(
                        data: qrPayload,
                        version: QrVersions.auto,
                        size: 220,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.glassCard(radius: 20),
            child: Column(
              children: [
                CheckboxListTile(
                  value: emailConfirmed,
                  onChanged: onEmailConfirmedChanged,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Confermo la mia email',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Apri la mail ricevuta e completa la verifica per accedere all’app.',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onConfirmEmail,
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: Text(
                      emailVerificationSent
                          ? 'Email di verifica inviata'
                          : 'Conferma email',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAddToWallet,
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Aggiungi al wallet'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Vai all’app'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.mist,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.ocean),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

InputDecoration _decoration(String label, IconData icon) => InputDecoration(
  labelText: label,
  prefixIcon: Icon(icon, color: AppColors.ocean),
);
String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Campo obbligatorio' : null;

String _registrationMessage(FirebaseAuthException error) =>
    switch (error.code) {
      'email-already-in-use' => 'Questa email è già registrata.',
      'invalid-email' => 'L’indirizzo email non è valido.',
      'weak-password' => 'Scegli una password più sicura.',
      'network-request-failed' => 'Connessione assente o instabile.',
      _ => error.message ?? 'Registrazione non riuscita.',
    };
