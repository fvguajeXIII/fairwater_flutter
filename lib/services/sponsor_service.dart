import 'package:cloud_firestore/cloud_firestore.dart';

class SponsorSpot {
  const SponsorSpot({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.contribution,
    required this.thankYouMessage,
    required this.supports,
    required this.socialLinks,
    required this.featured,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final String contribution;
  final String thankYouMessage;
  final List<String> supports;
  final Map<String, String> socialLinks;
  final bool featured;

  factory SponsorSpot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    return SponsorSpot(
      id: doc.id,
      name: (data['name'] as String? ?? 'Sponsor FairWater').trim(),
      category: (data['category'] as String? ?? '').trim(),
      address: (data['address'] as String? ?? '').trim(),
      contribution: (data['contribution'] as String? ?? '').trim(),
      thankYouMessage: (data['thankYouMessage'] as String? ?? '').trim(),
      supports: ((data['supports'] as List<dynamic>?) ?? const <dynamic>[])
          .map((support) => support.toString().trim())
          .where((support) => support.isNotEmpty)
          .toList(),
      socialLinks: ((data['socialLinks'] as Map<String, dynamic>?) ??
              const <String, dynamic>{})
          .map(
            (key, value) => MapEntry(
              key.trim(),
              value.toString().trim(),
            ),
          )
        ..removeWhere((key, value) => key.isEmpty || value.isEmpty),
      featured: data['featured'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'address': address,
      'contribution': contribution,
      'thankYouMessage': thankYouMessage,
      'supports': supports,
      'socialLinks': socialLinks,
      'featured': featured,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class SponsorService {
  SponsorService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'sponsors';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Stream<List<SponsorSpot>> watchSponsors() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs.map(SponsorSpot.fromDoc).toList(),
        );
  }
}
