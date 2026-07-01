import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static const Duration _requestTimeout = Duration(seconds: 20);

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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

  Future<void> signOut() => _auth.signOut();
}
