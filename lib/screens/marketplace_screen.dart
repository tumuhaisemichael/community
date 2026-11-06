import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../models/chat_models.dart';
import '../models/marketplace.dart';
import '../repositories/chat_repository.dart';
import '../repositories/marketplace_repository.dart';
import '../services/auth_service.dart';
import '../services/live_value.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../widgets/market_widgets.dart';
import '../widgets/overlap_header.dart';
import '../widgets/page_frame.dart';
import 'chat_messages_screen.dart';
import 'market_lists_screen.dart';
import 'order_screens.dart';
import 'start_selling_screen.dart';

enum _Sort { nearest, rating, newest }

/// Everything the Marketplace screens share: who is signed in, where they
/// are, and the live shops, products and favourites.
class MarketContext {
  MarketContext({
    required this.authService,
    required this.repository,
    this.chatRepository,
    this.currentLocation,
  });

  final AuthService authService;
  final MarketplaceRepository repository;
  final ChatRepository? chatRepository;
  final LatLng? currentLocation;

  String get userId => authService.currentUser?.uid ?? '';

  late final LiveValue<List<Shop>> shops = LiveValue(repository.watchShops());
  late final LiveValue<List<Product>> products = LiveValue(
    repository.watchProducts(),
  );
  late final LiveValue<MarketFavourites> favourites = LiveValue(
    userId.isEmpty
        ? Stream.value(const MarketFavourites())
        : repository.watchFavourites(userId),
  );

  void close() {
    shops.close();
    products.close();
    favourites.close();
  }

  double? distanceTo(Shop shop) => shopDistanceKm(shop, currentLocation);

  Future<void> toggleShop(BuildContext context, Shop shop, bool now) async {
    if (userId.isEmpty) return;
    try {
      await repository.setFavouriteShop(
        userId: userId,
        shopId: shop.id,
        favourite: !now,
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not save: $e');
    }
  }

  Future<void> toggleProduct(
    BuildContext context,
    Product product,
    bool now,
  ) async {
    if (userId.isEmpty) return;
    try {
      await repository.setFavouriteProduct(
        userId: userId,
        productId: product.id,
        favourite: !now,
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not save: $e');
    }
  }

  /// Sends [text] to another member in Messages, without opening the
  /// chat. Best effort: order updates still work if this fails.
  Future<void> notify({
    required String otherUserId,
    required String otherUserName,
    required String text,
  }) async {
    final chats = chatRepository;
    final me = authService.currentUser;
    if (chats == null || me == null || otherUserId == me.uid) return;
    try {
      final myName = me.displayName ?? me.email?.split('@').first ?? 'Member';
      final room = await chats.createOrGetPrivateChat(
        currentUserId: me.uid,
        currentUserName: myName,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
      );
      await chats.sendMessage(
        room.id,
        ChatMessage(
          id: '',
          senderId: me.uid,
          senderName: myName,
          content: text,
          type: MessageType.text,
          timestamp: DateTime.now(),
        ),
      );
    } catch (_) {
      // The order itself is saved; the message is only a heads-up.
    }
  }

  /// Opens (or starts) a private chat with a shop owner.
  Future<void> messageOwner(
    BuildContext context, {
    required String ownerId,
    required String ownerName,
  }) async {
    final chats = chatRepository;
    final me = authService.currentUser;
    if (chats == null || me == null) return;
    try {
      final room = await chats.createOrGetPrivateChat(
        currentUserId: me.uid,
        currentUserName: me.displayName ?? me.email ?? 'Member',
        otherUserId: ownerId,
        otherUserName: ownerName,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatMessagesScreen(
            authService: authService,
            chatRepository: chats,
            chatRoom: room,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not start chat: $e');
    }
  }
}

/// How much bigger than normal the phone's text is (1 = normal), used so
/// fixed-height rows grow with large text instead of overflowing.
double _textGrowth(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

// =================================================================== main

/// Shops and products from neighbours, and a way to start selling.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({
    super.key,
    required this.authService,
    this.repository,
    this.chatRepository,
    this.currentLocation,
  });

  final AuthService authService;

  /// Defaults to the Firestore-backed repository; tests pass their own.
  final MarketplaceRepository? repository;
  final ChatRepository? chatRepository;
  final LatLng? currentLocation;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const _radii = <double?>[1, 2, 5, 10, null];

  late final MarketContext _market = MarketContext(
    authService: widget.authService,
    repository: widget.repository ?? MarketplaceRepository(),
    chatRepository: widget.chatRepository,
    currentLocation: widget.currentLocation,
  );
  final _search = TextEditingController();
  final _banner = PageController();
  int _bannerPage = 0;

  MarketCategory? _category;
  _Sort _sort = _Sort.nearest;
  bool _openNow = false;

  /// Null means anywhere.
  double? _radiusKm = 5;

  @override
  void dispose() {
    _market.close();
    _search.dispose();
    _banner.dispose();
    super.dispose();
  }

  bool get _filtering =>
      _search.text.trim().isNotEmpty || _category != null || _openNow;

  List<Shop> _visibleShops(List<Shop> all) {
    final q = _search.text.trim().toLowerCase();
    final here = widget.currentLocation;
    final list = all.where((shop) {
      if (_category != null && shop.category != _category) return false;
      if (_openNow && !shop.isOpenAt()) return false;
      if (q.isNotEmpty &&
          !shop.name.toLowerCase().contains(q) &&
          !shop.category.label.toLowerCase().contains(q) &&
          !shop.description.toLowerCase().contains(q)) {
        return false;
      }
      final radius = _radiusKm;
      if (radius != null && here != null) {
        final d = _market.distanceTo(shop);
        if (d == null || d > radius) return false;
      }
      return true;
    }).toList();
    list.sort(switch (_sort) {
      _Sort.nearest => (a, b) {
        final da = _market.distanceTo(a) ?? double.infinity;
        final db = _market.distanceTo(b) ?? double.infinity;
        return da.compareTo(db);
      },
      _Sort.rating => (a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0),
      _Sort.newest => (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
        a.createdAt ?? DateTime(0),
      ),
    });
    return list;
  }

  List<Product> _visibleProducts(List<Product> all, Set<String> shopIds) {
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (!shopIds.contains(p.shopId)) return false;
      if (_category != null && p.category != _category) return false;
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.shopName.toLowerCase().contains(q) &&
          !p.category.label.toLowerCase().contains(q)) {
        return false;
      }
      // With no filters, show the featured products first.
      return _filtering || p.featured;
    }).toList();
  }

  String get _radiusLabel {
    if (widget.currentLocation == null) return 'All shops';
    final r = _radiusKm;
    if (r == null) return 'Anywhere';
    return 'Within ${r.toStringAsFixed(0)} km of you';
  }

  Future<void> _pickRadius() async {
    final picked = await showModalBottomSheet<(double?,)>(
      context: context,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Show shops',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final r in _radii)
              ListTile(
                title: Text(
                  r == null
                      ? 'Anywhere'
                      : 'Within ${r.toStringAsFixed(0)} km of you',
                  style: const TextStyle(color: HomeTone.ink),
                ),
                trailing: r == _radiusKm
                    ? const Icon(Icons.check_rounded, color: HomeTone.violet)
                    : null,
                onTap: () => Navigator.pop(context, (r,)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _radiusKm = picked.$1);
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sort and filter',
                    style: TextStyle(
                      color: HomeTone.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (sort, label) in const [
                        (_Sort.nearest, 'Nearest'),
                        (_Sort.rating, 'Top rated'),
                        (_Sort.newest, 'Newest'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _sort == sort,
                          showCheckmark: false,
                          selectedColor: HomeTone.violet,
                          labelStyle: TextStyle(
                            color: _sort == sort ? Colors.white : HomeTone.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => update(() => _sort = sort),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Open now only',
                      style: TextStyle(color: HomeTone.ink),
                    ),
                    value: _openNow,
                    activeTrackColor: HomeTone.violet,
                    onChanged: (v) => update(() => _openNow = v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<(MarketCategory?,)>(
      context: context,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.apps_rounded, color: HomeTone.violet),
              title: const Text(
                'All categories',
                style: TextStyle(color: HomeTone.ink),
              ),
              onTap: () => Navigator.pop(context, (null,)),
            ),
            for (final c in MarketCategory.values)
              ListTile(
                leading: Icon(c.icon, color: c.color),
                title: Text(
                  c.label,
                  style: const TextStyle(color: HomeTone.ink),
                ),
                trailing: c == _category
                    ? const Icon(Icons.check_rounded, color: HomeTone.violet)
                    : null,
                onTap: () => Navigator.pop(context, (c,)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked.$1);
  }

  void _openSaved() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _SavedScreen(market: _market)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: PinnedHeader(
          overlap: 28,
          header: PageHeroHeader(
            title: 'Marketplace',
            subtitle: 'Shop from local neighbours',
            actions: [
              HeaderRoundButton(
                icon: Icons.receipt_long_outlined,
                tooltip: 'My orders',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyOrdersScreen(market: _market),
                  ),
                ),
              ),
              HeaderRoundButton(
                icon: Icons.favorite_border_rounded,
                tooltip: 'Saved shops and products',
                onPressed: _openSaved,
              ),
            ],
            below: HeaderPill(
              icon: Icons.location_on_rounded,
              label: _radiusLabel,
              onTap: widget.currentLocation == null ? null : _pickRadius,
            ),
          ),
          body: StreamBuilder<MarketFavourites>(
            stream: _market.favourites.stream,
            initialData: _market.favourites.latest,
            builder: (context, favSnap) {
              final favs = favSnap.data ?? const MarketFavourites();
              return StreamBuilder<List<Shop>>(
                stream: _market.shops.stream,
                initialData: _market.shops.latest,
                builder: (context, shopSnap) => StreamBuilder<List<Product>>(
                  stream: _market.products.stream,
                  initialData: _market.products.latest,
                  builder: (context, productSnap) =>
                      _content(shopSnap, productSnap.data ?? const [], favs),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(
    AsyncSnapshot<List<Shop>> shopSnap,
    List<Product> allProducts,
    MarketFavourites favs,
  ) {
    final allShops = shopSnap.data ?? const <Shop>[];
    final shops = _visibleShops(allShops);
    final shopIds = {for (final s in shops) s.id};
    final products = _visibleProducts(allProducts, shopIds);
    final myShop = allShops.where((s) => s.ownerId == _market.userId);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: HomeTone.ink, fontSize: 15),
                cursorColor: HomeTone.violet,
                decoration:
                    frameInput(
                      hint: 'Search for shops, products or categories…',
                      icon: Icons.search_rounded,
                    ).copyWith(
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: HomeTone.border),
              ),
              child: IconButton(
                tooltip: 'Sort and filter',
                onPressed: _openFilters,
                icon: Badge(
                  isLabelVisible: _openNow || _sort != _Sort.nearest,
                  smallSize: 8,
                  backgroundColor: HomeTone.violet,
                  child: const Icon(Icons.tune_rounded, color: HomeTone.ink),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _CategoryRow(
          selected: _category,
          onSelect: (c) =>
              setState(() => _category = _category == c ? null : c),
          onMore: _pickCategory,
        ),
        const SizedBox(height: 14),
        if (!_filtering) ...[
          _PromoBanner(
            controller: _banner,
            page: _bannerPage,
            onPage: (p) => setState(() => _bannerPage = p),
          ),
          const SizedBox(height: 18),
        ],
        _SectionHeader(
          icon: Icons.storefront_outlined,
          title: _filtering ? 'Shops' : 'Nearby Shops',
          onSeeAll: shops.isEmpty
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NearbyShopsScreen(
                      market: _market,
                      radiusKm: _radiusKm,
                      initialCategory: _category,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        if (!shopSnap.hasData)
          const SizedBox(
            height: 210,
            child: Center(
              child: CircularProgressIndicator(color: HomeTone.violet),
            ),
          )
        else if (shops.isEmpty)
          _EmptyNote(
            text: allShops.isEmpty
                ? 'No shops yet. Be the first to start selling!'
                : 'No shops match. Try another category or a wider area.',
          )
        else
          SizedBox(
            height: 92 + 100 * _textGrowth(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shops.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final shop = shops[i];
                final fav = favs.shops.contains(shop.id);
                // Top-aligned so the card is only as tall as its content.
                return Align(
                  alignment: Alignment.topCenter,
                  child: ShopCard(
                    shop: shop,
                    distanceKm: _market.distanceTo(shop),
                    favourite: fav,
                    onTap: () => _openShop(shop),
                    onFavourite: () => _market.toggleShop(context, shop, fav),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 18),
        _SectionHeader(
          icon: Icons.sell_outlined,
          title: _filtering ? 'Products' : 'Featured Products',
          onSeeAll: products.isEmpty
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeaturedProductsScreen(
                      market: _market,
                      featuredOnly: !_filtering,
                      initialCategory: _category,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          _EmptyNote(
            text: _filtering
                ? 'No products match.'
                : 'Featured products from nearby shops appear here.',
          )
        else
          SizedBox(
            height: 84 + 80 * _textGrowth(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final p = products[i];
                final fav = favs.products.contains(p.id);
                // Top-aligned so the card is only as tall as its content.
                return Align(
                  alignment: Alignment.topCenter,
                  child: ProductCard(
                    product: p,
                    favourite: fav,
                    onTap: () => openProduct(context, _market, p),
                    onFavourite: () => _market.toggleProduct(context, p, fav),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 18),
        SellerCard(
          myShop: myShop.isEmpty ? null : myShop.first,
          onStart: _startSelling,
          onOpenShop: _openShop,
        ),
      ],
    );
  }

  void _openShop(Shop shop) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ShopScreen(market: _market, shopId: shop.id),
    ),
  );

  Future<void> _startSelling() async {
    if (_market.userId.isEmpty) {
      _snack(context, 'Sign in to start selling.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopFormScreen(market: _market)),
    );
  }
}

// ================================================================ widgets

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selected,
    required this.onSelect,
    required this.onMore,
  });
  final MarketCategory? selected;
  final ValueChanged<MarketCategory> onSelect;
  final VoidCallback onMore;

  static const _shown = [
    MarketCategory.groceries,
    MarketCategory.food,
    MarketCategory.fashion,
    MarketCategory.electronics,
    MarketCategory.home,
  ];

  @override
  Widget build(BuildContext context) {
    final extraSelected = selected != null && !_shown.contains(selected);
    final tileHeight = 54 + 30 * _textGrowth(context);
    Widget tile({
      required IconData icon,
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? HomeTone.violet : const Color(0xFFF1EDFA),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 84,
            height: tileHeight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : HomeTone.violet,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : HomeTone.ink,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: tileHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in _shown) ...[
            tile(
              icon: c.icon,
              label: c.label,
              isSelected: selected == c,
              onTap: () => onSelect(c),
            ),
            const SizedBox(width: 8),
          ],
          tile(
            icon: extraSelected ? selected!.icon : Icons.apps_rounded,
            label: extraSelected ? selected!.label : 'More',
            isSelected: extraSelected,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.controller,
    required this.page,
    required this.onPage,
  });
  final PageController controller;
  final int page;
  final ValueChanged<int> onPage;

  static const _slides = [
    (
      'Support local businesses',
      'Discover shops and great deals from your neighbourhood.',
      Icons.storefront_rounded,
    ),
    (
      'Fresh from your street',
      'Groceries, bakeries and food stalls just around the corner.',
      Icons.shopping_basket_rounded,
    ),
    (
      'Sell to your neighbours',
      'List your shop and products in a few minutes.',
      Icons.sell_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 76 + 52 * _textGrowth(context),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
      ),
      boxShadow: HomeTone.cardShadow,
    ),
    child: Stack(
      children: [
        PageView(
          controller: controller,
          onPageChanged: onPage,
          children: [
            for (final (title, text, icon) in _slides)
              Stack(
                children: [
                  Positioned(
                    right: -6,
                    bottom: -14,
                    child: ExcludeSemantics(
                      child: Icon(
                        icon,
                        size: 112,
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 110, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == page ? 1 : .5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.onSeeAll,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: HomeTone.violet, size: 24),
      const SizedBox(width: 10),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: HomeTone.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      if (onSeeAll != null)
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(foregroundColor: HomeTone.violet),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See All',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
    ],
  );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HomeTone.border),
    ),
    child: Text(text, style: const TextStyle(color: HomeTone.muted)),
  );
}

class SellerCard extends StatelessWidget {
  const SellerCard({
    super.key,
    required this.myShop,
    required this.onStart,
    required this.onOpenShop,
  });
  final Shop? myShop;
  final VoidCallback onStart;
  final ValueChanged<Shop> onOpenShop;

  @override
  Widget build(BuildContext context) {
    final shop = myShop;
    final button = OutlinedButton.icon(
      onPressed: shop == null ? onStart : () => onOpenShop(shop),
      style: OutlinedButton.styleFrom(
        foregroundColor: HomeTone.violet,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: const BorderSide(color: HomeTone.violet, width: 1.4),
        shape: const StadiumBorder(),
      ),
      icon: Icon(
        shop == null ? Icons.add_business_outlined : Icons.storefront_outlined,
        size: 19,
      ),
      label: Text(shop == null ? 'Start Selling' : 'My Shop'),
    );
    final text = Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: HomeTone.violetDim,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: HomeTone.violet,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop == null ? 'Are you a business owner?' : shop.name,
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                shop == null
                    ? 'List your shop, add products and sell to your '
                          'neighbours.'
                    : 'Your shop · add products and see your ratings.',
                style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeTone.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomeTone.border),
        boxShadow: HomeTone.cardShadow,
      ),
      // Side by side on wide screens; button underneath on phones.
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 460
            ? Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 10),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [text, const SizedBox(height: 12), button],
              ),
      ),
    );
  }
}

// ============================================================ shop screen

/// One shop: details, rating, contact and its products.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.market, required this.shopId});
  final MarketContext market;
  final String shopId;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int? _myStars;
  bool _rating = false;

  MarketContext get market => widget.market;

  @override
  void initState() {
    super.initState();
    if (market.userId.isNotEmpty) {
      market.repository
          .myRating(shopId: widget.shopId, userId: market.userId)
          .then((stars) {
            if (mounted) setState(() => _myStars = stars);
          })
          .catchError((_) {});
    }
  }

  Future<void> _rate(int stars) async {
    if (market.userId.isEmpty) return;
    setState(() {
      _rating = true;
      _myStars = stars;
    });
    try {
      await market.repository.rateShop(
        shopId: widget.shopId,
        userId: market.userId,
        stars: stars,
      );
      if (mounted) _snack(context, 'Thanks for rating!');
    } catch (e) {
      if (mounted) _snack(context, 'Could not save your rating: $e');
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Shop>>(
      stream: market.shops.stream,
      initialData: market.shops.latest,
      builder: (context, snap) {
        final found = (snap.data ?? const <Shop>[]).where(
          (s) => s.id == widget.shopId,
        );
        if (found.isEmpty) {
          return const PageFrame(
            title: 'Shop',
            subtitle: 'Loading…',
            children: [
              Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: HomeTone.violet),
                ),
              ),
            ],
          );
        }
        final shop = found.first;
        final isMine = shop.ownerId == market.userId;
        final distance = market.distanceTo(shop);
        return StreamBuilder<List<Product>>(
          stream: market.products.stream,
          initialData: market.products.latest,
          builder: (context, pSnap) {
            final products = [
              for (final p in pSnap.data ?? const <Product>[])
                if (p.shopId == shop.id) p,
            ];
            return StreamBuilder<MarketFavourites>(
              stream: market.favourites.stream,
              initialData: market.favourites.latest,
              builder: (context, fSnap) {
                final favs = fSnap.data ?? const MarketFavourites();
                final fav = favs.shops.contains(shop.id);
                return PageFrame(
                  title: shop.name,
                  subtitle: [
                    shop.category.label,
                    if (distance != null) shortDistance(distance),
                  ].join(' · '),
                  bottomBar: isMine
                      ? FramePrimaryButton(
                          label: 'Add Product',
                          icon: Icons.add_rounded,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormScreen(market: market, shop: shop),
                            ),
                          ),
                        )
                      : market.chatRepository == null && !shop.acceptsCalls
                      ? null
                      : Row(
                          children: [
                            if (shop.acceptsCalls) ...[
                              SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () => launchUrl(
                                    Uri(scheme: 'tel', path: shop.phone),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: HomeTone.violet,
                                    side: const BorderSide(
                                      color: HomeTone.violet,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('Call'),
                                ),
                              ),
                              if (market.chatRepository != null)
                                const SizedBox(width: 10),
                            ],
                            if (market.chatRepository != null)
                              Expanded(
                                child: FramePrimaryButton(
                                  label:
                                      'Message ${shop.ownerName.split(' ').first}',
                                  icon: Icons.chat_bubble_outline_rounded,
                                  onPressed: () => market.messageOwner(
                                    context,
                                    ownerId: shop.ownerId,
                                    ownerName: shop.ownerName,
                                  ),
                                ),
                              ),
                          ],
                        ),
                  children: [
                    FrameCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 130,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MarketArt(
                                  category: shop.category,
                                  iconSize: 56,
                                ),
                                Positioned(
                                  left: 10,
                                  top: 10,
                                  child: OpenPill(open: shop.isOpenAt()),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: HeartButton(
                                    favourite: fav,
                                    label: 'Save ${shop.name}',
                                    onPressed: () =>
                                        market.toggleShop(context, shop, fav),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    RatingLine(shop: shop),
                                    if (shop.isVerified) ...[
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 17,
                                        color: HomeTone.violet,
                                      ),
                                      const SizedBox(width: 3),
                                      const Text(
                                        'Verified shop',
                                        style: TextStyle(
                                          color: HomeTone.violet,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (shop.description.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    shop.description,
                                    style: const TextStyle(
                                      color: HomeTone.ink,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                _InfoLine(
                                  icon: Icons.schedule_rounded,
                                  text: shop.hoursLabel,
                                ),
                                if (shop.address.isNotEmpty)
                                  _InfoLine(
                                    icon: Icons.location_on_outlined,
                                    text: shop.address,
                                  ),
                                _InfoLine(
                                  icon: Icons.person_outline_rounded,
                                  text: isMine
                                      ? 'Your shop'
                                      : 'Run by ${shop.ownerName}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isMine && market.userId.isNotEmpty)
                      FrameCard(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Your rating',
                                style: TextStyle(
                                  color: HomeTone.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            for (var star = 1; star <= 5; star++)
                              IconButton(
                                tooltip:
                                    'Rate $star star${star == 1 ? '' : 's'}',
                                visualDensity: VisualDensity.compact,
                                onPressed: _rating ? null : () => _rate(star),
                                icon: Icon(
                                  star <= (_myStars ?? 0)
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: const Color(0xFFF5B301),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (isMine)
                      FrameCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(
                            Icons.receipt_long_outlined,
                            color: HomeTone.violet,
                          ),
                          title: const Text(
                            'Orders for your shop',
                            style: TextStyle(
                              color: HomeTone.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: const Text(
                            'Accept requests and update their progress',
                            style: TextStyle(color: HomeTone.muted),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: HomeTone.muted,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MyOrdersScreen(market: market, sales: true),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Products (${products.length})',
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (products.isEmpty)
                      _EmptyNote(
                        text: isMine
                            ? 'You have no products yet. Tap Add Product.'
                            : 'This shop has not listed products yet.',
                      ),
                    if (isMine && products.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Tap a product to edit or remove it.',
                          style: TextStyle(
                            color: HomeTone.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    if (products.isNotEmpty)
                      _ProductGrid(
                        products: products,
                        favs: favs,
                        market: market,
                        editShop: isMine ? shop : null,
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: HomeTone.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: HomeTone.ink)),
        ),
      ],
    ),
  );
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.favs,
    required this.market,
    this.editShop,
  });
  final List<Product> products;
  final MarketFavourites favs;
  final MarketContext market;

  /// The owner's own shop: tapping a product opens it for editing.
  final Shop? editShop;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in products)
            ProductCard(
              width: width,
              product: p,
              favourite: favs.products.contains(p.id),
              onTap: editShop == null
                  ? () => openProduct(context, market, p)
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(
                          market: market,
                          shop: editShop!,
                          product: p,
                        ),
                      ),
                    ),
              onFavourite: () => market.toggleProduct(
                context,
                p,
                favs.products.contains(p.id),
              ),
            ),
        ],
      );
    },
  );
}

// ============================================================== see all

class _SavedScreen extends StatelessWidget {
  const _SavedScreen({required this.market});
  final MarketContext market;

  @override
  Widget build(BuildContext context) => StreamBuilder<MarketFavourites>(
    stream: market.favourites.stream,
    initialData: market.favourites.latest,
    builder: (context, fSnap) {
      final favs = fSnap.data ?? const MarketFavourites();
      final shops = [
        for (final s in market.shops.latest ?? const <Shop>[])
          if (favs.shops.contains(s.id)) s,
      ];
      final products = [
        for (final p in market.products.latest ?? const <Product>[])
          if (favs.products.contains(p.id)) p,
      ];
      return PageFrame(
        title: 'Saved',
        subtitle: 'Shops and products you ♡',
        children: [
          if (shops.isEmpty && products.isEmpty)
            const _EmptyNote(
              text: 'Tap ♡ on a shop or product to save it here.',
            ),
          for (final shop in shops)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShopCard(
                width: null,
                shop: shop,
                distanceKm: market.distanceTo(shop),
                favourite: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopScreen(market: market, shopId: shop.id),
                  ),
                ),
                onFavourite: () => market.toggleShop(context, shop, true),
              ),
            ),
          if (products.isNotEmpty)
            _ProductGrid(products: products, favs: favs, market: market),
        ],
      );
    },
  );
}

// ================================================================= forms

/// Add a product to your shop, or edit / remove one ([product] set).
/// Only reachable from the owner's own shop page.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.market,
    required this.shop,
    this.product,
  });
  final MarketContext market;
  final Shop shop;
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final _name = TextEditingController(text: widget.product?.name);
  late final _price = TextEditingController(
    text: widget.product == null ? null : '${widget.product!.priceUgx}',
  );
  late final _description = TextEditingController(
    text: widget.product?.description,
  );
  late MarketCategory _category =
      widget.product?.category ?? widget.shop.category;
  late final _unit = TextEditingController(text: widget.product?.unit);
  late bool _featured = widget.product?.featured ?? true;
  late bool _inStock = widget.product?.inStock ?? true;
  bool _saving = false;

  bool get _editing => widget.product != null;

  Future<void> _delete() async {
    final p = widget.product!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove product?'),
        content: Text('${p.name} will no longer be listed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.market.repository.deleteProduct(p.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('${p.name} removed')));
    } catch (e) {
      if (mounted) _snack(context, 'Could not remove the product: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (name.isEmpty || price == null || price <= 0) {
      _snack(context, 'Please enter a name and a price.');
      return;
    }
    setState(() => _saving = true);
    try {
      final product = Product(
        id: widget.product?.id ?? '',
        shopId: widget.shop.id,
        shopName: widget.shop.name,
        ownerId: widget.shop.ownerId,
        name: name,
        priceUgx: price,
        category: _category,
        description: _description.text.trim(),
        featured: _featured,
        unit: _unit.text.trim(),
        inStock: _inStock,
      );
      if (_editing) {
        await widget.market.repository.updateProduct(product);
      } else {
        await widget.market.repository.addProduct(product);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(_editing ? '$name saved' : '$name added')),
      );
    } catch (e) {
      if (mounted) _snack(context, 'Could not save the product: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const field = TextStyle(color: HomeTone.ink, fontSize: 15);
    return PageFrame(
      title: _editing ? 'Edit Product' : 'Add Product',
      subtitle: 'For ${widget.shop.name}',
      bottomBar: FramePrimaryButton(
        label: _editing ? 'Save Changes' : 'Add Product',
        icon: _editing ? Icons.check_rounded : Icons.add_rounded,
        busy: _saving,
        onPressed: _save,
      ),
      children: [
        FrameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: field,
                decoration: frameInput(
                  label: 'Product name',
                  icon: Icons.sell_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: field,
                decoration: frameInput(
                  label: 'Price (UGX)',
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _unit,
                style: field,
                decoration: frameInput(
                  label: 'Sold per (optional), e.g. 1 kg',
                  icon: Icons.scale_outlined,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MarketCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: frameInput(
                  label: 'Category',
                  icon: Icons.category_outlined,
                ),
                dropdownColor: HomeTone.card,
                style: field,
                items: [
                  for (final c in MarketCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (c) => setState(() => _category = c ?? _category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                style: field,
                decoration: frameInput(label: 'Description (optional)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Feature on the Marketplace',
                  style: TextStyle(
                    color: HomeTone.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Shown under Featured Products',
                  style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
                ),
                value: _featured,
                activeTrackColor: HomeTone.violet,
                onChanged: (v) => setState(() => _featured = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'In stock',
                  style: TextStyle(
                    color: HomeTone.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Turn off to stop new orders for now',
                  style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
                ),
                value: _inStock,
                activeTrackColor: HomeTone.violet,
                onChanged: (v) => setState(() => _inStock = v),
              ),
            ],
          ),
        ),
        if (_editing)
          TextButton.icon(
            onPressed: _saving ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove this product'),
          ),
      ],
    );
  }
}
