import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/reservation_model.dart';
import '../../services/room_availability_service.dart';
import '../../utils/app_theme.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  String _selectedFilter = 'all'; // all, confirmed, pending, cancelled
  final RoomAvailabilityService _availabilityService = RoomAvailabilityService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Reservations'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Confirmed', 'confirmed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cancelled', 'cancelled'),
                ],
              ),
            ),
          ),
          
          // Reservations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReservationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reservations found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final reservations = snapshot.data!.docs
                    .map((doc) => ReservationModel.fromMap(
                          doc.data() as Map<String, dynamic>,
                          doc.id,
                        ))
                    .toList();

                // Sort by creation date (newest first)
                reservations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    return _buildReservationCard(reservations[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.orange.shade300,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Stream<QuerySnapshot> _getReservationsStream() {
    // Avoid composite index requirement by not combining where + orderBy
    // Sorting will be done in memory after fetching
    if (_selectedFilter == 'all') {
      // When showing all, we can use orderBy
      return FirebaseFirestore.instance
          .collection('reservations')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // When filtering by status, skip orderBy to avoid composite index
      return FirebaseFirestore.instance
          .collection('reservations')
          .where('status', isEqualTo: _selectedFilter)
          .snapshots();
    }
  }

  Widget _buildReservationCard(ReservationModel reservation) {
    final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showReservationDetails(reservation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      reservation.propertyTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadge(reservation.status),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // University
              Row(
                children: [
                  const Icon(Icons.school, size: 16, color: Colors.purple),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reservation.university,
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              
              // Student Info
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Phone
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    reservation.studentPhone,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Email
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.studentEmail,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              
              // Room Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bed, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          reservation.roomTypeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'UGX ${CurrencyFormatter.format(reservation.roomPrice)}/${reservation.pricingPeriod}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Payment Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        reservation.paymentStatus == 'paid'
                            ? Icons.check_circle
                            : Icons.pending,
                        size: 16,
                        color: reservation.paymentStatus == 'paid'
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reservation Fee: UGX ${CurrencyFormatter.format(reservation.reservationFee)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Date
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(reservation.createdAt),
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
      ),
    );
  }

  Widget _buildStatusBadge(ReservationStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case ReservationStatus.confirmed:
        color = Colors.green;
        text = 'Confirmed';
        break;
      case ReservationStatus.pending:
        color = Colors.orange;
        text = 'Pending';
        break;
      case ReservationStatus.cancelled:
        color = Colors.red;
        text = 'Cancelled';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReservationDetails(ReservationModel reservation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Reservation Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildDetailRow('Hostel', reservation.propertyTitle),
              _buildDetailRow('University', reservation.university),
              _buildDetailRow('Room Type', reservation.roomTypeName),
              _buildDetailRow(
                'Room Price',
                'UGX ${CurrencyFormatter.format(reservation.roomPrice)}/${reservation.pricingPeriod}',
              ),
              
              const Divider(height: 32),
              
              const Text(
                'Student Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildDetailRow('Name', reservation.studentName),
              _buildDetailRow('Phone', reservation.studentPhone),
              _buildDetailRow('Email', reservation.studentEmail),
              
              const Divider(height: 32),
              
              const Text(
                'Payment Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildDetailRow(
                'Reservation Fee',
                'UGX ${CurrencyFormatter.format(reservation.reservationFee)}',
              ),
              _buildDetailRow(
                'Payment Status',
                reservation.paymentStatus.toUpperCase(),
                valueColor: reservation.paymentStatus == 'paid'
                    ? Colors.green
                    : Colors.orange,
              ),
              if (reservation.paymentReference != null)
                _buildDetailRow(
                  'Reference',
                  reservation.paymentReference!,
                ),
              
              if (reservation.paymentDate != null)
                _buildDetailRow(
                  'Payment Date',
                  DateFormat('MMM dd, yyyy - HH:mm').format(reservation.paymentDate!),
                ),
              
              const Divider(height: 32),
              
              const Text(
                'Hostel Contact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildDetailRow('Manager', reservation.hostelManagerName),
              _buildDetailRow('Phone', reservation.hostelManagerPhone),
              if (reservation.hostelManagerEmail != null)
                _buildDetailRow('Email', reservation.hostelManagerEmail!),
              
              if (reservation.hostelPaymentInstructions != null &&
                  reservation.hostelPaymentInstructions!.isNotEmpty) ...[
                const Divider(height: 32),
                const Text(
                  'Payment Instructions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(reservation.hostelPaymentInstructions!),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callStudent(reservation.studentPhone),
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Student'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _emailStudent(
                        reservation.studentEmail,
                        reservation.studentName,
                        reservation.propertyTitle,
                      ),
                      icon: const Icon(Icons.email),
                      label: const Text('Email Student'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Status Update Buttons (only show for pending reservations)
              if (reservation.status == ReservationStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateReservationStatus(
                          reservation,
                          ReservationStatus.confirmed,
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateReservationStatus(
                          reservation,
                          ReservationStatus.cancelled,
                        ),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callStudent(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open phone dialer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _emailStudent(String email, String studentName, String hostelName) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Regarding Your Hostel Reservation - $hostelName',
        'body': 'Dear $studentName,\n\nThank you for your reservation at $hostelName.\n\nBest regards,\nTrueHome Team',
      },
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open email app'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateReservationStatus(
    ReservationModel reservation,
    ReservationStatus newStatus,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          newStatus == ReservationStatus.confirmed
              ? 'Confirm Reservation'
              : 'Cancel Reservation',
        ),
        content: Text(
          newStatus == ReservationStatus.confirmed
              ? 'Are you sure you want to confirm this reservation?'
              : 'Are you sure you want to cancel this reservation? This will restore the room availability.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == ReservationStatus.confirmed
                  ? Colors.green
                  : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // If cancelling, restore room availability
      if (newStatus == ReservationStatus.cancelled) {
        await _availabilityService.cancelBooking(
          propertyId: reservation.propertyId,
          roomTypeName: reservation.roomTypeName,
        );
      }

      // Update reservation status in Firestore
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservation.id)
          .update({
        'status': newStatus.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      });

      if (!mounted) return;
      
      // Close the bottom sheet
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == ReservationStatus.confirmed
                ? 'Reservation confirmed successfully'
                : 'Reservation cancelled and room availability restored',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating reservation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
