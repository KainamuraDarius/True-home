import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../utils/universities.dart';
import '../../services/imgbb_service.dart';

class AddHostelScreen extends StatefulWidget {
  const AddHostelScreen({super.key});

  @override
  State<AddHostelScreen> createState() => _AddHostelScreenState();
}

class _AddHostelScreenState extends State<AddHostelScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _whatsappPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _hostelManagerNameController = TextEditingController();
  final _paymentInstructionsController = TextEditingController();
  
  String? _selectedUniversity;
  PricingPeriod _pricingPeriod = PricingPeriod.month;
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  
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
  
  // Hostel room types
  final Map<String, TextEditingController> _roomPriceControllers = {
    'Single Room': TextEditingController(),
    'Double Room': TextEditingController(),
    'Triple Room': TextEditingController(),
    'Shared Room': TextEditingController(),
  };
  final Map<String, TextEditingController> _roomCountControllers = {
    'Single Room': TextEditingController(),
    'Double Room': TextEditingController(),
    'Triple Room': TextEditingController(),
    'Shared Room': TextEditingController(),
  };
  final Map<String, bool> _selectedRoomTypes = {
    'Single Room': false,
    'Double Room': false,
    'Triple Room': false,
    'Shared Room': false,
  };
  
  bool _isPickingImages = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Prevent logout when image picker opens
    if (state == AppLifecycleState.paused) {
      setState(() {
        _isPickingImages = true;
      });
    } else if (state == AppLifecycleState.resumed && _isPickingImages) {
      setState(() {
        _isPickingImages = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _contactPhoneController.dispose();
    _whatsappPhoneController.dispose();
    _contactEmailController.dispose();
    _hostelManagerNameController.dispose();
    _paymentInstructionsController.dispose();
    for (var controller in _roomPriceControllers.values) {
      controller.dispose();
    }
    for (var controller in _roomCountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final totalImages = _selectedImages.length + images.length;
        if (totalImages > 12) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You can only upload up to 20 images. Currently: ${_selectedImages.length}, Selected: ${images.length}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          final remainingSlots = 12 - _selectedImages.length;
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
    final List<String> imageUrls = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        print('Uploading image ${i + 1}/${_selectedImages.length} to ImgBB');
        final file = File(_selectedImages[i].path);
        final bytes = await file.readAsBytes();
        
        img.Image? image = img.decodeImage(bytes);
        if (image == null) {
          print('Failed to decode image ${i + 1}');
          continue;
        }
        
        // Resize if too large
        if (image.width > 1920 || image.height > 1920) {
          image = img.copyResize(image, width: 1920);
        }
        
        final compressedBytes = img.encodeJpg(image, quality: 85);
        print('Compressed image size: ${compressedBytes.length} bytes');
        
        final url = await ImgBBService.uploadImage(compressedBytes);
        if (url != null) {
          imageUrls.add(url);
          print('Successfully uploaded image ${i + 1}');
        }
      } catch (e) {
        print('Error uploading image ${i + 1}: $e');
      }
    }

    return imageUrls;
  }

  Future<void> _submitHostel() async {
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

      // Upload images
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

      // Prepare room types
      List<RoomType> roomTypes = [];
      for (var entry in _selectedRoomTypes.entries) {
        if (entry.value) {
          final priceText = _roomPriceControllers[entry.key]!.text.trim();
          final countText = _roomCountControllers[entry.key]!.text.trim();
          if (priceText.isNotEmpty && countText.isNotEmpty) {
            final totalRooms = int.parse(countText);
            roomTypes.add(RoomType(
              name: entry.key,
              price: double.parse(priceText),
              pricingPeriod: _pricingPeriod,
              description: '',
              totalRooms: totalRooms,
              availableRooms: totalRooms, // Initially all rooms available
            ));
          }
        }
      }

      // Validate at least one room type
      if (roomTypes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one room type with pricing'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create hostel property (automatically approved)
      final propertyRef = FirebaseFirestore.instance.collection('properties').doc();
      final property = PropertyModel(
        id: propertyRef.id,
        title: _titleController.text.trim(),
        category: 'Hostel',
        description: _descriptionController.text.trim(),
        type: PropertyType.hostel,
        price: 0, // Hostels use room pricing
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        bedrooms: 0,
        bathrooms: 0,
        areaSqft: 0,
        imageUrls: imageUrls,
        ownerId: user.uid,
        ownerName: userData.name,
        ownerEmail: userData.email,
        companyName: 'Student Accommodation',
        agentName: _hostelManagerNameController.text.trim(),
        agentProfileImageUrl: '',
        contactPhone: _contactPhoneController.text.trim(),
        whatsappPhone: _whatsappPhoneController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        status: PropertyStatus.approved, // Auto-approved for admin
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        amenities: _selectedAmenities,
        university: _selectedUniversity,
        roomTypes: roomTypes,
        paymentInstructions: _paymentInstructionsController.text.trim().isEmpty
            ? null
            : _paymentInstructionsController.text.trim(),
      );

      await propertyRef.set(property.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student hostel published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
        title: const Text('Add Student Hostel'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade50, Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.school, color: Colors.purple.shade700, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Student hostels are added by Admin only and are automatically published',
                            style: TextStyle(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // University Selection
                  DropdownButtonFormField<String>(
                    value: _selectedUniversity,
                    decoration: const InputDecoration(
                      labelText: 'University *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    isExpanded: true,
                    isDense: true,
                    items: universities.map((university) {
                      return DropdownMenuItem<String>(
                        value: university,
                        child: Text(
                          university,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return universities.map((String value) {
                        return Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      }).toList();
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedUniversity = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a university';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Hostel Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.hotel),
                      hintText: 'e.g., Sunshine Student Hostel',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter hostel name';
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
                      hintText: 'Describe the hostel facilities and features',
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

                  // Location
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location/Area *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                      hintText: 'e.g., Wandegeya',
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
                      prefixIcon: Icon(Icons.location_on),
                      hintText: 'e.g., Plot 123, Bombo Road',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Room Types & Pricing Section
                  const Divider(height: 32),
                  const Text(
                    'Room Types & Pricing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select available room types and set their prices',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  // Pricing Period Selection
                  Row(
                    children: [
                      const Text('Pricing Period: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: const Text('Per Month'),
                        selected: _pricingPeriod == PricingPeriod.month,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _pricingPeriod = PricingPeriod.month;
                            });
                          }
                        },
                        selectedColor: Colors.purple.withOpacity(0.2),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Per Semester'),
                        selected: _pricingPeriod == PricingPeriod.semester,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _pricingPeriod = PricingPeriod.semester;
                            });
                          }
                        },
                        selectedColor: Colors.purple.withOpacity(0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Room types with pricing and availability
                  ..._roomPriceControllers.keys.map((roomType) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _selectedRoomTypes[roomType],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedRoomTypes[roomType] = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  roomType,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _selectedRoomTypes[roomType] == true 
                                        ? FontWeight.w600 
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedRoomTypes[roomType] == true) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 48),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _roomPriceControllers[roomType],
                                      decoration: const InputDecoration(
                                        labelText: 'Price (UGX)',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Required';
                                        }
                                        if (double.tryParse(value) == null) {
                                          return 'Invalid';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _roomCountControllers[roomType],
                                      decoration: const InputDecoration(
                                        labelText: 'Total Rooms',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Required';
                                        }
                                        if (int.tryParse(value) == null || int.parse(value) < 1) {
                                          return 'Min 1';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 24),

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
                        selectedColor: Colors.purple.withOpacity(0.2),
                        checkmarkColor: Colors.purple,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.purple : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Contact Information
                  const Divider(height: 32),
                  const Text(
                    'Hostel Manager Contact',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Hostel Manager Name
                  TextFormField(
                    controller: _hostelManagerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Manager Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter manager name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contact Phone
                  TextFormField(
                    controller: _contactPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
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

                  // WhatsApp
                  TextFormField(
                    controller: _whatsappPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Number *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
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

                  // Email
                  TextFormField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),                  const SizedBox(height: 16),

                  // Payment Instructions
                  TextFormField(
                    controller: _paymentInstructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Payment Instructions (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info_outline),
                      hintText: 'e.g., Pay deposit of 500,000 UGX to Acc: 123456789',
                    ),
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Students will see these instructions after reserving. Include deposit amount, bank account, or mobile money details.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),                  const SizedBox(height: 24),

                  // Images Section
                  const Divider(height: 32),
                  const Text(
                    'Hostel Photos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload up to 12 photos (${_selectedImages.length}/12)',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  // Image grid
                  if (_selectedImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  
                  // Add images button
                  if (_selectedImages.length < 12)
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Photos'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Submit button
                  ElevatedButton(
                    onPressed: _submitHostel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Publish Hostel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
