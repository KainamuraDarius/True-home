import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../models/reservation_model.dart';
import '../../services/room_availability_service.dart';
import '../../services/mtn_momo_service.dart';
import '../../services/airtel_money_service.dart';
import '../../utils/app_theme.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final RoomAvailabilityService _availabilityService =
      RoomAvailabilityService();
  final MTNMoMoService _momoService = MTNMoMoService();
  final AirtelMoneyService _airtelService = AirtelMoneyService();

  bool _isProcessing = false;
  final double _reservationFee = 20000; // UGX
  bool _isCheckingAvailability = true;
  bool _roomAvailable = false;
  String? _paymentReferenceId;

  @override
  void initState() {
    super.initState();
    _checkRoomAvailability();
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // MTN Mobile Money Option
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showProviderPaymentDialog('MTN');
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.yellow.shade700, Colors.yellow.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/mtn_logo.png',
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.payment,
                        color: Colors.black,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MTN Mobile Money',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'Pay with MTN MoMo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.black),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Airtel Money Option
            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showProviderPaymentDialog('Airtel');
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade700, Colors.red.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Airtel Money',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Pay with Airtel Money',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showProviderPaymentDialog(String provider) {
    final isAirtel = provider == 'Airtel';
    final primaryColor = isAirtel
        ? Colors.red.shade700
        : Colors.yellow.shade700;
    final textColor = isAirtel ? Colors.white : Colors.black;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                if (isAirtel)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  Image.asset(
                    'assets/mtn_logo.png',
                    height: 30,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.payment, color: Colors.yellow),
                  ),
                const SizedBox(width: 12),
                Text('$provider Mobile Money'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Reservation Fee',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'UGX ${CurrencyFormatter.format(_reservationFee)}',
                        style: TextStyle(
                          fontSize: 28,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How it works:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildPaymentStep(
                  '1',
                  'You\'ll receive a payment request on your phone',
                  primaryColor,
                ),
                _buildPaymentStep(
                  '2',
                  'Enter your Mobile Money PIN',
                  primaryColor,
                ),
                _buildPaymentStep('3', 'Confirm the payment', primaryColor),
                _buildPaymentStep(
                  '4',
                  'Your reservation will be confirmed automatically',
                  primaryColor,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Make sure your phone number is registered with $provider Mobile Money',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  if (isAirtel) {
                    await _initiateAirtelPayment();
                  } else {
                    await _initiateMTNPayment();
                  }
                },
                icon: const Icon(Icons.payment),
                label: const Text('Pay Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentStep(String number, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color == Colors.red.shade700
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Future<void> _initiateMTNPayment() async {
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
              Text('Initiating payment...'),
              SizedBox(height: 8),
              Text(
                'Please wait',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Initiate MTN MoMo payment
      final phoneNumber = _phoneController.text.trim();
      final result = await _momoService.requestToPay(
        amount: _reservationFee.toStringAsFixed(0),
        currency: 'UGX',
        phoneNumber: phoneNumber,
        payerMessage: 'Hostel reservation fee',
        payeeNote:
            'Reservation for ${widget.property.title} - ${widget.roomType.name}',
      );

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (result != null && result['success'] == true) {
        _paymentReferenceId = result['referenceId'];

        // Show payment pending dialog
        _showPaymentPendingDialog(result['referenceId']);
      } else {
        // Payment initiation failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result?['message'] ?? 'Failed to initiate payment'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );

      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showPaymentPendingDialog(String referenceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 64, color: Colors.yellow.shade700),
            const SizedBox(height: 16),
            const Text(
              'Check your phone!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'A payment request has been sent to your MTN Mobile Money account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Please enter your PIN to approve the payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Waiting for confirmation...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkPaymentAndComplete(referenceId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow.shade700,
              foregroundColor: Colors.black,
            ),
            child: const Text('I\'ve Paid'),
          ),
        ],
      ),
    );

    // Auto-check payment status after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _paymentReferenceId == referenceId) {
        Navigator.pop(context);
        _checkPaymentAndComplete(referenceId);
      }
    });
  }

  Future<void> _checkPaymentAndComplete(String referenceId) async {
    if (!mounted) return;

    // Show checking status dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verifying payment...'),
          ],
        ),
      ),
    );

    try {
      // Check payment status
      final status = await _momoService.checkPaymentStatus(referenceId);

      if (!mounted) return;
      Navigator.pop(context); // Close checking dialog

      if (status?['status'] == 'SUCCESSFUL') {
        // Payment successful - complete reservation
        await _completeReservation(
          referenceId: referenceId,
          transactionId: status?['financialTransactionId'] ?? 'UNKNOWN',
        );
      } else if (status?['status'] == 'PENDING') {
        // Still pending
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment is still processing. Please check again in a moment.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );

        // Try again after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _checkPaymentAndComplete(referenceId);
          }
        });
      } else {
        // Payment failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment ${status?['status']?.toLowerCase() ?? 'failed'}. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking payment: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _initiateAirtelPayment() async {
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
              Text('Initiating Airtel Money payment...'),
              SizedBox(height: 8),
              Text(
                'Please wait',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

      // Initiate Airtel Money payment
      final phoneNumber = _phoneController.text.trim();
      final merchantTxId = 'AM${DateTime.now().millisecondsSinceEpoch}';

      final result = await _airtelService.requestToPay(
        amount: _reservationFee.toStringAsFixed(0),
        currency: 'UGX',
        phoneNumber: phoneNumber,
        description: 'Hostel reservation fee for ${widget.property.title}',
        merchantTransactionId: merchantTxId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (result != null && result['success'] == true) {
        _paymentReferenceId = result['referenceId'];

        // Show payment pending dialog for Airtel
        _showAirtelPaymentPendingDialog(
          result['referenceId'],
          result['transactionId'],
        );
      } else {
        // Payment initiation failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['message'] ?? 'Failed to initiate Airtel Money payment',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );

      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showAirtelPaymentPendingDialog(
    String referenceId,
    String transactionId,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 64, color: Colors.red.shade700),
            const SizedBox(height: 16),
            const Text(
              'Check your phone!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'A payment request has been sent to your Airtel Money account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Please enter your PIN to approve the payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Waiting for confirmation...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkAirtelPaymentAndComplete(transactionId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('I\'ve Paid'),
          ),
        ],
      ),
    );

    // Auto-check payment status after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _paymentReferenceId == referenceId) {
        Navigator.pop(context);
        _checkAirtelPaymentAndComplete(transactionId);
      }
    });
  }

  Future<void> _checkAirtelPaymentAndComplete(String transactionId) async {
    if (!mounted) return;

    // Show checking status dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking payment status...'),
          ],
        ),
      ),
    );

    try {
      // Check payment status
      final status = await _airtelService.checkPaymentStatus(transactionId);

      if (!mounted) return;
      Navigator.pop(context); // Close checking dialog

      if (status != null && status['success'] == true) {
        // Payment successful - complete reservation
        await _completeReservation(
          referenceId: transactionId,
          transactionId: transactionId,
        );
      } else {
        // Payment not yet confirmed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status?['message'] ??
                  'Payment not confirmed yet. Please try again.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking status: $e')));

      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeReservation({
    required String referenceId,
    required String transactionId,
  }) async {
    try {
      // Get current user if logged in
      final currentUser = FirebaseAuth.instance.currentUser;

      // Book the room first (this decreases available count)
      await _availabilityService.bookRoom(
        propertyId: widget.property.id,
        roomTypeName: widget.roomType.name,
      );

      // Create reservation with confirmed payment
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
        paymentStatus: 'paid',
        paymentReference: referenceId,
        paymentTransactionId: transactionId,
        paymentDate: DateTime.now(),
        hostelManagerName: widget.property.contactPhone.isNotEmpty
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

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('reservations')
          .add(reservation.toMap());

      // Navigate to confirmation screen
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReservationConfirmationScreen(
            reservation: reservation.copyWith(id: docRef.id),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      // If booking failed, try to restore the room count
      try {
        await _availabilityService.cancelBooking(
          propertyId: widget.property.id,
          roomTypeName: widget.roomType.name,
        );
      } catch (restoreError) {
        debugPrint('Failed to restore room count: $restoreError');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing reservation: $e'),
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
                        const Icon(
                          Icons.school,
                          size: 16,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.property.university ?? '',
                            style: TextStyle(
                              color: Colors.purple.shade700,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getRoomTypeIcon(widget.roomType.name),
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.roomType.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'UGX ${CurrencyFormatter.format(widget.roomType.price)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '/${widget.roomType.pricingPeriod.name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  hintText: '+256...',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.trim().length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Reservation Fee Info
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
                          'Reservation Fee',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A one-time reservation fee of UGX 20,000 is required to secure your booking and connect you to the Hostel managers for confirmation of hostel and room details.',
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
