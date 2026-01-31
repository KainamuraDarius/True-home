import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../services/imgbb_service.dart';
import '../../utils/app_theme.dart';

class SubmitProjectScreen extends StatefulWidget {
  const SubmitProjectScreen({super.key});

  @override
  State<SubmitProjectScreen> createState() => _SubmitProjectScreenState();
}

class _SubmitProjectScreenState extends State<SubmitProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectService = ProjectService();
  final _imagePicker = ImagePicker();
  
  // Form fields
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  
  String? _selectedLocation;
  ProjectStatus _selectedProjectStatus = ProjectStatus.underConstruction;
  List<XFile> _selectedImages = [];
  bool _isSubmitting = false;
  String? _developerName;
  
  // Flat pricing - minimum payment
  final double _flatPrice = 20000; // UGX 20,000 minimum for 30 days

  @override
  void initState() {
    super.initState();
    _loadDeveloperName();
  }

  Future<void> _loadDeveloperName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _developerName = userDoc.data()?['name'] ?? user.email ?? 'Developer';
      });
    }
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images.take(20).toList(); // Max 20 images
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    
    for (var i = 0; i < _selectedImages.length; i++) {
      try {
        final file = File(_selectedImages[i].path);
        final imageBytes = await file.readAsBytes();
        
        // Upload to ImgBB
        final url = await ImgBBService.uploadImage(imageBytes);
        
        if (url != null) {
          imageUrls.add(url);
          print('Image ${i + 1}/${_selectedImages.length} uploaded successfully');
        } else {
          throw Exception('Failed to upload image ${i + 1}');
        }
      } catch (e) {
        print('Error uploading image $i: $e');
        rethrow; // Re-throw to be caught by _submitProject
      }
    }
    
    return imageUrls;
  }

  double _calculateTotalCost() {
    return _flatPrice; // Flat rate of UGX 20,000
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one project image')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload images
      final imageUrls = await _uploadImages();
      
      // Create project
      final user = FirebaseAuth.instance.currentUser!;
      final project = Project(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        developerId: user.uid,
        developerName: _developerName ?? 'Developer',
        location: _selectedLocation!,
        adTier: AdTier.basic, // Single tier for all
        isFirstPlaceSubscriber: false,
        paymentAmount: _calculateTotalCost(),
        createdAt: DateTime.now(),
        adExpiresAt: DateTime.now().add(const Duration(days: 30)),
        isApproved: false, // Awaiting admin approval
        contactPhone: _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
        contactEmail: _emailController.text.trim().isNotEmpty 
            ? _emailController.text.trim() 
            : null,
        websiteUrl: _websiteController.text.trim().isNotEmpty 
            ? _websiteController.text.trim() 
            : null,
        projectStatus: _selectedProjectStatus,
      );

      await _projectService.createProject(project);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Project submitted successfully!\n'
              'Total Cost: UGX ${CurrencyFormatter.format(_calculateTotalCost())}\n'
              'Awaiting admin approval and payment verification.'
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error submitting project';
        
        // Provide specific error messages
        if (e.toString().contains('Failed to upload image')) {
          errorMessage = 'Image upload failed. Please check your internet connection and try again.';
        } else if (e.toString().contains('ImgBB')) {
          errorMessage = 'Image hosting service error. Please try again later.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _calculateTotalCost();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertise Your Project'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Card(
                      color: AppColors.primary.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'How it works',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '1. Fill in your project details and upload images\n'
                              '2. Choose your advertising package\n'
                              '3. Submit for admin review\n'
                              '4. Admin will verify payment and approve\n'
                              '5. Your project goes live for 30 days!',
                              style: TextStyle(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Project Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Project Name *',
                        hintText: 'e.g., Luxury Apartments Kololo',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Location Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      decoration: const InputDecoration(
                        labelText: 'Location *',
                        border: OutlineInputBorder(),
                      ),
                      items: _projectService.defaultLocations.map((location) {
                        return DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedLocation = value);
                      },
                      validator: (value) =>
                          value == null ? 'Please select a location' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Project Description *',
                        hintText: 'Describe your project...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Project Status
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
                      onChanged: (value) {
                        setState(() => _selectedProjectStatus = value!);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact Information Section
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                        labelText: 'Email',
                        hintText: 'contact@company.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website / Blog URL (Optional)',
                        hintText: 'https://yoursite.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language),
                        helperText: 'Add your website for customers to learn more',
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.startsWith('http://') && !value.startsWith('https://')) {
                            return 'URL must start with http:// or https://';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Images Section
                    const Text(
                      'Project Images *',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_selectedImages.isNotEmpty) ...[
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(_selectedImages[index].path),
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(_selectedImages.isEmpty 
                          ? 'Add Images (Max 20)' 
                          : 'Change Images'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Advertising Package
                    Card(
                      color: AppColors.primary.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.campaign, color: AppColors.primary, size: 28),
                                const SizedBox(width: 12),
                                const Text(
                                  'Advertising Package',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'What\'s Included:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem('Your project listed by location'),
                            _buildFeatureItem('Up to 20 project images'),
                            _buildFeatureItem('Contact information displayed'),
                            _buildFeatureItem('Link to your website/blog'),
                            _buildFeatureItem('30 days visibility'),
                            _buildFeatureItem('View and click analytics'),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200, width: 2),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'One-time Payment:',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'UGX 20,000',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Total Cost Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Total Cost:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'UGX ${CurrencyFormatter.format(totalCost)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Payment Instructions
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.payment, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Payment Instructions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'After submitting, please make payment to:\n\n'
                              'Mobile Money: +256-XXX-XXXXXX\n'
                              'Bank Account: XXXXXXX\n\n'
                              'Admin will verify your payment and approve your project within 24 hours.',
                              style: TextStyle(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Submit Project for Review',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
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
}
