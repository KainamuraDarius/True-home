import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/reservation_model.dart';
import '../../utils/app_theme.dart';

class ReservationConfirmationScreen extends StatelessWidget {
  final ReservationModel reservation;

  const ReservationConfirmationScreen({
    super.key,
    required this.reservation,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPaid = reservation.paymentStatus == 'paid';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isPaid ? 'Reservation Confirmed' : 'Reservation Pending'),
        backgroundColor: isPaid ? Colors.green : Colors.orange,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Success Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid ? Icons.check_circle : Icons.pending,
                size: 60,
                color: isPaid ? Colors.green.shade600 : Colors.orange.shade600,
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              isPaid ? 'Reservation Successful!' : 'Reservation Created!',
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
                    reservation.paymentStatus == 'paid' 
                        ? 'PAYMENT RECEIVED' 
                        : 'PENDING PAYMENT',
                    valueColor: reservation.paymentStatus == 'paid' 
                        ? Colors.green 
                        : Colors.red,
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
                  _buildDetailRow('Admin Phone', '+256702021112'),
                  const SizedBox(height: 12),
                  
                  // Call Admin Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri(scheme: 'tel', path: '+256702021112');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.phone),
                      label: const Text('Contact Admin for Confirmation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
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
                  _buildNextStep('1', 'Contact the hostel manager using the details above'),
                  _buildNextStep('2', 'Arrange a visit to view the room'),
                  _buildNextStep('3', 'Complete any additional payments as instructed'),
                  _buildNextStep('4', 'Sign the rental agreement'),
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
