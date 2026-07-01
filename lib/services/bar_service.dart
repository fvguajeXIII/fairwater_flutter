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
    required this.featured,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final LatLng location;
  final String refillInfo;
  final String openInfo;
  final bool featured;

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
      featured: data['featured'] == true,
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
      'featured': featured,
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
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final bar in _seedBars) {
      batch.set(_collection.doc(bar.id), bar.toMap());
    }
    await batch.commit();
  }
}

const List<BarSpot> _seedBars = [
  BarSpot(
    id: 'caffe-del-duomo',
    name: 'Caffe del Duomo',
    address: 'Piazza Municipio 18',
    city: 'Terracina',
    location: LatLng(41.2916360, 13.2485294),
    refillInfo: 'Refill verificato',
    openInfo: 'OSM',
    featured: true,
  ),
  BarSpot(
    id: 'bar-grande',
    name: 'Bar Grande',
    address: 'Piazza Municipio 12',
    city: 'Terracina',
    location: LatLng(41.2915161, 13.2490918),
    refillInfo: 'Punto refill',
    openInfo: 'OSM',
    featured: false,
  ),
  BarSpot(
    id: 'ready-steady-go',
    name: 'Ready Steady Go!',
    address: 'Via Salita Annunziata 17',
    city: 'Terracina',
    location: LatLng(41.2911870, 13.2496871),
    refillInfo: 'Punto refill',
    openInfo: 'OSM',
    featured: false,
  ),
  BarSpot(
    id: 'artis-cafe',
    name: 'Artis Cafe',
    address: 'Piazza Garibaldi 3;5',
    city: 'Terracina',
    location: LatLng(41.2882868, 13.2534868),
    refillInfo: 'Punto refill',
    openInfo: 'OSM',
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
    featured: false,
  ),
  BarSpot(
    id: 'caffe-del-viale',
    name: 'Caffe del viale',
    address: 'Viale della Vittoria 17',
    city: 'Terracina',
    location: LatLng(41.2882055, 13.2499981),
    refillInfo: 'Punto refill',
    openInfo: 'OSM',
    featured: false,
  ),
  BarSpot(
    id: 'colorado-caffe',
    name: 'Colorado Cafe',
    address: 'Piazza Garibaldi 21',
    city: 'Terracina',
    location: LatLng(41.2884611, 13.2524521),
    refillInfo: 'Punto refill',
    openInfo: 'OSM',
    featured: false,
  ),
  BarSpot(
    id: 'bar-roma',
    name: 'Bar Roma',
    address: 'Via Roma 72',
    city: 'Terracina',
    location: LatLng(41.2892293, 13.2513132),
    refillInfo: 'Punto refill',
    openInfo: 'OSM',
    featured: false,
  ),
  BarSpot(
    id: 'bar-traiano',
    name: 'Bar Traiano',
    address: 'Terracina',
    city: 'Terracina',
    location: LatLng(41.2865912, 13.2532889),
    refillInfo: 'Punto refill',
    openInfo: 'OSM',
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
    featured: false,
  ),
];
