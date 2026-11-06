import 'package:community/models/chat_models.dart';
import 'package:community/models/market_order.dart';
import 'package:community/models/marketplace.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/repositories/marketplace_repository.dart';
import 'package:community/screens/market_lists_screen.dart';
import 'package:community/screens/marketplace_screen.dart';
import 'package:community/screens/order_screens.dart';
import 'dart:async';
import 'package:community/services/auth_service.dart';
import 'package:community/theme/home_tone.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _User implements User {
  @override
  String get uid => 'me';
  @override
  String? get displayName => 'Mic';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

const _here = LatLng(0.3476, 32.5825);

Shop _shop(
  String id,
  String name,
  MarketCategory c, {
  double dLat = 0,
  int open = 0,
  int close = 0,
  int sum = 0,
  int count = 0,
}) => Shop(
  id: id,
  ownerId: 'owner-$id',
  ownerName: 'Owner',
  name: name,
  category: c,
  latitude: _here.latitude + dLat,
  longitude: _here.longitude,
  openHour: open,
  closeHour: close,
  ratingSum: sum,
  ratingCount: count,
);

Product _product(
  String id,
  String name,
  int price,
  MarketCategory c, {
  String shopId = 'g',
  bool featured = true,
}) => Product(
  id: id,
  shopId: shopId,
  shopName: 'Riverside Grocers',
  ownerId: 'owner-$shopId',
  name: name,
  priceUgx: price,
  category: c,
  featured: featured,
);

class _Repo implements MarketplaceRepository {
  _Repo(this.shops, this.products);
  final List<Shop> shops;
  final List<Product> products;
  final updated = <Product>[];
  final deleted = <String>[];
  final orders = <String, MarketOrder>{};
  final statusChanges = <(String, OrderStatus)>[];
  final _orderStreams = <String, StreamController<MarketOrder?>>{};
  @override
  Future<String> createOrder(MarketOrder order) async {
    final id = 'order${orders.length + 1}';
    orders[id] = order.copyWith(id: id);
    return id;
  }

  @override
  Stream<MarketOrder?> watchOrder(String orderId) {
    final c = _orderStreams[orderId] ??= StreamController.broadcast();
    return (() async* {
      yield orders[orderId];
      yield* c.stream;
    })();
  }

  @override
  Future<void> setOrderStatus(String orderId, OrderStatus status) async {
    statusChanges.add((orderId, status));
    orders[orderId] = orders[orderId]!.copyWith(status: status);
    _orderStreams[orderId]?.add(orders[orderId]);
  }

  @override
  Future<int?> myRating({
    required String shopId,
    required String userId,
  }) async => null;
  @override
  Future<void> updateProduct(Product product) async => updated.add(product);
  @override
  Future<void> deleteProduct(String productId) async => deleted.add(productId);
  @override
  Stream<List<Shop>> watchShops() => Stream.value(shops);
  @override
  Stream<List<Product>> watchProducts() => Stream.value(products);
  @override
  Stream<MarketFavourites> watchFavourites(String userId) =>
      Stream.value(const MarketFavourites());
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Chat implements ChatRepository {
  final sent = <ChatMessage>[];
  String? chattedWith;

  @override
  Future<ChatRoom> createOrGetPrivateChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    chattedWith = otherUserId;
    return ChatRoom(id: 'r', name: '', participantIds: const []);
  }

  @override
  Future<void> sendMessage(String chatRoomId, ChatMessage message) async {
    sent.add(message);
    // Stop before the chat screen opens (it needs Firebase).
    throw Exception('test stop');
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

MarketContext _market(_Repo repo, [_Chat? chat]) => MarketContext(
  authService: _Auth(),
  repository: repo,
  chatRepository: chat,
  currentLocation: _here,
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

void main() {
  test('Order code, time and message', () {
    expect(orderCode('abc'), orderCode('abc'));
    expect(orderCode('abc'), matches(RegExp(r'^CM-\d{4}$')));
    final now = DateTime(2026, 11, 6, 18);
    expect(orderTime(DateTime(2026, 11, 6, 17), now: now), 'Today, 5:00 PM');
    expect(
      orderTime(DateTime(2026, 11, 5, 9, 12), now: now),
      'Yesterday, 9:12 AM',
    );
    final order = MarketOrder(
      id: 'x',
      buyerId: 'me',
      buyerName: 'Mic',
      sellerId: 'owner-g',
      shopId: 'g',
      shopName: 'Riverside Grocers',
      productId: 't',
      productName: 'Fresh Tomatoes',
      unit: '1 kg',
      category: MarketCategory.groceries,
      priceUgx: 4000,
      quantity: 2,
      fulfilment: Fulfilment.pickup,
      note: 'Pick up at 5pm',
    );
    expect(
      orderMessageText(order),
      '🛒 New order request #${order.code}\n'
      'Fresh Tomatoes (1 kg) × 2\n'
      'Total: UGX 8,000 · Pickup\n'
      'Note: Pick up at 5pm',
    );
    expect(
      orderMessageText(order, status: OrderStatus.ready),
      startsWith('📦 Order #${order.code} is now Ready for Pickup'),
    );
  });

  testWidgets('Nearby Shops: count, open now, top rated, filter, search', (
    tester,
  ) async {
    final hour = DateTime.now().hour;
    final repo = _Repo([
      _shop(
        'g',
        'Riverside Grocers',
        MarketCategory.groceries,
        dLat: .002,
        sum: 8,
        count: 2,
      ),
      _shop(
        'b',
        'Neighbourhood Bakery',
        MarketCategory.food,
        dLat: .005,
        sum: 15,
        count: 3,
      ),
      // Closed right now: open for one hour, starting two hours from now.
      _shop(
        'c',
        'Closed Kiosk',
        MarketCategory.other,
        dLat: .001,
        open: (hour + 2) % 24,
        close: (hour + 3) % 24,
      ),
    ], const []);
    await _pump(tester, NearbyShopsScreen(market: _market(repo)));

    expect(find.text('3 shops nearby'), findsOneWidget);
    // Default: nearest first.
    expect(
      tester.getTopLeft(find.text('Closed Kiosk')).dy,
      lessThan(tester.getTopLeft(find.text('Riverside Grocers')).dy),
    );

    await tester.ensureVisible(find.text('Open Now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Now'));
    await tester.pumpAndSettle();
    expect(find.text('Closed Kiosk'), findsNothing);
    expect(find.text('2 shops nearby'), findsOneWidget);

    await tester.ensureVisible(find.text('Top Rated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top Rated'));
    await tester.pumpAndSettle();
    // Bakery 5.0 beats Grocers 4.0.
    expect(
      tester.getTopLeft(find.text('Neighbourhood Bakery')).dy,
      lessThan(tester.getTopLeft(find.text('Riverside Grocers')).dy),
    );

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food & Drinks'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // close the sheet
    await tester.pumpAndSettle();
    expect(find.text('Riverside Grocers'), findsNothing);
    expect(find.text('1 shop nearby'), findsOneWidget);

    await tester.ensureVisible(find.text('All Shops'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Shops'));
    await tester.tap(find.byTooltip('Search shops'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bak');
    await tester.pumpAndSettle();
    expect(find.text('Neighbourhood Bakery'), findsOneWidget);
    expect(find.text('View Shop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Featured Products: featured only, sort, category, order', (
    tester,
  ) async {
    final chat = _Chat();
    final repo = _Repo(
      [
        _shop(
          'g',
          'Riverside Grocers',
          MarketCategory.groceries,
          sum: 9,
          count: 2,
        ),
      ],
      [
        _product('t', 'Fresh Tomatoes', 4000, MarketCategory.groceries),
        _product('e', 'Wireless Earbuds', 85000, MarketCategory.electronics),
        _product('s', 'Cotton T-Shirt', 20000, MarketCategory.fashion),
        _product(
          'x',
          'Not Featured',
          1000,
          MarketCategory.groceries,
          featured: false,
        ),
      ],
    );
    await _pump(tester, FeaturedProductsScreen(market: _market(repo, chat)));

    expect(find.text('3 featured products'), findsOneWidget);
    expect(find.text('Not Featured'), findsNothing);
    expect(find.text('UGX 85,000'), findsOneWidget);

    // Sort by price, low to high.
    await tester.tap(find.text('Sort: Featured'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price: low to high'));
    await tester.pumpAndSettle();
    final tomatoes = tester.getTopLeft(find.text('Fresh Tomatoes'));
    final earbuds = tester.getTopLeft(find.text('Wireless Earbuds'));
    expect(
      tomatoes.dy < earbuds.dy ||
          (tomatoes.dy == earbuds.dy && tomatoes.dx < earbuds.dx),
      isTrue,
    );

    // Category chip.
    await tester.ensureVisible(find.text('Electronics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electronics'));
    await tester.pumpAndSettle();
    expect(find.text('1 featured product'), findsOneWidget);
    expect(find.text('Fresh Tomatoes'), findsNothing);

    // Purchase opens screen 1, Product Details (read-only).
    await tester.tap(find.text('Purchase'));
    await tester.pumpAndSettle();
    expect(find.text('Product Details'), findsNWidgets(2));
    expect(find.text('In Stock'), findsOneWidget);
    expect(find.byTooltip('Share Wireless Earbuds'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    await tester.tap(find.text('Product Details').last);
    await tester.pumpAndSettle();
    expect(find.text('Sold by'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Edit Product'), findsNothing);

    // Request Order: 2 earbuds, delivered, with a note.
    await tester.tap(find.text('Request Order'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Fulfilment Method', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(find.text('UGX 170,000'), findsOneWidget);
    await tester.tap(find.text('Delivery'));
    await tester.enterText(find.byType(TextField), 'Before 6pm please');
    await tester.tap(find.text('Send Order Request'));
    await tester.pumpAndSettle();
    final order = repo.orders['order1']!;
    expect(order.quantity, 2);
    expect(order.totalUgx, 170000);
    expect(order.fulfilment, Fulfilment.delivery);
    expect(order.note, 'Before 6pm please');
    expect(order.buyerId, 'me');
    expect(order.sellerId, 'owner-g');
    // The seller also gets a heads-up in Messages.
    expect(chat.chattedWith, 'owner-g');
    expect(chat.sent.single.content, contains('Wireless Earbuds × 2'));

    // Order Request Sent, then the tracking page.
    expect(find.text('Order Request Sent!'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    await tester.tap(find.text('View Order'));
    await tester.pumpAndSettle();
    expect(find.text('Order #${order.code}'), findsOneWidget);
    expect(find.text('Out for Delivery'), findsOneWidget);

    // The buyer cancels while it is still pending.
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Order').last);
    await tester.pumpAndSettle();
    expect(repo.statusChanges.single.$2, OrderStatus.cancelled);
    expect(find.text('This order was cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The seller moves an order through each step', (tester) async {
    final repo = _Repo([], []);
    repo.orders['o'] = MarketOrder(
      id: 'o',
      buyerId: 'buyer',
      buyerName: 'Amina',
      sellerId: 'me',
      shopId: 'm',
      shopName: 'Mic Snacks',
      productId: 'p',
      productName: 'Samosa',
      category: MarketCategory.food,
      priceUgx: 1000,
      quantity: 3,
      fulfilment: Fulfilment.pickup,
    );
    await _pump(
      tester,
      OrderDetailsScreen(market: _market(repo, _Chat()), orderId: 'o'),
    );
    expect(find.text('From Amina'), findsOneWidget);
    for (final step in [
      'Accept Order',
      'Start Preparing',
      'Mark Ready',
      'Mark Completed',
    ]) {
      await tester.tap(find.text(step));
      await tester.pumpAndSettle();
    }
    expect(repo.statusChanges.map((c) => c.$2), [
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.completed,
    ]);
    expect(find.text('Completed'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Owners edit and remove products only from their shop', (
    tester,
  ) async {
    final mine = Shop(
      id: 'm',
      ownerId: 'me',
      ownerName: 'Mic',
      name: 'Mic Snacks',
      category: MarketCategory.food,
      latitude: _here.latitude,
      longitude: _here.longitude,
    );
    final repo = _Repo(
      [mine],
      [
        Product(
          id: 'p1',
          shopId: 'm',
          shopName: 'Mic Snacks',
          ownerId: 'me',
          name: 'Samosa',
          featured: true,
          priceUgx: 1000,
          category: MarketCategory.food,
        ),
      ],
    );
    final market = _market(repo, _Chat());

    // In the product list a seller sees View and Purchase like everyone.
    await _pump(tester, FeaturedProductsScreen(market: market));
    expect(find.text('View'), findsOneWidget);
    await tester.tap(find.text('Purchase'));
    await tester.pumpAndSettle();
    // Screen 1 has Chat and Request Order even on your own product: you
    // can still buy it. Chat explains there's nobody to chat to.
    expect(find.text('Product Details'), findsWidgets);
    // The Chat label is purple (not the theme's near-white).
    final chatText = tester.widget<RichText>(
      find.descendant(of: find.text('Chat'), matching: find.byType(RichText)),
    );
    expect(chatText.text.style?.color, HomeTone.violet);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This is your shop'), findsOneWidget);
    await tester.tap(find.text('Request Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Order Request'));
    await tester.pumpAndSettle();
    expect(repo.orders.values.single.buyerId, 'me');
    expect(repo.orders.values.single.sellerId, 'me');
    expect(find.text('Order Request Sent!'), findsOneWidget);
    expect(find.text('Chat with Vendor'), findsNothing);

    // From the shop page the owner can edit the product.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, ShopScreen(market: market, shopId: 'm'));
    await tester.tap(find.text('Samosa'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Product'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '1000'), '1500');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repo.updated.single.id, 'p1');
    expect(repo.updated.single.priceUgx, 1500);

    // ...and remove it.
    await tester.tap(find.text('Samosa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove this product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['p1']);
    expect(tester.takeException(), isNull);
  });
}
