import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/marketplace.dart';
import '../services/address_lookup.dart';
import '../theme/home_tone.dart';
import '../widgets/market_widgets.dart';
import '../widgets/page_frame.dart';
import 'marketplace_screen.dart';
import 'vacation_house_picker_screen.dart';

/// "Start Selling": a 4-step form that creates a shop.
///
/// 1 Shop details · 2 Location · 3 Verification · 4 Review.
class ShopFormScreen extends StatefulWidget {
  const ShopFormScreen({super.key, required this.market, this.addressLookup});
  final MarketContext market;

  /// Turns the pinned spot into an address; tests pass their own.
  final AddressLookup? addressLookup;

  @override
  State<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends State<ShopFormScreen> {
  static const _steps = ['Shop Details', 'Location', 'Verification', 'Review'];
  static const _defaultCenter = LatLng(0.3476, 32.5825);
  static const _guidelines = [
    'I sell legal goods and services only.',
    'My prices and descriptions are honest.',
    'I will reply to neighbours who contact me.',
  ];

  late final AddressLookup _lookup = widget.addressLookup ?? AddressLookup();

  int _step = 0;
  bool _saving = false;

  // Step 1
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  MarketCategory? _category;
  String _contact = 'chat';

  // Step 2
  late LatLng? _location = widget.market.currentLocation;
  final _address = TextEditingController();
  bool _locating = false;
  int _open = 8;
  int _close = 20;

  // Step 3
  final _registration = TextEditingController();
  final _agreed = List<bool>.filled(_guidelines.length, false);

  @override
  void initState() {
    super.initState();
    final here = _location;
    if (here != null) _fillAddress(here);
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _phone, _address, _registration]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Shows [text], replacing any message still on screen.
  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  // ------------------------------------------------------------ location

  Future<void> _fillAddress(LatLng point) async {
    final address = await _lookup.addressFor(point);
    if (!mounted || address == null) return;
    // Only fill it in if the owner has not typed their own.
    if (_address.text.trim().isEmpty) setState(() => _address.text = address);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is needed.');
      }
      final p = await Geolocator.getCurrentPosition();
      final point = LatLng(p.latitude, p.longitude);
      if (!mounted) return;
      setState(() {
        _location = point;
        _address.clear();
      });
      await _fillAddress(point);
    } catch (e) {
      if (mounted) {
        _snack(
          e is StateError
              ? e.message
              : 'Could not get your location. Try picking it on the map.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => VacationHousePickerScreen(
          initialCenter: _location ?? _defaultCenter,
          initialSelection: _location,
          title: 'Pin your shop',
          pinLabel: 'Shop location',
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _location = picked;
      _address.clear();
    });
    await _fillAddress(picked);
  }

  // ------------------------------------------------------------ steps

  /// What is missing on the current step, or null if it is complete.
  String? get _problem => switch (_step) {
    0 when _name.text.trim().isEmpty => 'Please enter your shop name.',
    0 when _category == null => 'Please choose a business category.',
    0 when _description.text.trim().isEmpty => 'Please describe what you sell.',
    0
        when _contact == 'phone' &&
            _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 9 =>
      'Please enter a valid phone number.',
    1 when _location == null => 'Please set where your shop is.',
    2 when _agreed.contains(false) => 'Please agree to the selling guidelines.',
    _ => null,
  };

  void _next() {
    final problem = _problem;
    if (problem != null) {
      _snack(problem);
      return;
    }
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _create();
    }
  }

  Future<void> _create() async {
    final user = widget.market.authService.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final registration = _registration.text.trim();
      final id = await widget.market.repository.createShop(
        Shop(
          id: '',
          ownerId: user.uid,
          ownerName:
              user.displayName ?? user.email?.split('@').first ?? 'Neighbour',
          name: _name.text.trim(),
          category: _category!,
          description: _description.text.trim(),
          address: _address.text.trim(),
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          openHour: _open,
          closeHour: _close,
          contactPreference: _contact,
          phone: _contact == 'phone' ? _phone.text.trim() : '',
          registrationNumber: registration,
          verificationRequested: registration.isNotEmpty,
        ),
      );
      if (!mounted) return;
      _snack('Your shop is live! Now add some products.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ShopScreen(market: widget.market, shopId: id),
        ),
      );
    } catch (e) {
      if (mounted) _snack('Could not create your shop: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _steps.length - 1;
    return PageFrame(
      title: 'Start Selling',
      subtitle: 'List your shop, add products and sell to your neighbours.',
      badge: const _ShopBadge(),
      bottomBar: Row(
        children: [
          if (_step > 0) ...[
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _saving ? null : () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeTone.violet,
                  side: const BorderSide(color: HomeTone.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FramePrimaryButton(
              label: last
                  ? 'Create My Shop'
                  : 'Continue to ${_steps[_step + 1]}',
              icon: last
                  ? Icons.storefront_rounded
                  : Icons.arrow_forward_rounded,
              busy: _saving,
              onPressed: _next,
            ),
          ),
        ],
      ),
      children: [
        _StepBar(
          steps: _steps,
          current: _step,
          onTap: (i) {
            if (i < _step) setState(() => _step = i);
          },
        ),
        const SizedBox(height: 14),
        FrameCard(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_step),
              child: switch (_step) {
                0 => _detailsStep(),
                1 => _locationStep(),
                2 => _verificationStep(),
                _ => _reviewStep(),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepHeader(IconData icon, String title, String subtitle) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: HomeTone.violetDim,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: HomeTone.violet, size: 26),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: HomeTone.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: HomeTone.violetDim,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          'Step ${_step + 1} of ${_steps.length}',
          style: const TextStyle(
            color: HomeTone.violet,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  // ------------------------------------------------------- 1 shop details

  Widget _detailsStep() {
    const field = TextStyle(color: HomeTone.ink, fontSize: 15);
    final category = _category;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.storefront_rounded,
          'Shop Details',
          'Tell us about your business.',
        ),
        const SizedBox(height: 18),
        const _Label('Shop Name', required: true),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          style: field,
          decoration: frameInput(hint: 'e.g. Riverside Grocers'),
        ),
        const SizedBox(height: 16),
        const _Label('Business Category', required: true),
        _CategoryGrid(
          selected: category,
          onSelect: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        const _Label('Shop Description', required: true),
        TextField(
          controller: _description,
          minLines: 3,
          maxLines: 5,
          maxLength: 250,
          textCapitalization: TextCapitalization.sentences,
          style: field,
          decoration: frameInput(
            hint: 'Describe what you sell, your shop or services…',
          ),
        ),
        const SizedBox(height: 6),
        const _Label('Shop Picture'),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 110,
            child: MarketArt(
              category: category ?? MarketCategory.other,
              iconSize: 48,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your shop uses this picture for its category. Uploading your own '
          'logo and cover photo is coming soon.',
          style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        const _Label('Contact Preference', required: true),
        const Text(
          'How would you like customers to reach you?',
          style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        _ContactOption(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Chat on Community',
          subtitle: 'Receive enquiries and orders in Messages',
          selected: _contact == 'chat',
          onTap: () => setState(() => _contact = 'chat'),
        ),
        const SizedBox(height: 8),
        _ContactOption(
          icon: Icons.call_outlined,
          title: 'Phone & Chat',
          subtitle: 'Allow calls and messages',
          selected: _contact == 'phone',
          onTap: () => setState(() => _contact = 'phone'),
        ),
        if (_contact == 'phone') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            style: field,
            decoration: frameInput(
              label: 'Phone number',
              hint: 'e.g. 0772 123456',
              icon: Icons.call_outlined,
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ 2 location

  Widget _locationStep() {
    String hourLabel(int h) => h == 24
        ? 'Midnight'
        : '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}';
    Widget hours(String label, int value, ValueChanged<int> onChanged) =>
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            decoration: frameInput(label: label, icon: Icons.schedule_rounded),
            dropdownColor: HomeTone.card,
            style: const TextStyle(color: HomeTone.ink, fontSize: 15),
            items: [
              for (var h = 0; h <= 24; h++)
                DropdownMenuItem(value: h, child: Text(hourLabel(h))),
            ],
            onChanged: (v) => onChanged(v ?? value),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.location_on_rounded,
          'Location',
          'Where neighbours can find you.',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.my_location_rounded,
                label: _locating ? 'Locating…' : 'Use my location',
                onTap: _locating ? null : _useMyLocation,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: Icons.map_outlined,
                label: _location == null ? 'Pick on map' : 'Repick on map',
                onTap: _pickOnMap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              _location == null
                  ? Icons.location_off_outlined
                  : Icons.check_circle_rounded,
              size: 17,
              color: _location == null ? HomeTone.muted : HomeTone.green,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _location == null
                    ? 'Not set yet'
                    : 'Location set — neighbours will see how far away you are',
                style: TextStyle(
                  color: _location == null ? HomeTone.muted : HomeTone.green,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _Label('Address'),
        TextField(
          controller: _address,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: HomeTone.ink, fontSize: 15),
          decoration: frameInput(
            hint: 'Filled in from your location; you can edit it',
            icon: Icons.signpost_outlined,
          ),
        ),
        const SizedBox(height: 16),
        const _Label('Opening Hours'),
        Row(
          children: [
            hours('Opens', _open, (v) => setState(() => _open = v)),
            const SizedBox(width: 10),
            hours('Closes', _close, (v) => setState(() => _close = v)),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------- 3 verification

  Widget _verificationStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _stepHeader(
        Icons.verified_user_outlined,
        'Verification',
        'Build trust with your neighbours.',
      ),
      const SizedBox(height: 18),
      const _Label('Business Registration Number'),
      TextField(
        controller: _registration,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(color: HomeTone.ink, fontSize: 15),
        decoration: frameInput(
          hint: 'Optional, e.g. URSB number',
          icon: Icons.badge_outlined,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'If you add one, an admin can check it and give your shop a '
        'verified tick ✓.',
        style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      const _Label('Selling Guidelines', required: true),
      for (var i = 0; i < _guidelines.length; i++)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: HomeTone.violet,
          value: _agreed[i],
          onChanged: (v) => setState(() => _agreed[i] = v ?? false),
          title: Text(
            _guidelines[i],
            style: const TextStyle(color: HomeTone.ink, fontSize: 14),
          ),
        ),
    ],
  );

  // ------------------------------------------------------------- 4 review

  Widget _reviewStep() {
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: HomeTone.violet),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: HomeTone.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final preview = Shop(
      id: '',
      ownerId: '',
      ownerName: '',
      name: _name.text.trim(),
      category: _category ?? MarketCategory.other,
      openHour: _open,
      closeHour: _close,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(
          Icons.fact_check_outlined,
          'Review',
          'Check everything before you go live.',
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MarketArt(category: preview.category, iconSize: 44),
                Positioned(
                  left: 10,
                  top: 10,
                  child: OpenPill(open: preview.isOpenAt()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        row(Icons.storefront_outlined, 'Shop', preview.name),
        row(Icons.category_outlined, 'Category', preview.category.label),
        row(Icons.notes_rounded, 'About', _description.text.trim()),
        row(
          Icons.chat_bubble_outline_rounded,
          'Contact',
          _contact == 'phone'
              ? 'Phone & chat · ${_phone.text.trim()}'
              : 'Chat on Community',
        ),
        row(Icons.location_on_outlined, 'Address', _address.text.trim()),
        row(Icons.schedule_rounded, 'Hours', preview.hoursLabel),
        row(
          Icons.verified_user_outlined,
          'Verification',
          _registration.text.trim().isEmpty
              ? 'Not requested'
              : 'Requested (${_registration.text.trim()})',
        ),
      ],
    );
  }
}

// ================================================================ widgets

class _ShopBadge extends StatelessWidget {
  const _ShopBadge();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: 30,
      ),
    ),
  );
}

/// 1 — 2 — 3 — 4 progress, with labels; earlier steps can be tapped.
class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.steps,
    required this.current,
    required this.onTap,
  });
  final List<String> steps;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < steps.length; i++) ...[
        Expanded(
          child: Semantics(
            label:
                'Step ${i + 1}, ${steps[i]}'
                '${i == current
                    ? ', current'
                    : i < current
                    ? ', done'
                    : ''}',
            button: i < current,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == 0
                              ? Colors.transparent
                              : i <= current
                              ? HomeTone.violet
                              : HomeTone.border,
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= current ? HomeTone.violet : Colors.white,
                          border: Border.all(
                            color: i <= current
                                ? HomeTone.violet
                                : HomeTone.border,
                            width: 2,
                          ),
                        ),
                        child: i < current
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: i == current
                                      ? Colors.white
                                      : HomeTone.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == steps.length - 1
                              ? Colors.transparent
                              : i < current
                              ? HomeTone.violet
                              : HomeTone.border,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: i == current ? HomeTone.violet : HomeTone.ink,
                      fontSize: 12,
                      fontWeight: i == current
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      label: required ? '$text, required' : text,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: HomeTone.red),
              ),
          ],
        ),
        style: const TextStyle(
          color: HomeTone.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// Business category cards, like "What happened?" on the Report screen:
/// four across, the chosen one tinted with a violet border and a tick.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelect});
  final MarketCategory? selected;
  final ValueChanged<MarketCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    const all = MarketCategory.values;
    return Column(
      children: [
        for (var row = 0; row < all.length; row += 4) ...[
          if (row > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = row; i < row + 4; i++) ...[
                  if (i > row) const SizedBox(width: 8),
                  Expanded(
                    child: i < all.length
                        ? _CategoryCard(
                            category: all[i],
                            selected: all[i] == selected,
                            onTap: () => onSelect(all[i]),
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final MarketCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: category.label,
    excludeSemantics: true,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Material(
            color: selected ? HomeTone.violetDim : HomeTone.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: selected ? HomeTone.violet : HomeTone.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon, color: category.color, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    category.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: HomeTone.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: HomeTone.violet,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

class _ContactOption extends StatelessWidget {
  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    inMutuallyExclusiveGroup: true,
    child: Material(
      color: selected ? HomeTone.violetDim : HomeTone.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? HomeTone.violet : HomeTone.border,
          width: selected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? HomeTone.violet : HomeTone.muted,
              ),
              const SizedBox(width: 10),
              Icon(icon, color: HomeTone.ink, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 12.5,
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: HomeTone.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: HomeTone.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: HomeTone.violet),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
