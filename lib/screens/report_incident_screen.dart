import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io' show File;
import '../models/community_post.dart';
import '../theme/app_theme.dart';
import '../widgets/neighborhood_banner.dart';
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
      appBar: AppBar(title: const Text('Report Incident')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NeighborhoodBanner(
                title: 'Every detail helps.',
                eyebrow: 'Report Incident',
                subtitle: 'Keep your neighbors informed. Help starts here.',
              ),
              const SizedBox(height: 24),
              Text(
                'Incident Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in [
                    PostCategory.theft,
                    PostCategory.medical,
                    PostCategory.fire,
                    PostCategory.accident,
                  ])
                    ChoiceChip(
                      avatar: Icon(switch (category) {
                        PostCategory.theft => Icons.local_police_outlined,
                        PostCategory.medical => Icons.medical_services_outlined,
                        PostCategory.fire =>
                          Icons.local_fire_department_outlined,
                        _ => Icons.car_crash_outlined,
                      }, size: 20),
                      label: Text(category.name.toUpperCase()),
                      selected: _selectedCategory == category,
                      selectedColor: AppColors.watchDim,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = category),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PostCategory>(
                key: ValueKey(_selectedCategory),
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Incident Type'),
                items: PostCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('Severity', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final severity in PostSeverity.values)
                    ChoiceChip(
                      avatar: Icon(
                        severity == PostSeverity.critical
                            ? Icons.priority_high
                            : Icons.flag_outlined,
                        size: 18,
                      ),
                      label: Text(severity.name.toUpperCase()),
                      selected: _selectedSeverity == severity,
                      selectedColor: switch (severity) {
                        PostSeverity.low => AppColors.safeDim,
                        PostSeverity.medium => AppColors.watchDim,
                        PostSeverity.high => const Color(0xFFFFECD9),
                        PostSeverity.critical => AppColors.alertDim,
                      },
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
                ),
                tileColor: AppColors.safeDim,
                title: const Text('Report Anonymously'),
                value: _isAnonymous,
                onChanged: (value) => setState(() => _isAnonymous = value),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Add Photos'),
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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
