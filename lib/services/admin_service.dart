import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AdminRole {
  superAdmin,
  admin,
  refillManager,
  sponsorManager,
}

extension AdminRoleExtension on AdminRole {
  String get value {
    switch (this) {
      case AdminRole.superAdmin:
        return 'super_admin';
      case AdminRole.admin:
        return 'admin';
      case AdminRole.refillManager:
        return 'refill_manager';
      case AdminRole.sponsorManager:
        return 'sponsor_manager';
    }
  }

  String get displayName {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.admin:
        return 'Admin';
      case AdminRole.refillManager:
        return 'Refill Manager';
      case AdminRole.sponsorManager:
        return 'Sponsor Manager';
    }
  }
}

class AdminService {
  AdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String usersCollection = 'users';
  static const String adminsCollection = 'admins';

  /// Ottieni i ruoli admin dell'utente corrente
  Future<List<AdminRole>> getCurrentUserAdminRoles() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(user.uid)
          .get();

      if (!doc.exists) return [];

      final roles = (doc['roles'] as List<dynamic>?)?.cast<String>() ?? [];
      return roles
          .map((role) => _stringToAdminRole(role))
          .whereType<AdminRole>()
          .toList();
    } catch (e) {
      debugPrint('Errore nel recupero dei ruoli admin: $e');
      return [];
    }
  }

  /// Verifica se l'utente è un admin
  Future<bool> isUserAdmin() async {
    final roles = await getCurrentUserAdminRoles();
    return roles.isNotEmpty;
  }

  /// Verifica se l'utente è super admin
  Future<bool> isUserSuperAdmin() async {
    final roles = await getCurrentUserAdminRoles();
    return roles.contains(AdminRole.superAdmin);
  }

  /// Verifica se l'utente ha un ruolo specifico
  Future<bool> userHasRole(AdminRole role) async {
    final roles = await getCurrentUserAdminRoles();
    return roles.contains(role);
  }

  /// Assegna un ruolo admin a un utente (solo per super admin)
  Future<void> assignAdminRole({
    required String userId,
    required AdminRole role,
  }) async {
    final isSuperAdmin = await isUserSuperAdmin();
    if (!isSuperAdmin) {
      throw Exception('Solo i Super Admin possono assegnare ruoli');
    }

    final userDoc = await _firestore
        .collection(usersCollection)
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      throw Exception('Utente non trovato');
    }

    final roles = (userDoc['roles'] as List<dynamic>?)?.cast<String>() ?? [];
    if (!roles.contains(role.value)) {
      roles.add(role.value);
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .update({'roles': roles});
    }
  }

  /// Rimuovi un ruolo admin da un utente (solo per super admin)
  Future<void> removeAdminRole({
    required String userId,
    required AdminRole role,
  }) async {
    final isSuperAdmin = await isUserSuperAdmin();
    if (!isSuperAdmin) {
      throw Exception('Solo i Super Admin possono rimuovere ruoli');
    }

    final userDoc = await _firestore
        .collection(usersCollection)
        .doc(userId)
        .get();

    if (!userDoc.exists) {
      throw Exception('Utente non trovato');
    }

    final roles = (userDoc['roles'] as List<dynamic>?)?.cast<String>() ?? [];
    roles.removeWhere((r) => r == role.value);

    await _firestore
        .collection(usersCollection)
        .doc(userId)
        .update({'roles': roles});
  }

  /// Ottieni tutti gli admin
  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('roles', arrayContains: 'admin')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Errore nel recupero degli admin: $e');
      return [];
    }
  }

  AdminRole? _stringToAdminRole(String roleString) {
    switch (roleString) {
      case 'super_admin':
        return AdminRole.superAdmin;
      case 'admin':
        return AdminRole.admin;
      case 'refill_manager':
        return AdminRole.refillManager;
      case 'sponsor_manager':
        return AdminRole.sponsorManager;
      default:
        return null;
    }
  }
}

// Aggiungi questo import in debug
void debugPrint(String message) {
  // Implementazione di debug print se necessario
}
