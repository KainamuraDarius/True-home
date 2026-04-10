import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../services/storage_service.dart';
import '../../services/organization_access_service.dart';
import '../common/legal_policies_screen.dart';
import 'choose_plan_screen.dart';
import '../../services/pandora_payment_service.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  bool _showPlanScreen = false;
  String? _selectedPlan;
  String? _selectedPeriod;
  int? _selectedPlanPrice;
  bool _planStepCompleted = false;
  bool _submitAfterPlan = false;
  bool _isPaying = false;
  final PandoraPaymentService _pandoraService = PandoraPaymentService();
  final OrganizationAccessService _organizationAccessService =
      OrganizationAccessService();
  final _titleController = TextEditingController();
  // Custom additions for commercial property flexibility
  String? _customCategory;
  String _rentalUnit = 'per day';
  String _selectedCategory = 'Flat';
  final List<String> _residentialCategories = const [
    'Flat',
    'Bungalow',
    'Condo',
    'Villa',
    'Apartment',
    'Studio room',
  ];
  final List<String> _commercialCategories = const [
    'Office',
    'Shop',
    'Warehouse',
    'Showroom',
    'Commercial Plot',
    'Mixed-Use Building',
  ];
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _fullAddressController = TextEditingController();
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
  String _areaUnit = 'sqft';
  String _currency = 'UGX';
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  Timer? _autoSaveTimer;

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

  List<String> get _availableCategories {
    return _selectedType == PropertyType.commercial
        ? _commercialCategories
        : _residentialCategories;
  }

  void _setPropertyType(PropertyType type) {
    setState(() {
      _selectedType = type;
      if (!_availableCategories.contains(_selectedCategory)) {
        _selectedCategory = _availableCategories.first;
      }
      if (_selectedType == PropertyType.commercial) {
        _bedroomsController.clear();
        _bathroomsController.clear();
        _areaSqftController.clear();
      }
    });
    _saveDraft();
  }

  String get _draftKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'add_property_draft_v1_$uid';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreDraft();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _saveDraft();
    });
  }

  PropertyType _parsePropertyType(String? value) {
    if (value == null || value.isEmpty) return _selectedType;
    for (final type in PropertyType.values) {
      if (type.name == value || type.toString().split('.').last == value) {
        return type;
      }
    }
    return _selectedType;
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = <String, dynamic>{
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'selectedPlan': _selectedPlan,
        'selectedPeriod': _selectedPeriod,
        'selectedPlanPrice': _selectedPlanPrice,
        'planStepCompleted': _planStepCompleted,
        'title': _titleController.text,
        'selectedCategory': _selectedCategory,
        'description': _descriptionController.text,
        'price': _priceController.text,
        'location': _locationController.text,
        'fullAddress': _fullAddressController.text,
        'bedrooms': _bedroomsController.text,
        'bathrooms': _bathroomsController.text,
        'areaSqft': _areaSqftController.text,
        'contactPhone': _contactPhoneController.text,
        'whatsappPhone': _whatsappPhoneController.text,
        'contactEmail': _contactEmailController.text,
        'companyName': _companyNameController.text,
        'agentName': _agentNameController.text,
        'selectedType': _selectedType.name,
        'requestSpotlightPromotion': _requestSpotlightPromotion,
        'agreedToAgentTerms': _agreedToAgentTerms,
        'areaUnit': _areaUnit,
        'currency': _currency,
        'selectedAmenities': _selectedAmenities,
        'selectedImagePaths': _selectedImages.map((e) => e.path).toList(),
      };
      await prefs.setString(_draftKey, jsonEncode(draft));
    } catch (e) {
      debugPrint('Error saving add property draft: $e');
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawDraft = prefs.getString(_draftKey);
      if (rawDraft == null || rawDraft.isEmpty) {
        return;
      }

      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) return;

      _titleController.text = decoded['title']?.toString() ?? '';
      _descriptionController.text = decoded['description']?.toString() ?? '';
      _priceController.text = decoded['price']?.toString() ?? '';
      _locationController.text = decoded['location']?.toString() ?? '';
      _fullAddressController.text = decoded['fullAddress']?.toString() ?? '';
      _bedroomsController.text = decoded['bedrooms']?.toString() ?? '';
      _bathroomsController.text = decoded['bathrooms']?.toString() ?? '';
      _areaSqftController.text = decoded['areaSqft']?.toString() ?? '';
      _contactPhoneController.text = decoded['contactPhone']?.toString() ?? '';
      _whatsappPhoneController.text =
          decoded['whatsappPhone']?.toString() ?? '';
      _contactEmailController.text = decoded['contactEmail']?.toString() ?? '';
      _companyNameController.text = decoded['companyName']?.toString() ?? '';
      _agentNameController.text = decoded['agentName']?.toString() ?? '';

      final restoredType = _parsePropertyType(
        decoded['selectedType']?.toString(),
      );
      final restoredCategory = decoded['selectedCategory']?.toString();
      final imagePaths =
          (decoded['selectedImagePaths'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final restoredImages = kIsWeb
          ? <XFile>[]
          : imagePaths.map((path) => XFile(path)).toList();
      final restoredAmenities =
          (decoded['selectedAmenities'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];

      if (!mounted) return;

      setState(() {
        _showPlanScreen = false;
        _selectedPlan = decoded['selectedPlan']?.toString();
        _selectedPeriod = decoded['selectedPeriod']?.toString();
        _selectedPlanPrice = (decoded['selectedPlanPrice'] as num?)?.toInt();
        _planStepCompleted = decoded['planStepCompleted'] as bool? ?? false;
        _selectedType = restoredType;
        _selectedCategory = _availableCategories.contains(restoredCategory)
            ? restoredCategory!
            : _availableCategories.first;
        _requestSpotlightPromotion =
            decoded['requestSpotlightPromotion'] as bool? ??
            _requestSpotlightPromotion;
        _agreedToAgentTerms =
            decoded['agreedToAgentTerms'] as bool? ?? _agreedToAgentTerms;
        _areaUnit = decoded['areaUnit']?.toString() ?? _areaUnit;
        _currency = decoded['currency']?.toString() ?? _currency;
        _selectedAmenities
          ..clear()
          ..addAll(restoredAmenities);
        _selectedImages
          ..clear()
          ..addAll(restoredImages);
      });

      if (_titleController.text.trim().isNotEmpty ||
          _descriptionController.text.trim().isNotEmpty ||
          _selectedImages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Draft restored. You can continue from where you stopped.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error restoring add property draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugPrint('Error clearing add property draft: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDraft();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _saveDraft();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _fullAddressController.dispose();
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

      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 95);

      if (images.isNotEmpty) {
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
        await _saveDraft();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _saveDraft();
  }

  Future<Uint8List> _getThumbnail(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        return bytes;
      }
      img.Image thumbnail;
      if (decodedImage.width > decodedImage.height) {
        thumbnail = img.copyResize(decodedImage, width: 150);
      } else {
        thumbnail = img.copyResize(decodedImage, height: 150);
      }
      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 60));
    } catch (e) {
      print('Error generating thumbnail: $e');
      return await image.readAsBytes();
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];
    final totalImages = _selectedImages.length;

    for (int i = 0; i < totalImages; i++) {
      setState(() {
        _uploadProgress = (i / totalImages);
        _uploadStatus = 'Uploading image ${i + 1} of $totalImages...';
      });

      try {
        final image = _selectedImages[i];
        final bytes = await image.readAsBytes();
        print('Uploading original image ${i + 1} (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
        final imageUrl = await StorageService.uploadImage(
          bytes,
          folder: 'properties',
        );
        if (imageUrl != null) {
          print('✅ Uploaded image ${i + 1}');
          imageUrls.add(imageUrl);
        } else {
          print('❌ Failed to upload image ${i + 1}');
        }
      } catch (e) {
        print('❌ Error with image ${i + 1}: $e');
      }
    }

    setState(() {
      _uploadProgress = 1.0;
      _uploadStatus = 'Uploaded ${imageUrls.length} of $totalImages images';
    });

    print('✅ Upload complete: ${imageUrls.length}/$totalImages images');
    return imageUrls;
  }

  Future<void> _submitProperty() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a property.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

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
      final user = currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = UserModel.fromJson({
        ...userDoc.data()!,
        'id': userDoc.id,
      });

      final accessResult = await _organizationAccessService
          .checkPropertyListingAccess(userId: user.uid);
      if (!accessResult.allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(accessResult.message ?? 'Permission denied.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final activeOrganizationId = accessResult.organizationId;

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages();

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
        location: _locationController.text
            .trim()
            .split(' ')
            .map(
              (w) => w.isEmpty
                  ? ''
                  : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
            )
            .join(' '),
        address: _fullAddressController.text.trim().isNotEmpty
            ? _fullAddressController.text.trim()
            : _locationController.text
                  .trim()
                  .split(' ')
                  .map(
                    (w) => w.isEmpty
                        ? ''
                        : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
                  )
                  .join(' '),
        bedrooms: _bedroomsController.text.trim().isEmpty
            ? 0
            : (_selectedType == PropertyType.commercial
                  ? 0
                  : int.parse(_bedroomsController.text.trim())),
        bathrooms: _bathroomsController.text.trim().isEmpty
            ? 0
            : (_selectedType == PropertyType.commercial
                  ? 0
                  : int.parse(_bathroomsController.text.trim())),
        areaSqft: _areaSqftController.text.trim().isEmpty
            ? 0
            : double.parse(_areaSqftController.text.trim()),
        areaUnit: _areaUnit,
        currency: _currency,
        imageUrls: imageUrls,
        ownerId: user.uid,
        organizationId: activeOrganizationId,
        createdByUserId: user.uid,
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
        featuredPromotion: false,
        developerAdvertising: false,
        promotionRequested: _requestSpotlightPromotion,
        inspectionFee: null,
      );

      await propertyRef.set(property.toJson());
      await _clearDraft();

      setState(() {
        _uploadStatus = 'Notifying admins...';
      });

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
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
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

  // ── Moved out of build() so it can be referenced before being "declared" ──
  Future<bool> _showAgentPlanPaymentDialog() async {
    if (_selectedPlan == null || _selectedPlanPrice == null) return false;

    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool paymentSuccess = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.payment,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text('Confirm Payment'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan: ${_selectedPlan!.toUpperCase()}'),
                    const SizedBox(height: 8),
                    Text(
                      'Period: ${_selectedPeriod == 'annual' ? 'Annual (Save 20%)' : 'Monthly'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Amount: UGX ${_selectedPlanPrice!.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => ",")}',
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: formKey,
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Money Number',
                          hintText: 'e.g. 2567XXXXXXXX',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter phone number'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isPaying ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isPaying
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => _isPaying = true);

                          final transactionRef =
                              'AGENTPLAN_${DateTime.now().millisecondsSinceEpoch}';
                          final narrative =
                              'Agent Plan: ${_selectedPlan!.toUpperCase()} (${_selectedPeriod == 'annual' ? 'Annual' : 'Monthly'})';

                          try {
                            final response = await _pandoraService
                                .initiatePayment(
                                  phoneNumber: phoneController.text.trim(),
                                  amount: _selectedPlanPrice!.toDouble(),
                                  transactionRef: transactionRef,
                                  narrative: narrative,
                                );
                            if (!response.success) {
                              throw PaymentException(response.message);
                            }

                            if (context.mounted) {
                              await showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text(
                                        'Check your phone to complete payment...',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            await Future.delayed(const Duration(seconds: 3));
                            paymentSuccess = true;

                            if (context.mounted) {
                              Navigator.pop(context); // close waiting dialog
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Payment Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => _isPaying = false);
                            if (paymentSuccess && context.mounted) {
                              Navigator.pop(context); // close payment dialog
                            }
                          }
                        },
                  child: _isPaying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Proceed to Pay'),
                ),
              ],
            );
          },
        );
      },
    );

    return paymentSuccess;
  }

  bool _canProceedToPlanStep() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a property.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add property images before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _handleSubmitFlow() async {
    if (!_canProceedToPlanStep()) return;

    await _submitProperty();
  }

  @override
  Widget build(BuildContext context) {
    if (_showPlanScreen) {
      return ChoosePlanScreen(
        onCancel: () {
          setState(() {
            _showPlanScreen = false;
            _submitAfterPlan = false;
          });
          _saveDraft();
        },
        onSkip: () {
          final shouldSubmit = _submitAfterPlan;
          setState(() {
            _showPlanScreen = false;
            _submitAfterPlan = false;
            _planStepCompleted = true;
            _selectedPlan = null;
            _selectedPeriod = null;
            _selectedPlanPrice = null;
          });
          _saveDraft();
          if (shouldSubmit) {
            _submitProperty();
          }
        },
        onPlanSelected: (plan, period, price) async {
          setState(() {
            _selectedPlan = plan;
            _selectedPeriod = period;
            _selectedPlanPrice = price;
          });
          _saveDraft();

          final paymentSuccess = await _showAgentPlanPaymentDialog();
          if (!paymentSuccess || !mounted) return;

          final shouldSubmit = _submitAfterPlan;
          setState(() {
            _showPlanScreen = false;
            _submitAfterPlan = false;
            _planStepCompleted = true;
          });
          _saveDraft();

          if (shouldSubmit) {
            await _submitProperty();
          }
        },
      );
    }

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
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
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
                              _buildInstructionItem(
                                'Fields marked with * are required',
                              ),
                              _buildInstructionItem(
                                'Fields without * are optional',
                              ),
                              _buildInstructionItem(
                                'Provide accurate contact information',
                              ),
                              _buildInstructionItem(
                                'Ensure phone numbers are active and correct',
                              ),
                              _buildInstructionItem(
                                'Add clear, high-quality property images',
                              ),
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

                        // Property Type
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
                                  if (value != null) {
                                    _setPropertyType(value);
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<PropertyType>(
                                title: const Text('For Rent'),
                                value: PropertyType.rent,
                                groupValue: _selectedType,
                                onChanged: (value) {
                                  if (value != null) {
                                    _setPropertyType(value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        RadioListTile<PropertyType>(
                          title: const Text('Commercial'),
                          value: PropertyType.commercial,
                          groupValue: _selectedType,
                          onChanged: (value) {
                            if (value != null) {
                              _setPropertyType(value);
                            }
                          },
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

                        // Category and custom category (if needed)
                        ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: _selectedType == PropertyType.commercial
                                  ? 'Commercial Category *'
                                  : 'Property Category *',
                              border: const OutlineInputBorder(),
                            ),
                            style: const TextStyle(color: Colors.black),
                            items: [
                              ..._availableCategories.map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category, style: const TextStyle(color: Colors.black)),
                                ),
                              ),
                              if (_selectedType == PropertyType.commercial)
                                const DropdownMenuItem<String>(
                                  value: 'Other',
                                  child: Text('Other', style: TextStyle(color: Colors.black)),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                                if (value != 'Other') _customCategory = null;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a category';
                              }
                              if (value == 'Other' && (_customCategory == null || _customCategory!.isEmpty)) {
                                return 'Please enter a custom category';
                              }
                              return null;
                            },
                          ),
                          if (_selectedType == PropertyType.commercial && _selectedCategory == 'Other')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Custom Category',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _customCategory = val;
                                  });
                                },
                                validator: (val) {
                                  if (_selectedCategory == 'Other' && (val == null || val.isEmpty)) {
                                    return 'Please enter a custom category';
                                  }
                                  return null;
                                },
                              ),
                            ),
                        ],
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
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: InputDecoration(
                                      labelText: _selectedType == PropertyType.rent
                                          ? 'Monthly Rent *'
                                          : 'Price *',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 14),
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
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _currency,
                                    decoration: const InputDecoration(
                                      labelText: 'Currency',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'UGX',
                                        child: Text('UGX', style: TextStyle(fontSize: 14)),
                                      ),
                                      DropdownMenuItem(
                                        value: 'USD',
                                        child: Text('USD', style: TextStyle(fontSize: 14)),
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
                            if (_selectedType == PropertyType.commercial) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _rentalUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Rental Unit',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 14, color: Colors.black),
                                items: [
                                  'per hour',
                                  'per day',
                                  'per week',
                                  'per month',
                                  'per year',
                                ].map((unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit, style: const TextStyle(fontSize: 14, color: Colors.black)),
                                    )).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _rentalUnit = value!;
                                  });
                                },
                              ),
                            ],
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

                        // Full Address
                        TextFormField(
                          controller: _fullAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Full Address (Optional)',
                            hintText: 'e.g., Plot 25, Acacia Avenue, Kololo',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home_outlined),
                            helperText:
                                'Exact street address — only visible to admin and your agent view',
                            helperMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bedrooms and Bathrooms (not for commercial)
                        if (_selectedType != PropertyType.commercial) ...[
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
                        ],

                        // Area with unit selection (not for commercial)
                        if (_selectedType != PropertyType.commercial) ...[
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
                                  initialValue: _areaUnit,
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
                        ],

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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
                            final isSelected = _selectedAmenities.contains(
                              amenity,
                            );
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
                                          future: _getThumbnail(
                                            _selectedImages[index],
                                          ),
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
                                                child:
                                                    CircularProgressIndicator(
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

                        // Spotlight Promotion
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

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Featured Property Promotion is available after approval from the My Properties page.',
                                  style: TextStyle(fontSize: 13),
                                ),
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
                                      const TextSpan(text: 'I agree to the '),
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
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const LegalPoliciesScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.article_outlined,
                                  size: 18,
                                ),
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
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
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
                            onPressed: (_agreedToAgentTerms && !_isLoading)
                                ? _handleSubmitFlow
                                : null,
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
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
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
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
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
          Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
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
