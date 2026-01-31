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
import '../../services/imgbb_service.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
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
  double?
  _selectedInspectionFee; // Selected inspection fee for rental properties

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
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _addressController.dispose();
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
      final List<XFile> images = await _picker.pickMultiImage();
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        print('Uploading image ${i + 1}/${_selectedImages.length} to ImgBB');
        // Use XFile.readAsBytes() for web compatibility
        final bytes = await _selectedImages[i].readAsBytes();
        print('Original image size: ${bytes.length} bytes');

        // Decode and compress the image
        img.Image? image = img.decodeImage(bytes);
        if (image == null) {
          print('Failed to decode image ${i + 1}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to process image ${i + 1}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          continue;
        }

        print('Original dimensions: ${image.width}x${image.height}');

        // Resize image more aggressively to reduce upload time
        if (image.width > 800) {
          image = img.copyResize(image, width: 800);
        } else if (image.height > 1200) {
          image = img.copyResize(image, height: 1200);
        }

        print('Resized dimensions: ${image.width}x${image.height}');

        // Compress more to reduce upload size
        final compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: 70),
        );

        print('Compressed image size: ${compressedBytes.length} bytes');

        // Upload to ImgBB (FREE unlimited storage!)
        final imageUrl = await ImgBBService.uploadImage(compressedBytes);

        if (imageUrl != null) {
          imageUrls.add(imageUrl);
          print('Successfully uploaded image ${i + 1} to ImgBB: $imageUrl');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Uploaded image ${i + 1}/${_selectedImages.length}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } else {
          print('❌ Failed to upload image ${i + 1} to ImgBB - No URL returned');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Upload failed for image ${i + 1}. Check your internet connection.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Error processing image ${i + 1}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error with image ${i + 1}: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Continue with other images
        continue;
      }
    }

    print(
      'Successfully uploaded ${imageUrls.length}/${_selectedImages.length} images to ImgBB',
    );
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
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        price: double.parse(_priceController.text.trim()),
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        bedrooms: _bedroomsController.text.trim().isEmpty
            ? 0
            : int.parse(_bedroomsController.text.trim()),
        bathrooms: _bathroomsController.text.trim().isEmpty
            ? 0
            : int.parse(_bathroomsController.text.trim()),
        areaSqft: _areaSqftController.text.trim().isEmpty
            ? 0
            : double.parse(_areaSqftController.text.trim()),
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
        inspectionFee: _selectedInspectionFee,
      );

      await propertyRef.set(property.toJson());

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
              '${userData.name} submitted "${_titleController.text.trim()}" for review',
          'propertyId': propertyRef.id,
          'type': 'property_submission',
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property submitted for review successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error submitting property: $e');
      if (mounted) {
        String errorMessage = 'Error submitting property';

        // Provide specific error messages
        if (e.toString().contains('timeout') ||
            e.toString().contains('connection')) {
          errorMessage =
              'Network error. Please check your internet connection and try again.';
        } else if (e.toString().contains('Rate limit')) {
          errorMessage =
              'Too many uploads. Please wait a few minutes and try again.';
        } else if (e.toString().contains('ImgBB') ||
            e.toString().contains('upload')) {
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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    // Subscription Notice
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Subscription Required',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'To add properties, you need an active monthly subscription of UGX 50,000.',
                            style: TextStyle(fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Admin will only review and publish properties from subscribed agents.',
                            style: TextStyle(fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payment,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pay subscription to:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '+256 702021112',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
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

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Property Title *',
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

                    // Price
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: _selectedType == PropertyType.sale
                            ? 'Price (UGX) *'
                            : 'Monthly Rent (UGX) *',
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

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Full Address *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter address';
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

                    // Area
                    TextFormField(
                      controller: _areaSqftController,
                      decoration: const InputDecoration(
                        labelText: 'Approximate Area (sq ft) - Optional',
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
                    const SizedBox(height: 16),

                    // Inspection Fee Section
                    const Divider(height: 32),
                    const Text(
                      'Inspection Fee',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select the inspection fee that clients will pay when viewing the property',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<double>(
                      decoration: InputDecoration(
                        labelText: 'Select Inspection Fee *',
                        border: const OutlineInputBorder(),
                        hintText: 'Choose inspection fee amount',
                        helperText: _selectedInspectionFee != null
                            ? _selectedInspectionFee == 0
                                  ? 'No inspection fee will be charged'
                                  : 'Clients will be informed they need to pay UGX ${_selectedInspectionFee!.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} after confirming property availability'
                            : null,
                        helperMaxLines: 3,
                      ),
                      value: _selectedInspectionFee,
                      validator: (value) {
                        if (value == null) {
                          return 'Please select an inspection fee option';
                        }
                        return null;
                      },
                      items: [
                        ...[
                          10000.0,
                          15000.0,
                          20000.0,
                          25000.0,
                          30000.0,
                          35000.0,
                          40000.0,
                          45000.0,
                          50000.0,
                          55000.0,
                          60000.0,
                          65000.0,
                          70000.0,
                          75000.0,
                          80000.0,
                          85000.0,
                          90000.0,
                          95000.0,
                          100000.0,
                        ].map((fee) {
                          return DropdownMenuItem<double>(
                            value: fee,
                            child: Text(
                              'UGX ${fee.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            ),
                          );
                        }).toList(),
                        const DropdownMenuItem<double>(
                          value: 0.0,
                          child: Text('No Inspection Fee'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedInspectionFee = value;
                        });
                      },
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
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: FutureBuilder<Uint8List>(
                                      future: _selectedImages[index]
                                          .readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return const Center(
                                          child: CircularProgressIndicator(),
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

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitProperty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Submit for Review',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
