import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/marketplace.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../widgets/market_widgets.dart';
import '../widgets/overlap_header.dart';
import '../widgets/page_frame.dart';
import 'marketplace_screen.dart';
import 'order_screens.dart';
import 'start_selling_screen.dart';

void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

Future<double?> _pickRadius(BuildContext context, double? current) async {
  const radii = <double?>[1, 2, 5, 10, null];
  final picked = await showModalBottomSheet<(double?,)>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomeTone.card,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in radii)
            ListTile(
              title: Text(
                r == null
                    ? 'Anywhere'
                    : 'Within ${r.toStringAsFixed(0)} km of you',
                style: const TextStyle(color: HomeTone.ink),
              ),
              trailing: r == current
                  ? const Icon(Icons.check_rounded, color: HomeTone.violet)
                  : null,
              onTap: () => Navigator.pop(context, (r,)),
            ),
        ],
      ),
    ),
  );
  return picked == null ? current : picked.$1;
}

// ============================================================ nearby shops

enum _ShopMode { all, openNow, closest, topRated }

/// "See All" for Nearby Shops.
class NearbyShopsScreen extends StatefulWidget {
  const NearbyShopsScreen({
    super.key,
    required this.market,
    this.radiusKm = 5,
    this.initialCategory,
  });

  final MarketContext market;

  /// Null means anywhere.
  final double? radiusKm;
  final MarketCategory? initialCategory;

  @override
  State<NearbyShopsScreen> createState() => _NearbyShopsScreenState();
}

class _NearbyShopsScreenState extends State<NearbyShopsScreen> {
  late double? _radius = widget.radiusKm;
  late MarketCategory? _category = widget.initialCategory;
  _ShopMode _mode = _ShopMode.all;
  bool _searching = false;
  final _search = TextEditingController();

  MarketContext get market => widget.market;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Shop> _visible(List<Shop> all) {
    final q = _search.text.trim().toLowerCase();
    final here = market.currentLocation;
    final list = all.where((shop) {
      if (_category != null && shop.category != _category) return false;
      if (_mode == _ShopMode.openNow && !shop.isOpenAt()) return false;
      if (q.isNotEmpty &&
          !shop.name.toLowerCase().contains(q) &&
          !shop.description.toLowerCase().contains(q) &&
          !shop.category.label.toLowerCase().contains(q)) {
        return false;
      }
      final r = _radius;
      if (r != null && here != null) {
        final d = market.distanceTo(shop);
        if (d == null || d > r) return false;
      }
      return true;
    }).toList();
    int byDistance(Shop a, Shop b) => (market.distanceTo(a) ?? double.infinity)
        .compareTo(market.distanceTo(b) ?? double.infinity);
    list.sort(
      _mode == _ShopMode.topRated
          ? (a, b) {
              final r = (b.rating ?? 0).compareTo(a.rating ?? 0);
              return r != 0 ? r : b.ratingCount.compareTo(a.ratingCount);
            }
          : byDistance,
    );
    return list;
  }

  String get _subtitle {
    if (market.currentLocation == null) return 'Local shops near you';
    final r = _radius;
    return r == null
        ? 'Local shops anywhere'
        : 'Local shops within ${r.toStringAsFixed(0)} km of you';
  }

  Future<void> _openFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter shops',
                  style: TextStyle(
                    color: HomeTone.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All categories'),
                      selected: _category == null,
                      showCheckmark: false,
                      selectedColor: HomeTone.violet,
                      labelStyle: TextStyle(
                        color: _category == null ? Colors.white : HomeTone.ink,
                      ),
                      onSelected: (_) {
                        setState(() => _category = null);
                        setSheet(() {});
                      },
                    ),
                    for (final c in MarketCategory.values)
                      ChoiceChip(
                        avatar: Icon(
                          c.icon,
                          size: 17,
                          color: _category == c ? Colors.white : c.color,
                        ),
                        label: Text(c.label),
                        selected: _category == c,
                        showCheckmark: false,
                        selectedColor: HomeTone.violet,
                        labelStyle: TextStyle(
                          color: _category == c ? Colors.white : HomeTone.ink,
                        ),
                        onSelected: (_) {
                          setState(() => _category = c);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: PinnedHeader(
          header: PageHeroHeader(
            title: 'Nearby Shops',
            subtitle: _subtitle,
            actions: [
              HeaderRoundButton(
                icon: _searching ? Icons.close_rounded : Icons.search_rounded,
                tooltip: _searching ? 'Close search' : 'Search shops',
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
              ),
              if (market.currentLocation != null)
                HeaderRoundButton(
                  icon: Icons.location_on_outlined,
                  tooltip: 'Change distance',
                  onPressed: () async {
                    final r = await _pickRadius(context, _radius);
                    if (mounted) setState(() => _radius = r);
                  },
                ),
            ],
          ),
          body: StreamBuilder<MarketFavourites>(
            stream: market.favourites.stream,
            initialData: market.favourites.latest,
            builder: (context, favSnap) => StreamBuilder<List<Shop>>(
              stream: market.shops.stream,
              initialData: market.shops.latest,
              builder: (context, snap) =>
                  _list(snap, favSnap.data ?? const MarketFavourites()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(AsyncSnapshot<List<Shop>> snap, MarketFavourites favs) {
    final all = snap.data ?? const <Shop>[];
    final shops = _visible(all);
    final mine = all.where((s) => s.ownerId == market.userId);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        if (_searching) ...[
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: HomeTone.ink, fontSize: 15),
            decoration: frameInput(
              hint: 'Search shops…',
              icon: Icons.search_rounded,
            ).copyWith(fillColor: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (mode, label) in const [
                      (_ShopMode.all, 'All Shops'),
                      (_ShopMode.openNow, 'Open Now'),
                      (_ShopMode.closest, 'Closest'),
                      (_ShopMode.topRated, 'Top Rated'),
                    ]) ...[
                      _Pill(
                        label: label,
                        selected: _mode == mode,
                        onTap: () => setState(() => _mode = mode),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _FilterButton(
              active: _category != null,
              label: _category?.label ?? 'Filter',
              onTap: _openFilter,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          !snap.hasData
              ? 'Loading shops…'
              : '${shops.length} shop${shops.length == 1 ? '' : 's'} '
                    '${market.currentLocation == null ? 'found' : 'nearby'}',
          style: const TextStyle(color: HomeTone.ink, fontSize: 15),
        ),
        const SizedBox(height: 10),
        if (snap.hasData && shops.isEmpty)
          _Empty(
            text: all.isEmpty
                ? 'No shops yet. Be the first to start selling!'
                : 'No shops match. Try another filter or a wider distance.',
          ),
        for (final shop in shops) ...[
          ShopListCard(
            shop: shop,
            distanceKm: market.distanceTo(shop),
            favourite: favs.shops.contains(shop.id),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopScreen(market: market, shopId: shop.id),
              ),
            ),
            onFavourite: () =>
                market.toggleShop(context, shop, favs.shops.contains(shop.id)),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        SellerCard(
          myShop: mine.isEmpty ? null : mine.first,
          onStart: () {
            if (market.userId.isEmpty) {
              _snack(context, 'Sign in to start selling.');
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ShopFormScreen(market: market)),
            );
          },
          onOpenShop: (shop) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShopScreen(market: market, shopId: shop.id),
            ),
          ),
        ),
      ],
    );
  }
}

// ======================================================== featured products

enum _ProductSort { featured, newest, priceLow, priceHigh, nearest }

extension on _ProductSort {
  String get label => switch (this) {
    _ProductSort.featured => 'Featured',
    _ProductSort.newest => 'Newest',
    _ProductSort.priceLow => 'Price: low to high',
    _ProductSort.priceHigh => 'Price: high to low',
    _ProductSort.nearest => 'Nearest',
  };
}

/// "See All" for Featured Products (or all products, when [featuredOnly]
/// is false).
class FeaturedProductsScreen extends StatefulWidget {
  const FeaturedProductsScreen({
    super.key,
    required this.market,
    this.featuredOnly = true,
    this.initialCategory,
  });

  final MarketContext market;
  final bool featuredOnly;
  final MarketCategory? initialCategory;

  @override
  State<FeaturedProductsScreen> createState() => _FeaturedProductsScreenState();
}

class _FeaturedProductsScreenState extends State<FeaturedProductsScreen> {
  static const _chips = [
    MarketCategory.groceries,
    MarketCategory.electronics,
    MarketCategory.fashion,
    MarketCategory.home,
  ];

  late MarketCategory? _category = widget.initialCategory;
  _ProductSort _sort = _ProductSort.featured;
  final _search = TextEditingController();

  MarketContext get market => widget.market;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Product> _visible(List<Product> all, Map<String, Shop> shops) {
    final q = _search.text.trim().toLowerCase();
    final list = all.where((p) {
      if (widget.featuredOnly && !p.featured) return false;
      if (_category != null && p.category != _category) return false;
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.shopName.toLowerCase().contains(q) &&
          !p.category.label.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    double distance(Product p) {
      final shop = shops[p.shopId];
      return shop == null
          ? double.infinity
          : market.distanceTo(shop) ?? double.infinity;
    }

    switch (_sort) {
      case _ProductSort.featured:
        list.sort((a, b) {
          if (a.featured != b.featured) return a.featured ? -1 : 1;
          return (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          );
        });
      case _ProductSort.newest:
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      case _ProductSort.priceLow:
        list.sort((a, b) => a.priceUgx.compareTo(b.priceUgx));
      case _ProductSort.priceHigh:
        list.sort((a, b) => b.priceUgx.compareTo(a.priceUgx));
      case _ProductSort.nearest:
        list.sort((a, b) => distance(a).compareTo(distance(b)));
    }
    return list;
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

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<_ProductSort>(
      context: context,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in _ProductSort.values)
              if (sort != _ProductSort.nearest ||
                  market.currentLocation != null)
                ListTile(
                  title: Text(
                    sort.label,
                    style: const TextStyle(color: HomeTone.ink),
                  ),
                  trailing: sort == _sort
                      ? const Icon(Icons.check_rounded, color: HomeTone.violet)
                      : null,
                  onTap: () => Navigator.pop(context, sort),
                ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.featuredOnly ? 'Featured Products' : 'Products';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: PinnedHeader(
          header: PageHeroHeader(
            title: title,
            subtitle: 'Top picks from local shops',
          ),
          body: StreamBuilder<MarketFavourites>(
            stream: market.favourites.stream,
            initialData: market.favourites.latest,
            builder: (context, favSnap) => StreamBuilder<List<Shop>>(
              stream: market.shops.stream,
              initialData: market.shops.latest,
              builder: (context, shopSnap) => StreamBuilder<List<Product>>(
                stream: market.products.stream,
                initialData: market.products.latest,
                builder: (context, snap) => _grid(snap, {
                  for (final s in shopSnap.data ?? const <Shop>[]) s.id: s,
                }, favSnap.data ?? const MarketFavourites()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(
    AsyncSnapshot<List<Product>> snap,
    Map<String, Shop> shops,
    MarketFavourites favs,
  ) {
    final products = _visible(snap.data ?? const <Product>[], shops);
    final extraSelected = _category != null && !_chips.contains(_category);
    final noun = widget.featuredOnly ? 'featured product' : 'product';
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
                decoration: frameInput(
                  hint: widget.featuredOnly
                      ? 'Search featured products…'
                      : 'Search products…',
                  icon: Icons.search_rounded,
                ).copyWith(fillColor: Colors.white),
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
                tooltip: 'Sort',
                onPressed: _pickSort,
                icon: const Icon(Icons.tune_rounded, color: HomeTone.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Pill(
                label: 'All',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final c in _chips) ...[
                const SizedBox(width: 8),
                _Pill(
                  label: c.label,
                  icon: c.icon,
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
              ],
              const SizedBox(width: 8),
              _Pill(
                label: extraSelected ? _category!.label : 'More',
                icon: extraSelected ? _category!.icon : Icons.apps_rounded,
                selected: extraSelected,
                onTap: _pickCategory,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                !snap.hasData
                    ? 'Loading…'
                    : '${products.length} $noun${products.length == 1 ? '' : 's'}',
                style: const TextStyle(color: HomeTone.ink, fontSize: 15),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: _pickSort,
                style: TextButton.styleFrom(foregroundColor: HomeTone.violet),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Sort: ${_sort.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (snap.hasData && products.isEmpty)
          const _Empty(text: 'No products match. Try another category.')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in products)
                    SizedBox(
                      width: width,
                      child: ProductTileCard(
                        product: p,
                        shop: shops[p.shopId],
                        distanceKm: shops[p.shopId] == null
                            ? null
                            : market.distanceTo(shops[p.shopId]!),
                        favourite: favs.products.contains(p.id),
                        onTap: () => openProduct(context, market, p),
                        onFavourite: () => market.toggleProduct(
                          context,
                          p,
                          favs.products.contains(p.id),
                        ),
                        onPurchase: () => openProduct(context, market, p),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? HomeTone.violet : const Color(0xFFF1EDFA),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: icon == null ? 18 : 14,
            vertical: 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : HomeTone.violet,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : HomeTone.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.active,
    required this.label,
    required this.onTap,
  });
  final bool active;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? HomeTone.violetDim : Colors.white,
    shape: StadiumBorder(
      side: BorderSide(color: active ? HomeTone.violet : HomeTone.border),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: active ? HomeTone.violet : HomeTone.ink,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? HomeTone.violet : HomeTone.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
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
