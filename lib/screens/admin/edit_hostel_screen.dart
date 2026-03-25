import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import '../../models/property_model.dart';
import '../../utils/universities.dart';
import '../../services/storage_service.dart';

class EditHostelScreen extends StatefulWidget {
  final String hostelId;
  final Map<String, dynamic> hostelData;

  const EditHostelScreen({
    super.key,
    required this.hostelId,
    required this.hostelData,
  });

  @override
  State<EditHostelScreen> createState() => _EditHostelScreenState();
}

class _EditHostelScreenState extends State<EditHostelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _addressController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _whatsappPhoneController;
  late TextEditingController _contactEmailController;
  late TextEditingController _hostelManagerNameController;
  late TextEditingController _paymentInstructionsController;

  String? _selectedUniversity;
  PricingPeriod _pricingPeriod = PricingPeriod.month;

  // Existing images from database
  List<String> _existingImages = [];
  // New images to upload
  final List<XFile> _newImages = [];
  final Map<String, Uint8List> _newImageBytes = {};
  // Images to delete
  final List<String> _imagesToDelete = [];

  bool _isLoading = false;
  bool _isAvailable = true;
  String _uploadStatus = '';
  double _uploadProgress = 0.0;
  final ImagePicker _picker = ImagePicker();
  static const int _webMaxImageDimension = 1920;
  static const int _mobileMaxImageDimension = 1400;
  static const int _webJpegQuality = 92;
  static const int _mobileJpegQuality = 86;

  // Amenities
  List<String> _selectedAmenities = [];
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

  // Room types
  final Map<String, TextEditingController> _roomPriceControllers = {};
  final Map<String, TextEditingController> _roomCountControllers = {};
  final Map<String, bool> _selectedRoomTypes = {
    'Self Contained Single Room': false,
    'Non-self Contained Single Room': false,
    'Self Contained Double Room': false,
    'Non-self Contained Double Room': false,
    'Shared Room (3 in room)': false,
    'Shared Room (4 in room)': false,
    'Bed Space': false,
    'Single Room': false,
    'Double Room': false,
    'Triple Room': false,
    'Shared Room': false,
  };

  img.Image _resizeImageForUpload(img.Image image) {
    final maxDimension = kIsWeb
        ? _webMaxImageDimension
        : _mobileMaxImageDimension;
    final currentMaxDimension = image.width > image.height
        ? image.width
        : image.height;

    if (currentMaxDimension <= maxDimension) {
      return image;
    }

    if (image.width >= image.height) {
      return img.copyResize(image, width: maxDimension);
    }

    return img.copyResize(image, height: maxDimension);
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadExistingData();
  }

  void _initializeControllers() {
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _addressController = TextEditingController();
    _contactPhoneController = TextEditingController();
    _whatsappPhoneController = TextEditingController();
    _contactEmailController = TextEditingController();
    _hostelManagerNameController = TextEditingController();
    _paymentInstructionsController = TextEditingController();

    // Initialize room controllers
    for (final roomType in _selectedRoomTypes.keys) {
      _roomPriceControllers[roomType] = TextEditingController();
      _roomCountControllers[roomType] = TextEditingController();
    }
  }

  void _loadExistingData() {
    final data = widget.hostelData;

    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _locationController.text = data['location'] ?? '';
    _addressController.text = data['address'] ?? '';
    _contactPhoneController.text = data['contactPhone'] ?? '';
    _whatsappPhoneController.text =
        data['contactWhatsApp'] ?? data['whatsappPhone'] ?? '';
    _contactEmailController.text = data['contactEmail'] ?? '';
    _hostelManagerNameController.text =
        data['hostelManagerName'] ?? data['agentName'] ?? '';
    _paymentInstructionsController.text = data['paymentInstructions'] ?? '';

    _selectedUniversity = data['nearbyUniversity'] ?? data['university'];
    _isAvailable = data['isAvailable'] ?? data['isActive'] ?? true;
    _existingImages = List<String>.from(data['imageUrls'] ?? []);
    _selectedAmenities = List<String>.from(data['amenities'] ?? []);

    // Load pricing period
    final periodStr = data['pricingPeriod'] ?? 'month';
    _pricingPeriod = PricingPeriod.values.firstWhere(
      (p) => p.toString().split('.').last == periodStr,
      orElse: () => PricingPeriod.month,
    );

    // Load room types - roomTypes can be List or Map format
    final roomTypesData = data['roomTypes'];
    if (roomTypesData is List) {
      for (final roomData in roomTypesData) {
        if (roomData is Map) {
          final roomMap = Map<String, dynamic>.from(roomData);
          final roomName = roomMap['name']?.toString();
          if (roomName != null && _selectedRoomTypes.containsKey(roomName)) {
            _selectedRoomTypes[roomName] = true;
            _roomPriceControllers[roomName]?.text = (roomMap['price'] ?? 0)
                .toString();
            _roomCountControllers[roomName]?.text =
                (roomMap['totalRooms'] ?? roomMap['count'] ?? 0).toString();
          }
        }
      }
    } else if (roomTypesData is Map) {
      // Legacy format - Map<String, dynamic>
      final roomTypes = Map<String, dynamic>.from(roomTypesData);
      for (final entry in roomTypes.entries) {
        final roomType = entry.key.toString();
        if (entry.value is Map) {
          final roomDataMap = Map<String, dynamic>.from(entry.value as Map);

          if (_selectedRoomTypes.containsKey(roomType)) {
            _selectedRoomTypes[roomType] = true;
            _roomPriceControllers[roomType]?.text = (roomDataMap['price'] ?? 0)
                .toString();
            _roomCountControllers[roomType]?.text = (roomDataMap['count'] ?? 0)
                .toString();
          }
        }
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
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
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final totalImages =
            _existingImages.length -
            _imagesToDelete.length +
            _newImages.length +
            images.length;
        if (totalImages > 12) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 12 images allowed'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        for (final img in images) {
          _newImageBytes[img.path] = await img.readAsBytes();
        }
        setState(() {
          _newImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
    }
  }

  void _removeExistingImage(String url) {
    setState(() {
      _imagesToDelete.add(url);
    });
  }

  void _restoreExistingImage(String url) {
    setState(() {
      _imagesToDelete.remove(url);
    });
  }

  void _removeNewImage(int index) {
    final path = _newImages[index].path;
    setState(() {
      _newImages.removeAt(index);
      _newImageBytes.remove(path);
    });
  }

  Future<List<String>> _uploadNewImages() async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < _newImages.length; i++) {
      try {
        setState(() {
          _uploadStatus = 'Uploading image ${i + 1}/${_newImages.length}...';
          _uploadProgress = (i / _newImages.length);
        });

        final xfile = _newImages[i];
        final bytes = _newImageBytes[xfile.path] ?? await xfile.readAsBytes();

        img.Image? image = img.decodeImage(bytes);
        if (image == null) continue;

        final processedImage = _resizeImageForUpload(image);
        final jpegQuality = kIsWeb ? _webJpegQuality : _mobileJpegQuality;
        final compressedBytes = Uint8List.fromList(
          img.encodeJpg(processedImage, quality: jpegQuality),
        );
        final url = await StorageService.uploadImage(
          compressedBytes,
          folder: 'properties',
        );

        if (url != null) {
          uploadedUrls.add(url);
          setState(() {
            _uploadProgress = ((i + 1) / _newImages.length);
          });
        }
      } catch (e) {
        print('Error uploading image ${i + 1}: $e');
      }
    }

    setState(() {
      _uploadStatus = '';
      _uploadProgress = 0.0;
    });

    return uploadedUrls;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Check for at least one room type
    final hasSelectedRoom = _selectedRoomTypes.values.any((v) => v);
    if (!hasSelectedRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one room type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload new images
      List<String> newUploadedUrls = [];
      if (_newImages.isNotEmpty) {
        newUploadedUrls = await _uploadNewImages();
      }

      // Combine existing (minus deleted) with new images
      final finalImages = [
        ..._existingImages.where((url) => !_imagesToDelete.contains(url)),
        ...newUploadedUrls,
      ];

      // Build room types as a List (to match PropertyModel format)
      final List<Map<String, dynamic>> roomTypesList = [];
      for (final entry in _selectedRoomTypes.entries) {
        if (entry.value) {
          final price =
              int.tryParse(_roomPriceControllers[entry.key]?.text ?? '0') ?? 0;
          final count =
              int.tryParse(_roomCountControllers[entry.key]?.text ?? '0') ?? 0;
          roomTypesList.add({
            'name': entry.key,
            'price': price,
            'totalRooms': count,
            'availableRooms': count,
            'pricingPeriod': _pricingPeriod.toString().split('.').last,
            'description': '',
          });
        }
      }

      // Get lowest price for display
      int lowestPrice = 0;
      if (roomTypesList.isNotEmpty) {
        lowestPrice = roomTypesList
            .map((r) => r['price'] as int)
            .reduce((a, b) => a < b ? a : b);
      }

      // Update hostel document
      await _firestore.collection('properties').doc(widget.hostelId).update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'address': _addressController.text.trim(),
        'nearbyUniversity': _selectedUniversity,
        'university': _selectedUniversity,
        'contactPhone': _contactPhoneController.text.trim(),
        'contactWhatsApp': _whatsappPhoneController.text.trim(),
        'whatsappPhone': _whatsappPhoneController.text.trim(),
        'contactEmail': _contactEmailController.text.trim(),
        'hostelManagerName': _hostelManagerNameController.text.trim(),
        'agentName': _hostelManagerNameController.text.trim(),
        'paymentInstructions': _paymentInstructionsController.text.trim(),
        'imageUrls': finalImages,
        'amenities': _selectedAmenities,
        'roomTypes': roomTypesList,
        'pricingPeriod': _pricingPeriod.toString().split('.').last,
        'price': lowestPrice,
        'isAvailable': _isAvailable,
        'isActive': _isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating hostel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeImageCount =
        _existingImages.length - _imagesToDelete.length + _newImages.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Hostel'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          // Availability toggle
          Row(
            children: [
              const Text('Available'),
              Switch(
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
                activeThumbColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
      body: _isLoading && _uploadStatus.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Card(
                      color: Colors.purple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.edit, color: Colors.purple),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Editing Hostel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'ID: ${widget.hostelId}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
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

                    // University Selection
                    DropdownButtonFormField<String>(
                      initialValue: _selectedUniversity,
                      decoration: const InputDecoration(
                        labelText: 'University *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      isExpanded: true,
                      items: universities.map((university) {
                        return DropdownMenuItem<String>(
                          value: university,
                          child: Text(
                            university,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedUniversity = value),
                      validator: (value) =>
                          value == null ? 'Please select a university' : null,
                    ),
                    const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Hostel Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Please enter hostel name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) => value?.isEmpty == true
                          ? 'Please enter description'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Location & Address
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: 'Location *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Full Address',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Contact Information Section
                    const Divider(),
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _hostelManagerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Hostel Manager Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _contactPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                                value?.isEmpty == true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _whatsappPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'WhatsApp (optional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.chat),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _contactEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    // Room Types Section
                    const Divider(),
                    const Text(
                      'Room Types & Pricing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Pricing period
                    Row(
                      children: [
                        const Text('Pricing Per: '),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Month'),
                          selected: _pricingPeriod == PricingPeriod.month,
                          onSelected: (selected) {
                            if (selected)
                              setState(
                                () => _pricingPeriod = PricingPeriod.month,
                              );
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Semester'),
                          selected: _pricingPeriod == PricingPeriod.semester,
                          onSelected: (selected) {
                            if (selected)
                              setState(
                                () => _pricingPeriod = PricingPeriod.semester,
                              );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Room types list
                    ..._selectedRoomTypes.keys.map((roomType) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: CheckboxListTile(
                          title: Text(roomType),
                          value: _selectedRoomTypes[roomType],
                          onChanged: (value) {
                            setState(
                              () =>
                                  _selectedRoomTypes[roomType] = value ?? false,
                            );
                          },
                          subtitle: _selectedRoomTypes[roomType] == true
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller:
                                              _roomPriceControllers[roomType],
                                          decoration: const InputDecoration(
                                            labelText: 'Price (UGX)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller:
                                              _roomCountControllers[roomType],
                                          decoration: const InputDecoration(
                                            labelText: 'Room Count',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // Amenities Section
                    const Divider(),
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Payment Instructions
                    TextFormField(
                      controller: _paymentInstructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Instructions (optional)',
                        hintText:
                            'e.g., Mobile money number, bank details, etc.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Images Section
                    const Divider(),
                    Row(
                      children: [
                        const Text(
                          'Hostel Photos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$activeImageCount/12 images',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Existing images
                    if (_existingImages.isNotEmpty) ...[
                      const Text(
                        'Current Images:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _existingImages.length,
                        itemBuilder: (context, index) {
                          final url = _existingImages[index];
                          final isMarkedForDeletion = _imagesToDelete.contains(
                            url,
                          );

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ColorFiltered(
                                  colorFilter: isMarkedForDeletion
                                      ? const ColorFilter.mode(
                                          Colors.grey,
                                          BlendMode.saturation,
                                        )
                                      : const ColorFilter.mode(
                                          Colors.transparent,
                                          BlendMode.multiply,
                                        ),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              ),
                              if (isMarkedForDeletion)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.undo,
                                        color: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _restoreExistingImage(url),
                                    ),
                                  ),
                                )
                              else
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.red,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _removeExistingImage(url),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // New images
                    if (_newImages.isNotEmpty) ...[
                      const Text(
                        'New Images to Upload:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: _newImages.length,
                        itemBuilder: (context, index) {
                          final bytes = _newImageBytes[_newImages[index].path];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: bytes != null
                                    ? Image.memory(bytes, fit: BoxFit.cover)
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.red,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _removeNewImage(index),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Add images button
                    if (activeImageCount < 12)
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add More Photos'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Upload progress
                    if (_uploadStatus.isNotEmpty) ...[
                      Card(
                        color: Colors.purple.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                _uploadStatus,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: _uploadProgress,
                                backgroundColor: Colors.purple.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Save button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
