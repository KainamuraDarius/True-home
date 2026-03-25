import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/currency_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../services/pandora_payment_service.dart';
import '../../services/organization_access_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';

class SubmitProjectScreen extends StatefulWidget {
  const SubmitProjectScreen({super.key});

  @override
  State<SubmitProjectScreen> createState() => _SubmitProjectScreenState();
}

class _SubmitProjectScreenState extends State<SubmitProjectScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _projectService = ProjectService();
  final _imagePicker = ImagePicker();
  final _pandoraService = PandoraPaymentService();
  final _organizationAccessService = OrganizationAccessService();

  // Form fields
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _startingPriceController = TextEditingController();
  final _priceDescriptorController = TextEditingController();
  final _bookingDepositController = TextEditingController();
  final _bookingDepositDescriptionController = TextEditingController();
  final _developerTaglineController = TextEditingController();
  final _operationalAreasController = TextEditingController();
  final _companyAboutController = TextEditingController();

  String? _selectedLocation;
  ProjectStatus _selectedProjectStatus = ProjectStatus.underConstruction;
  List<XFile> _selectedImages = [];
  XFile? _companyIcon; // Company icon image
  Currency _selectedCurrency = Currency.UGX;
  bool _isSubmitting = false;
  String? _developerName;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';
  Timer? _autoSaveTimer;

  static const double _developerProjectAdvertisingPrice = 400000;
  String? _developerAdvertisingAccessMode; // 'paid' or 'testing'
  String? _developerAdvertisingPaymentReference;
  bool _isProcessingAdvertisingPlan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeveloperName();
    _restoreDraft();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _saveDraft();
    });
  }

  String get _draftKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'submit_project_draft_v1_$uid';
  }

  ProjectStatus _parseProjectStatus(String? value) {
    if (value == null || value.isEmpty) return _selectedProjectStatus;
    for (final status in ProjectStatus.values) {
      if (status.name == value || status.toString().split('.').last == value) {
        return status;
      }
    }
    return _selectedProjectStatus;
  }

  Currency _parseCurrency(String? value) {
    if (value == null || value.isEmpty) return _selectedCurrency;
    for (final currency in Currency.values) {
      if (currency.name == value ||
          currency.toString().split('.').last == value) {
        return currency;
      }
    }
    return _selectedCurrency;
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = <String, dynamic>{
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'name': _nameController.text,
        'description': _descriptionController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'website': _websiteController.text,
        'startingPrice': _startingPriceController.text,
        'priceDescriptor': _priceDescriptorController.text,
        'bookingDeposit': _bookingDepositController.text,
        'bookingDepositDescription': _bookingDepositDescriptionController.text,
        'developerTagline': _developerTaglineController.text,
        'operationalAreas': _operationalAreasController.text,
        'companyAbout': _companyAboutController.text,
        'selectedLocation': _selectedLocation,
        'selectedProjectStatus': _selectedProjectStatus.name,
        'selectedCurrency': _selectedCurrency.name,
        'selectedImagePaths': _selectedImages.map((e) => e.path).toList(),
        'companyIconPath': _companyIcon?.path,
      };
      await prefs.setString(_draftKey, jsonEncode(draft));
    } catch (e) {
      debugPrint('Error saving submit project draft: $e');
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawDraft = prefs.getString(_draftKey);
      if (rawDraft == null || rawDraft.isEmpty) return;

      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map<String, dynamic>) return;

      _nameController.text = decoded['name']?.toString() ?? '';
      _descriptionController.text = decoded['description']?.toString() ?? '';
      _phoneController.text = decoded['phone']?.toString() ?? '';
      _emailController.text = decoded['email']?.toString() ?? '';
      _websiteController.text = decoded['website']?.toString() ?? '';
      _startingPriceController.text =
          decoded['startingPrice']?.toString() ?? '';
      _priceDescriptorController.text =
          decoded['priceDescriptor']?.toString() ?? '';
      _bookingDepositController.text =
          decoded['bookingDeposit']?.toString() ?? '';
      _bookingDepositDescriptionController.text =
          decoded['bookingDepositDescription']?.toString() ?? '';
      _developerTaglineController.text =
          decoded['developerTagline']?.toString() ?? '';
      _operationalAreasController.text =
          decoded['operationalAreas']?.toString() ?? '';
      _companyAboutController.text = decoded['companyAbout']?.toString() ?? '';

      final restoredLocation = decoded['selectedLocation']?.toString();
      final restoredProjectStatus = _parseProjectStatus(
        decoded['selectedProjectStatus']?.toString(),
      );
      final restoredCurrency = _parseCurrency(
        decoded['selectedCurrency']?.toString(),
      );
      final imagePaths =
          (decoded['selectedImagePaths'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final restoredImages = kIsWeb
          ? <XFile>[]
          : imagePaths
                .where((path) => File(path).existsSync())
                .map((path) => XFile(path))
                .toList();
      final companyIconPath = decoded['companyIconPath']?.toString();
      final restoredCompanyIcon =
          !kIsWeb &&
              companyIconPath != null &&
              companyIconPath.isNotEmpty &&
              File(companyIconPath).existsSync()
          ? XFile(companyIconPath)
          : null;

      if (!mounted) return;
      setState(() {
        _selectedLocation =
            _projectService.defaultLocations.contains(restoredLocation)
            ? restoredLocation
            : null;
        _selectedProjectStatus = restoredProjectStatus;
        _selectedCurrency = restoredCurrency;
        _selectedImages = restoredImages;
        _companyIcon = restoredCompanyIcon;
      });

      if (_nameController.text.trim().isNotEmpty ||
          _descriptionController.text.trim().isNotEmpty ||
          _selectedImages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Draft restored. You can continue where you left off.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error restoring submit project draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugPrint('Error clearing submit project draft: $e');
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

  Future<void> _loadDeveloperName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _developerName = userDoc.data()?['name'] ?? user.email ?? 'Developer';
      });
    }
  }

  Future<void> _pickImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (!mounted) return;
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images.take(20).toList(); // Max 20 images
      });
      await _saveDraft();
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];
    final totalImages = _selectedImages.length;

    // Detect mobile web to prevent memory crashes on iOS Safari
    final isMobileWeb = kIsWeb && MediaQuery.of(context).size.width < 768;

    // Use sequential processing on mobile web to avoid memory pressure
    // Use smaller batches on desktop web for better performance
    final batchSize = isMobileWeb ? 1 : 3;

    // Use platform-appropriate settings
    final maxWidth = isMobileWeb ? 1200 : 1920;
    final maxHeight = isMobileWeb ? 1600 : 2560;
    final quality = isMobileWeb ? 85 : 92;

    for (
      int batchStart = 0;
      batchStart < totalImages;
      batchStart += batchSize
    ) {
      final batchEnd = (batchStart + batchSize).clamp(0, totalImages);
      final batch = _selectedImages.sublist(batchStart, batchEnd);

      setState(() {
        _uploadProgress = (batchStart / totalImages);
        _uploadStatus =
            'Uploading images ${batchStart + 1}-$batchEnd of $totalImages...';
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
            print(
              'Original size: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
            );

            img.Image? decodedImage = img.decodeImage(bytes);
            if (decodedImage == null) {
              print('Failed to decode image ${index + 1}');
              return null;
            }

            // Resize only when needed (preserve detail)
            if (decodedImage.width > maxWidth ||
                decodedImage.height > maxHeight) {
              if (decodedImage.width > decodedImage.height) {
                decodedImage = img.copyResize(decodedImage, width: maxWidth);
              } else {
                decodedImage = img.copyResize(decodedImage, height: maxHeight);
              }
            }

            // Compress with platform-appropriate quality
            final compressedBytes = Uint8List.fromList(
              img.encodeJpg(decodedImage, quality: quality),
            );

            print(
              'Compressed size: ${(compressedBytes.length / 1024).toStringAsFixed(1)} KB',
            );

            // Upload to Firebase Storage
            final imageUrl = await StorageService.uploadImage(
              compressedBytes,
              folder: 'projects',
            );

            if (imageUrl != null) {
              print('✅ Uploaded image ${index + 1}');
              return imageUrl;
            } else {
              print('❌ Failed to upload image ${index + 1}');
              return null;
            }
          } catch (e) {
            debugPrint('Error compressing/uploading image ${index + 1}: $e');
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

    if (imageUrls.isEmpty) {
      throw Exception(
        'Image upload failed: no images were successfully uploaded',
      );
    }

    print('✅ Upload complete: ${imageUrls.length}/$totalImages images');
    return imageUrls;
  }

  Future<String?> _uploadSingleImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();

      img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;

      // Resize for icon (make it square and smaller)
      final size = 256;
      decodedImage = img.copyResize(decodedImage, width: size, height: size);

      // Compress
      final compressedBytes = Uint8List.fromList(
        img.encodeJpg(decodedImage, quality: 90),
      );

      // Upload to Firebase Storage
      final imageUrl = await StorageService.uploadImage(
        compressedBytes,
        folder: 'profiles',
      );

      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading company icon: $e');
      return null;
    }
  }

  bool get _hasSelectedAdvertisingAccessMode =>
      _developerAdvertisingAccessMode == 'paid' ||
      _developerAdvertisingAccessMode == 'testing';

  Future<void> _continueAdvertisingInTesting() async {
    if (!mounted) return;
    setState(() {
      _developerAdvertisingAccessMode = 'testing';
      _developerAdvertisingPaymentReference = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Testing mode selected. You can submit project advertising without charging.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _startDeveloperAdvertisingPaymentPlan() async {
    if (_isProcessingAdvertisingPlan) return;

    setState(() => _isProcessingAdvertisingPlan = true);
    try {
      final paymentReference = await _payForDeveloperProjectAdvertising();
      if (!mounted || paymentReference == null) return;

      setState(() {
        _developerAdvertisingAccessMode = 'paid';
        _developerAdvertisingPaymentReference = paymentReference;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Developer Project Advertising plan payment confirmed.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingAdvertisingPlan = false);
      }
    }
  }

  Widget _buildDeveloperAdvertisingPlanCard() {
    final isPaid = _developerAdvertisingAccessMode == 'paid';
    final isTesting = _developerAdvertisingAccessMode == 'testing';
    final statusText = isPaid
        ? 'Payment confirmed for this submission.'
        : isTesting
        ? 'Testing mode enabled for this submission.'
        : 'Choose payment or testing mode to continue.';
    final statusColor = isPaid
        ? const Color(0xFF0A8F77)
        : isTesting
        ? Colors.orange.shade800
        : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2F9FF), Color(0xFFE5F2FF)],
        ),
        border: Border.all(color: const Color(0xFFB3D8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Developer Project Advertising',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'UGX 400,000 / month · per project',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Showcase an active construction or development project with dedicated exposure to buyers in a specific location. Includes rich media display, full project description, and a direct call-to-action link to your sales team.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessingAdvertisingPlan
                      ? null
                      : _startDeveloperAdvertisingPaymentPlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isProcessingAdvertisingPlan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payment),
                  label: Text(isPaid ? 'Paid' : 'Pay & Continue'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessingAdvertisingPlan
                      ? null
                      : _continueAdvertisingInTesting,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade600),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Continue In Testing'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isPaymentSuccessStatus(String status) {
    const successStatuses = {'completed', 'success', 'paid'};
    return successStatuses.contains(status.toLowerCase());
  }

  bool _isPaymentFailureStatus(String status) {
    const failureStatuses = {
      'failed',
      'declined',
      'cancelled',
      'expired',
      'user_cancelled',
      'timeout',
    };
    return failureStatuses.contains(status.toLowerCase());
  }

  Future<bool> _waitForDeveloperProjectAdvertisingPaymentConfirmation(
    String transactionRef,
  ) async {
    if (!mounted) return false;

    bool dialogOpen = true;
    bool cancelledByUser = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Confirm Payment'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Check your phone and enter your PIN to confirm payment.'),
              SizedBox(height: 12),
              Text(
                'Waiting for confirmation...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              SizedBox(height: 16),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelledByUser = true;
                if (!dialogOpen) return;
                dialogOpen = false;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    void closeDialogIfOpen() {
      if (!dialogOpen || !mounted) return;
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    const int maxAttempts = 24; // 2 minutes with 5-second interval
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted || cancelledByUser) break;

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || cancelledByUser) break;

      try {
        final statusResponse = await _pandoraService.checkPaymentStatus(
          transactionRef: transactionRef,
        );
        if (!mounted || cancelledByUser) {
          break;
        }

        final status = statusResponse.status.toLowerCase().trim();

        if (statusResponse.success || _isPaymentSuccessStatus(status)) {
          closeDialogIfOpen();
          return true;
        }

        if (_isPaymentFailureStatus(status)) {
          closeDialogIfOpen();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(statusResponse.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      } catch (e) {
        debugPrint(
          'Developer project advertising payment status check error: $e',
        );
      }
    }

    closeDialogIfOpen();
    if (!mounted) return false;

    if (cancelledByUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmation cancelled.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment confirmation timed out. Please complete payment and try again.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    return false;
  }

  Future<String?> _payForDeveloperProjectAdvertising() async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? paymentReference;
    bool isPaying = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: !isPaying,
              child: AlertDialog(
                title: const Text('Pay For Project Advertising'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount: UGX ${CurrencyFormatter.format(_developerProjectAdvertisingPrice)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Money Number',
                            hintText: 'e.g. 2567XXXXXXXX',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter phone number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isPaying
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: isPaying
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => isPaying = true);
                            final transactionRef =
                                'DEVPROJECT_${DateTime.now().millisecondsSinceEpoch}';

                            try {
                              final response = await _pandoraService
                                  .initiatePayment(
                                    phoneNumber: phoneController.text.trim(),
                                    amount: _developerProjectAdvertisingPrice,
                                    transactionRef: transactionRef,
                                    narrative: 'Developer Project Advertising',
                                  );

                              if (!response.success) {
                                throw PaymentException(response.message);
                              }

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Payment initiated. Enter your PIN on phone to confirm.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }

                              final isConfirmed =
                                  await _waitForDeveloperProjectAdvertisingPaymentConfirmation(
                                    response.transactionReference,
                                  );
                              if (!mounted || !isConfirmed) {
                                return;
                              }

                              paymentReference = response.transactionReference;
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Payment confirmed successfully.',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Payment failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              if (dialogContext.mounted) {
                                setDialogState(() => isPaying = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: isPaying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Pay Now'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return paymentReference;
  }

  Future<void> _submitProject() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a project.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one project image')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a location')));
      return;
    }

    final accessResult = await _organizationAccessService
        .checkProjectListingAccess(userId: currentUser.uid);
    if (!mounted) return;
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

    if (!_hasSelectedAdvertisingAccessMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose Developer Project Advertising access first: Pay & Continue or Continue In Testing.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool usesPaidAdvertising = _developerAdvertisingAccessMode == 'paid';
    final bool usesTestingBypass = _developerAdvertisingAccessMode == 'testing';
    final String? paymentReference = _developerAdvertisingPaymentReference;

    if (usesPaidAdvertising &&
        (paymentReference == null || paymentReference.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment record missing. Please tap Pay & Continue again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final totalCost = usesPaidAdvertising
        ? _developerProjectAdvertisingPrice
        : 0.0;
    final now = DateTime.now();

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Starting upload...';
    });

    try {
      // Upload images
      final imageUrls = await _uploadImages();

      // Upload company icon if selected
      String? companyIconUrl;
      if (_companyIcon != null) {
        setState(() => _uploadStatus = 'Uploading company icon...');
        companyIconUrl = await _uploadSingleImage(_companyIcon!);
      }

      setState(() {
        _uploadStatus = 'Saving project...';
      });

      // Create project
      final user = currentUser;

      // Parse operational areas from comma-separated input
      List<String> operationalAreas = [];
      if (_operationalAreasController.text.trim().isNotEmpty) {
        operationalAreas = _operationalAreasController.text
            .split(',')
            .map((area) => area.trim())
            .where((area) => area.isNotEmpty)
            .toList();
      }

      final project = Project(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        developerId: user.uid,
        organizationId: activeOrganizationId,
        createdByUserId: user.uid,
        developerName: _developerName ?? 'Developer',
        location: _selectedLocation!,
        adTier: AdTier.basic, // Single tier for all
        isFirstPlaceSubscriber: false,
        paymentAmount: totalCost,
        createdAt: now,
        adExpiresAt: now.add(const Duration(days: 30)),
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
        startingPrice: _startingPriceController.text.trim().isNotEmpty
            ? _startingPriceController.text.trim()
            : null,
        priceDescriptor: _priceDescriptorController.text.trim().isNotEmpty
            ? _priceDescriptorController.text.trim()
            : null,
        currency: _selectedCurrency,
        bookingDeposit: _bookingDepositController.text.trim().isNotEmpty
            ? double.tryParse(_bookingDepositController.text.trim())
            : null,
        bookingDepositDescription:
            _bookingDepositDescriptionController.text.trim().isNotEmpty
            ? _bookingDepositDescriptionController.text.trim()
            : null,
        developerTagline: _developerTaglineController.text.trim().isNotEmpty
            ? _developerTaglineController.text.trim()
            : null,
        operationalAreas: operationalAreas,
        companyIconUrl: companyIconUrl,
        companyAbout: _companyAboutController.text.trim().isNotEmpty
            ? _companyAboutController.text.trim()
            : null,
      );

      final projectId = await _projectService.createProject(project);
      await _projectService.updateProject(projectId, {
        'developerAdvertisingSelected': true,
        'developerAdvertisingPaid': usesPaidAdvertising,
        'developerAdvertisingTestingBypass': usesTestingBypass,
        'developerAdvertisingAccessMode': usesPaidAdvertising
            ? 'paid'
            : 'testing',
        'paymentStatus': usesPaidAdvertising ? 'paid' : 'testing_bypass',
        if (paymentReference != null)
          'developerAdvertisingPaymentRef': paymentReference,
        if (usesPaidAdvertising) 'developerAdvertisingPaidAt': Timestamp.now(),
        if (usesTestingBypass)
          'developerAdvertisingTestingBypassAt': Timestamp.now(),
      });
      await _clearDraft();

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatus = 'Complete!';
      });

      if (mounted) {
        setState(() => _isSubmitting = false);

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
                    'Project Submitted Successfully!',
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
                      usesPaidAdvertising
                          ? 'Total Cost: UGX ${CurrencyFormatter.format(totalCost)}\n\nYour project has been submitted and is awaiting admin approval.'
                          : 'Submitted in testing mode (no charge).\n\nYour project has been submitted and is awaiting admin approval.',
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadProgress = 0.0;
          _uploadStatus = '';
        });

        String errorMessage = 'Error submitting project';

        // Provide specific error messages based on error type
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('failed to upload') ||
            errorStr.contains('upload any images')) {
          errorMessage =
              'Image upload failed. Please check your internet connection and try again.';
        } else if (errorStr.contains('sockexception') ||
            errorStr.contains('networkexception') ||
            errorStr.contains('timeout')) {
          errorMessage =
              'Network connection error. Please check your internet and try again.';
        } else if (errorStr.contains('permission') ||
            errorStr.contains('denied')) {
          errorMessage =
              'Permission denied. Please check your account permissions.';
        } else if (errorStr.contains('firestore')) {
          errorMessage = 'Database error. Please try again later.';
        } else if (errorStr.contains('storage')) {
          errorMessage = 'Image storage error. Please try again later.';
        } else {
          errorMessage = 'An unexpected error occurred. Please try again.';
        }

        debugPrint('Submission error: $e');

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
          _isSubmitting = false;
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
                        _buildDeveloperAdvertisingPlanCard(),

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
                          initialValue: _selectedLocation,
                          decoration: const InputDecoration(
                            labelText: 'Location *',
                            border: OutlineInputBorder(),
                          ),
                          items: _projectService.defaultLocations.map((
                            location,
                          ) {
                            return DropdownMenuItem(
                              value: location,
                              child: Text(location),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedLocation = value);
                            _saveDraft();
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
                          initialValue: _selectedProjectStatus,
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
                            _saveDraft();
                          },
                        ),
                        const SizedBox(height: 24),

                        // Pricing Information Section
                        const Text(
                          'Pricing Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _startingPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Starting Price (Optional)',
                            hintText: 'e.g., 136K, UGX 500M',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_offer),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _priceDescriptorController,
                          decoration: const InputDecoration(
                            labelText: 'Unit Type/Price Range (Optional)',
                            hintText: 'e.g., 1-4 bedroom units',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.apartment),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Currency Selection Dropdown
                        DropdownButtonFormField<Currency>(
                          initialValue: _selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_exchange),
                          ),
                          items: Currency.values.map((currency) {
                            return DropdownMenuItem(
                              value: currency,
                              child: Text(currency.toString().split('.').last),
                            );
                          }).toList(),
                          onChanged: (Currency? value) {
                            if (value != null) {
                              setState(() => _selectedCurrency = value);
                              _saveDraft();
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _bookingDepositController,
                          decoration: const InputDecoration(
                            labelText: 'Booking Deposit (Optional)',
                            hintText: 'e.g., 1500 (in currency units)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _bookingDepositDescriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Booking Deposit Terms (Optional)',
                            hintText: 'e.g., 1% monthly til handover',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Developer Information Section
                        const Text(
                          'Developer Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _developerTaglineController,
                          decoration: const InputDecoration(
                            labelText: 'Company Tagline (Optional)',
                            hintText: 'e.g., Building Legacies Since 2014',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _operationalAreasController,
                          decoration: const InputDecoration(
                            labelText: 'Operational Areas (Optional)',
                            hintText:
                                'e.g., UAE, Africa, Europe (comma-separated)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.public),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Developer Photo Picker
                        const Text(
                          'Developer Photo (Company Logo) (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final image = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              setState(() => _companyIcon = image);
                              _saveDraft();
                            }
                          },
                          child: Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: _companyIcon != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(60),
                                    child: Image.file(
                                      File(_companyIcon!.path),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image,
                                        size: 40,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to upload',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _companyAboutController,
                          decoration: const InputDecoration(
                            labelText: 'About the Company (Optional)',
                            hintText: 'Tell customers about your company...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

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
                            labelText: 'Email (Optional)',
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
                            labelText: 'Website / Social Media Link (Optional)',
                            hintText: 'yoursite.com, YouTube, Facebook, etc.',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                            helperText:
                                'Add any link: website, YouTube video, Facebook page, Instagram, etc.',
                            helperMaxLines: 2,
                          ),
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              // Auto-add https:// if the link doesn't start with http:// or https://
                              if (!value.startsWith('http://') &&
                                  !value.startsWith('https://')) {
                                _websiteController.text = 'https://$value';
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
                                            _saveDraft();
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
                          label: Text(
                            _selectedImages.isEmpty
                                ? 'Add Images (Max 20)'
                                : 'Change Images',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (!_hasSelectedAdvertisingAccessMode)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'Complete Developer Project Advertising step above before submitting.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

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
        ),
        // Circular progress overlay
        if (_isSubmitting && _uploadProgress > 0)
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

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _saveDraft();
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _startingPriceController.dispose();
    _priceDescriptorController.dispose();
    _bookingDepositController.dispose();
    _bookingDepositDescriptionController.dispose();
    _developerTaglineController.dispose();
    _operationalAreasController.dispose();
    _companyAboutController.dispose();
    super.dispose();
  }
}
