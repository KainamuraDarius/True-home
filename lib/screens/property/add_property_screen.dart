import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/database_helper.dart';

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
  
  PropertyType _selectedType = PropertyType.sale;
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

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
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageIds = [];
    
    // Generate a temporary property ID for grouping images
    final tempPropertyId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        print('Processing image ${i + 1}/${_selectedImages.length}');
        final file = File(_selectedImages[i].path);
        final bytes = await file.readAsBytes();
        print('Original image size: ${bytes.length} bytes');
        
        // Decode and compress the image
        img.Image? image = img.decodeImage(bytes);
        if (image == null) {
          print('Failed to decode image ${i + 1}');
          continue;
        }
        
        print('Original dimensions: ${image.width}x${image.height}');
        
        // Resize image more aggressively to max width of 600px
        if (image.width > 600) {
          image = img.copyResize(image, width: 600);
        } else if (image.height > 800) {
          // Also check height and resize if too tall
          image = img.copyResize(image, height: 800);
        }
        
        print('Resized dimensions: ${image.width}x${image.height}');
        
        // Compress as JPEG with 70% quality for smaller size
        final compressedBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: 70),
        );
        
        print('Compressed image size: ${compressedBytes.length} bytes');
        
        // Check if compressed size is within SQLite limits (max ~1MB to be safe)
        if (compressedBytes.length > 1000000) {
          print('Image ${i + 1} still too large after compression, skipping');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image ${i + 1} is too large and was skipped'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          continue;
        }
        
        // Store compressed image in SQLite
        final imageId = await DatabaseHelper.instance.insertImage(
          propertyId: tempPropertyId,
          imageData: compressedBytes,
        );
        imageIds.add(imageId);
        print('Successfully stored image ${i + 1} with ID: $imageId');
        
      } catch (e) {
        print('Error processing image ${i + 1}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process image ${i + 1}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Continue with other images
        continue;
      }
    }

    print('Successfully processed ${imageIds.length}/${_selectedImages.length} images');
    return imageIds;
  }

  Future<void> _submitProperty() async {
    if (!_formKey.currentState!.validate()) {
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

      // Upload images to SQLite and get image IDs
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages();
        if (mounted && imageUrls.length < _selectedImages.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${imageUrls.length} of ${_selectedImages.length} images uploaded successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Create property
      final propertyRef = FirebaseFirestore.instance.collection('properties').doc();
      final property = PropertyModel(
        id: propertyRef.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        price: double.parse(_priceController.text.trim()),
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        bedrooms: _bedroomsController.text.trim().isEmpty ? 0 : int.parse(_bedroomsController.text.trim()),
        bathrooms: _bathroomsController.text.trim().isEmpty ? 0 : int.parse(_bathroomsController.text.trim()),
        areaSqft: _areaSqftController.text.trim().isEmpty ? 0 : double.parse(_areaSqftController.text.trim()),
        imageUrls: imageUrls,
        ownerId: user.uid,
        ownerName: userData.name,
        ownerEmail: userData.email,
        contactPhone: _contactPhoneController.text.trim(),
        whatsappPhone: _whatsappPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        status: PropertyStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
          'message': '${userData.name} submitted "${_titleController.text.trim()}" for review',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting property: $e'),
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
                    // Property Type
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
                    const Text(
                      'Property Images',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                    image: DecorationImage(
                                      image: FileImage(File(_selectedImages[index].path)),
                                      fit: BoxFit.cover,
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
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(_selectedImages.isEmpty
                          ? 'Add Images (Stored Locally)'
                          : 'Add More Images'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
