import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/market_order.dart';
import '../models/marketplace.dart';

/// Reads and writes Marketplace data in Firestore:
/// `shops`, `shops/{id}/ratings`, `products`, `orders`, and the favourite
/// lists on `users/{uid}`.
class MarketplaceRepository {
  MarketplaceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');
  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Stream<List<Shop>> watchShops() => _shops.snapshots().map(
    (s) => [for (final d in s.docs) Shop.fromMap(d.id, d.data())],
  );

  Stream<List<Product>> watchProducts() => _products
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => [for (final d in s.docs) Product.fromMap(d.id, d.data())]);

  Stream<MarketFavourites> watchFavourites(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => MarketFavourites.fromMap(doc.data()));

  /// Creates a shop and returns its id.
  Future<String> createShop(Shop shop) async {
    final ref = await _shops.add(shop.toNewMap());
    return ref.id;
  }

  Future<String> addProduct(Product product) async {
    final ref = await _products.add(product.toNewMap());
    return ref.id;
  }

  /// Saves changes to a product (owner only; done from the shop page).
  Future<void> updateProduct(Product product) =>
      _products.doc(product.id).update(product.toEditMap());

  Future<void> deleteProduct(String productId) =>
      _products.doc(productId).delete();

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  /// Creates an order request and returns its id.
  Future<String> createOrder(MarketOrder order) async {
    final ref = await _orders.add(order.toNewMap());
    return ref.id;
  }

  Stream<MarketOrder?> watchOrder(String orderId) => _orders
      .doc(orderId)
      .snapshots()
      .map((d) => d.exists ? MarketOrder.fromMap(d.id, d.data()!) : null);

  /// Orders the user placed (as buyer) or received (as seller), newest
  /// first. Sorted here so Firestore needs no composite index.
  Stream<List<MarketOrder>> watchOrders(
    String userId, {
    required bool asSeller,
  }) => _orders
      .where(asSeller ? 'sellerId' : 'buyerId', isEqualTo: userId)
      .snapshots()
      .map((s) {
        final list = [
          for (final d in s.docs) MarketOrder.fromMap(d.id, d.data()),
        ];
        final far = DateTime(3000);
        list.sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
        return list;
      });

  Future<void> setOrderStatus(String orderId, OrderStatus status) =>
      _orders.doc(orderId).update({
        'status': status.name,
        'times.${status.name}': FieldValue.serverTimestamp(),
      });

  Future<void> setFavouriteShop({
    required String userId,
    required String shopId,
    required bool favourite,
  }) => _setFavourite(userId, 'favouriteShops', shopId, favourite);

  Future<void> setFavouriteProduct({
    required String userId,
    required String productId,
    required bool favourite,
  }) => _setFavourite(userId, 'favouriteProducts', productId, favourite);

  Future<void> _setFavourite(
    String userId,
    String field,
    String id,
    bool favourite,
  ) => _firestore.collection('users').doc(userId).set({
    field: favourite
        ? FieldValue.arrayUnion([id])
        : FieldValue.arrayRemove([id]),
  }, SetOptions(merge: true));

  /// The stars [userId] gave [shopId], or null if they have not rated it.
  Future<int?> myRating({
    required String shopId,
    required String userId,
  }) async {
    final doc = await _shops
        .doc(shopId)
        .collection('ratings')
        .doc(userId)
        .get();
    return (doc.data()?['stars'] as num?)?.toInt();
  }

  /// Rates a shop 1–5. One rating per person: rating again replaces the
  /// earlier one, and the shop's totals are kept in step in a transaction.
  Future<void> rateShop({
    required String shopId,
    required String userId,
    required int stars,
  }) {
    final shopRef = _shops.doc(shopId);
    final ratingRef = shopRef.collection('ratings').doc(userId);
    return _firestore.runTransaction((tx) async {
      final previous = await tx.get(ratingRef);
      final before = (previous.data()?['stars'] as num?)?.toInt();
      tx.set(ratingRef, {
        'stars': stars,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(shopRef, {
        'ratingSum': FieldValue.increment(stars - (before ?? 0)),
        if (before == null) 'ratingCount': FieldValue.increment(1),
      });
    });
  }
}
