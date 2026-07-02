import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const Duration _requestTimeout = Duration(seconds: 20);

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        )
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
          'email': email.trim(),
          'residence': residence.trim(),
          'phone': phone?.trim() ?? '',
          'referralCode': referralCode?.trim() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_requestTimeout);

    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final credential = await _auth
          .signInWithPopup(provider)
          .timeout(_requestTimeout);
      await _ensureUserProfile(credential.user);
      return credential;
    }

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'sign_in_canceled',
          message: 'Accesso con Google annullato.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message:
              'Google Sign-In non ha restituito un ID token valido. Verifica SHA-1, package name e configurazione Firebase.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(_requestTimeout);

      await _ensureUserProfile(userCredential.user);
      return userCredential;
    } on PlatformException catch (e) {
      throw FirebaseAuthException(
        code: 'google-platform-error',
        message: e.message ?? 'Errore nativo durante l\'accesso con Google.',
      );
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<void> _ensureUserProfile(User? user) async {
    if (user == null) {
      return;
    }

    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get().timeout(_requestTimeout);

    if (snapshot.exists) {
      await userDoc.update({
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoUrl': user.photoURL ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_requestTimeout);
      return;
    }

    final displayName = (user.displayName ?? '').trim();
    final nameParts = displayName.isEmpty
        ? const <String>[]
        : displayName.split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    await userDoc.set({
      'uid': user.uid,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName,
      'email': user.email ?? '',
      'residence': '',
      'phone': user.phoneNumber ?? '',
      'referralCode': '',
      'photoUrl': user.photoURL ?? '',
      'provider': 'google',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_requestTimeout);
  }
}
