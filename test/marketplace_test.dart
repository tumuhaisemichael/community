import 'package:community/models/marketplace.dart';
import 'package:community/repositories/marketplace_repository.dart';
import 'package:community/screens/marketplace_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/widgets/home_overview.dart';
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
  String owner = 'someone',
  int open = 0,
  int close = 0,
  int sum = 0,
  int count = 0,
}) => Shop(
  id: id,
  ownerId: owner,
  ownerName: 'Owner $id',
  name: name,
  category: c,
  latitude: _here.latitude + dLat,
  longitude: _here.longitude,
  openHour: open,
  closeHour: close,
  ratingSum: sum,
  ratingCount: count,
);

class _Repo implements MarketplaceRepository {
  _Repo(this.shops, this.products);
  final List<Shop> shops;
  final List<Product> products;
  final created = <Shop>[];
  final favShops = <String, bool>{};
  final ratings = <String, int>{};

  @override
  Stream<List<Shop>> watchShops() => Stream.value(shops);
  @override
  Stream<List<Product>> watchProducts() => Stream.value(products);
  @override
  Stream<MarketFavourites> watchFavourites(String userId) =>
      Stream.value(const MarketFavourites());
  @override
  Future<String> createShop(Shop shop) async {
    created.add(shop);
    return 'new';
  }

  @override
  Future<void> setFavouriteShop({
    required String userId,
    required String shopId,
    required bool favourite,
  }) async => favShops[shopId] = favourite;
  @override
  Future<int?> myRating({
    required String shopId,
    required String userId,
  }) async => null;
  @override
  Future<void> rateShop({
    required String shopId,
    required String userId,
    required int stars,
  }) async => ratings[shopId] = stars;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<_Repo> _open(WidgetTester tester, _Repo repo) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MarketplaceScreen(
        authService: _Auth(),
        repository: repo,
        currentLocation: _here,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('Marketplace data', () {
    test('Shop and product save and load', () {
      final shop = _shop('s', 'Bakery', MarketCategory.food, sum: 9, count: 2);
      final map = shop.toNewMap();
      expect(map['category'], 'food');
      expect(map['ratingCount'], 0); // new shops always start unrated
      final read = Shop.fromMap('s', {
        ...map,
        'ratingSum': 9,
        'ratingCount': 2,
      });
      expect(read.name, 'Bakery');
      expect(read.category, MarketCategory.food);
      expect(read.rating, 4.5);

      final product = Product(
        id: 'p',
        shopId: 's',
        shopName: 'Bakery',
        ownerId: 'o',
        name: 'Bread',
        priceUgx: 5000,
        category: MarketCategory.food,
        featured: true,
      );
      final p = Product.fromMap('p', product.toNewMap());
      expect(p.priceUgx, 5000);
      expect(p.featured, isTrue);
    });

    test('Old or partial records load with safe defaults', () {
      final shop = Shop.fromMap('x', const {'name': 'Kiosk'});
      expect(shop.category, MarketCategory.other);
      expect(shop.rating, isNull);
      expect(shop.hasLocation, isFalse);
      expect(Product.fromMap('y', const {}).priceUgx, 0);
    });

    test('Opening hours, including past midnight', () {
      final day = Shop.fromMap('a', const {'openHour': 8, 'closeHour': 20});
      expect(day.isOpenAt(DateTime(2026, 1, 1, 9)), isTrue);
      expect(day.isOpenAt(DateTime(2026, 1, 1, 21)), isFalse);
      final night = Shop.fromMap('b', const {'openHour': 18, 'closeHour': 2});
      expect(night.isOpenAt(DateTime(2026, 1, 1, 23)), isTrue);
      expect(night.isOpenAt(DateTime(2026, 1, 1, 1)), isTrue);
      expect(night.isOpenAt(DateTime(2026, 1, 1, 12)), isFalse);
    });
  });

  testWidgets('Nearby shops: nearest first, area limit, filters, favourite', (
    tester,
  ) async {
    final repo = await _open(
      tester,
      _Repo(
        [
          _shop('far', 'Far Mart', MarketCategory.groceries, dLat: .2),
          _shop('b', 'Neighbourhood Bakery', MarketCategory.food, dLat: .005),
          _shop('g', 'Riverside Grocers', MarketCategory.groceries, dLat: .002),
        ],
        const [
          Product(
            id: 'p',
            shopId: 'b',
            shopName: 'Neighbourhood Bakery',
            ownerId: 'someone',
            name: 'Bread Loaf',
            priceUgx: 5000,
            category: MarketCategory.food,
            featured: true,
          ),
        ],
      ),
    );

    expect(find.text('Within 5 km of you'), findsOneWidget);
    // ~22 km away: outside the 5 km area.
    expect(find.text('Far Mart'), findsNothing);
    // Nearest first.
    expect(
      tester.getTopLeft(find.text('Riverside Grocers')).dx,
      lessThan(tester.getTopLeft(find.text('Neighbourhood Bakery')).dx),
    );
    expect(find.text('Bread Loaf'), findsOneWidget);
    expect(find.text('UGX 5,000'), findsOneWidget);

    // Category tile filters.
    await tester.tap(find.bySemanticsLabel('Food & Drinks'));
    await tester.pumpAndSettle();
    expect(find.text('Riverside Grocers'), findsNothing);
    expect(find.text('Neighbourhood Bakery'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Food & Drinks'));
    await tester.pumpAndSettle();

    // Search.
    await tester.enterText(find.byType(TextField), 'grocer');
    await tester.pumpAndSettle();
    expect(find.text('Neighbourhood Bakery'), findsNothing);
    expect(find.text('Riverside Grocers'), findsOneWidget);

    // Favourite.
    await tester.tap(find.bySemanticsLabel('Save Riverside Grocers'));
    await tester.pumpAndSettle();
    expect(repo.favShops, {'g': true});
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start Selling creates a shop; rating a shop saves stars', (
    tester,
  ) async {
    final repo = await _open(
      tester,
      _Repo([
        _shop('g', 'Riverside Grocers', MarketCategory.groceries),
      ], const []),
    );
    await tester.ensureVisible(find.text('Start Selling'));
    await tester.tap(find.text('Start Selling'));
    await tester.pumpAndSettle();

    // Step 1: details. Continuing without a category is blocked.
    expect(find.text('Step 1 of 4'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Mic’s Snacks');
    await tester.enterText(find.byType(TextField).at(1), 'Samosas and juice');
    await tester.tap(find.text('Continue to Location'));
    await tester.pump();
    expect(find.text('Please choose a business category.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Food & Drinks'));
    await tester.tap(find.text('Phone & Chat'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number'),
      '0772 123456',
    );
    await tester.ensureVisible(find.text('Continue to Location'));
    await tester.tap(find.text('Continue to Location'));
    await tester.pumpAndSettle();

    // Step 2: location is already set from where you are.
    expect(find.text('Step 2 of 4'), findsOneWidget);
    await tester.tap(find.text('Continue to Verification'));
    await tester.pumpAndSettle();

    // Step 3: guidelines must be agreed.
    await tester.enterText(find.byType(TextField).first, 'URSB-123');
    await tester.tap(find.text('Continue to Review'));
    // The earlier message slides away first, then this one appears.
    await tester.pumpAndSettle();
    expect(
      find.text('Please agree to the selling guidelines.'),
      findsOneWidget,
    );
    for (final box in find.byType(Checkbox).evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Review'));
    await tester.pumpAndSettle();

    // Step 4: review and create.
    expect(find.text('Step 4 of 4'), findsOneWidget);
    await tester.tap(find.text('Create My Shop'));
    await tester.pump();
    expect(repo.created.single.name, 'Mic’s Snacks');
    expect(repo.created.single.ownerId, 'me');
    expect(repo.created.single.latitude, _here.latitude);
    expect(repo.created.single.category, MarketCategory.food);
    expect(repo.created.single.contactPreference, 'phone');
    expect(repo.created.single.phone, '0772 123456');
    expect(repo.created.single.registrationNumber, 'URSB-123');
    expect(repo.created.single.verificationRequested, isTrue);
    // The new shop's page opens and waits for the live list to include
    // it (real Firestore sends that update straight away).
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ShopScreen), findsOneWidget);

    // Back on the marketplace: open the grocer and rate it 4 stars.
    Navigator.of(
      tester.element(find.byType(Scaffold).first),
    ).popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riverside Grocers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rate 4 stars'));
    await tester.pumpAndSettle();
    expect(repo.ratings, {'g': 4});
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home has a Market place shortcut next to Vacation watch', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeOverview(
              posts: const [],
              currentLocation: null,
              onSosTap: () {},
              onSosTriggered: () {},
              onReport: () {},
              onVacation: () {},
              onMarketplace: () => opened++,
              onEmergency: () {},
              onPolice: () {},
              onOpenMap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final vacation = tester.getCenter(find.text('Vacation watch').last);
    final market = tester.getCenter(find.text('Market place').last);
    expect(market.dx, greaterThan(vacation.dx));
    await tester.tap(find.text('Market place').last);
    expect(opened, 1);
  });
}
