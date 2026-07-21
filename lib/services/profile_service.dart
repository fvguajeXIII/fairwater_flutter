import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  static const double plasticSavedKgPerRefill = 0.025;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<FairWaterUserProfile> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      return FairWaterUserProfile.fromSnapshot(snapshot);
    });
  }

  Stream<FairWaterCommunityStats> watchCommunityStats() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return FairWaterCommunityStats.fromUsers(snapshot.docs);
    });
  }

  Stream<FairWaterSolidarityImpact> watchSolidarityImpact() {
    return _firestore.collection('community').doc('impact').snapshots().map((
      snapshot,
    ) {
      return FairWaterSolidarityImpact.fromSnapshot(snapshot);
    });
  }

  Future<RecordedRefill> recordCustomerRefill(String qrPayload) async {
    final result = await _functions.httpsCallable('recordCustomerRefill').call({
      'qrPayload': qrPayload,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return RecordedRefill(
      customerName: (data['customerName'] as String? ?? '').trim(),
      customerRefillCount: (data['customerRefillCount'] as num?)?.toInt() ?? 0,
      refillerRefillCount: (data['refillerRefillCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> updateProfileImage({
    required String uid,
    required String photoBase64,
  }) {
    return _firestore.collection('users').doc(uid).set({
      'photoBase64': photoBase64,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FairWaterUserProfile {
  const FairWaterUserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.email,
    required this.residence,
    required this.phone,
    required this.referralCode,
    required this.photoUrl,
    required this.photoBase64,
    required this.provider,
    required this.refillCount,
    required this.createdAt,
    required this.bottleOwnerSince,
    required this.roles,
    required this.accountType,
  });

  factory FairWaterUserProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final firstName = (data['firstName'] as String? ?? '').trim();
    final lastName = (data['lastName'] as String? ?? '').trim();
    final rawDisplayName = (data['displayName'] as String? ?? '').trim();
    final fallbackDisplayName = '$firstName $lastName'.trim();
    final createdAt = _readTimestamp(data['createdAt']);
    final bottleOwnerSince =
        _readTimestamp(data['bottleOwnerSince']) ?? createdAt;

    return FairWaterUserProfile(
      uid: snapshot.id,
      firstName: firstName,
      lastName: lastName,
      displayName: rawDisplayName.isNotEmpty
          ? rawDisplayName
          : fallbackDisplayName,
      email: (data['email'] as String? ?? '').trim(),
      residence: (data['residence'] as String? ?? '').trim(),
      phone: (data['phone'] as String? ?? '').trim(),
      referralCode: (data['referralCode'] as String? ?? '').trim(),
      photoUrl: (data['photoUrl'] as String? ?? '').trim(),
      photoBase64: (data['photoBase64'] as String? ?? '').trim(),
      provider: (data['provider'] as String? ?? '').trim(),
      refillCount: (data['refillCount'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      bottleOwnerSince: bottleOwnerSince,
      roles:
          (data['roles'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const ['user'],
      accountType: (data['accountType'] as String? ?? 'user').trim(),
    );
  }

  final String uid;
  final String firstName;
  final String lastName;
  final String displayName;
  final String email;
  final String residence;
  final String phone;
  final String referralCode;
  final String photoUrl;
  final String photoBase64;
  final String provider;
  final int refillCount;
  final DateTime? createdAt;
  final DateTime? bottleOwnerSince;
  final List<String> roles;
  final String accountType;

  bool get isRefiller =>
      accountType == 'refill_point' || roles.contains('refill_manager');

  String get fullName {
    if (displayName.isNotEmpty) {
      return displayName;
    }
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }
    if (email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Utente FairWater';
  }

  String get initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'FW';
    }
    if (parts.length == 1) {
      final part = parts.first;
      final end = part.length >= 2 ? 2 : 1;
      return part.substring(0, end).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  double get plasticSavedKg =>
      refillCount * ProfileService.plasticSavedKgPerRefill;
}

class RecordedRefill {
  const RecordedRefill({
    required this.customerName,
    required this.customerRefillCount,
    required this.refillerRefillCount,
  });

  final String customerName;
  final int customerRefillCount;
  final int refillerRefillCount;
}

class FairWaterCommunityStats {
  const FairWaterCommunityStats({
    required this.totalMembers,
    required this.totalRefills,
    required this.totalPlasticSavedKg,
  });

  factory FairWaterCommunityStats.fromUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var totalRefills = 0;

    for (final doc in docs) {
      totalRefills += ((doc.data()['refillCount'] as num?)?.toInt() ?? 0);
    }

    return FairWaterCommunityStats(
      totalMembers: docs.length,
      totalRefills: totalRefills,
      totalPlasticSavedKg:
          totalRefills * ProfileService.plasticSavedKgPerRefill,
    );
  }

  final int totalMembers;
  final int totalRefills;
  final double totalPlasticSavedKg;
}

class FairWaterSolidarityImpact {
  const FairWaterSolidarityImpact({
    required this.totalSponsorRevenueEuro,
    required this.fundsForWellsEuro,
    required this.wellsFunded,
    required this.peopleSupported,
    required this.nextWellTargetEuro,
  });

  factory FairWaterSolidarityImpact.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    return FairWaterSolidarityImpact(
      totalSponsorRevenueEuro:
          (data['totalSponsorRevenueEuro'] as num?)?.toDouble() ?? 0,
      fundsForWellsEuro: (data['fundsForWellsEuro'] as num?)?.toDouble() ?? 0,
      wellsFunded: (data['wellsFunded'] as num?)?.toInt() ?? 0,
      peopleSupported: (data['peopleSupported'] as num?)?.toInt() ?? 0,
      nextWellTargetEuro: (data['nextWellTargetEuro'] as num?)?.toDouble() ?? 0,
    );
  }

  final double totalSponsorRevenueEuro;
  final double fundsForWellsEuro;
  final int wellsFunded;
  final int peopleSupported;
  final double nextWellTargetEuro;

  double get nextWellProgress {
    if (nextWellTargetEuro <= 0) {
      return 0;
    }

    final currentCycleEuro = fundsForWellsEuro % nextWellTargetEuro;
    return (currentCycleEuro / nextWellTargetEuro).clamp(0.0, 1.0);
  }

  double get euroMissingForNextWell {
    if (nextWellTargetEuro <= 0) {
      return 0;
    }

    final currentCycleEuro = fundsForWellsEuro % nextWellTargetEuro;
    if (currentCycleEuro == 0 && fundsForWellsEuro > 0) {
      return 0;
    }
    return nextWellTargetEuro - currentCycleEuro;
  }
}

DateTime? _readTimestamp(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return null;
}
