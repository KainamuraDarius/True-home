import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reservation_model.dart';
import '../../utils/app_theme.dart';

class ReservationConfirmationScreen extends StatefulWidget {
  final ReservationModel reservation;

  const ReservationConfirmationScreen({
    super.key,
    required this.reservation,
  });

  @override
  State<ReservationConfirmationScreen> createState() =>
      _ReservationConfirmationScreenState();
}

class _ReservationConfirmationScreenState
    extends State<ReservationConfirmationScreen> {
  static const String _adminSupportName = 'TrueHome Support Desk';
  static const String _adminSupportPhone = '+256702021112';
  static const String _adminSupportEmail = 'truehome376@gmail.com';

  @override
  Widget build(BuildContext context) {
    // Live-listen to the Firestore reservation doc so payment status
    // updates automatically when PandoraPayments fires the webhook.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id)
          .snapshots(),
      builder: (context, snapshot) {
        // Merge live data with the initial reservation model
        ReservationModel liveReservation = widget.reservation;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          liveReservation = ReservationModel.fromMap(
            data,
            widget.reservation.id,
          );
        }
        return _buildContent(context, liveReservation);
      },
    );
  }

  Widget _buildContent(BuildContext context, ReservationModel reservation) {
    final String paymentStatus = reservation.paymentStatus;
    final bool isPaid = paymentStatus == 'paid';
    final bool isProcessing = paymentStatus == 'processing';
    final bool isFailed =
        paymentStatus == 'failed' ||
        paymentStatus == 'cancelled' ||
        paymentStatus == 'expired';

    Color statusColor = isPaid
        ? Colors.green
        : isProcessing
        ? Colors.blue
        : isFailed
        ? Colors.red
        : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPaid
              ? 'Reservation Confirmed'
              : isProcessing
                  ? 'Awaiting Payment'
                  : isFailed
                      ? 'Payment ${paymentStatus[0].toUpperCase()}${paymentStatus.substring(1)}'
                      : 'Reservation Pending',
        ),
        backgroundColor: statusColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Processing banner
            if (isProcessing) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Waiting for payment confirmation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Check your phone for a mobile money prompt and approve the payment.',
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
              const SizedBox(height: 20),
            ],

            // Status Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid
                    ? Icons.check_circle
                    : isFailed
                        ? Icons.cancel
                        : isProcessing
                            ? Icons.hourglass_top
                            : Icons.pending,
                size: 60,
                color: statusColor,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              isPaid
                  ? 'Reservation Successful!'
                  : isFailed
                      ? 'Payment ${paymentStatus[0].toUpperCase()}${paymentStatus.substring(1)}'
                      : 'Reservation Created!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              isPaid
                  ? 'Your room has been successfully reserved'
                  : isFailed
                      ? 'Your payment could not be completed. Please try again.'
                      : isProcessing
                          ? 'Waiting for mobile money confirmation...'
                          : 'Complete your payment to confirm the reservation',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Reservation Details Card
            Container(
              width: double.infinity,
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
                  const Text(
                    'Reservation Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  
                  _buildDetailRow('Hostel', reservation.propertyTitle),
                  _buildDetailRow('University', reservation.university),
                  _buildDetailRow('Room Type', reservation.roomTypeName),
                  _buildDetailRow(
                    'Room Price',
                    'UGX ${CurrencyFormatter.format(reservation.roomPrice)}/${reservation.pricingPeriod}',
                  ),
                  _buildDetailRow('Student Name', reservation.studentName),
                  _buildDetailRow('Phone', reservation.studentPhone),
                  _buildDetailRow('Email', reservation.studentEmail),
                  
                  const Divider(height: 24),
                  
                  _buildDetailRow(
                    'Reservation Fee',
                    'UGX ${CurrencyFormatter.format(reservation.reservationFee)}',
                  ),
                  _buildDetailRow(
                    'Payment Status',
                    isPaid
                        ? 'PAYMENT RECEIVED'
                        : isProcessing
                            ? 'PROCESSING...'
                            : isFailed
                                ? paymentStatus.toUpperCase()
                                : 'PENDING PAYMENT',
                    valueColor: statusColor,
                    valueBold: true,
                  ),
                  _buildDetailRow(
                    'Payment Reference',
                    reservation.paymentReference ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Date',
                    '${reservation.createdAt.day}/${reservation.createdAt.month}/${reservation.createdAt.year}',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Admin Contact Card
            Container(
              width: double.infinity,
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
                      Icon(Icons.support_agent, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'TrueHome Admin Contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, 
                          color: Colors.blue.shade700,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPaid 
                            ? 'Payment Confirmed! Admin will connect you to the hostel manager. Please keep checking your email or WhatsApp.'
                            : 'Complete your payment of UGX 20,000 to +256702021112 (Ssemakula Ramzy Hadah). Admin will verify and connect you to the hostel manager. Please keep checking your email or WhatsApp.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Admin Contact', _adminSupportName),
                  _buildDetailRow('Admin Phone', _adminSupportPhone),
                  _buildDetailRow('Admin Email', _adminSupportEmail),
                  const SizedBox(height: 12),
                  
                  _buildSupportActions(context),
                  const SizedBox(height: 12),
                  
                  Text(
                    'Note: Contact the above number to confirm your reservation and the confirmation email will be sent to your email or WhatsApp soon.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Custodian Contact Card
            Container(
              width: double.infinity,
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
                      Icon(Icons.apartment_rounded, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Hostel Custodian Contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Custodian', reservation.hostelManagerName),
                  _buildDetailRow('Phone', reservation.hostelManagerPhone),
                  if (reservation.hostelManagerEmail != null &&
                      reservation.hostelManagerEmail!.isNotEmpty)
                    _buildDetailRow('Email', reservation.hostelManagerEmail!),
                  const SizedBox(height: 10),
                  Text(
                    'Booking instructions: Contact the custodian with your reservation details for room allocation and check-in guidance.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri(scheme: 'tel', path: reservation.hostelManagerPhone);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.call),
                          label: const Text('Call Custodian'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final whatsappUrl = _buildWhatsAppUri(
                              reservation.hostelManagerPhone,
                              'Hello ${reservation.hostelManagerName}, I completed a reservation for ${reservation.propertyTitle}. My name is ${reservation.studentName}.',
                            );
                            if (await canLaunchUrl(whatsappUrl)) {
                              await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Payment Instructions (if available)
            if (reservation.hostelPaymentInstructions != null &&
                reservation.hostelPaymentInstructions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
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
                        Icon(Icons.info_outline, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Important Payment Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reservation.hostelPaymentInstructions!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Next Steps
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNextStep('1', 'Contact support if you need help confirming your booking'),
                  _buildNextStep('2', 'Contact the hostel custodian using the details above'),
                  _buildNextStep('3', 'Arrange a room viewing or move-in process'),
                  _buildNextStep('4', 'Complete any remaining hostel payment instructions'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement call functionality
                      // launch('tel:${reservation.hostelManagerPhone}');
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call Manager'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Go Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri(scheme: 'tel', path: _adminSupportPhone);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            icon: const Icon(Icons.phone),
            label: const Text('Call Support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final uri = _buildWhatsAppUri(
                _adminSupportPhone,
                'Hello TrueHome support, I need help with reservation ${widget.reservation.id}.',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Uri _buildWhatsAppUri(String phone, String message) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final normalized = cleaned.startsWith('0') ? '256${cleaned.substring(1)}' : cleaned;
    return Uri.parse('https://wa.me/$normalized?text=${Uri.encodeComponent(message)}');
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
