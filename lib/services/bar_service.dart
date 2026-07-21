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
      openInfo: (data['openInfo'] as String? ?? 'Orari OSM').trim(),
      services: ((data['services'] as List<dynamic>?) ?? const <dynamic>[])
          .map((service) => service.toString().trim())
          .where((service) => service.isNotEmpty)
          .toList(),
      socialLinks: ((data['socialLinks'] as Map<String, dynamic>?) ??
              const <String, dynamic>{})
          .map(
            (key, value) => MapEntry(
              key.trim(),
              value.toString().trim(),
            ),
          )
        ..removeWhere(
          (key, value) => key.isEmpty || value.isEmpty,
        ),
      galleryImages: ((data['galleryImages'] as List<dynamic>?) ??
              _buildDefaultGallery(doc.id))
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
  BarService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'bars';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  Stream<List<BarSpot>> watchBars() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs.map(BarSpot.fromDoc).toList(),
        );
  }

  Future<void> ensureSeedData() async {
    final snapshot = await _collection.get();
    final existingDocs = {
      for (final doc in snapshot.docs) doc.id: doc.data(),
    };
    final batch = _firestore.batch();

    for (final bar in _seedBars) {
      final existingData = existingDocs[bar.id];
      if (existingData == null) {
        batch.set(_collection.doc(bar.id), bar.toMap());
        continue;
      }

      final patch = <String, dynamic>{};

      final openInfo = (existingData['openInfo'] as String? ?? '').trim();
      if (openInfo.isEmpty || openInfo == 'OSM') {
        patch['openInfo'] = bar.openInfo;
      }

      final services = (existingData['services'] as List<dynamic>?) ?? const [];
      if (services.isEmpty) {
        patch['services'] = bar.services;
      }

      final socialLinks =
          (existingData['socialLinks'] as Map<String, dynamic>?) ?? const {};
      if (socialLinks.isEmpty) {
        patch['socialLinks'] = bar.socialLinks;
      }

      final galleryImages =
          (existingData['galleryImages'] as List<dynamic>?) ?? const [];
      if (galleryImages.length < 6) {
        patch['galleryImages'] = bar.galleryImages;
      }

      if (patch.isNotEmpty) {
        patch['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(_collection.doc(bar.id), patch, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }
}

List<String> _buildDefaultGallery(String seed) {
  return List<String>.generate(
    6,
    (index) => 'https://picsum.photos/seed/$seed-${index + 1}/1200/900',
  );
}

final List<BarSpot> _seedBars = [
  BarSpot(
    id: 'caffe-del-duomo',
    name: 'Caffe del Duomo',
    address: 'Piazza Municipio 18',
    city: 'Terracina',
    location: LatLng(41.2916360, 13.2485294),
    refillInfo: 'Refill verificato',
    openInfo: 'Lun-Dom 07:00-23:30',
    services: ['Acqua fresca', 'Bottle refill', 'Tavoli esterni'],
    socialLinks: {
      'instagram': 'https://instagram.com/caffedelduomoterracina',
      'facebook': 'https://facebook.com/caffedelduomoterracina',
    },
    galleryImages: _buildDefaultGallery('caffe-del-duomo'),
    featured: true,
  ),
  BarSpot(
    id: 'bar-grande',
    name: 'Bar Grande',
    address: 'Piazza Municipio 12',
    city: 'Terracina',
    location: LatLng(41.2915161, 13.2490918),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Sab 06:30-22:30',
    services: ['Refill rapido', 'Caffetteria', 'Snack'],
    socialLinks: {
      'instagram': 'https://instagram.com/bargrandeterracina',
      'facebook': 'https://facebook.com/bargrandeterracina',
    },
    galleryImages: _buildDefaultGallery('bar-grande'),
    featured: false,
  ),
  BarSpot(
    id: 'ready-steady-go',
    name: 'Ready Steady Go!',
    address: 'Via Salita Annunziata 17',
    city: 'Terracina',
    location: LatLng(41.2911870, 13.2496871),
    refillInfo: 'Punto refill',
    openInfo: 'Mar-Dom 08:00-00:00',
    services: ['Refill water', 'Brunch', 'Wi-Fi'],
    socialLinks: {
      'instagram': 'https://instagram.com/readysteadygoterracina',
      'facebook': 'https://facebook.com/readysteadygoterracina',
    },
    galleryImages: _buildDefaultGallery('ready-steady-go'),
    featured: false,
  ),
  BarSpot(
    id: 'artis-cafe',
    name: 'Artis Cafe',
    address: 'Piazza Garibaldi 3;5',
    city: 'Terracina',
    location: LatLng(41.2882868, 13.2534868),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 07:00-20:30',
    services: ['Acqua filtrata', 'Dolci', 'Posti a sedere'],
    socialLinks: {
      'instagram': 'https://instagram.com/artiscafeterracina',
      'facebook': 'https://facebook.com/artiscafeterracina',
    },
    galleryImages: _buildDefaultGallery('artis-cafe'),
    featured: false,
  ),
  BarSpot(
    id: 'caffetteria-bar-quadrifoglio',
    name: 'Caffetteria Bar Quadrifoglio',
    address: 'Viale della Vittoria 59',
    city: 'Terracina',
    location: LatLng(41.2855149, 13.2480586),
    refillInfo: 'Punto refill',
    openInfo: 'Mo-Su 07:30-02:00',
    services: ['Refill bottle', 'Cocktail', 'Dehors'],
    socialLinks: {
      'instagram': 'https://instagram.com/barquadrifoglioterracina',
      'facebook': 'https://facebook.com/barquadrifoglioterracina',
    },
    galleryImages: _buildDefaultGallery('caffetteria-bar-quadrifoglio'),
    featured: false,
  ),
  BarSpot(
    id: 'caffe-del-viale',
    name: 'Caffe del viale',
    address: 'Viale della Vittoria 17',
    city: 'Terracina',
    location: LatLng(41.2882055, 13.2499981),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Sab 06:30-21:30',
    services: ['Acqua fresca', 'Colazioni', 'Take away'],
    socialLinks: {
      'instagram': 'https://instagram.com/caffedelviale',
      'facebook': 'https://facebook.com/caffedelviale',
    },
    galleryImages: _buildDefaultGallery('caffe-del-viale'),
    featured: false,
  ),
  BarSpot(
    id: 'colorado-caffe',
    name: 'Colorado Cafe',
    address: 'Piazza Garibaldi 21',
    city: 'Terracina',
    location: LatLng(41.2884611, 13.2524521),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 07:00-01:00',
    services: ['Refill', 'Aperitivi', 'Outdoor seating'],
    socialLinks: {
      'instagram': 'https://instagram.com/coloradocafeterracina',
      'facebook': 'https://facebook.com/coloradocafeterracina',
    },
    galleryImages: _buildDefaultGallery('colorado-caffe'),
    featured: false,
  ),
  BarSpot(
    id: 'bar-roma',
    name: 'Bar Roma',
    address: 'Via Roma 72',
    city: 'Terracina',
    location: LatLng(41.2892293, 13.2513132),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 05:30-23:00',
    services: ['Acqua refrigerata', 'Caffetteria', 'Accessibile'],
    socialLinks: {
      'instagram': 'https://instagram.com/barromaterracina',
      'facebook': 'https://facebook.com/barromaterracina',
    },
    galleryImages: _buildDefaultGallery('bar-roma'),
    featured: false,
  ),
  BarSpot(
    id: 'bar-traiano',
    name: 'Bar Traiano',
    address: 'Terracina',
    city: 'Terracina',
    location: LatLng(41.2865912, 13.2532889),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Sab 07:00-22:00',
    services: ['Refill acqua', 'Snack veloci', 'Tavoli interni'],
    socialLinks: {
      'instagram': 'https://instagram.com/bartraiano',
      'facebook': 'https://facebook.com/bartraiano',
    },
    galleryImages: _buildDefaultGallery('bar-traiano'),
    featured: false,
  ),
  BarSpot(
    id: 'bar-milano',
    name: 'Bar Milano',
    address: 'Piazzale Lido 20',
    city: 'Terracina',
    location: LatLng(41.2845739, 13.2469707),
    refillInfo: 'Punto refill',
    openInfo: 'Mo-Su 07:30-02:00',
    services: ['Refill gratuito', 'Lounge', 'Vista mare'],
    socialLinks: {
      'instagram': 'https://instagram.com/barmilanoterracina',
      'facebook': 'https://facebook.com/barmilanoterracina',
    },
    galleryImages: _buildDefaultGallery('bar-milano'),
    featured: false,
  ),
  BarSpot(
    id: 'caffe-del-corso-fondi',
    name: 'Caffe del Corso',
    address: 'Corso Appio Claudio 44',
    city: 'Fondi',
    location: LatLng(41.3579250, 13.4253160),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 07:00-22:30',
    services: ['Refill acqua', 'Colazioni', 'Tavoli interni'],
    socialLinks: {
      'instagram': 'https://instagram.com/caffedelcorsofondi',
      'facebook': 'https://facebook.com/caffedelcorsofondi',
    },
    galleryImages: _buildDefaultGallery('caffe-del-corso-fondi'),
    featured: true,
  ),
  BarSpot(
    id: 'bar-san-pietro-fondi',
    name: 'Bar San Pietro',
    address: 'Via San Pietro 12',
    city: 'Fondi',
    location: LatLng(41.3568120, 13.4271440),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Sab 06:30-21:30',
    services: ['Refill rapido', 'Caffetteria', 'Snack'],
    socialLinks: {
      'instagram': 'https://instagram.com/barsanpietrofondi',
      'facebook': 'https://facebook.com/barsanpietrofondi',
    },
    galleryImages: _buildDefaultGallery('bar-san-pietro-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'bistrot-castello-fondi',
    name: 'Bistrot Castello',
    address: 'Piazza Unita d Italia 6',
    city: 'Fondi',
    location: LatLng(41.3557440, 13.4280660),
    refillInfo: 'Punto refill',
    openInfo: 'Mar-Dom 08:00-23:00',
    services: ['Refill bottle', 'Brunch', 'Wi-Fi'],
    socialLinks: {
      'instagram': 'https://instagram.com/bistrotcastellofondi',
      'facebook': 'https://facebook.com/bistrotcastellofondi',
    },
    galleryImages: _buildDefaultGallery('bistrot-castello-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'gran-caffe-baronale-fondi',
    name: 'Gran Caffe Baronale',
    address: 'Via Baronale 21',
    city: 'Fondi',
    location: LatLng(41.3549680, 13.4295520),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 07:00-00:00',
    services: ['Acqua fresca', 'Aperitivi', 'Dehors'],
    socialLinks: {
      'instagram': 'https://instagram.com/grancaffebaronalefondi',
      'facebook': 'https://facebook.com/grancaffebaronalefondi',
    },
    galleryImages: _buildDefaultGallery('gran-caffe-baronale-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'lido-urban-cafe-fondi',
    name: 'Lido Urban Cafe',
    address: 'Viale Vittorio Emanuele III 18',
    city: 'Fondi',
    location: LatLng(41.3585110, 13.4311890),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Sab 07:30-22:00',
    services: ['Refill gratuito', 'Take away', 'Posti a sedere'],
    socialLinks: {
      'instagram': 'https://instagram.com/lidourbancafefondi',
      'facebook': 'https://facebook.com/lidourbancafefondi',
    },
    galleryImages: _buildDefaultGallery('lido-urban-cafe-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'caffetteria-porta-romana-fondi',
    name: 'Caffetteria Porta Romana',
    address: 'Via Roma 83',
    city: 'Fondi',
    location: LatLng(41.3539220, 13.4327010),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 06:30-21:00',
    services: ['Acqua refrigerata', 'Dolci', 'Accessibile'],
    socialLinks: {
      'instagram': 'https://instagram.com/caffetteriaportaromanafondi',
      'facebook': 'https://facebook.com/caffetteriaportaromanafondi',
    },
    galleryImages: _buildDefaultGallery('caffetteria-porta-romana-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'vittoria-lounge-fondi',
    name: 'Vittoria Lounge',
    address: 'Viale Regina Margherita 10',
    city: 'Fondi',
    location: LatLng(41.3596740, 13.4239810),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 08:00-01:00',
    services: ['Refill water', 'Cocktail', 'Outdoor seating'],
    socialLinks: {
      'instagram': 'https://instagram.com/vittorialoungefondi',
      'facebook': 'https://facebook.com/vittorialoungefondi',
    },
    galleryImages: _buildDefaultGallery('vittoria-lounge-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'piazza-cafe-fondi',
    name: 'Piazza Cafe',
    address: 'Piazza Alcide De Gasperi 5',
    city: 'Fondi',
    location: LatLng(41.3611020, 13.4278520),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Sab 07:00-20:30',
    services: ['Refill acqua', 'Panini', 'Tavoli esterni'],
    socialLinks: {
      'instagram': 'https://instagram.com/piazzacafefondi',
      'facebook': 'https://facebook.com/piazzacafefondi',
    },
    galleryImages: _buildDefaultGallery('piazza-cafe-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'dolce-pausa-fondi',
    name: 'Dolce Pausa',
    address: 'Via Arnale Rosso 14',
    city: 'Fondi',
    location: LatLng(41.3552860, 13.4239440),
    refillInfo: 'Punto refill',
    openInfo: 'Mar-Dom 07:30-22:30',
    services: ['Refill bottle', 'Pasticceria', 'Wi-Fi'],
    socialLinks: {
      'instagram': 'https://instagram.com/dolcepausafondi',
      'facebook': 'https://facebook.com/dolcepausafondi',
    },
    galleryImages: _buildDefaultGallery('dolce-pausa-fondi'),
    featured: false,
  ),
  BarSpot(
    id: 'le-cinema-sant-anastasia',
    name: 'Le Cinema',
    address: 'Via Roma 343',
    city: 'Sant Anastasia',
    location: LatLng(40.8677610, 14.4025950),
    refillInfo: 'Punto refill',
    openInfo: 'Lun-Dom 16:30-00:30',
    services: ['Refill acqua', 'Area relax', 'Snack bar'],
    socialLinks: {
      'instagram': 'https://instagram.com/lecinemasantanastasia',
      'facebook': 'https://facebook.com/lecinemasantanastasia',
      'website': 'https://lecinema.it',
    },
    galleryImages: _buildDefaultGallery('le-cinema-sant-anastasia'),
    featured: false,
  ),
];
