import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';

/// Screen for agents/developers to edit their advertised projects.
class EditProjectScreen extends StatefulWidget {
  final Project project;

  const EditProjectScreen({super.key, required this.project});

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectService = ProjectService();
  final _imagePicker = ImagePicker();

  // Controllers pre-populated from existing project
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;

  late String _selectedLocation;
  late ProjectStatus _selectedProjectStatus;

  // Track existing URLs and newly picked files separately
  late List<String> _existingImageUrls;
  final List<String> _removedImageUrls = [];
  List<XFile> _newImages = [];

  bool _isSaving = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameController = TextEditingController(text: p.name);
    _descriptionController = TextEditingController(text: p.description);
    _phoneController = TextEditingController(text: p.contactPhone ?? '');
    _emailController = TextEditingController(text: p.contactEmail ?? '');
    _websiteController = TextEditingController(text: p.websiteUrl ?? '');
    _selectedLocation = p.location;
    _selectedProjectStatus = p.projectStatus;
    _existingImageUrls = List<String>.from(p.imageUrls);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  // ── Image helpers ──────────────────────────────────────────────────────────

  Future<void> _pickNewImages() async {
    final picked = await _imagePicker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _newImages = [..._newImages, ...picked]
            .take(20 - _existingImageUrls.length)
            .toList();
      });
    }
  }

  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      _removedImageUrls.add(url);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  /// Upload newly picked images with platform-appropriate quality (matches
  /// submit_project_screen quality settings).
  Future<List<String>> _uploadNewImages() async {
    if (_newImages.isEmpty) return [];

    final List<String> urls = [];
    final total = _newImages.length;

    final isMobileWeb = kIsWeb && MediaQuery.of(context).size.width < 768;
    final batchSize = isMobileWeb ? 1 : 3;
    final maxWidth = isMobileWeb ? 1200 : 1920;
    final maxHeight = isMobileWeb ? 1600 : 2560;
    final quality = isMobileWeb ? 85 : 92;

    for (int start = 0; start < total; start += batchSize) {
      final end = (start + batchSize).clamp(0, total);
      final batch = _newImages.sublist(start, end);

      setState(() {
        _uploadProgress = start / total;
        _uploadStatus = 'Uploading images ${start + 1}–$end of $total...';
      });

      final results = await Future.wait(
        batch.asMap().entries.map((entry) async {
          final xfile = entry.value;
          try {
            final bytes = await xfile.readAsBytes();
            img.Image? decoded = img.decodeImage(bytes);
            if (decoded == null) return null;

            if (decoded.width > maxWidth || decoded.height > maxHeight) {
              decoded = decoded.width > decoded.height
                  ? img.copyResize(decoded, width: maxWidth)
                  : img.copyResize(decoded, height: maxHeight);
            }

            final compressed = Uint8List.fromList(
              img.encodeJpg(decoded, quality: quality),
            );

            return await StorageService.uploadImage(compressed, folder: 'projects');
          } catch (e) {
            debugPrint('Image upload error: $e');
            return null;
          }
        }),
      );

      for (final url in results) {
        if (url != null) urls.add(url);
      }

      setState(() {
        _uploadProgress = end / total;
        _uploadStatus = 'Uploaded ${urls.length} of $total images';
      });
    }

    return urls;
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_totalImageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please keep at least one image')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing...';
    });

    try {
      // 1. Upload any new images
      final newUrls = await _uploadNewImages();

      // 2. Build the final list: remaining existing + new
      final finalUrls = [..._existingImageUrls, ...newUrls];

      setState(() => _uploadStatus = 'Saving project...');

      // 3. Persist updates
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _selectedLocation,
        'projectStatus': _selectedProjectStatus.toString().split('.').last,
        'contactPhone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'contactEmail': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'websiteUrl': _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        'imageUrls': finalUrls,
        // Reset approval so admin reviews the updated project
        if (newUrls.isNotEmpty || _removedImageUrls.isNotEmpty)
          'isApproved': false,
      };

      await _projectService.updateProject(widget.project.id, updates);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadProgress = 1.0;
          _uploadStatus = 'Saved!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newUrls.isNotEmpty || _removedImageUrls.isNotEmpty
                  ? 'Project updated. Awaiting admin re-approval.'
                  : 'Project updated successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // signal refresh
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Edit Project'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              TextButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          body: _isSaving && _uploadProgress == 0
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Project Name ──────────────────────────────────
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Project Name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Location ──────────────────────────────────────
                        DropdownButtonFormField<String>(
                          value: _selectedLocation,
                          decoration: const InputDecoration(
                            labelText: 'Location *',
                            border: OutlineInputBorder(),
                          ),
                          items: _projectService.defaultLocations
                              .map((loc) => DropdownMenuItem(
                                    value: loc,
                                    child: Text(loc),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedLocation = v!),
                          validator: (v) =>
                              v == null ? 'Please select a location' : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Description ───────────────────────────────────
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Project Description *',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // ── Project Status ────────────────────────────────
                        DropdownButtonFormField<ProjectStatus>(
                          value: _selectedProjectStatus,
                          decoration: const InputDecoration(
                            labelText: 'Project Status *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.construction),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ProjectStatus.underConstruction,
                              child: Text('Under Construction'),
                            ),
                            DropdownMenuItem(
                              value: ProjectStatus.offPlan,
                              child: Text('Off-Plan'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedProjectStatus = v!),
                        ),
                        const SizedBox(height: 16),

                        // ── Contact ───────────────────────────────────────
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+256...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _websiteController,
                          decoration: const InputDecoration(
                            labelText: 'Website / Social Media Link (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 24),

                        // ── Images ────────────────────────────────────────
                        Row(
                          children: [
                            const Text(
                              'Project Images',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '$_totalImageCount / 20',
                              style:
                                  TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_totalImageCount > 0)
                          SizedBox(
                            height: 130,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Existing images
                                ..._existingImageUrls
                                    .asMap()
                                    .entries
                                    .map((e) => _existingImageTile(e.value)),
                                // Newly picked images
                                ..._newImages
                                    .asMap()
                                    .entries
                                    .map((e) => _newImageTile(e.key, e.value)),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          onPressed: _totalImageCount >= 20 ? null : _pickNewImages,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: Text(_totalImageCount >= 20
                              ? 'Max 20 images reached'
                              : 'Add More Images'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),

                        if (_removedImageUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade700, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Changing images will require admin re-approval.',
                                    style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // ── Save Button ───────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        ),

        // ── Upload progress overlay ────────────────────────────────────────
        if (_isSaving && _uploadProgress > 0)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: _uploadProgress,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Icon(Icons.cloud_upload_outlined,
                                  color: AppColors.primary, size: 28),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _uploadStatus,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text('Please wait...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Image tile widgets ────────────────────────────────────────────────────

  Widget _existingImageTile(String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeExistingImage(url),
              child: Container(
                decoration:
                    const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Saved',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _newImageTile(int index, XFile xfile) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: kIsWeb
                ? Image.network(
                    xfile.path,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(xfile.path),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeNewImage(index),
              child: Container(
                decoration:
                    const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('New',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }
}
