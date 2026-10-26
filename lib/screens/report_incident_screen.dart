import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io' show File;
import '../models/community_post.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  ReportIncidentScreen({
    super.key,
    required this.authService,
    required this.postRepository,
    this.initialLocation,
  }) : storageService = StorageService();

  final AuthService authService;
  final PostRepository postRepository;
  final LatLng? initialLocation;
  final StorageService storageService;

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  PostCategory _selectedCategory = PostCategory.general;
  PostSeverity _selectedSeverity = PostSeverity.low;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  final List<XFile> _selectedImages = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = widget.authService.currentUser;

      final imageUrls = await widget.storageService.uploadImages(
        _selectedImages,
      );

      final authorName = user?.displayName ?? user?.email ?? 'Member';

      final post = CommunityPost(
        id: '',
        authorName: _isAnonymous ? 'Anonymous' : authorName,
        authorId: user?.uid ?? '',
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
        likes: 0,
        category: _selectedCategory,
        severity: _selectedSeverity,
        isAnonymous: _isAnonymous,
        latitude: widget.initialLocation?.latitude,
        longitude: widget.initialLocation?.longitude,
        mediaUrls: imageUrls,
      );

      await widget.postRepository.addPost(post);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident reported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reporting incident: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an incident')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tell neighbours what happened. Reports are shared with '
                'the community feed and map.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'What happened?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in PostCategory.values)
                    if (category != PostCategory.vacationWatch)
                      ChoiceChip(
                        avatar: Icon(categoryIcon(category), size: 18),
                        label: Text(category.label),
                        selected: _selectedCategory == category,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = category),
                      ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'How serious is it?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final severity in PostSeverity.values)
                    ChoiceChip(
                      avatar: Icon(
                        Icons.circle,
                        size: 12,
                        color: severityColor(severity),
                      ),
                      label: Text(severity.label),
                      showCheckmark: false,
                      selected: _selectedSeverity == severity,
                      selectedColor: severityColor(
                        severity,
                      ).withValues(alpha: .18),
                      onSelected: (_) =>
                          setState(() => _selectedSeverity = severity),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Provide details about the incident...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                tileColor: AppColors.card,
                title: const Text('Post anonymously'),
                subtitle: const Text('Neighbours will not see your name'),
                value: _isAnonymous,
                onChanged: (value) => setState(() => _isAnonymous = value),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add photos'),
              ),
              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: kIsWeb
                            ? Image.network(
                                _selectedImages[index].path,
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_selectedImages[index].path),
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Post report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
