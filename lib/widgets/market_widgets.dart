import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;

import '../models/marketplace.dart';
import '../theme/home_tone.dart';

final NumberFormat _ugx = NumberFormat('#,###', 'en_US');

/// "UGX 85,000".
String ugx(int amount) => 'UGX ${_ugx.format(amount)}';

/// Kilometres from [here] to the shop, or null if either is unknown.
double? shopDistanceKm(Shop shop, LatLng? here) {
  if (here == null || !shop.hasLocation) return null;
  return const Distance().as(
        LengthUnit.Meter,
        here,
        LatLng(shop.latitude!, shop.longitude!),
      ) /
      1000;
}

/// "350 m", "1.2 km".
String shortDistance(double km) => km < 1
    ? '${(km * 1000 / 50).round() * 50} m'
    : '${km.toStringAsFixed(1)} km';

/// Stand-in picture for a shop or product until photo uploads are set up:
/// the category's colour with its icon.
class MarketArt extends StatelessWidget {
  const MarketArt({super.key, required this.category, this.iconSize = 44});
  final MarketCategory category;
  final double iconSize;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(category.color, Colors.white, .78)!,
          Color.lerp(category.color, Colors.white, .55)!,
        ],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -10,
          bottom: -14,
          child: Icon(
            category.icon,
            size: iconSize * 1.8,
            color: category.color.withValues(alpha: .14),
          ),
        ),
        Center(
          child: Icon(category.icon, size: iconSize, color: category.color),
        ),
      ],
    ),
  );
}

/// White circle with a heart that fills when favourited.
class HeartButton extends StatelessWidget {
  const HeartButton({
    super.key,
    required this.favourite,
    required this.onPressed,
    this.label = 'Favourite',
  });
  final bool favourite;
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    // Its own item, not merged into the card it sits on.
    container: true,
    button: true,
    toggled: favourite,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 19,
            color: favourite ? HomeTone.red : HomeTone.ink,
          ),
        ),
      ),
    ),
  );
}

/// "● Open" / "● Closed" label for a shop.
class OpenPill extends StatelessWidget {
  const OpenPill({super.key, required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: open ? HomeTone.green : HomeTone.muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          open ? 'Open' : 'Closed',
          style: TextStyle(
            color: open ? HomeTone.green : HomeTone.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// "★ 4.8 (124)" or "New" when the shop has no ratings yet.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.shop});
  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final rating = shop.rating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF5B301)),
        const SizedBox(width: 3),
        Text(
          rating == null
              ? 'New'
              : '${rating.toStringAsFixed(1)} (${shop.ratingCount})',
          style: const TextStyle(color: HomeTone.ink, fontSize: 13),
        ),
      ],
    );
  }
}

class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.shop,
    required this.distanceKm,
    required this.favourite,
    required this.onTap,
    required this.onFavourite,
    this.width = 176,
  });

  final Shop shop;
  final double? distanceKm;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback? onFavourite;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final open = shop.isOpenAt();
    return SizedBox(
      width: width,
      child: Material(
        color: HomeTone.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: HomeTone.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MarketArt(category: shop.category),
                    Positioned(left: 8, top: 8, child: OpenPill(open: open)),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: HeartButton(
                        favourite: favourite,
                        label: 'Save ${shop.name}',
                        onPressed: onFavourite,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomeTone.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (shop.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 17,
                            color: HomeTone.violet,
                            semanticLabel: 'Verified',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        shop.category.label,
                        if (distanceKm != null) shortDistance(distanceKm!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RatingLine(shop: shop),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.favourite,
    required this.onTap,
    required this.onFavourite,
    this.width = 132,
  });

  final Product product;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback? onFavourite;
  final double? width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: HomeTone.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: HomeTone.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 82,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MarketArt(category: product.category, iconSize: 38),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: HeartButton(
                      favourite: favourite,
                      label: 'Save ${product.name}',
                      onPressed: onFavourite,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomeTone.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ugx(product.priceUgx),
                    style: const TextStyle(
                      color: HomeTone.violet,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Small outlined violet button: "View Shop ›", "Request Order ›".
class MarketLinkButton extends StatelessWidget {
  const MarketLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: HomeTone.violet,
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      side: const BorderSide(color: HomeTone.violet, width: 1.3),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        const Icon(Icons.chevron_right_rounded, size: 18),
      ],
    ),
  );
}

/// Wide shop card for the Nearby Shops list: picture on the left, details
/// and "View Shop" on the right.
class ShopListCard extends StatelessWidget {
  const ShopListCard({
    super.key,
    required this.shop,
    required this.distanceKm,
    required this.favourite,
    required this.onTap,
    required this.onFavourite,
  });

  final Shop shop;
  final double? distanceKm;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback? onFavourite;

  @override
  Widget build(BuildContext context) => Material(
    color: HomeTone.card,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: HomeTone.border),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 112,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MarketArt(category: shop.category, iconSize: 34),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: OpenPill(open: shop.isOpenAt()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: shop.name,
                              children: [
                                if (shop.isVerified)
                                  const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: HomeTone.violet,
                                        semanticLabel: 'Verified',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomeTone.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        HeartButton(
                          favourite: favourite,
                          label: 'Save ${shop.name}',
                          onPressed: onFavourite,
                        ),
                      ],
                    ),
                    Text(
                      [
                        shop.category.label,
                        if (distanceKm != null) shortDistance(distanceKm!),
                      ].join(' · '),
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RatingLine(shop: shop),
                    if (shop.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        shop.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HomeTone.ink,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: MarketLinkButton(
                        label: 'View Shop',
                        onPressed: onTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Product card for the Featured Products grid: picture, price, which shop
/// sells it, how far away, the shop's rating, then "View" and "Purchase".
class ProductTileCard extends StatelessWidget {
  const ProductTileCard({
    super.key,
    required this.product,
    required this.shop,
    required this.distanceKm,
    required this.favourite,
    required this.onTap,
    required this.onFavourite,
    required this.onPurchase,
  });

  final Product product;

  /// The shop selling it, if known (for distance and rating).
  final Shop? shop;
  final double? distanceKm;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback? onFavourite;

  /// Opens the order sheet; null disables "Purchase" (e.g. no chat).
  final VoidCallback? onPurchase;

  @override
  Widget build(BuildContext context) => Material(
    color: HomeTone.card,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: HomeTone.border),
    ),
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MarketArt(category: product.category, iconSize: 40),
                Positioned(
                  right: 6,
                  top: 6,
                  child: HeartButton(
                    favourite: favourite,
                    label: 'Save ${product.name}',
                    onPressed: onFavourite,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomeTone.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  ugx(product.priceUgx),
                  style: const TextStyle(
                    color: HomeTone.violet,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _MetaLine(
                  icon: Icons.storefront_outlined,
                  text: product.shopName,
                ),
                if (distanceKm != null)
                  _MetaLine(
                    icon: Icons.location_on_outlined,
                    text: shortDistance(distanceKm!),
                  ),
                if (shop != null) RatingLine(shop: shop!),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: _smallButton(outlined: true),
                        child: const Text('View', maxLines: 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FilledButton(
                        onPressed: onPurchase,
                        style: _smallButton(outlined: false),
                        child: const Text(
                          'Purchase',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

ButtonStyle _smallButton({required bool outlined}) {
  const text = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);
  const shape = StadiumBorder();
  const size = Size(0, 34);
  const pad = EdgeInsets.symmetric(horizontal: 6);
  return outlined
      ? OutlinedButton.styleFrom(
          foregroundColor: HomeTone.violet,
          minimumSize: size,
          padding: pad,
          side: const BorderSide(color: HomeTone.violet, width: 1.3),
          shape: shape,
          textStyle: text,
        )
      : FilledButton.styleFrom(
          backgroundColor: HomeTone.violet,
          foregroundColor: Colors.white,
          minimumSize: size,
          padding: pad,
          shape: shape,
          textStyle: text,
        );
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Icon(icon, size: 15, color: HomeTone.violet),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: HomeTone.ink, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
