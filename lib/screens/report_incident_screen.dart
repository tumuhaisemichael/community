import 'dart:io' show File;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/home_tone.dart';
import '../widgets/community_ui.dart';
import '../widgets/hero_header.dart';
import '../widgets/overlap_header.dart';

class ReportIncidentScreen extends StatefulWidget {
  ReportIncidentScreen({
    super.key,
    required this.authService,
    required this.postRepository,
    this.initialLocation,
    StorageService? storageService,
  }) : storageService = storageService ?? StorageService();

  final AuthService authService;
  final PostRepository postRepository;
  final LatLng? initialLocation;
  final StorageService storageService;

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  static const int _maxPhotos = 5;
  static const int _maxLength = 500;
  static const LatLng _defaultCenter = LatLng(0.3476, 32.5825);

  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  /// Picked categories in the order they were chosen; never empty.
  List<PostCategory> _categories = [PostCategory.general];
  PostSeverity _selectedSeverity = PostSeverity.low;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  late LatLng? _location = widget.initialLocation;
  bool _locationPicked = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxPhotos - _selectedImages.length;
    if (remaining <= 0) return;
    final images = remaining == 1
        ? [?await _picker.pickImage(source: ImageSource.gallery)]
        : await _picker.pickMultiImage(limit: remaining);
    if (images.isEmpty || !mounted) return;
    setState(() => _selectedImages.addAll(images.take(remaining)));
  }

  Future<void> _changeLocation() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _LocationPickerScreen(initial: _location ?? _defaultCenter),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _location = picked;
      _locationPicked = true;
    });
  }

  /// General is the default; picking anything else replaces it. Tapping a
  /// picked category removes it, and removing the last one goes back to
  /// General.
  void _toggleCategory(PostCategory category) {
    setState(() {
      if (category == PostCategory.general) {
        _categories = [PostCategory.general];
      } else if (_categories.contains(category)) {
        _categories = [
          for (final c in _categories)
            if (c != category) c,
        ];
        if (_categories.isEmpty) _categories = [PostCategory.general];
      } else {
        _categories = [
          for (final c in _categories)
            if (c != PostCategory.general) c,
          category,
        ];
      }
    });
  }

  /// Uploads the picked photos. Returns null if they could not be uploaded
  /// in time, so the report can still be posted without them.
  Future<List<String>?> _uploadPhotos() async {
    if (_selectedImages.isEmpty) return const [];
    try {
      return await widget.storageService
          .uploadImages(_selectedImages)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Photo upload failed, posting without photos: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final user = widget.authService.currentUser;
      final imageUrls = await _uploadPhotos();
      final authorName = user?.displayName ?? user?.email ?? 'Member';

      final post = CommunityPost(
        id: '',
        authorName: _isAnonymous ? 'Anonymous' : authorName,
        authorId: user?.uid ?? '',
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
        likes: 0,
        category: _categories.first,
        categories: _categories,
        severity: _selectedSeverity,
        isAnonymous: _isAnonymous,
        latitude: _location?.latitude,
        longitude: _location?.longitude,
        mediaUrls: imageUrls ?? const [],
      );

      await widget.postRepository.addPost(post);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              imageUrls == null
                  ? 'Report posted. Photos could not be uploaded, so it '
                        'shows the default image.'
                  : 'Incident reported successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reporting incident: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              OverlapHeader(
                overlap: 28,
                header: const PageHeroHeader(
                  title: 'Report an Incident',
                  subtitle:
                      'Tell your neighbours what happened.\n'
                      'Reports are shared with the community feed and map.',
                  badge: _AlertShield(),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: HomeTone.canvas,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _buildForm(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            bottomInset > 0 ? bottomInset : 16,
          ),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HomeTone.violet,
                foregroundColor: Colors.white,
                disabledBackgroundColor: HomeTone.violet.withValues(alpha: .6),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Transform.rotate(
                      angle: -0.5,
                      child: const Icon(Icons.send_rounded, size: 24),
                    ),
              label: Text(_isSubmitting ? 'Posting…' : 'Post report'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final categories = [
      for (final c in PostCategory.values)
        if (c != PostCategory.vacationWatch) c,
    ];
    final rows = <List<PostCategory>>[
      for (var i = 0; i < categories.length; i += 4)
        categories.sublist(i, (i + 4).clamp(0, categories.length)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading('What happened?'),
        const SizedBox(height: 4),
        const Text(
          'Pick all that apply',
          style: TextStyle(color: HomeTone.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final row in rows) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _CategoryTile(
                      category: row[i],
                      selected: _categories.contains(row[i]),
                      onTap: () => _toggleCategory(row[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        const _Heading('How serious is it?'),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < PostSeverity.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SeverityPill(
                  severity: PostSeverity.values[i],
                  selected: PostSeverity.values[i] == _selectedSeverity,
                  onTap: () => setState(
                    () => _selectedSeverity = PostSeverity.values[i],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 26),
        const _Heading('Description'),
        const SizedBox(height: 12),
        _DescriptionField(
          controller: _contentController,
          maxLength: _maxLength,
        ),
        // The counter row below the field already adds some space.
        const SizedBox(height: 2),
        _PhotoRow(
          images: _selectedImages,
          max: _maxPhotos,
          onAdd: _pickImages,
          onRemove: (index) => setState(() => _selectedImages.removeAt(index)),
        ),
        const SizedBox(height: 16),
        _OptionCard(
          icon: Icons.no_accounts_outlined,
          title: 'Post anonymously',
          subtitle: 'Neighbours will not see your name',
          trailing: Switch(
            value: _isAnonymous,
            activeThumbColor: Colors.white,
            activeTrackColor: HomeTone.violet,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: HomeTone.border,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            onChanged: (value) => setState(() => _isAnonymous = value),
          ),
          onTap: () => setState(() => _isAnonymous = !_isAnonymous),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.location_on_rounded,
          title: 'Report location',
          subtitle: _location == null
              ? 'Location unavailable. Tap Change to pick a spot.'
              : _locationPicked
              ? 'Pinned on the map'
              : 'Your current location',
          trailing: OutlinedButton.icon(
            onPressed: _changeLocation,
            style: OutlinedButton.styleFrom(
              foregroundColor: HomeTone.violet,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              side: const BorderSide(color: HomeTone.violet, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Change'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ------------------------------------------------------------------ widgets

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: '$text, required',
    excludeSemantics: true,
    child: Text.rich(
      TextSpan(
        text: text,
        children: const [
          TextSpan(
            text: '  *',
            style: TextStyle(color: HomeTone.red),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: HomeTone.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Red shield with an exclamation mark, shown in the header.
class _AlertShield extends StatelessWidget {
  const _AlertShield();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 64,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 70, color: Colors.white),
          Icon(Icons.shield_rounded, size: 56, color: HomeTone.red),
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(
              Icons.priority_high_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final PostCategory category;
  final bool selected;
  final VoidCallback onTap;

  Color get _iconColor => switch (category) {
    PostCategory.fire => HomeTone.orange,
    PostCategory.medical => HomeTone.red,
    _ => HomeTone.violet,
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
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
              shadowColor: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          // Center fills the tile so the content sits in the middle of it,
          // also when a neighbour's two-line label makes the row taller.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 9, 4, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon(category), color: _iconColor, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      category.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 12.5,
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
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final PostSeverity severity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: severity.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? HomeTone.violetDim : HomeTone.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? HomeTone.violet : HomeTone.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: HomeTone.severity(severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    severity.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomeTone.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller, required this.maxLength});

  final TextEditingController controller;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextFormField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: HomeTone.ink, fontSize: 13.5, height: 1.4),
      cursorColor: HomeTone.violet,
      decoration: InputDecoration(
        hintText: 'Provide details about what happened, where and when…',
        hintStyle: const TextStyle(color: HomeTone.muted, fontSize: 13.5),
        filled: true,
        fillColor: HomeTone.card,
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        border: border(HomeTone.border),
        enabledBorder: border(HomeTone.border),
        focusedBorder: border(HomeTone.violet, 1.6),
        errorBorder: border(HomeTone.red, 1.4),
        focusedErrorBorder: border(HomeTone.red, 1.6),
        errorStyle: const TextStyle(color: HomeTone.red),
      ),
      // Counter drawn inside the box, bottom right.
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              Transform.translate(
                offset: const Offset(-14, -30),
                child: Text(
                  '$currentLength / $maxLength',
                  style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
                ),
              ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Please describe what happened'
          : null,
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.images,
    required this.max,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> images;
  final int max;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final canAdd = images.length < max;
    final addBox = _DashedBox(
      onTap: canAdd ? onAdd : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              color: HomeTone.violet,
              size: 32,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add photos',
                    style: TextStyle(
                      color: HomeTone.violet,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    images.isEmpty
                        ? 'Upload up to $max photos (optional)'
                        : '${images.length} of $max added',
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
    );

    if (images.isEmpty) return SizedBox(height: 84, child: addBox);

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          SizedBox(width: 220, child: addBox),
          for (var i = 0; i < images.length; i++) ...[
            const SizedBox(width: 10),
            _Thumbnail(file: images[i], onRemove: () => onRemove(i)),
          ],
          if (canAdd) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              child: _DashedBox(
                onTap: onAdd,
                filled: true,
                child: const Icon(
                  Icons.add_rounded,
                  color: HomeTone.violet,
                  size: 32,
                  semanticLabel: 'Add another photo',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.file, required this.onRemove});
  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final image = kIsWeb
        ? Image.network(file.path, fit: BoxFit.cover)
        : Image.file(File(file.path), fit: BoxFit.cover);
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: image,
            ),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: Semantics(
              button: true,
              label: 'Remove photo',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: HomeTone.border),
                    boxShadow: HomeTone.cardShadow,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: HomeTone.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded box with a dashed violet outline.
class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.child, this.onTap, this.filled = false});
  final Widget child;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .5 : 1,
    child: CustomPaint(
      painter: const _DashedBorderPainter(),
      child: Material(
        color: filled
            ? HomeTone.violetDim.withValues(alpha: .6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HomeTone.violet.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.7),
          const Radius.circular(16),
        ),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeTone.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: HomeTone.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: HomeTone.violetDim,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: HomeTone.violet, size: 26),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen map with a fixed centre pin; returns the chosen point.
class _LocationPickerScreen extends StatefulWidget {
  const _LocationPickerScreen({required this.initial});
  final LatLng initial;

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );

  late LatLng _center = widget.initial;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HomeTone.violet,
        foregroundColor: Colors.white,
        title: const Text(
          'Choose report location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 16,
              onPositionChanged: (camera, _) => _center = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}',
                additionalOptions: const {'key': _mapTilerKey},
                userAgentPackageName: 'com.example.community',
              ),
            ],
          ),
          // Pin tip sits on the map centre.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 46),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 50,
                  color: HomeTone.violet,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: HomeTone.cardShadow,
              ),
              child: const Text(
                'Move the map to put the pin where it happened.',
                style: TextStyle(color: HomeTone.ink, fontSize: 13.5),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 16,
            child: SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: HomeTone.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => Navigator.pop(context, _center),
                child: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
