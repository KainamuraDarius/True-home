import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../services/storage_service.dart';
import '../common/legal_policies_screen.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _selectedCategory = 'Flat'; // Default category
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaSqftController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _whatsappPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _agentNameController = TextEditingController();

  PropertyType _selectedType = PropertyType.sale;
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  bool _requestSpotlightPromotion = false;
  bool _agreedToAgentTerms = false;
  String _areaUnit = 'sqft'; // Default unit is square feet
  String _currency = 'UGX'; // Default currency is UGX
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  // Amenities
  final List<String> _selectedAmenities = [];
  final List<String> _availableAmenities = [
    'Swimming Pool',
    'Gym',
    'Parking',
    'Security',
    'Garden',
    'Balcony',
    'Air Conditioning',
    'Heating',
    'Wi-Fi',
    'Elevator',
    'Backup Generator',
    'Water Tank',
    'CCTV',
    'Playground',
    'Laundry',
    'Pets Allowed',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _areaSqftController.dispose();
    _contactPhoneController.dispose();
    _whatsappPhoneController.dispose();
    _contactEmailController.dispose();
    _companyNameController.dispose();
    _agentNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      // Show a small loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Loading images...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85, // Reduce quality during selection for faster loading
      );
      
      if (images.isNotEmpty) {
        // Check if adding these images would exceed the limit
        final totalImages = _selectedImages.length + images.length;
        if (totalImages > 20) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You can only upload up to 20 images. Currently: ${_selectedImages.length}, Selected: ${images.length}',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Add only images that fit within the limit
          final remainingSlots = 20 - _selectedImages.length;
          if (remainingSlots > 0) {
            setState(() {
              _selectedImages.addAll(images.take(remainingSlots));
            });
          }
        } else {
          setState(() {
            _selectedImages.addAll(images);
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${images.length} image(s) selected'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Generate thumbnail for faster preview
  Future<Uint8List> _getThumbnail(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      
      // Decode image
      img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return bytes; // Return original if decode fails
      }
      
      // Create small thumbnail (150px) for fast display
      img.Image thumbnail;
      if (decodedImage.width > decodedImage.height) {
        thumbnail = img.copyResize(decodedImage, width: 150);
      } else {
        thumbnail = img.copyResize(decodedImage, height: 150);
      }
      
      // Compress thumbnail
      return Uint8List.fromList(
        img.encodeJpg(thumbnail, quality: 60),
      );
    } catch (e) {
      print('Error generating thumbnail: $e');
      // Return original bytes if thumbnail generation fails
      return await image.readAsBytes();
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];
    final totalImages = _selectedImages.length;
    
    // Process and upload images in parallel batches of 3 for faster upload
    const batchSize = 3;
    
    for (int batchStart = 0; batchStart < totalImages; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize).clamp(0, totalImages);
      final batch = _selectedImages.sublist(batchStart, batchEnd);
      
      setState(() {
        _uploadProgress = (batchStart / totalImages);
        _uploadStatus = 'Uploading images ${batchStart + 1}-$batchEnd of $totalImages...';
      });
      
      // Process batch in parallel
      final batchResults = await Future.wait(
        batch.asMap().entries.map((entry) async {
          final index = batchStart + entry.key;
          final image = entry.value;
          
          try {
            print('Processing image ${index + 1}/$totalImages');
            
            // Read and decode image
            final bytes = await image.readAsBytes();
            print('Original size: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
            
            img.Image? decodedImage = img.decodeImage(bytes);
            if (decodedImage == null) {
              print('Failed to decode image ${index + 1}');
              return null;
            }
            
            // More aggressive resizing for faster uploads
            if (decodedImage.width > 600 || decodedImage.height > 900) {
              if (decodedImage.width > decodedImage.height) {
                decodedImage = img.copyResize(decodedImage, width: 600);
              } else {
                decodedImage = img.copyResize(decodedImage, height: 900);
              }
            }
            
            // Compress with lower quality for smaller file size
            final compressedBytes = Uint8List.fromList(
              img.encodeJpg(decodedImage, quality: 55),
            );
            
            print('Compressed size: ${(compressedBytes.length / 1024).toStringAsFixed(1)} KB');
            
            // Upload to Firebase Storage
            final imageUrl = await StorageService.uploadImage(
              compressedBytes,
              folder: 'properties',
            );
            
            if (imageUrl != null) {
              print('✅ Uploaded image ${index + 1}');
              return imageUrl;
            } else {
              print('❌ Failed to upload image ${index + 1}');
              return null;
            }
          } catch (e) {
            print('❌ Error with image ${index + 1}: $e');
            return null;
          }
        }),
      );
      
      // Add successful uploads to the list
      for (var url in batchResults) {
        if (url != null) {
          imageUrls.add(url);
        }
      }
      
      setState(() {
        _uploadProgress = (batchEnd / totalImages);
        _uploadStatus = 'Uploaded ${imageUrls.length} of $totalImages images';
      });
    }
    
    print('✅ Upload complete: ${imageUrls.length}/$totalImages images');
    return imageUrls;
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that at least one image is selected
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add property images before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Starting upload...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = UserModel.fromJson({
        ...userDoc.data()!,
        'id': userDoc.id,
      });

      // Upload images to ImgBB and get image URLs
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages();

        // Check if at least one image was uploaded successfully
        if (imageUrls.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Failed to upload images. Please check your internet connection and try again.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        if (mounted && imageUrls.length < _selectedImages.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${imageUrls.length} of ${_selectedImages.length} images uploaded successfully',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Create property
      final propertyRef = FirebaseFirestore.instance
          .collection('properties')
          .doc();
      final property = PropertyModel(
        id: propertyRef.id,
        title: _titleController.text,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        type: _selectedType,
        price: double.parse(_priceController.text.trim()),
        location: _locationController.text.trim(),
        address: _locationController.text.trim(),
        bedrooms: _bedroomsController.text.trim().isEmpty
            ? 0
            : int.parse(_bedroomsController.text.trim()),
        bathrooms: _bathroomsController.text.trim().isEmpty
            ? 0
            : int.parse(_bathroomsController.text.trim()),
        areaSqft: _areaSqftController.text.trim().isEmpty
            ? 0
            : double.parse(_areaSqftController.text.trim()),
        areaUnit: _areaUnit,
        currency: _currency,
        imageUrls: imageUrls,
        ownerId: user.uid,
        ownerName: userData.name,
        ownerEmail: userData.email,
        companyName: _companyNameController.text.trim(),
        agentName: _agentNameController.text.trim(),
        agentProfileImageUrl: userData.profileImageUrl,
        contactPhone: _contactPhoneController.text.trim(),
        whatsappPhone: _whatsappPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        status: PropertyStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        amenities: _selectedAmenities,
        university: null,
        roomTypes: const [],
        promotionRequested: _requestSpotlightPromotion,
        inspectionFee: null,
      );

      await propertyRef.set(property.toJson());

      setState(() {
        _uploadStatus = 'Notifying admins...';
      });

      // Notify all admins about new property submission
      final admins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': admin.id,
          'title': 'New Property Submitted',
          'message':
              '${userData.name} submitted "$_selectedCategory" for review',
          'propertyId': propertyRef.id,
          'type': 'property_submission',
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatus = 'Complete!';
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show full-screen success overlay
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog.fullscreen(
            backgroundColor: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 120,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Property Submitted Successfully!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Waiting for Admin Approval',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      'Your property has been submitted successfully. Our admin team will review it and get back to you soon.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          Navigator.of(context).pop(); // Go back
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Back to Dashboard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error submitting property: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
          _uploadStatus = '';
        });
        
        String errorMessage = 'Error submitting property';

        // Provide specific error messages
        if (e.toString().contains('timeout') ||
            e.toString().contains('connection') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('NetworkException')) {
          errorMessage =
              'Network error. Please check your internet connection and try again.';
        } else if (e.toString().contains('Rate limit')) {
          errorMessage =
              'Too many uploads. Please wait a few minutes and try again.';
        } else if (e.toString().contains('upload')) {
          errorMessage =
              'Image upload failed. Please try again or use different images.';
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
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
          _uploadStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Add Property'),
            backgroundColor: AppColors.primary,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Property Submission Guide',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionItem('Fields marked with * are required'),
                          _buildInstructionItem('Fields without * are optional'),
                          _buildInstructionItem('Provide accurate contact information'),
                          _buildInstructionItem('Ensure phone numbers are active and correct'),
                          _buildInstructionItem('Add clear, high-quality property images'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Your property will be reviewed by admin before publishing',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Property Type (Note: Student Hostels can only be added by Admin)
                    const Text(
                      'Property Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<PropertyType>(
                            title: const Text('For Sale'),
                            value: PropertyType.sale,
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<PropertyType>(
                            title: const Text('For Rent'),
                            value: PropertyType.rent,
                            groupValue: _selectedType,
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.purple.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Note: Student Hostels can only be added by Admin',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Property Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Property Title *',
                        hintText: 'e.g., Luxury Villa in Kampala',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter property title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Property Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Flat', child: Text('Flat')),
                        DropdownMenuItem(value: 'Bungalow', child: Text('Bungalow')),
                        DropdownMenuItem(value: 'Condo', child: Text('Condo')),
                        DropdownMenuItem(value: 'Villa', child: Text('Villa')),
                        DropdownMenuItem(value: 'Apartment', child: Text('Apartment')),
                        DropdownMenuItem(value: 'Studio room', child: Text('Studio room')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price with currency selector
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _priceController,
                            decoration: InputDecoration(
                              labelText: _selectedType == PropertyType.sale
                                  ? 'Price *'
                                  : 'Monthly Rent *',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter price';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _currency,
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'UGX',
                                child: Text('UGX'),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text('USD'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _currency = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location/City *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bedrooms and Bathrooms
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bedroomsController,
                            decoration: const InputDecoration(
                              labelText: 'Bedrooms (Optional)',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., 3',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  int.tryParse(value) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _bathroomsController,
                            decoration: const InputDecoration(
                              labelText: 'Bathrooms (Optional)',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., 2',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  int.tryParse(value) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Area with unit selection
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _areaSqftController,
                            decoration: const InputDecoration(
                              labelText: 'Approximate Area - Optional',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., 1200',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _areaUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'sqft',
                                child: Text('sq ft'),
                              ),
                              DropdownMenuItem(
                                value: 'sqm',
                                child: Text('sq m'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  _areaUnit = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Agent Information Section
                    const Divider(height: 32),
                    const Text(
                      'Agent Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Company Name
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Company Name (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                        hintText: 'e.g., ABC Real Estate Ltd',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Agent Name
                    TextFormField(
                      controller: _agentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Agent Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        hintText: 'e.g., John Doe',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter agent name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amenities Section
                    const Divider(height: 32),
                    Row(
                      children: [
                        const Text(
                          'Amenities',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Optional',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select amenities available at this property',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableAmenities.map((amenity) {
                        final isSelected = _selectedAmenities.contains(amenity);
                        return FilterChip(
                          label: Text(amenity),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAmenities.add(amenity);
                              } else {
                                _selectedAmenities.remove(amenity);
                              }
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Contact Information Section
                    const Divider(height: 32),
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contact Phone
                    TextFormField(
                      controller: _contactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number for Calls *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        hintText: '+256...',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // WhatsApp Phone
                    TextFormField(
                      controller: _whatsappPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Number *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.chat),
                        hintText: '+256...',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter WhatsApp number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact Email
                    TextFormField(
                      controller: _contactEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Email (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        hintText: 'email@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        // Only validate format if email is provided
                        if (value != null &&
                            value.isNotEmpty &&
                            !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Images Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Property Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_selectedImages.length}/20',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedImages.length >= 20
                                ? Colors.red
                                : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade200,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: FutureBuilder<Uint8List>(
                                      future: _getThumbnail(_selectedImages[index]),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          );
                                        } else if (snapshot.hasError) {
                                          return const Center(
                                            child: Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                            ),
                                          );
                                        }
                                        return const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _selectedImages.length >= 12
                          ? null
                          : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(
                        _selectedImages.isEmpty
                            ? 'Add Images (Up to 12)'
                            : _selectedImages.length >= 12
                            ? 'Maximum 12 images reached'
                            : 'Add More Images (${12 - _selectedImages.length} remaining)',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Request Spotlight Promotion
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.orange.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Spotlight Promotion',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Request to feature your property in the Spotlight Properties carousel on the customer home page. Admin will review and approve if eligible.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _requestSpotlightPromotion,
                            onChanged: (value) {
                              setState(() {
                                _requestSpotlightPromotion = value ?? false;
                              });
                            },
                            title: const Text(
                              'Request Spotlight Promotion',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Subject to admin approval',
                              style: TextStyle(fontSize: 12),
                            ),
                            activeColor: Colors.orange,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Agent Agreement Checkbox
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _agreedToAgentTerms
                              ? Colors.green
                              : Colors.orange.shade200,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: _agreedToAgentTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreedToAgentTerms = value ?? false;
                              });
                            },
                            title: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'I agree to the ',
                                  ),
                                  TextSpan(
                                    text: 'Agent & Listing Agreement',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              'Required to post listings on TrueHome',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            activeColor: Colors.orange,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LegalPoliciesScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.article_outlined, size: 18),
                            label: const Text('Read Agreement'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Progress indicator when uploading
                    if (_isLoading) ...[
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _uploadStatus,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_agreedToAgentTerms && !_isLoading) ? _submitProperty : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Uploading ${(_uploadProgress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                _agreedToAgentTerms
                                    ? 'Submit for Review'
                                    : 'Accept Agreement to Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _agreedToAgentTerms
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ),
        // Circular progress overlay
        if (_isLoading && _uploadProgress > 0)
          Container(
            color: Colors.black.withOpacity(0.7),
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
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: _uploadProgress,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(_uploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Icon(
                                Icons.cloud_upload_outlined,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _uploadStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait...',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
