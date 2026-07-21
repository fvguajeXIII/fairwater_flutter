import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const String _googleServerClientId =
      '574931919668-uirgob0ok1cqume08u5n61ah79b03mek.apps.googleusercontent.com';

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn =
           googleSignIn ?? GoogleSignIn(serverClientId: _googleServerClientId);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  void _logGoogleSignIn(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[GoogleSignIn] $message');
    if (error != null) {
      debugPrint('[GoogleSignIn] error: $error');
    }
    if (stackTrace != null) {
      debugPrint('[GoogleSignIn] stackTrace: $stackTrace');
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth
        .signInWithEmailAndPassword(email: email.trim(), password: password)
        .timeout(_requestTimeout);

    await _ensureUserProfile(credential.user, provider: 'password');
    return credential;
  }

  Future<UserCredential> registerWithProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String residence,
    String? phone,
    String? referralCode,
  }) async {
    final credential = await _auth
        .createUserWithEmailAndPassword(email: email.trim(), password: password)
        .timeout(_requestTimeout);

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-created',
        message: 'Impossibile creare l\'account utente.',
      );
    }

    await user.updateDisplayName('$firstName $lastName'.trim());

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set({
          'uid': user.uid,
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'displayName': '$firstName $lastName'.trim(),
          'email': email.trim(),
          'residence': residence.trim(),
          'phone': phone?.trim() ?? '',
          'referralCode': referralCode?.trim() ?? '',
          'photoUrl': '',
          'provider': 'password',
          'roles': ['customer'],
          'accountType': 'customer',
          'status': 'active',
          'managedRefillPointIds': [],
          'managedSponsorIds': [],
          'refillCount': 0,
          'bottleOwnerSince': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_requestTimeout);

    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      _logGoogleSignIn('Avvio login Google su web.');
      final provider = GoogleAuthProvider();
      final credential = await _auth
          .signInWithPopup(provider)
          .timeout(_requestTimeout);
      _logGoogleSignIn(
        'Login web completato. UID=${credential.user?.uid}, email=${credential.user?.email}',
      );
      await _ensureUserProfile(credential.user, provider: 'google');
      return credential;
    }

    try {
      _logGoogleSignIn('Avvio login Google su Android/iOS.');
      _logGoogleSignIn(
        'Configurazione GoogleSignIn: serverClientId=$_googleServerClientId',
      );
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logGoogleSignIn('Login Google annullato dall utente prima del token.');
        throw FirebaseAuthException(
          code: 'sign_in_canceled',
          message: 'Accesso con Google annullato.',
        );
      }

      _logGoogleSignIn(
        'Account Google selezionato: email=${googleUser.email}, id=${googleUser.id}',
      );
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      _logGoogleSignIn(
        'Token ricevuti da Google. idTokenPresente=${idToken != null && idToken.isNotEmpty}, accessTokenPresente=${accessToken != null && accessToken.isNotEmpty}',
      );

      if (idToken == null || idToken.isEmpty) {
        _logGoogleSignIn(
          'ID token mancante. Possibile problema di SHA-1/SHA-256, package name o configurazione Firebase/Google Sign-In.',
        );
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message:
              'Google Sign-In non ha restituito un ID token valido. Verifica SHA-1, package name e configurazione Firebase.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      _logGoogleSignIn('Invio credenziale Google a Firebase Auth.');

      final userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(_requestTimeout);

      _logGoogleSignIn(
        'Login Firebase completato. UID=${userCredential.user?.uid}, email=${userCredential.user?.email}',
      );
      await _ensureUserProfile(userCredential.user, provider: 'google');
      return userCredential;
    } on FirebaseAuthException catch (e, st) {
      _logGoogleSignIn(
        'FirebaseAuthException durante login Google. code=${e.code}, message=${e.message}',
        e,
        st,
      );
      rethrow;
    } on PlatformException catch (e) {
      final nativeStackTrace = e.stacktrace == null
          ? null
          : StackTrace.fromString(e.stacktrace!);
      _logGoogleSignIn(
        'PlatformException durante login Google. code=${e.code}, message=${e.message}, details=${e.details}',
        e,
        nativeStackTrace,
      );
      throw FirebaseAuthException(
        code: 'google-platform-error',
        message:
            'Errore nativo durante l\'accesso con Google. code=${e.code}${e.message != null ? ', message=${e.message}' : ''}',
      );
    } catch (e, st) {
      _logGoogleSignIn('Errore inatteso durante login Google.', e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<void> _ensureUserProfile(
    User? user, {
    required String provider,
  }) async {
    if (user == null) {
      return;
    }

    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get().timeout(_requestTimeout);

    if (snapshot.exists) {
      await userDoc
          .set({
            'email': user.email ?? '',
            'displayName': user.displayName ?? '',
            'photoUrl': user.photoURL ?? '',
            'provider': provider,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_requestTimeout);
      return;
    }

    final displayName = (user.displayName ?? '').trim();
    final nameParts = displayName.isEmpty
        ? const <String>[]
        : displayName.split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    await userDoc
        .set({
          'uid': user.uid,
          'firstName': firstName,
          'lastName': lastName,
          'displayName': displayName,
          'email': user.email ?? '',
          'residence': '',
          'phone': user.phoneNumber ?? '',
          'referralCode': '',
          'photoUrl': user.photoURL ?? '',
          'provider': provider,
          'roles': ['customer'],
          'accountType': 'customer',
          'status': 'active',
          'managedRefillPointIds': [],
          'managedSponsorIds': [],
          'refillCount': 0,
          'bottleOwnerSince': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_requestTimeout);
  }
}
