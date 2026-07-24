import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class BarSpot {
  const BarSpot({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.location,
    required this.refillInfo,
    required this.openInfo,
    required this.services,
    required this.socialLinks,
    required this.galleryImages,
    required this.featured,
    this.postalCode = '',
    this.googlePlaceId = '',
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final LatLng location;
  final String refillInfo;
  final String openInfo;
  final List<String> services;
  final Map<String, String> socialLinks;
  final List<String> galleryImages;
  final bool featured;
  final String postalCode;
  final String googlePlaceId;

  factory BarSpot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw StateError('Documento bar senza coordinate: ${doc.id}');
    }

    return BarSpot(
      id: doc.id,
      name: (data['name'] as String? ?? 'Bar senza nome').trim(),
      address: (data['address'] as String? ?? '').trim(),
      city: (data['city'] as String? ?? '').trim(),
      location: LatLng(latitude, longitude),
      refillInfo: (data['refillInfo'] as String? ?? 'Punto refill').trim(),
      openInfo: (data['openInfo'] as String? ?? '').trim(),
      services: ((data['services'] as List<dynamic>?) ?? const <dynamic>[])
          .map((service) => service.toString().trim())
          .where((service) => service.isNotEmpty)
          .toList(),
      socialLinks:
          ((data['socialLinks'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{})
              .map(
                (key, value) => MapEntry(key.trim(), value.toString().trim()),
              )
            ..removeWhere((key, value) => key.isEmpty || value.isEmpty),
      galleryImages:
          ((data['galleryImages'] as List<dynamic>?) ?? const <dynamic>[])
              .map((image) => image.toString().trim())
              .where((image) => image.isNotEmpty)
              .take(6)
              .toList(),
      featured: data['featured'] == true,
      postalCode: (data['postalCode'] as String? ?? '').trim(),
      googlePlaceId: (data['googlePlaceId'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'refillInfo': refillInfo,
      'openInfo': openInfo,
      'services': services,
      'socialLinks': socialLinks,
      'galleryImages': galleryImages,
      'featured': featured,
      'postalCode': postalCode,
      'googlePlaceId': googlePlaceId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class BarService {
  BarService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'bars';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  /// Firestore is the single source of truth shared with the CRM.
  /// Snapshot listeners propagate CRM additions, updates, and deletions live.
  Stream<List<BarSpot>> watchBars() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs.map(BarSpot.fromDoc).toList(),
    );
  }
}
