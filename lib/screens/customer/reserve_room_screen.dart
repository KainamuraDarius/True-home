import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../models/reservation_model.dart';
import '../../services/room_availability_service.dart';
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

  void _showPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Payment Instructions'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions
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
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How to Pay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Dial *165# on your phone\n'
                      '2. Follow the prompts to make payment\n'
                      '3. Pay UGX 20,000 to: 0702021112\n'
                      '4. Account Name: Ssemakula Ramzy Hadah\n'
                      '5. Your reservation will be confirmed',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Reservation Fee Amount
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
                    Text(
                      'Reservation Fee:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade900,
                      ),
                    ),
                    Text(
                      'UGX 20,000',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.property.paymentInstructions != null &&
                  widget.property.paymentInstructions!.isNotEmpty) ...[
                const SizedBox(height: 16),
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
                            Icons.account_balance,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Payment Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.property.paymentInstructions!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              _submitReservation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('I Understand, Reserve Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReservation() async {
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
              Text('Creating reservation...'),
            ],
          ),
        ),
      );

      // Get current user if logged in
      final currentUser = FirebaseAuth.instance.currentUser;

      // Book the room first (this decreases available count)
      await _availabilityService.bookRoom(
        propertyId: widget.property.id,
        roomTypeName: widget.roomType.name,
      );

      // Create reservation with manual payment (to be paid via *165#)
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
        paymentStatus: 'pending', // Payment to be made via *165#
        paymentReference: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
        paymentTransactionId: null,
        paymentDate: null,
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

      // If booking failed, try to restore the room count
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
