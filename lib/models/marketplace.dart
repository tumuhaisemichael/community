import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Kinds of shop and product in the Marketplace.
enum MarketCategory {
  groceries('Groceries', Icons.shopping_basket_outlined, Color(0xFF22A45D)),
  food('Food & Drinks', Icons.restaurant_rounded, Color(0xFFF26B1D)),
  fashion('Fashion', Icons.checkroom_rounded, Color(0xFFDB2777)),
  electronics('Electronics', Icons.smartphone_rounded, Color(0xFF2563EB)),
  home('Home & Living', Icons.chair_outlined, Color(0xFF7C3AED)),
  beauty('Health & Beauty', Icons.spa_outlined, Color(0xFF0D9488)),
  services('Services', Icons.handyman_outlined, Color(0xFFB45309)),
  other('Other', Icons.storefront_outlined, Color(0xFF6B6485));

  const MarketCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  static MarketCategory parse(Object? value) => MarketCategory.values
      .firstWhere((c) => c.name == value, orElse: () => MarketCategory.other);
}

/// A shop run by a neighbour (`shops/{id}`).
class Shop {
  const Shop({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.name,
    required this.category,
    this.description = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.openHour = 8,
    this.closeHour = 20,
    this.isVerified = false,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.createdAt,
    this.contactPreference = 'chat',
    this.phone = '',
    this.registrationNumber = '',
    this.verificationRequested = false,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String name;
  final MarketCategory category;
  final String description;
  final String address;
  final double? latitude;
  final double? longitude;

  /// Opening hours, 0–24 (closeHour may be 24 for midnight).
  final int openHour;
  final int closeHour;
  final bool isVerified;

  /// Sum and number of 1–5 star ratings; see [rating].
  final int ratingSum;
  final int ratingCount;
  final DateTime? createdAt;

  /// How customers reach the owner: 'chat' (in-app messages only) or
  /// 'phone' (calls as well as messages).
  final String contactPreference;

  /// Phone number, when [contactPreference] is 'phone'.
  final String phone;

  /// Optional business registration number, for an admin to check.
  final String registrationNumber;

  /// The owner asked an admin to verify the shop.
  final bool verificationRequested;

  bool get acceptsCalls => contactPreference == 'phone' && phone.isNotEmpty;

  /// Average stars, or null if nobody has rated the shop yet.
  double? get rating => ratingCount == 0 ? null : ratingSum / ratingCount;

  bool get hasLocation => latitude != null && longitude != null;

  /// Whether the shop is open at [time] (now by default).
  bool isOpenAt([DateTime? time]) {
    final hour = (time ?? DateTime.now()).hour;
    if (openHour == closeHour) return true; // open all day
    if (openHour < closeHour) return hour >= openHour && hour < closeHour;
    return hour >= openHour || hour < closeHour; // past midnight
  }

  String get hoursLabel {
    String fmt(int h) {
      final hour = h % 24;
      final suffix = hour < 12 ? 'AM' : 'PM';
      final twelve = hour % 12 == 0 ? 12 : hour % 12;
      return '$twelve $suffix';
    }

    return openHour == closeHour
        ? 'Open 24 hours'
        : '${fmt(openHour)} – ${fmt(closeHour)}';
  }

  factory Shop.fromMap(String id, Map<String, dynamic> data) => Shop(
    id: id,
    ownerId: data['ownerId'] as String? ?? '',
    ownerName: data['ownerName'] as String? ?? 'Neighbour',
    name: data['name'] as String? ?? 'Shop',
    category: MarketCategory.parse(data['category']),
    description: data['description'] as String? ?? '',
    address: data['address'] as String? ?? '',
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    openHour: (data['openHour'] as num?)?.toInt() ?? 8,
    closeHour: (data['closeHour'] as num?)?.toInt() ?? 20,
    isVerified: data['isVerified'] == true,
    ratingSum: (data['ratingSum'] as num?)?.toInt() ?? 0,
    ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
    createdAt: _dateOf(data['createdAt']),
    contactPreference: data['contactPreference'] as String? ?? 'chat',
    phone: data['phone'] as String? ?? '',
    registrationNumber: data['registrationNumber'] as String? ?? '',
    verificationRequested: data['verificationRequested'] == true,
  );

  /// Fields written when a shop is created. Ratings and verification are
  /// not set here: they start at zero / false.
  Map<String, dynamic> toNewMap() => {
    'ownerId': ownerId,
    'ownerName': ownerName,
    'name': name,
    'category': category.name,
    'description': description,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'openHour': openHour,
    'closeHour': closeHour,
    'isVerified': false,
    'ratingSum': 0,
    'ratingCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
    'contactPreference': contactPreference,
    'phone': phone,
    'registrationNumber': registrationNumber,
    'verificationRequested': verificationRequested,
  };
}

/// Something a shop sells (`products/{id}`).
class Product {
  const Product({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.ownerId,
    required this.name,
    required this.priceUgx,
    required this.category,
    this.description = '',
    this.featured = false,
    this.unit = '',
    this.inStock = true,
    this.createdAt,
  });

  final String id;
  final String shopId;
  final String shopName;
  final String ownerId;
  final String name;

  /// Price in Ugandan shillings (whole numbers).
  final int priceUgx;
  final MarketCategory category;
  final String description;

  /// Shown under "Featured Products".
  final bool featured;

  /// What one price buys, e.g. "1 kg" (optional).
  final String unit;
  final bool inStock;
  final DateTime? createdAt;

  /// Name with the unit, e.g. "Fresh Tomatoes (1 kg)".
  String get displayName => unit.isEmpty ? name : '$name ($unit)';

  factory Product.fromMap(String id, Map<String, dynamic> data) => Product(
    id: id,
    shopId: data['shopId'] as String? ?? '',
    shopName: data['shopName'] as String? ?? '',
    ownerId: data['ownerId'] as String? ?? '',
    name: data['name'] as String? ?? 'Product',
    priceUgx: (data['priceUgx'] as num?)?.toInt() ?? 0,
    category: MarketCategory.parse(data['category']),
    description: data['description'] as String? ?? '',
    featured: data['featured'] == true,
    unit: data['unit'] as String? ?? '',
    inStock: data['inStock'] != false,
    createdAt: _dateOf(data['createdAt']),
  );

  Map<String, dynamic> toNewMap() => {
    'shopId': shopId,
    'shopName': shopName,
    'ownerId': ownerId,
    'name': name,
    'priceUgx': priceUgx,
    'category': category.name,
    'description': description,
    'featured': featured,
    'unit': unit,
    'inStock': inStock,
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// Fields an owner may change later (not the shop, owner or date).
  Map<String, dynamic> toEditMap() => {
    'name': name,
    'priceUgx': priceUgx,
    'category': category.name,
    'description': description,
    'featured': featured,
    'unit': unit,
    'inStock': inStock,
  };
}

/// The user's ♡ shops and products (`users/{uid}.favouriteShops/Products`).
class MarketFavourites {
  const MarketFavourites({this.shops = const {}, this.products = const {}});
  final Set<String> shops;
  final Set<String> products;

  factory MarketFavourites.fromMap(Map<String, dynamic>? data) =>
      MarketFavourites(
        shops: {...List<String>.from(data?['favouriteShops'] ?? const [])},
        products: {
          ...List<String>.from(data?['favouriteProducts'] ?? const []),
        },
      );
}

/// A Firestore time, or null for anything else (missing, or a pending
/// server timestamp).
DateTime? _dateOf(Object? value) => value is Timestamp ? value.toDate() : null;
