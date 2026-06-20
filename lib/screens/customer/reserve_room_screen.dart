// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../utils/currency_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../models/reservation_model.dart';
import '../../services/room_availability_service.dart';
import '../../services/nylon_payment_service.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';
import '../auth/role_selection_screen.dart';
import 'reservation_confirmation_screen.dart';

class ReserveRoomScreen extends StatefulWidget {
  final PropertyModel property;
  final RoomType roomType;

  const ReserveRoomScreen({
    super.key,
    required this.property,
    required this.roomType,
  });

  @override
  State<ReserveRoomScreen> createState() => _ReserveRoomScreenState();
}

class _ReserveRoomScreenState extends State<ReserveRoomScreen> {
  static const Uuid _uuid = Uuid();
  Map<String, dynamic>? _userProfile;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final RoomAvailabilityService _availabilityService =
      RoomAvailabilityService();
  final NylonPaymentService _nylonService = NylonPaymentService();

  bool _isProcessing = false;
  final double _reservationFee = 20000; // UGX
  bool _isCheckingAvailability = true;
  bool _roomAvailable = false;

  String? _currentTransactionId; // Track current payment transaction

  String _buildPaymentReference() {
    return _uuid.v4().replaceAll('-', '').substring(0, 14);
  }

  void _showPaymentMessage(
    String message, {
    Color backgroundColor = Colors.orange,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  bool _isMissingPaymentTransactionMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('transaction not found') ||
        normalized.contains('provider transaction id not found');
  }

  String _normalizePaymentPhoneForInput(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('256256')) {
      digits = '256${digits.substring(6)}';
    }

    if (digits.startsWith('2560')) {
      digits = '256${digits.substring(4)}';
    }

    if (digits.startsWith('0')) {
      digits = '256${digits.substring(1)}';
    } else if (!digits.startsWith('256') && digits.startsWith('7')) {
      digits = '256$digits';
    }

    if (digits.startsWith('256') && digits.length > 12) {
      digits = digits.substring(0, 12);
    }

    return digits.isEmpty ? '' : '+$digits';
  }

  bool _isValidPaymentPhoneNumber(String value) {
    final normalized = _normalizePaymentPhoneForInput(value);
    return RegExp(r'^\+2567\d{8}$').hasMatch(normalized);
  }

  @override
  void initState() {
    super.initState();
    _checkRoomAvailability();
    _prefillUserInfo();
  }

  Future<void> _prefillUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Try to get extra profile info from Firestore
    String? firestorePhone;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        _userProfile = doc.data();
        _nameController.text = _userProfile?['name'] ?? user.displayName ?? '';
        _emailController.text = _userProfile?['email'] ?? user.email ?? '';
        firestorePhone = _userProfile?['phone'];
      } else {
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
      }
    } catch (e) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
    // Prefer FirebaseAuth phoneNumber if available, else Firestore, else blank
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      _phoneController.text = user.phoneNumber!;
    } else if (firestorePhone != null && firestorePhone.isNotEmpty) {
      _phoneController.text = firestorePhone;
    } else {
      _phoneController.text = '';
    }
  }

  Future<void> _checkRoomAvailability() async {
    try {
      final roomType = await _availabilityService.getRoomAvailability(
        propertyId: widget.property.id,
        roomTypeName: widget.roomType.name,
      );

      setState(() {
        _roomAvailable = roomType != null && roomType.availableRooms > 0;
        _isCheckingAvailability = false;
      });
    } catch (e) {
      setState(() {
        _roomAvailable = false;
        _isCheckingAvailability = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showPaymentDialog() {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Confirm Payment'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Method Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Payment will be processed securely',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You will receive a payment prompt on your mobile money app or via USSD (*165# for MTN, etc). Complete the payment on your phone to confirm the processing fee.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Processing Fee
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Processing Fee:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _phoneController.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'UGX ${CurrencyFormatter.format(_reservationFee)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initiateNylonPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed to Pay'),
          ),
        ],
      ),
    );
  }

  /// Initiate Nylon payment
  /// Sends payment request to Nylon Pay - user will receive USSD/app prompt
  Future<void> _initiateNylonPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show processing dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Sending payment request to your phone...'),
            ],
          ),
        ),
      );

      final transactionRef = _buildPaymentReference();
      _phoneController.value = TextEditingValue(
        text: _normalizePaymentPhoneForInput(_phoneController.text.trim()),
        selection: TextSelection.collapsed(
          offset: _normalizePaymentPhoneForInput(
            _phoneController.text.trim(),
          ).length,
        ),
      );

      // Call Nylon Pay to initiate payment
      final response = await _nylonService.initiatePayment(
        phoneNumber: _phoneController.text.trim(),
        amount: _reservationFee,
        transactionRef: transactionRef,
        narrative: 'Hostel room reservation - ${widget.property.title}',
      );

      if (!response.success) {
        throw PaymentException(response.message);
      }

      _currentTransactionId = response.transactionReference;

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      // Show payment status checking dialog
      _showPaymentStatusDialog(transactionRef);
    } on PaymentException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      setState(() {
        _isProcessing = false;
      });

      _showPaymentMessage(e.message, backgroundColor: Colors.red);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      setState(() {
        _isProcessing = false;
      });

      _showPaymentMessage(
        'We could not start the payment right now. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  /// Show dialog that checks payment status
  /// Polls Nylon Pay and waits for payment to complete
  void _showPaymentStatusDialog(String transactionRef) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📱 Check Your Phone',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✓ You should have received a payment prompt on your phone\n'
                    '✓ Follow the on-screen instructions to complete payment\n',
                    style: TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount: UGX ${CurrencyFormatter.format(_reservationFee)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phone: ${_phoneController.text}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Waiting for payment confirmation...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelPayment();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Start polling for payment status
    _pollPaymentStatus(
      transactionRef,
      maxAttempts: 60,
    ); // Poll for up to 5 minutes
  }

  /// Poll Nylon Pay to check payment status
  Future<void> _pollPaymentStatus(
    String transactionRef, {
    int maxAttempts = 60,
    int attemptNumber = 0,
    int missingTransactionCount = 0,
  }) async {
    if (attemptNumber >= maxAttempts) {
      if (mounted) {
        Navigator.pop(context); // Close status dialog

        _showPaymentMessage(
          'We could not confirm the payment in time. Please try again if it did not complete on your phone.',
        );
      }
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    try {
      // Wait 5 seconds before first check, then check every 5 seconds
      await Future.delayed(const Duration(seconds: 5));

      if (!mounted) return;

      // Check payment status
      final statusResponse = await _nylonService.checkPaymentStatus(
        transactionRef: transactionRef,
      );

      if (!mounted) return;

      if (statusResponse.success) {
        // Payment completed!
        Navigator.pop(context); // Close status dialog

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Payment received. We are creating your reservation now.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Create reservation with paid status
        _submitReservationAfterPayment(transactionRef);
      } else if (statusResponse.status.toLowerCase() == 'failed' ||
          statusResponse.status.toLowerCase() == 'cancelled' ||
          statusResponse.status.toLowerCase() == 'expired') {
        // Payment failed
        Navigator.pop(context); // Close status dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusResponse.message),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isProcessing = false;
        });
      } else {
        // Still processing - poll again
        _pollPaymentStatus(
          transactionRef,
          maxAttempts: maxAttempts,
          attemptNumber: attemptNumber + 1,
          missingTransactionCount: 0,
        );
      }
    } on PaymentException catch (e) {
      debugPrint('Error checking payment status: ${e.message}');

      if (_isMissingPaymentTransactionMessage(e.message)) {
        final nextMissingTransactionCount = missingTransactionCount + 1;
        if (nextMissingTransactionCount >= 4) {
          if (mounted) {
            Navigator.pop(context);
            _showPaymentMessage(
              'We could not confirm the payment request with the provider. If no prompt reached your phone, please confirm the number and try again.',
              backgroundColor: Colors.red,
            );
          }
          setState(() {
            _isProcessing = false;
            _currentTransactionId = null;
          });
          return;
        }

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _pollPaymentStatus(
            transactionRef,
            maxAttempts: maxAttempts,
            attemptNumber: attemptNumber + 1,
            missingTransactionCount: nextMissingTransactionCount,
          );
        }
        return;
      }

      // Continue polling on temporary status errors.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _pollPaymentStatus(
          transactionRef,
          maxAttempts: maxAttempts,
          attemptNumber: attemptNumber + 1,
          missingTransactionCount: 0,
        );
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');

      // Continue polling on error (network might be temporarily down)
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _pollPaymentStatus(
          transactionRef,
          maxAttempts: maxAttempts,
          attemptNumber: attemptNumber + 1,
          missingTransactionCount: 0,
        );
      }
    }
  }

  /// Cancel the payment
  Future<void> _cancelPayment() async {
    if (_currentTransactionId != null) {
      try {
        await _nylonService.cancelPayment(
          transactionRef: _currentTransactionId!,
        );
      } catch (e) {
        debugPrint('Error cancelling payment: $e');
      }
    }

    setState(() {
      _isProcessing = false;
      _currentTransactionId = null;
    });
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'You need to log in or create an account before placing a reservation.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                this.context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              );
            },
            child: const Text('Create Account'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                this.context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReservationAfterPayment(String transactionId) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show processing dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating reservation...'),
            ],
          ),
        ),
      );

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;

      // Book the room (decreases available count)
      await _availabilityService.bookRoom(
        propertyId: widget.property.id,
        roomTypeName: widget.roomType.name,
      );

      // Create reservation with paid status
      final reservation = ReservationModel(
        id: '', // Will be set by Firestore
        propertyId: widget.property.id,
        propertyTitle: widget.property.title,
        university: widget.property.university ?? '',
        roomTypeName: widget.roomType.name,
        roomPrice: widget.roomType.price,
        pricingPeriod: widget.roomType.pricingPeriod.name,
        studentName: _nameController.text.trim(),
        studentPhone: _phoneController.text.trim(),
        studentEmail: _emailController.text.trim(),
        studentUserId: currentUser?.uid,
        reservationFee: _reservationFee,
        paymentStatus: 'paid', // Payment successful!
        paymentReference: _currentTransactionId ?? '',
        paymentTransactionId: transactionId,
        paymentDate: DateTime.now(),
        hostelManagerName: widget.property.agentName.trim().isNotEmpty
            ? widget.property.agentName
            : 'Hostel Manager',
        hostelManagerPhone: widget.property.contactPhone,
        hostelManagerEmail: widget.property.contactEmail.isNotEmpty
            ? widget.property.contactEmail
            : null,
        hostelPaymentInstructions: widget.property.paymentInstructions,
        status: ReservationStatus.confirmed,
        createdAt: DateTime.now(),
      );

      // Save reservation to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('reservations')
          .add(reservation.toMap());

      // Store custodian notification for follow-up
      try {
        await FirebaseFirestore.instance
            .collection('custodian_booking_notifications')
            .add({
              'reservationId': docRef.id,
              'propertyId': widget.property.id,
              'propertyTitle': widget.property.title,
              'roomTypeName': widget.roomType.name,
              'studentName': _nameController.text.trim(),
              'studentPhone': _phoneController.text.trim(),
              'studentEmail': _emailController.text.trim(),
              'custodianName': widget.property.agentName.trim().isNotEmpty
                  ? widget.property.agentName.trim()
                  : 'Hostel Manager',
              'custodianPhone': widget.property.contactPhone.trim(),
              'custodianEmail': widget.property.contactEmail.trim(),
              'studentUserId': currentUser!.uid,
              'paymentStatus': 'paid',
              'transactionId': transactionId,
              'status': 'confirmed',
              'createdAt': Timestamp.fromDate(DateTime.now()),
            });
      } catch (notificationError) {
        debugPrint(
          'Custodian notification error for reservation ${docRef.id}: $notificationError',
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      // Navigate to confirmation screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReservationConfirmationScreen(
            reservation: reservation.copyWith(id: docRef.id),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      setState(() {
        _isProcessing = false;
      });

      // Try to restore room count on failure
      try {
        await _availabilityService.cancelBooking(
          propertyId: widget.property.id,
          roomTypeName: widget.roomType.name,
        );
      } catch (restoreError) {
        debugPrint('Failed to restore room count: $restoreError');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Your payment was received, but we could not finish the reservation right now. Please try again or contact support if this keeps happening.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reserve Room'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hostel Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.property.university ?? '',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _getRoomTypeIcon(widget.roomType.name),
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.roomType.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.property.type == PropertyType.hostel &&
                                          !widget.property.showPriceToCustomers
                                      ? 'Price on request'
                                      : 'UGX ${CurrencyFormatter.format(widget.roomType.price)} / ${widget.roomType.pricingPeriod.name}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
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

              // Room Availability Status
              if (_isCheckingAvailability)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Checking room availability...',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                )
              else if (!_roomAvailable)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Sorry, this room type is currently fully booked.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'This room type is available for booking!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Student Information Section
              const Text(
                'Your Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                readOnly: FirebaseAuth.instance.currentUser != null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Field with toggle
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number for Payment *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  hintText: '+2567XXXXXXXX',
                  helperText:
                      'Enter the mobile money number in the format +2567XXXXXXXX.',
                ),
                readOnly: false,
                keyboardType: TextInputType.phone,
                onChanged: (value) {
                  final normalized = _normalizePaymentPhoneForInput(value);
                  if (normalized == value) return;
                  _phoneController.value = TextEditingValue(
                    text: normalized,
                    selection: TextSelection.collapsed(
                      offset: normalized.length,
                    ),
                  );
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (!_isValidPaymentPhoneNumber(value.trim())) {
                    return 'Use +2567XXXXXXXX with no spaces';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                readOnly: FirebaseAuth.instance.currentUser != null,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  // Only validate format if email is provided
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      !value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Processing Fee Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Processing Fee',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A one-time processing fee of UGX 20,000 is required to connect you to the Hostel managers for confirmation of hostel and room details.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: UGX ${CurrencyFormatter.format(_reservationFee)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Reserve Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      (_isProcessing ||
                          _isCheckingAvailability ||
                          !_roomAvailable)
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _showPaymentDialog();
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.payment),
                  label: Text(
                    _isCheckingAvailability
                        ? 'Checking availability...'
                        : !_roomAvailable
                        ? 'Room Not Available'
                        : _isProcessing
                        ? 'Processing...'
                        : 'Proceed to Payment',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    minimumSize: const Size(double.infinity, 56),
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRoomTypeIcon(String roomName) {
    final lowerName = roomName.toLowerCase();
    if (lowerName.contains('single')) {
      return Icons.person;
    } else if (lowerName.contains('double')) {
      return Icons.people;
    } else if (lowerName.contains('triple')) {
      return Icons.group;
    } else if (lowerName.contains('shared')) {
      return Icons.groups;
    }
    return Icons.bed;
  }
}
