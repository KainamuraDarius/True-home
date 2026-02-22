import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';

class VerificationDocumentUploadScreen extends StatefulWidget {
  const VerificationDocumentUploadScreen({super.key});

  @override
  State<VerificationDocumentUploadScreen> createState() => _VerificationDocumentUploadScreenState();
}

class _VerificationDocumentUploadScreenState extends State<VerificationDocumentUploadScreen> {
  File? _nationalIdImage;
  File? _businessLicenseImage;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  Future<void> _pickImage(bool isNationalId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          if (isNationalId) {
            _nationalIdImage = File(image.path);
          } else {
            _businessLicenseImage = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToFirebase(File image, String fileName, String docType) async {
    try {
      debugPrint('📤 Starting upload for $fileName');
      
      setState(() {
        _uploadStatus = 'Uploading $docType...';
      });
      
      // Read image bytes
      final bytes = await image.readAsBytes();
      final sizeInKB = bytes.length / 1024;
      debugPrint('📊 Image size: ${sizeInKB.toStringAsFixed(2)} KB');
      
      // Upload to Firebase Storage
      final url = await StorageService.uploadImage(bytes, folder: 'verification_documents');
      
      if (url != null) {
        debugPrint('✅ Image uploaded successfully: $url');
        return url;
      } else {
        throw Exception('Upload failed - No URL returned');
      }
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      
      // Check for network errors
      String errorMsg = 'Failed to upload $docType';
      if (e.toString().contains('SocketException') || 
          e.toString().contains('NetworkException') ||
          e.toString().contains('timeout')) {
        errorMsg = 'Network error: Please check your internet connection';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _submitVerification() async {
    if (_nationalIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your National ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Starting upload...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Calculate total steps
      int totalSteps = _businessLicenseImage != null ? 4 : 3; // uploads + firestore updates
      int currentStep = 0;

      // Upload National ID to Firebase Storage
      setState(() {
        _uploadProgress = (currentStep / totalSteps);
      });
      
      final nationalIdUrl = await _uploadImageToFirebase(
        _nationalIdImage!,
        'national_id_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'National ID',
      );

      if (nationalIdUrl == null) {
        throw Exception('Failed to upload National ID');
      }
      
      currentStep++;
      setState(() {
        _uploadProgress = (currentStep / totalSteps);
      });

      // Upload Business License if provided
      String? businessLicenseUrl;
      if (_businessLicenseImage != null) {
        businessLicenseUrl = await _uploadImageToFirebase(
          _businessLicenseImage!,
          'business_license_${DateTime.now().millisecondsSinceEpoch}.jpg',
          'Business License',
        );
        currentStep++;
        setState(() {
          _uploadProgress = (currentStep / totalSteps);
        });
      }

      // Create verification request in Firestore
      setState(() {
        _uploadStatus = 'Saving verification request...';
      });
      
      await FirebaseFirestore.instance
          .collection('verification_requests')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'nationalIdUrl': nationalIdUrl,
        'businessLicenseUrl': businessLicenseUrl,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
      });
      
      currentStep++;
      setState(() {
        _uploadProgress = (currentStep / totalSteps);
      });

      // Update user document with verification status
      setState(() {
        _uploadStatus = 'Updating profile...';
      });
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'verificationStatus': 'pending',
        'verificationRequestedAt': FieldValue.serverTimestamp(),
      });
      
      currentStep++;
      setState(() {
        _uploadProgress = 1.0;
        _uploadStatus = 'Complete!';
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
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
                    'Submitted Successfully!',
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
                      'Your verification documents have been submitted successfully. Our admin team will review them and get back to you within 1-2 business days.',
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
        
        String errorMsg = 'Error submitting verification';
        if (e.toString().contains('SocketException') || 
            e.toString().contains('NetworkException') ||
            e.toString().contains('timeout') ||
            e.toString().contains('connection')) {
          errorMsg = 'Network error: Please check your internet connection and try again';
        } else {
          errorMsg = 'Error: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verification')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Required Documents'),
            elevation: 0,
            backgroundColor: Colors.white,
          ),
          body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User data not found'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final isVerified = userData['isVerified'] ?? false;
          final verificationStatus = userData['verificationStatus'] ?? '';

          // If already verified, show verified status
          if (isVerified) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_user,
                        size: 80,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Account Verified!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your account has been successfully verified by our admin team.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Go Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            );
          }

          // If verification is pending, show pending status
          if (verificationStatus == 'pending') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pending_outlined,
                        size: 80,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Verification Pending',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your documents have been submitted and are currently under review. We\'ll notify you once the verification is complete.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Go Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            );
          }

          // If unverified by admin, show message and allow reapplication
          if (verificationStatus == 'unverified') {
            final unverifiedAt = userData['unverifiedAt'] != null
                ? (userData['unverifiedAt'] as Timestamp).toDate()
                : null;
            
            return Column(
              children: [
                // Warning banner at top
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.red.shade200, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Account Unverified by Admin',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        unverifiedAt != null
                            ? 'Your verification was removed on ${_formatDate(unverifiedAt)}'
                            : 'Your verification has been removed by the admin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          'You can reapply for verification by submitting your documents below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Show upload form below
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildUploadForm(),
                    ),
                  ),
                ),
              ],
            );
          }

          // Show upload form if not verified and not pending
          return _buildUploadForm();
        },
      ),
        ),
        // Circular progress overlay
        if (_isSubmitting)
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

  Widget _buildUploadForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade100,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Required Documents for Verification',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'National Id\nBusiness Licence (Optional) for those with registered businesses',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Section Title
                  const Text(
                    'Required Documents',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Upload clear photos of your documents',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // National ID Upload
                  _buildDocumentUploadCard(
                    title: 'National ID',
                    subtitle: 'Front side of your National ID',
                    isRequired: true,
                    icon: Icons.badge_outlined,
                    image: _nationalIdImage,
                    onTap: () => _pickImage(true),
                    onRemove: () {
                      setState(() {
                        _nationalIdImage = null;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Business License Upload
                  _buildDocumentUploadCard(
                    title: 'Business License',
                    subtitle: 'If you have a registered business',
                    isRequired: false,
                    icon: Icons.business_center_outlined,
                    image: _businessLicenseImage,
                    onTap: () => _pickImage(false),
                    onRemove: () {
                      setState(() {
                        _businessLicenseImage = null;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        
        // Bottom Submit Button
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator when uploading
              if (_isSubmitting) ...[
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
                    Text(
                      _uploadStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 24,
                              width: 24,
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Submit for Verification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    required bool isRequired,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRequired 
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isRequired ? AppColors.primary : Colors.orange.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isRequired) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!isRequired)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Upload Area
          if (image == null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click to upload',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    image,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
