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

class EditPropertyScreen extends StatefulWidget {
  final PropertyModel property;
  
  const EditPropertyScreen({
    super.key,
    required this.property,
  });

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
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
  
  late PropertyType _selectedType;
  final List<XFile> _newImages = []; // Newly selected images
  final List<String> _existingImageUrls = []; // Existing images from property
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  bool _requestSpotlightPromotion = false;
  
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
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    // Populate controllers with existing property data
    _titleController.text = widget.property.title;
    _descriptionController.text = widget.property.description;
    _priceController.text = widget.property.price.toString();
    _locationController.text = widget.property.location;
    _addressController.text = widget.property.address;
    _bedroomsController.text = widget.property.bedrooms > 0 ? widget.property.bedrooms.toString() : '';
    _bathroomsController.text = widget.property.bathrooms > 0 ? widget.property.bathrooms.toString() : '';
    _areaSqftController.text = widget.property.areaSqft > 0 ? widget.property.areaSqft.toString() : '';
    _contactPhoneController.text = widget.property.contactPhone;
    _whatsappPhoneController.text = widget.property.whatsappPhone;
    _contactEmailController.text = widget.property.contactEmail;
    _companyNameController.text = widget.property.companyName;
    _agentNameController.text = widget.property.agentName;
    
    // Set property type
    _selectedType = widget.property.type;
    
    // Copy existing images
    _existingImageUrls.addAll(widget.property.imageUrls);
    
    // Set amenities
    _selectedAmenities.addAll(widget.property.amenities);
    
    // Set promotion request status
    _requestSpotlightPromotion = widget.property.promotionRequested;
  }

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

  // Get total image count
  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        // Check if adding these images would exceed the limit
        final totalImages = _totalImageCount + images.length;
        if (totalImages > 20) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You can only upload up to 20 images. Currently: $_totalImageCount, Selected: ${images.length}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Add only images that fit within the limit
          final remainingSlots = 12 - _totalImageCount;
          if (remainingSlots > 0) {
            setState(() {
              _newImages.addAll(images.take(remainingSlots));
            });
          }
        } else {
          setState(() {
            _newImages.addAll(images);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadNewImages() async {
    final List<String> imageUrls = [];

    for (int i = 0; i < _newImages.length; i++) {
      try {
        print('Uploading image ${i + 1}/${_newImages.length} to ImgBB');
        final file = File(_newImages[i].path);
        final bytes = await file.readAsBytes();
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
        
        // Resize image to max width of 1200px for good quality
        if (image.width > 1200) {
          image = img.copyResize(image, width: 1200);
        } else if (image.height > 1600) {
          image = img.copyResize(image, height: 1600);
        }
        
        print('Resized dimensions: ${image.width}x${image.height}');
        
        // Compress as JPEG with 85% quality
        final compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: 85),
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
                content: Text('Uploaded image ${i + 1}/${_newImages.length}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } else {
          print('Failed to upload image ${i + 1} to ImgBB');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image ${i + 1}'),
                backgroundColor: Colors.red,
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

    print('Successfully uploaded ${imageUrls.length}/${_newImages.length} images to ImgBB');
    return imageUrls;
  }

  Future<void> _updateProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that at least one image exists
    if (_totalImageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one property image'),
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

      // Upload new images to ImgBB if any
      List<String> newlyUploadedUrls = [];
      if (_newImages.isNotEmpty) {
        newlyUploadedUrls = await _uploadNewImages();
        if (mounted && newlyUploadedUrls.length < _newImages.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newlyUploadedUrls.length} of ${_newImages.length} new images uploaded successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Combine existing images with newly uploaded ones
      final allImageUrls = [..._existingImageUrls, ...newlyUploadedUrls];

      // Update property with new data
      final updatedProperty = PropertyModel(
        id: widget.property.id,
        title: _titleController.text.trim(),
        category: widget.property.category, // Keep existing category
        description: _descriptionController.text.trim(),
        type: _selectedType,
        price: double.parse(_priceController.text.trim()),
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        bedrooms: _bedroomsController.text.trim().isEmpty ? 0 : int.parse(_bedroomsController.text.trim()),
        bathrooms: _bathroomsController.text.trim().isEmpty ? 0 : int.parse(_bathroomsController.text.trim()),
        areaSqft: _areaSqftController.text.trim().isEmpty ? 0 : double.parse(_areaSqftController.text.trim()),
        imageUrls: allImageUrls,
        ownerId: widget.property.ownerId,
        ownerName: widget.property.ownerName,
        ownerEmail: widget.property.ownerEmail,
        companyName: _companyNameController.text.trim(),
        agentName: _agentNameController.text.trim(),
        agentProfileImageUrl: userData.profileImageUrl,
        contactPhone: _contactPhoneController.text.trim(),
        whatsappPhone: _whatsappPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        status: widget.property.status, // Keep existing status (pending)
        createdAt: widget.property.createdAt,
        updatedAt: DateTime.now(), // Update the timestamp
        amenities: _selectedAmenities,
        university: widget.property.university,
        roomTypes: widget.property.roomTypes,
        promotionRequested: _requestSpotlightPromotion,
      );

      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.property.id)
          .update(updatedProperty.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate successful update
      }
    } catch (e) {
      print('Error updating property: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating property: $e'),
            backgroundColor: Colors.red,
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
        title: const Text('Edit Property'),
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
                    // Property Type (Note: Student Hostels can only be added by Admin)
                    const Text(
                      'Property Type',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          Icon(Icons.info_outline, color: Colors.purple.shade700, size: 20),
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
                              if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
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
                              if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
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
                        if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Agent Information Section
                    const Divider(height: 32),
                    const Text(
                      'Agent Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Company Name
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Company Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                        hintText: 'e.g., ABC Real Estate Ltd',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter company name';
                        }
                        return null;
                      },
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            color: isSelected ? AppColors.primary : Colors.black87,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Contact Information Section
                    const Divider(height: 32),
                    const Text(
                      'Contact Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        labelText: 'Contact Email *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        hintText: 'email@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_totalImageCount/12',
                          style: TextStyle(
                            fontSize: 14,
                            color: _totalImageCount >= 12 
                                ? Colors.red 
                                : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Existing Images (from URLs)
                    if (_existingImageUrls.isNotEmpty) ...[
                      const Text(
                        'Existing Images',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _existingImageUrls.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(_existingImageUrls[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => _removeExistingImage(index),
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
                      const SizedBox(height: 16),
                    ],
                    
                    // New Images (locally selected)
                    if (_newImages.isNotEmpty) ...[
                      const Text(
                        'New Images to Upload',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _newImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(File(_newImages[index].path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () => _removeNewImage(index),
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
                    ],
                    
                    OutlinedButton.icon(
                      onPressed: _totalImageCount >= 12 ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(_totalImageCount == 0
                          ? 'Add Images (Up to 12)'
                          : _totalImageCount >= 12
                              ? 'Maximum 12 images reached'
                              : 'Add More Images (${12 - _totalImageCount} remaining)'),
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
                              Icon(Icons.star, color: Colors.orange.shade700, size: 24),
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
                            style: TextStyle(fontSize: 14, color: Colors.black87),
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

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateProperty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Update Property',
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
