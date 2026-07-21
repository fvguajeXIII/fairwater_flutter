import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AddressSuggestion {
  const AddressSuggestion({
    required this.placeId,
    required this.label,
    required this.mainText,
    required this.secondaryText,
  });

  final String placeId;
  final String label;
  final String mainText;
  final String secondaryText;
}

class AddressDetails {
  const AddressDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.streetNumber,
    required this.route,
    required this.city,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.website,
    required this.openingHours,
    required this.services,
  });

  final String placeId;
  final String formattedAddress;
  final String streetNumber;
  final String route;
  final String city;
  final String postalCode;
  final double latitude;
  final double longitude;
  final String name;
  final String website;
  final String openingHours;
  final List<String> services;

  factory AddressDetails.fromGeoapify(Map<String, dynamic> place) {
    final latitude = (place['lat'] as num?)?.toDouble();
    final longitude = (place['lon'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('Coordinate del luogo non disponibili.');
    }

    return AddressDetails(
      placeId: (place['place_id'] as String? ?? '').trim(),
      formattedAddress: (place['formatted'] as String? ?? '').trim(),
      streetNumber: (place['housenumber'] as String? ?? '').trim(),
      route: (place['street'] as String? ?? '').trim(),
      city: _firstNonEmpty(place, const ['city', 'town', 'village', 'county']),
      postalCode: (place['postcode'] as String? ?? '').trim(),
      latitude: latitude,
      longitude: longitude,
      name: (place['name'] as String? ?? '').trim(),
      website: (place['website'] as String? ?? '').trim(),
      openingHours: (place['opening_hours'] as String? ?? '').trim(),
      services: _servicesFromGeoapify(place),
    );
  }
}

class AddressSearchService {
  AddressSearchService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, AddressDetails> _detailsByPlaceId = {};

  Future<List<AddressSuggestion>> autocomplete({
    required String query,
    required String sessionToken,
  }) async {
    if (geoapifyApiKey.isEmpty) {
      throw StateError('GEOAPIFY_API_KEY non configurata.');
    }

    final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': query,
      'format': 'json',
      'lang': 'it',
      'limit': '8',
      'filter': 'countrycode:it',
      'bias': 'proximity:13.35,41.30',
      'apiKey': geoapifyApiKey,
    });
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Geoapify ha risposto con ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (payload['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    _detailsByPlaceId.clear();

    final suggestions = <AddressSuggestion>[];
    for (final place in results) {
      final details = AddressDetails.fromGeoapify(place);
      if (details.placeId.isEmpty || details.formattedAddress.isEmpty) continue;
      _detailsByPlaceId[details.placeId] = details;
      suggestions.add(
        AddressSuggestion(
          placeId: details.placeId,
          label: details.formattedAddress,
          mainText: (place['address_line1'] as String? ?? '').trim(),
          secondaryText: (place['address_line2'] as String? ?? '').trim(),
        ),
      );
    }
    return suggestions;
  }

  Future<AddressDetails> details({
    required String placeId,
    required String sessionToken,
  }) async {
    if (geoapifyApiKey.isEmpty) {
      throw StateError('GEOAPIFY_API_KEY non configurata.');
    }
    if (!_detailsByPlaceId.containsKey(placeId)) {
      throw StateError('Seleziona nuovamente il luogo dai risultati.');
    }

    final uri = Uri.https('api.geoapify.com', '/v2/place-details', {
      'id': placeId,
      'features': 'details',
      'lang': 'it',
      'apiKey': geoapifyApiKey,
    });
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Geoapify ha risposto con ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final features = payload['features'] as List<dynamic>? ?? const [];
    final feature = features.whereType<Map<String, dynamic>>().firstWhere(
      (item) =>
          (item['properties'] as Map<String, dynamic>?)?['feature_type'] ==
          'details',
      orElse: () => const <String, dynamic>{},
    );
    final properties = feature['properties'] as Map<String, dynamic>?;
    if (properties == null) {
      return _detailsByPlaceId[placeId]!;
    }
    return AddressDetails.fromGeoapify(properties);
  }
}

String _firstNonEmpty(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = (source[key] as String? ?? '').trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

List<String> _servicesFromGeoapify(Map<String, dynamic> place) {
  const labels = <String, String>{
    'internet_access': 'Wi-Fi',
    'wheelchair': 'Accessibile',
    'outdoor_seating': 'Tavoli esterni',
    'takeaway': 'Take away',
    'delivery': 'Consegna',
    'toilets': 'Servizi igienici',
    'air_conditioning': 'Aria condizionata',
  };
  return [
    for (final entry in labels.entries)
      if (place[entry.key] == true || place[entry.key] == 'yes') entry.value,
  ];
}
