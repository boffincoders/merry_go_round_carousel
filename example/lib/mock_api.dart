import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A travel destination, as returned by the (mock) server.
class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.country,
    required this.icon,
    required this.color,
    required this.price,
    required this.nights,
    required this.rating,
    required this.description,
  });

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        id: json['id'] as String,
        name: json['name'] as String,
        country: json['country'] as String,
        icon: _icons[json['icon']] ?? Icons.place,
        color: _parseHex(json['color'] as String),
        price: json['price'] as int,
        nights: json['nights'] as int,
        rating: (json['rating'] as num).toDouble(),
        description: json['description'] as String,
      );

  final String id;
  final String name;
  final String country;
  final IconData icon;
  final Color color;

  /// Price per person, in rupees.
  final int price;
  final int nights;
  final double rating;
  final String description;

  static const _icons = <String, IconData>{
    'beach': Icons.beach_access,
    'mountain': Icons.landscape,
    'city': Icons.location_city,
    'forest': Icons.forest,
    'boat': Icons.sailing,
    'hiking': Icons.hiking,
    'snow': Icons.ac_unit,
    'sun': Icons.wb_sunny,
  };

  static Color _parseHex(String hex) =>
      Color(int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
}

class MockApiException implements Exception {
  const MockApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Pretends to be a REST API so the example runs offline.
///
/// In a real app, [fetchDestinations] would be something like:
///
/// ```dart
/// final res = await http.get(Uri.parse('https://api.example.com/destinations'));
/// if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
/// final json = jsonDecode(res.body) as List;
/// return json.map((e) => Destination.fromJson(e)).toList();
/// ```
class MockApi {
  int _calls = 0;

  Future<List<Destination>> fetchDestinations({bool fail = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (fail) {
      throw const MockApiException('Server returned 503 Service Unavailable');
    }
    _calls++;

    final json =
        (jsonDecode(_responseBody) as List).cast<Map<String, dynamic>>();

    // Like a live feed, every refresh after the first comes back in a
    // different order with slightly different prices.
    if (_calls > 1) {
      final random = math.Random(_calls);
      json.shuffle(random);
      for (final item in json) {
        item['price'] = (item['price'] as int) + random.nextInt(9) * 500 - 2000;
      }
    }
    return json.map(Destination.fromJson).toList();
  }
}

const _responseBody = '''
[
  {"id": "goa", "name": "Goa", "country": "India", "icon": "beach", "color": "#4DD0E1",
   "price": 18500, "nights": 4, "rating": 4.6,
   "description": "Golden beaches, Portuguese-era churches and seafood shacks by the sea."},
  {"id": "manali", "name": "Manali", "country": "India", "icon": "snow", "color": "#90CAF9",
   "price": 22000, "nights": 5, "rating": 4.5,
   "description": "Snowy peaks, apple orchards and the road up to Rohtang Pass."},
  {"id": "jaipur", "name": "Jaipur", "country": "India", "icon": "city", "color": "#F48FB1",
   "price": 15000, "nights": 3, "rating": 4.4,
   "description": "The Pink City: Amber Fort, Hawa Mahal and busy bazaars."},
  {"id": "kerala", "name": "Kerala", "country": "India", "icon": "boat", "color": "#81C784",
   "price": 26000, "nights": 6, "rating": 4.8,
   "description": "Houseboats on the backwaters, tea gardens and Ayurvedic retreats."},
  {"id": "ladakh", "name": "Ladakh", "country": "India", "icon": "mountain", "color": "#BCAAA4",
   "price": 34000, "nights": 7, "rating": 4.9,
   "description": "High desert passes, Pangong Lake and centuries-old monasteries."},
  {"id": "coorg", "name": "Coorg", "country": "India", "icon": "forest", "color": "#A5D6A7",
   "price": 14000, "nights": 3, "rating": 4.3,
   "description": "Misty coffee estates, waterfalls and quiet forest stays."},
  {"id": "rishikesh", "name": "Rishikesh", "country": "India", "icon": "hiking", "color": "#FFB74D",
   "price": 12500, "nights": 3, "rating": 4.5,
   "description": "River rafting on the Ganges, yoga ashrams and Himalayan treks."},
  {"id": "andaman", "name": "Andaman", "country": "India", "icon": "sun", "color": "#FFD54F",
   "price": 38000, "nights": 6, "rating": 4.7,
   "description": "Turquoise water, coral reefs and the white sand of Radhanagar Beach."}
]
''';
