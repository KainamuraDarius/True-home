import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../models/reservation_model.dart';
import '../../services/room_availability_service.dart';
import '../../services/pandora_payments_service.dart';
import '../../config/api_keys.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final RoomAvailabilityService _availabilityService = RoomAvailabilityService();
  final PandoraPaymentsService _pandoraService = PandoraPaymentsService();

  bool _isProcessing = false;
  final double _reservationFee = 20000; // UGX
  bool _isCheckingAvailability = true;
  bool _roomAvailable = false;

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

  /// Returns 'MTN', 'Airtel', or '' based on the Ugandan phone number prefix.
  String _detectNetwork(String number) {
    final cleaned = number.replaceAll(RegExp(r'[\s\-\+]'), '');
    String prefix;
    if (cleaned.startsWith('256') && cleaned.length >= 5) {
      prefix = cleaned.substring(3, 5);
    } else if (cleaned.startsWith('0') && cleaned.length >= 3) {
      prefix = cleaned.substring(1, 3);
    } else if (cleaned.length >= 2) {
      prefix = cleaned.substring(0, 2);
    } else {
      return '';
    }
    const mtnPrefixes = ['76', '77', '78', '39'];
    const airtelPrefixes = ['70', '75', '74'];
    if (mtnPrefixes.contains(prefix)) return 'MTN';
    if (airtelPrefixes.contains(prefix)) return 'Airtel';
    return '';
  }

  void _showPaymentBottomSheet() {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    final momoController = TextEditingController(
      // Pre-fill with student's phone if already entered
      text: _phoneController.text.trim(),
    );
    final sheetFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final network = _detectNetwork(momoController.text);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: sheetFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.smartphone, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mobile Money Payment',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'MTN or Airtel accepted',
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Amount box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Reservation Fee',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'UGX ${CurrencyFormatter.format(_reservationFee)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mobile money number
                      TextFormField(
                        controller: momoController,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Mobile Money Number *',
                          hintText: '07XXXXXXXX or 256XXXXXXXXX',
                          prefixIcon: const Icon(Icons.phone_android),
                          border: const OutlineInputBorder(),
                          suffixIcon: network.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: network == 'MTN'
                                          ? Colors.yellow.shade700
                                          : Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      network,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your mobile money number';
                          }
                          final formatted = PandoraPaymentsService.formatNumber(
                            value.trim(),
                          );
                          if (formatted.length != 12 ||
                              !formatted.startsWith('256')) {
                            return 'Enter a valid Ugandan number (e.g. 0771234567)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A prompt will be sent to this number to approve the payment.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),

                      // Pay button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (sheetFormKey.currentState!.validate()) {
                              Navigator.pop(ctx);
                              _initiatePayment(
                                PandoraPaymentsService.formatNumber(
                                  momoController.text.trim(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.lock),
                          label: Text(
                            'Pay UGX ${CurrencyFormatter.format(_reservationFee)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Secured by PandoraPayments',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _initiatePayment(String formattedMomoNumber) async {
    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    // Show "processing" dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initiating payment...'),
          ],
        ),
      ),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser!;

      // Step 1: Reserve the room slot
      await _availabilityService.bookRoom(
        propertyId: widget.property.id,
        roomTypeName: widget.roomType.name,
      );

      // Step 2: Create Firestore reservation doc (status: 'processing')
      final reservationRef =
          FirebaseFirestore.instance.collection('reservations').doc();
      final reservation = ReservationModel(
        id: reservationRef.id,
        propertyId: widget.property.id,
        propertyTitle: widget.property.title,
        university: widget.property.university ?? '',
        roomTypeName: widget.roomType.name,
        roomPrice: widget.roomType.price,
        pricingPeriod: widget.roomType.pricingPeriod.name,
        studentName: _nameController.text.trim(),
        studentPhone: _phoneController.text.trim(),
        studentEmail: _emailController.text.trim(),
        studentUserId: currentUser.uid,
        reservationFee: _reservationFee,
        paymentStatus: 'processing',
        paymentReference: 'PANDORA_${reservationRef.id}',
        paymentTransactionId: null,
        paymentDate: null,
        hostelManagerName: widget.property.agentName.trim().isNotEmpty
            ? widget.property.agentName
            : 'Hostel Manager',
        hostelManagerPhone: widget.property.contactPhone,
        hostelManagerEmail: widget.property.contactEmail.isNotEmpty
            ? widget.property.contactEmail
            : null,
        hostelPaymentInstructions: widget.property.paymentInstructions,
        status: ReservationStatus.pending,
        createdAt: DateTime.now(),
      );
      await reservationRef.set(reservation.toMap());

      // Step 3: Call PandoraPayments API
      final result = await _pandoraService.initiatePayment(
        amount: _reservationFee,
        transactionRef: reservationRef.id,
        contact: formattedMomoNumber,
        narrative: 'TrueHome hostel reservation - ${widget.property.title}',
        callbackUrl: ApiKeys.pandoraCallbackUrl,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (result.success) {
        // Step 4: Update reservation with transaction ID
        await reservationRef.update({
          'paymentTransactionId': result.transactionReference,
          'paymentNetwork': result.network,
        });

        // Step 5: Write custodian notification
        try {
          await FirebaseFirestore.instance
              .collection('custodian_booking_notifications')
              .add({
            'reservationId': reservationRef.id,
            'propertyId': widget.property.id,
            'propertyTitle': widget.property.title,
            'roomTypeName': widget.roomType.name,
            'studentName': _nameController.text.trim(),
            'studentPhone': _phoneController.text.trim(),
            'studentEmail': _emailController.text.trim(),
            'custodianName': widget.property.agentName.trim().isNotEmpty
                ? widget.property.agentName.trim()
                : 'Hostel Custodian',
            'custodianPhone': widget.property.contactPhone.trim(),
            'custodianEmail': widget.property.contactEmail.trim(),
            'studentUserId': currentUser.uid,
            'status': 'pending_follow_up',
            'createdAt': Timestamp.fromDate(DateTime.now()),
          });
        } catch (e) {
          debugPrint('Custodian notification failed: $e');
        }

        // Step 6: Navigate to confirmation (real-time listener there)
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReservationConfirmationScreen(
              reservation: reservation.copyWith(
                paymentTransactionId: result.transactionReference,
              ),
            ),
          ),
        );
      } else {
        // Payment initiation failed — mark reservation failed and restore room
        await reservationRef.update({'paymentStatus': 'failed'});
        await _availabilityService.cancelBooking(
          propertyId: widget.property.id,
          roomTypeName: widget.roomType.name,
        );
        setState(() => _isProcessing = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Payment could not be initiated. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close dialog if still open
      setState(() => _isProcessing = false);

      try {
        await _availabilityService.cancelBooking(
          propertyId: widget.property.id,
          roomTypeName: widget.roomType.name,
        );
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                  labelText: 'Email Address (Optional)',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
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
                            _showPaymentBottomSheet();
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
