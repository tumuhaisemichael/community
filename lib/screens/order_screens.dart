import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/market_order.dart';
import '../models/marketplace.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../widgets/market_widgets.dart';
import '../widgets/page_frame.dart';
import 'marketplace_screen.dart';

void _snack(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}

/// "Today, 5:00 PM", "Yesterday, 9:12 AM" or "3 Nov, 4:30 PM".
String orderTime(DateTime? time, {DateTime? now}) {
  if (time == null) return 'Just now';
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(time);
  final clock = DateFormat.jm().format(time).replaceAll('\u202f', ' ');
  if (day == today) return 'Today, $clock';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday, $clock';
  }
  return '${DateFormat('d MMM').format(time)}, $clock';
}

/// Text shared from a product's Share button.
String shareProductText(Product p) =>
    '${p.displayName}: ${ugx(p.priceUgx)}'
    '${p.unit.isEmpty ? '' : ' per ${p.unit}'} at ${p.shopName}. '
    'Find it in the Marketplace on the Community app.';

/// Chat text telling the other person about an order.
String orderMessageText(MarketOrder order, {OrderStatus? status}) {
  final head = status == null
      ? '🛒 New order request #${order.code}'
      : '📦 Order #${order.code} is now ${status == OrderStatus.ready ? order.readyLabel : status.label}';
  return [
    head,
    '${order.itemName} × ${order.quantity}',
    'Total: ${ugx(order.totalUgx)} · ${order.fulfilment.label}',
    if (status == null && order.note.trim().isNotEmpty)
      'Note: ${order.note.trim()}',
  ].join('\n');
}

const _title = TextStyle(
  color: HomeTone.ink,
  fontSize: 15,
  fontWeight: FontWeight.w800,
);
const _muted = TextStyle(color: HomeTone.muted, fontSize: 13);

Widget _thumb(MarketCategory category, {double size = 60}) => ClipRRect(
  borderRadius: BorderRadius.circular(14),
  child: SizedBox.square(
    dimension: size,
    child: MarketArt(category: category, iconSize: size * .45),
  ),
);

// Colours are set for every state: the app's dark theme would otherwise
// draw disabled labels near-white on these white pages.
ButtonStyle _outlined() => OutlinedButton.styleFrom(
  foregroundColor: HomeTone.violet,
  disabledForegroundColor: HomeTone.violet.withValues(alpha: .45),
  backgroundColor: HomeTone.card,
  disabledBackgroundColor: HomeTone.card,
  minimumSize: const Size(0, 52),
  side: const BorderSide(color: HomeTone.violet, width: 1.3),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
);

/// Small coloured pill, e.g. "In Stock", "Pending".
class _Chip extends StatelessWidget {
  const _Chip(this.text, {required this.color, this.dot = false});
  final String text;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.order});
  final MarketOrder order;

  @override
  Widget build(BuildContext context) => _Chip(
    order.status == OrderStatus.ready ? order.readyLabel : order.status.label,
    color: order.status.color,
  );
}

/// A tappable row with an icon, title, subtitle and chevron.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: HomeTone.violet, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _title.copyWith(fontSize: 14)),
                if (subtitle != null) Text(subtitle!, style: _muted),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: HomeTone.ink),
        ],
      ),
    ),
  );
}

void _openShop(BuildContext context, MarketContext market, String shopId) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopScreen(market: market, shopId: shopId),
      ),
    );

/// Opens a product's details page.
Future<void> openProduct(
  BuildContext context,
  MarketContext market,
  Product product,
) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ProductDetailsScreen(market: market, product: product),
  ),
);

/// Starts an order for [product] ("Purchase" / "Request Order").
Future<void> openOrderRequest(
  BuildContext context,
  MarketContext market,
  Product product,
) async {
  if (!product.inStock) {
    _snack(context, '${product.name} is out of stock right now.');
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RequestOrderScreen(market: market, product: product),
    ),
  );
}

// ======================================================= product details

/// 1. Product Details: picture, price, stock, the shop, then Chat and
/// Request Order. Read-only: owners change products from their shop page.
class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({
    super.key,
    required this.market,
    required this.product,
  });
  final MarketContext market;
  final Product product;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
    stream: market.products.stream,
    initialData: market.products.latest,
    builder: (context, pSnap) {
      // Follow live edits; fall back to what was tapped.
      final p = (pSnap.data ?? const <Product>[]).firstWhere(
        (x) => x.id == product.id,
        orElse: () => product,
      );
      return StreamBuilder<MarketFavourites>(
        stream: market.favourites.stream,
        initialData: market.favourites.latest,
        builder: (context, fSnap) {
          final fav = (fSnap.data ?? const MarketFavourites()).products
              .contains(p.id);
          Shop? shop;
          for (final s in market.shops.latest ?? const <Shop>[]) {
            if (s.id == p.shopId) shop = s;
          }
          return _details(context, p, shop, fav);
        },
      );
    },
  );

  Widget _details(BuildContext context, Product p, Shop? shop, bool fav) {
    final mine = p.ownerId == market.userId;
    final distance = shop == null ? null : market.distanceTo(shop);
    return PageFrame(
      title: 'Product Details',
      subtitle: p.shopName,
      actions: [
        HeaderRoundButton(
          icon: Icons.share_outlined,
          tooltip: 'Share ${p.name}',
          onPressed: () => _share(context, p),
        ),
        HeaderRoundButton(
          icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          tooltip: fav ? 'Remove from saved' : 'Save ${p.name}',
          onPressed: () => market.toggleProduct(context, p, fav),
        ),
      ],
      // Chat + Request Order, as in the design. On your own product you
      // can still order, but there's nobody to chat to.
      bottomBar: Row(
        children: [
          if (market.chatRepository != null) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: mine
                    ? () => _snack(
                        context,
                        'This is your shop. Customers\' messages about it '
                        'reach you in Messages.',
                      )
                    : () => market.messageOwner(
                        context,
                        ownerId: p.ownerId,
                        ownerName: p.shopName,
                      ),
                style: _outlined(),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 3,
            child: FramePrimaryButton(
              label: p.inStock ? 'Request Order' : 'Out of Stock',
              icon: Icons.shopping_bag_outlined,
              onPressed: p.inStock
                  ? () => openOrderRequest(context, market, p)
                  : null,
            ),
          ),
        ],
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 190,
            child: MarketArt(category: p.category, iconSize: 72),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          p.displayName,
          style: const TextStyle(
            color: HomeTone.ink,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text.rich(
          TextSpan(
            text: ugx(p.priceUgx),
            style: const TextStyle(
              color: HomeTone.violet,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
            children: [
              if (p.unit.isNotEmpty)
                TextSpan(
                  text: ' per ${p.unit}',
                  style: const TextStyle(
                    color: HomeTone.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            p.description,
            style: const TextStyle(color: HomeTone.ink, height: 1.4),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            p.inStock
                ? const _Chip('In Stock', color: Color(0xFF16A34A), dot: true)
                : const _Chip(
                    'Out of Stock',
                    color: Color(0xFFDC2626),
                    dot: true,
                  ),
            if (p.unit.isNotEmpty)
              _Chip('Per ${p.unit}', color: HomeTone.violet),
            _Chip(p.category.label, color: p.category.color),
          ],
        ),
        const SizedBox(height: 14),
        FrameCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: () => _openShop(context, market, p.shopId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _thumb(shop?.category ?? p.category, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _title,
                              ),
                            ),
                            if (shop?.isVerified ?? false) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 17,
                                color: HomeTone.violet,
                              ),
                            ],
                          ],
                        ),
                        if (shop != null) RatingLine(shop: shop),
                        if (distance != null)
                          Text(
                            '${shortDistance(distance)} away',
                            style: _muted,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HomeTone.ink),
                ],
              ),
            ),
          ),
        ),
        FrameCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _LinkRow(
                icon: Icons.info_outline_rounded,
                title: 'Delivery & Pickup',
                subtitle: 'Pickup or vendor-arranged delivery',
                onTap: () => _showFulfilmentInfo(context, shop),
              ),
              _LinkRow(
                icon: Icons.fact_check_outlined,
                title: 'Product Details',
                onTap: () => _showProductInfo(context, p, mine),
              ),
              _LinkRow(
                icon: Icons.star_border_rounded,
                title: shop == null || shop.ratingCount == 0
                    ? 'Ratings'
                    : 'Ratings (${shop.ratingCount})',
                onTap: () => _openShop(context, market, p.shopId),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context, Product p) {
    // iPads need to know where the share sheet points from: the header's
    // top-right corner, where the button is.
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    return SharePlus.instance.share(
      ShareParams(
        subject: p.displayName,
        text: shareProductText(p),
        sharePositionOrigin: Rect.fromLTWH(size.width - 110, top + 8, 44, 44),
      ),
    );
  }

  void _showProductInfo(BuildContext context, Product p, bool mine) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: HomeTone.card,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Product Details', style: _title),
                const SizedBox(height: 8),
                _Fact(icon: Icons.sell_outlined, label: 'Name', value: p.name),
                _Fact(
                  icon: Icons.payments_outlined,
                  label: 'Price',
                  value: p.unit.isEmpty
                      ? ugx(p.priceUgx)
                      : '${ugx(p.priceUgx)} per ${p.unit}',
                ),
                _Fact(
                  icon: p.category.icon,
                  label: 'Category',
                  value: p.category.label,
                ),
                _Fact(
                  icon: Icons.inventory_2_outlined,
                  label: 'Stock',
                  value: p.inStock ? 'In stock' : 'Out of stock',
                ),
                _Fact(
                  icon: Icons.storefront_outlined,
                  label: 'Sold by',
                  value: p.shopName,
                ),
                if (p.createdAt != null)
                  _Fact(
                    icon: Icons.event_outlined,
                    label: 'Listed',
                    value: DateFormat('d MMM y').format(p.createdAt!),
                  ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    p.description,
                    style: const TextStyle(color: HomeTone.ink, height: 1.4),
                  ),
                ],
                if (mine) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'This is your product. To change it, open your shop and '
                    'tap the product.',
                    style: _muted,
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  void _showFulfilmentInfo(
    BuildContext context,
    Shop? shop,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomeTone.card,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Delivery & Pickup', style: _title),
            const SizedBox(height: 12),
            for (final f in Fulfilment.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(f.icon, color: HomeTone.violet),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        f == Fulfilment.pickup
                            ? 'Pickup: collect from the shop'
                                  '${shop == null || shop.address.isEmpty ? '' : ' at ${shop.address}'}'
                                  '${shop == null ? '' : ' (${shop.hoursLabel})'}.'
                            : 'Delivery: ask the vendor to deliver. '
                                  'They confirm when they accept, and you '
                                  'can share your address in Chat.',
                        style: const TextStyle(
                          color: HomeTone.ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Text(
              'Payment is agreed with the vendor directly.',
              style: _muted,
            ),
          ],
        ),
      ),
    ),
  );
}

// ========================================================= request order

/// 2. Place Order Request: quantity, pickup or delivery, and a note.
class RequestOrderScreen extends StatefulWidget {
  const RequestOrderScreen({
    super.key,
    required this.market,
    required this.product,
  });
  final MarketContext market;
  final Product product;

  @override
  State<RequestOrderScreen> createState() => _RequestOrderScreenState();
}

class _RequestOrderScreenState extends State<RequestOrderScreen> {
  int _quantity = 1;
  Fulfilment _fulfilment = Fulfilment.pickup;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final market = widget.market;
    final me = market.authService.currentUser;
    if (me == null) return;
    final p = widget.product;
    setState(() => _sending = true);
    try {
      final draft = MarketOrder(
        id: '',
        buyerId: me.uid,
        buyerName: me.displayName ?? me.email?.split('@').first ?? 'Neighbour',
        sellerId: p.ownerId,
        shopId: p.shopId,
        shopName: p.shopName,
        productId: p.id,
        productName: p.name,
        category: p.category,
        priceUgx: p.priceUgx,
        unit: p.unit,
        quantity: _quantity,
        fulfilment: _fulfilment,
        note: _note.text.trim(),
      );
      final id = await market.repository.createOrder(draft);
      final order = draft.copyWith(id: id);
      // Let the seller know in Messages (best effort).
      market.notify(
        otherUserId: p.ownerId,
        otherUserName: p.shopName,
        text: orderMessageText(order),
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSentScreen(market: market, order: order),
        ),
      );
    } catch (e) {
      if (mounted) _snack(context, 'Could not send your order: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return PageFrame(
      title: 'Request Order',
      subtitle: p.shopName,
      bottomBar: FramePrimaryButton(
        label: 'Send Order Request',
        busy: _sending,
        onPressed: _send,
      ),
      children: [
        FrameCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _thumb(p.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayName, style: _title),
                    Text.rich(
                      TextSpan(
                        text: ugx(p.priceUgx),
                        style: const TextStyle(
                          color: HomeTone.violet,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          if (p.unit.isNotEmpty)
                            TextSpan(
                              text: ' per ${p.unit}',
                              style: const TextStyle(
                                color: HomeTone.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(p.shopName, style: _muted),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('Quantity', required: true),
                const SizedBox(height: 8),
                _Stepper(
                  value: _quantity,
                  onChanged: (v) => setState(() => _quantity = v),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Shrinks rather than overflowing for big totals or large text.
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerRight,
                fit: BoxFit.scaleDown,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total (est.)',
                      style: TextStyle(color: HomeTone.ink),
                    ),
                    Text(
                      ugx(p.priceUgx * _quantity),
                      style: const TextStyle(
                        color: HomeTone.violet,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _Label('Fulfilment Method', required: true),
        const SizedBox(height: 8),
        for (final f in Fulfilment.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceCard(
              fulfilment: f,
              selected: _fulfilment == f,
              onTap: () => setState(() => _fulfilment = f),
            ),
          ),
        const SizedBox(height: 10),
        const _Label('Note to Vendor (Optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 4,
          maxLength: 250,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: HomeTone.ink),
          decoration: frameInput(hint: 'E.g. Please pack the freshest ones.'),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: text,
      style: _title,
      children: [
        if (required)
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFDC2626)),
          ),
      ],
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, int? to) => SizedBox(
      width: 46,
      height: 46,
      child: IconButton(
        tooltip: tip,
        onPressed: to == null ? null : () => onChanged(to),
        color: HomeTone.violet,
        icon: Icon(icon),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: HomeTone.card,
        border: Border.all(color: HomeTone.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, 'Less', value > 1 ? value - 1 : null),
          Container(
            width: 52,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: HomeTone.border),
              ),
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          button(Icons.add_rounded, 'More', value < 99 ? value + 1 : null),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.fulfilment,
    required this.selected,
    required this.onTap,
  });
  final Fulfilment fulfilment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? HomeTone.violet.withValues(alpha: .06) : HomeTone.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? HomeTone.violet : HomeTone.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? HomeTone.violet : HomeTone.muted,
              ),
              const SizedBox(width: 12),
              Icon(fulfilment.icon, color: HomeTone.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fulfilment.label,
                      style: _title.copyWith(fontSize: 14),
                    ),
                    Text(fulfilment.hint, style: _muted),
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

// ============================================================ order sent

/// 3. Order Request Sent: confirmation while the vendor decides.
class OrderSentScreen extends StatelessWidget {
  const OrderSentScreen({super.key, required this.market, required this.order});
  final MarketContext market;
  final MarketOrder order;

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Order Sent',
    subtitle: 'Waiting for ${order.shopName}',
    children: [
      const SizedBox(height: 8),
      Center(
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: HomeTone.violet.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shopping_bag_outlined,
            size: 54,
            color: HomeTone.violet,
          ),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Order Request Sent!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: HomeTone.ink,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Your order request has been sent to ${order.shopName}. '
        'You\'ll get a message when they respond.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: HomeTone.muted, height: 1.4),
      ),
      const SizedBox(height: 18),
      FrameCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: HomeTone.violet.withValues(alpha: .05),
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(child: Text('Order #${order.code}', style: _title)),
                  OrderStatusPill(order: order),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _thumb(order.category),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.itemName, style: _title),
                            Text('Qty: ${order.quantity}', style: _muted),
                            Text(
                              '${ugx(order.totalUgx)} (est.)',
                              style: const TextStyle(color: HomeTone.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _Fact(
                    icon: order.fulfilment.icon,
                    label: 'Fulfilment',
                    value: order.fulfilment.label,
                  ),
                  _Fact(
                    icon: Icons.storefront_outlined,
                    label: 'Shop',
                    value: order.shopName,
                  ),
                  _Fact(
                    icon: Icons.schedule_rounded,
                    label: 'Requested',
                    value: orderTime(order.createdAt ?? DateTime.now()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      FramePrimaryButton(
        label: 'View Order',
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrderDetailsScreen(market: market, orderId: order.id),
          ),
        ),
      ),
      if (market.chatRepository != null && order.sellerId != market.userId) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => market.messageOwner(
            context,
            ownerId: order.sellerId,
            ownerName: order.shopName,
          ),
          style: _outlined(),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          label: const Text('Chat with Vendor'),
        ),
      ],
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 19, color: HomeTone.violet),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: HomeTone.ink)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: HomeTone.ink)),
        ),
      ],
    ),
  );
}

// ========================================================= order details

/// 4. Order Details & Tracking. Buyers see progress and can cancel early or
/// confirm receipt; the seller moves the order through each step here.
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.market,
    required this.orderId,
  });
  final MarketContext market;
  final String orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final Stream<MarketOrder?> _order = widget.market.repository.watchOrder(
    widget.orderId,
  );
  bool _busy = false;

  MarketContext get market => widget.market;

  Future<void> _setStatus(MarketOrder order, OrderStatus status) async {
    if (status == OrderStatus.cancelled || status == OrderStatus.declined) {
      final verb = status == OrderStatus.cancelled ? 'Cancel' : 'Decline';
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('$verb order #${order.code}?'),
          content: const Text('This can\'t be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep Order'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('$verb Order'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await market.repository.setOrderStatus(order.id, status);
      final iAmSeller = order.sellerId == market.userId;
      market.notify(
        otherUserId: iAmSeller ? order.buyerId : order.sellerId,
        otherUserName: iAmSeller ? order.buyerName : order.shopName,
        text: orderMessageText(order, status: status),
      );
    } catch (e) {
      if (mounted) _snack(context, 'Could not update the order: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MarketOrder?>(
    stream: _order,
    builder: (context, snap) {
      final order = snap.data;
      if (order == null) {
        return PageFrame(
          title: 'Order',
          subtitle: 'Order details',
          children: [
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: snap.connectionState == ConnectionState.waiting
                    ? const CircularProgressIndicator(color: HomeTone.violet)
                    : const Text('This order is no longer available.'),
              ),
            ),
          ],
        );
      }
      return _page(order);
    },
  );

  Widget _page(MarketOrder order) {
    final seller = order.sellerId == market.userId;
    Shop? shop;
    for (final s in market.shops.latest ?? const <Shop>[]) {
      if (s.id == order.shopId) shop = s;
    }
    return PageFrame(
      title: 'Order #${order.code}',
      subtitle: seller ? 'From ${order.buyerName}' : order.shopName,
      bottomBar: _actions(order, seller),
      children: [
        FrameCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _thumb(order.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.itemName, style: _title),
                    Text('Qty: ${order.quantity}', style: _muted),
                    Text(
                      ugx(order.totalUgx),
                      style: const TextStyle(
                        color: HomeTone.violet,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              OrderStatusPill(order: order),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('Order Progress', style: _title),
        const SizedBox(height: 10),
        _Progress(order: order, seller: seller),
        const SizedBox(height: 8),
        FrameCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(order.fulfilment.icon, color: HomeTone.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.fulfilment.label} Details',
                      style: _title.copyWith(fontSize: 14),
                    ),
                    Text(order.shopName, style: _muted),
                    if (order.fulfilment == Fulfilment.pickup)
                      Text(
                        [
                          if (shop != null && shop.address.isNotEmpty)
                            shop.address,
                          if (shop != null && market.distanceTo(shop) != null)
                            '${shortDistance(market.distanceTo(shop)!)} away',
                          if (shop != null) shop.hoursLabel,
                        ].join(', '),
                        style: _muted,
                      )
                    else
                      const Text(
                        'The vendor arranges delivery. Share your address '
                        'in Chat.',
                        style: _muted,
                      ),
                    if (order.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Note: ${order.note}',
                        style: const TextStyle(color: HomeTone.ink),
                      ),
                    ],
                  ],
                ),
              ),
              if (order.fulfilment == Fulfilment.pickup &&
                  (shop?.hasLocation ?? false))
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.https('www.google.com', '/maps/dir/', {
                      'api': '1',
                      'destination': '${shop!.latitude},${shop.longitude}',
                    }),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: HomeTone.violet,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Get Directions'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _actions(MarketOrder order, bool seller) {
    final other = seller ? order.buyerId : order.sellerId;
    final chat = market.chatRepository == null || other == market.userId
        ? null
        : OutlinedButton.icon(
            onPressed: () => market.messageOwner(
              context,
              ownerId: seller ? order.buyerId : order.sellerId,
              ownerName: seller ? order.buyerName : order.shopName,
            ),
            style: _outlined(),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Chat'),
          );

    Widget? main;
    Widget? second;
    final s = order.status;
    if (seller) {
      final next = switch (s) {
        OrderStatus.requested => (OrderStatus.accepted, 'Accept Order'),
        OrderStatus.accepted => (OrderStatus.preparing, 'Start Preparing'),
        OrderStatus.preparing => (
          OrderStatus.ready,
          order.fulfilment == Fulfilment.pickup
              ? 'Mark Ready'
              : 'Out for Delivery',
        ),
        OrderStatus.ready => (OrderStatus.completed, 'Mark Completed'),
        _ => null,
      };
      if (next != null) {
        main = FramePrimaryButton(
          label: next.$2,
          busy: _busy,
          onPressed: () => _setStatus(order, next.$1),
        );
      }
      if (s == OrderStatus.requested) {
        second = _cancelButton('Decline', () {
          _setStatus(order, OrderStatus.declined);
        });
      } else if (s == OrderStatus.accepted && order.buyerId == market.userId) {
        // Your own order from your own shop.
        second = _cancelButton('Cancel Order', () {
          _setStatus(order, OrderStatus.cancelled);
        });
      }
    } else {
      if (s == OrderStatus.ready) {
        main = FramePrimaryButton(
          label: 'Confirm Received',
          busy: _busy,
          onPressed: () => _setStatus(order, OrderStatus.completed),
        );
      } else if (s == OrderStatus.completed) {
        main = FramePrimaryButton(
          label: 'Rate the Shop',
          icon: Icons.star_border_rounded,
          onPressed: () => _openShop(context, market, order.shopId),
        );
      }
      if (s == OrderStatus.requested || s == OrderStatus.accepted) {
        second = _cancelButton('Cancel Order', () {
          _setStatus(order, OrderStatus.cancelled);
        });
      }
    }

    final buttons = [?chat, ?second, ?main];
    if (buttons.isEmpty) return null;
    if (main != null && (chat != null || second != null)) {
      // Main action on its own row, the smaller ones above it.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (chat != null) Expanded(child: chat),
              if (chat != null && second != null) const SizedBox(width: 10),
              if (second != null) Expanded(child: second),
            ],
          ),
          const SizedBox(height: 10),
          main,
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _cancelButton(String label, VoidCallback onPressed) =>
      OutlinedButton.icon(
        onPressed: _busy ? null : onPressed,
        style: _outlined().copyWith(
          foregroundColor: const WidgetStatePropertyAll(Color(0xFFDC2626)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFFDC2626), width: 1.3),
          ),
        ),
        icon: const Icon(Icons.close_rounded),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

/// The Requested → Completed timeline.
class _Progress extends StatelessWidget {
  const _Progress({required this.order, required this.seller});
  final MarketOrder order;
  final bool seller;

  @override
  Widget build(BuildContext context) {
    final pickup = order.fulfilment == Fulfilment.pickup;
    final steps = [
      (OrderStatus.requested, 'Requested', 'Waiting for the vendor'),
      (
        OrderStatus.accepted,
        'Accepted',
        seller
            ? 'Tap Accept Order to confirm'
            : 'The vendor confirms your order',
      ),
      (
        OrderStatus.preparing,
        'Preparing',
        'The vendor is getting the order ready',
      ),
      (
        OrderStatus.ready,
        order.readyLabel,
        pickup
            ? 'You\'ll get a message when it\'s ready'
            : 'The vendor is on the way',
      ),
      (
        OrderStatus.completed,
        'Completed',
        seller
            ? 'The order was handed over'
            : 'Confirm receipt and rate the shop',
      ),
    ];
    final stopped =
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.declined;
    final reached = stopped
        ? steps.lastIndexWhere((s) => order.times.containsKey(s.$1))
        : steps.indexWhere((s) => s.$1 == order.status);

    return FrameCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stopped)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: order.status.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.status == OrderStatus.cancelled
                          ? 'This order was cancelled'
                          : 'The vendor declined this order',
                      style: TextStyle(
                        color: order.status.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (order.times[order.status] != null)
                    Text(orderTime(order.times[order.status]), style: _muted),
                ],
              ),
            ),
          for (var i = 0; i < steps.length; i++)
            _Step(
              title: steps[i].$2,
              subtitle: i <= reached
                  ? orderTime(
                      order.times[steps[i].$1] ??
                          (i == 0 ? order.createdAt : null),
                    )
                  : steps[i].$3,
              done: i <= reached,
              last: i == steps.length - 1,
              lineDone: i < reached,
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.last,
    required this.lineDone,
  });
  final String title;
  final String subtitle;
  final bool done;
  final bool last;
  final bool lineDone;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? HomeTone.violet : HomeTone.card,
                  border: Border.all(
                    color: done ? HomeTone.violet : HomeTone.border,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: lineDone ? HomeTone.violet : HomeTone.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Semantics(
              container: true,
              checked: done,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _title.copyWith(fontSize: 14)),
                  Text(subtitle, style: _muted),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================= my orders

/// Orders you placed and, if you sell, orders for your shop.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, required this.market, this.sales = false});
  final MarketContext market;

  /// Start on the "Shop Orders" tab.
  final bool sales;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  late bool _sales = widget.sales;
  late final _purchases = widget.market.repository.watchOrders(
    widget.market.userId,
    asSeller: false,
  );
  late final _received = widget.market.repository.watchOrders(
    widget.market.userId,
    asSeller: true,
  );

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'My Orders',
    subtitle: 'Track what you buy and sell',
    children: [
      Row(
        children: [
          for (final sales in [false, true]) ...[
            if (sales) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(sales ? 'Shop Orders' : 'Purchases'),
              selected: _sales == sales,
              showCheckmark: false,
              selectedColor: HomeTone.violet,
              backgroundColor: HomeTone.card,
              side: const BorderSide(color: HomeTone.border),
              labelStyle: TextStyle(
                color: _sales == sales ? Colors.white : HomeTone.ink,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => setState(() => _sales = sales),
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      StreamBuilder<List<MarketOrder>>(
        key: ValueKey(_sales),
        stream: _sales ? _received : _purchases,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: CircularProgressIndicator(color: HomeTone.violet),
              ),
            );
          }
          final orders = snap.data!;
          if (orders.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _sales
                    ? 'No orders for your shop yet.'
                    : 'You haven\'t ordered anything yet. Tap Purchase on a '
                          'product to start.',
                textAlign: TextAlign.center,
                style: _muted,
              ),
            );
          }
          return Column(
            children: [
              for (final o in orders)
                _OrderTile(market: widget.market, order: o, sale: _sales),
            ],
          );
        },
      ),
    ],
  );
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.market,
    required this.order,
    required this.sale,
  });
  final MarketContext market;
  final MarketOrder order;
  final bool sale;

  @override
  Widget build(BuildContext context) {
    return FrameCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OrderDetailsScreen(market: market, orderId: order.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _thumb(order.category, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.itemName} × ${order.quantity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _title.copyWith(fontSize: 14),
                    ),
                    Text(
                      '#${order.code} · ${sale ? order.buyerName : order.shopName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _muted,
                    ),
                    Text(
                      '${ugx(order.totalUgx)} · ${orderTime(order.createdAt)}',
                      style: _muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OrderStatusPill(order: order),
            ],
          ),
        ),
      ),
    );
  }
}
