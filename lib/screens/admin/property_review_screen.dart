import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';

class PropertyReviewScreen extends StatefulWidget {
  final PropertyModel property;

  const PropertyReviewScreen({super.key, required this.property});

  @override
  State<PropertyReviewScreen> createState() => _PropertyReviewScreenState();
}

class _PropertyReviewScreenState extends State<PropertyReviewScreen> {
  final _rejectionReasonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _whatsappPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  bool _isLoading = false;
  int _currentImageIndex = 0;
  
  // Promotion management
  bool _markAsNewProject = false;
  bool _enablePromotion = false;
  DateTime? _promotionEndDate;

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    _contactPhoneController.dispose();
    _whatsappPhoneController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _updatePropertyStatus(PropertyStatus status, {
    String? reason, 
    String? contactPhone, 
    String? whatsappPhone, 
    String? contactEmail,
    bool? isNewProject,
    bool? hasActivePromotion,
    DateTime? promotionEndDate,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updateData = {
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
        if (reason != null) 'rejectionReason': reason,
        if (contactPhone != null) 'contactPhone': contactPhone,
        if (whatsappPhone != null) 'whatsappPhone': whatsappPhone,
        if (contactEmail != null) 'contactEmail': contactEmail,
        if (isNewProject != null) 'isNewProject': isNewProject,
        if (hasActivePromotion != null) 'hasActivePromotion': hasActivePromotion,
        if (promotionEndDate != null) 'promotionEndDate': promotionEndDate.toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.property.id)
          .update(updateData);

      // Send notification to property owner/manager
      await _sendNotification(status, reason);

      // If approved, notify all customers about new property
      if (status == PropertyStatus.approved) {
        await _notifyCustomers();
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Property ${status.name} successfully!'),
            backgroundColor: status == PropertyStatus.approved ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendNotification(PropertyStatus status, String? reason) async {
    try {
      final notification = {
        'userId': widget.property.ownerId,
        'title': status == PropertyStatus.approved
            ? 'Property Approved!'
            : 'Property Rejected',
        'message': status == PropertyStatus.approved
            ? 'Your property "${widget.property.title}" has been approved and is now live!'
            : 'Your property "${widget.property.title}" was rejected. Reason: ${reason ?? "No reason provided"}',
        'propertyId': widget.property.id,
        'type': status == PropertyStatus.approved ? 'approval' : 'rejection',
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance.collection('notifications').add(notification);
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _notifyCustomers() async {
    try {
      // Get all customer users
      final customers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();
      
      // Send notification
      for (var customer in customers.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': customer.id,
          'title': 'New Property Available!',
          'message': 'Check out "${widget.property.title}" in ${widget.property.location} - UGX ${CurrencyFormatter.format(widget.property.price)}${widget.property.type == PropertyType.rent ? '/month' : widget.property.type == PropertyType.hostel ? '/semester' : ''}',
          'propertyId': widget.property.id,
          'type': 'new_property',
          'isRead': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error notifying customers: $e');
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Property'),
          content: TextField(
            controller: _rejectionReasonController,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updatePropertyStatus(
                  PropertyStatus.rejected,
                  reason: _rejectionReasonController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  void _showApproveDialog() {
    // Pre-fill with current contact info
    _contactPhoneController.text = widget.property.contactPhone;
    _whatsappPhoneController.text = widget.property.whatsappPhone;
    _contactEmailController.text = widget.property.contactEmail;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve & Publish Property'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fill in the contact details that will be shown to customers:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contactPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone *',
                    border: OutlineInputBorder(),
                    prefixText: '+256 ',
                    hintText: '7XX XXX XXX',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _whatsappPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number *',
                    border: OutlineInputBorder(),
                    prefixText: '+256 ',
                    hintText: '7XX XXX XXX',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contactEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Email *',
                    border: OutlineInputBorder(),
                    hintText: 'contact@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                const Text(
                  '* These contacts will be visible to customers',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Promotion Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Mark as New Project'),
                  subtitle: const Text('Show in "New Projects from Developers" carousel'),
                  value: _markAsNewProject,
                  onChanged: (value) {
                    setState(() {
                      _markAsNewProject = value ?? false;
                      if (!_markAsNewProject) {
                        _enablePromotion = false;
                        _promotionEndDate = null;
                      }
                    });
                  },
                ),
                if (_markAsNewProject) ...[
                  CheckboxListTile(
                    title: const Text('Enable Promotion'),
                    subtitle: const Text('Feature this project in the carousel'),
                    value: _enablePromotion,
                    onChanged: (value) {
                      setState(() {
                        _enablePromotion = value ?? false;
                        if (!_enablePromotion) {
                          _promotionEndDate = null;
                        }
                      });
                    },
                  ),
                  if (_enablePromotion) ...[
                    ListTile(
                      title: const Text('Promotion End Date'),
                      subtitle: Text(
                        _promotionEndDate != null
                            ? 'Ends: ${_promotionEndDate!.day}/${_promotionEndDate!.month}/${_promotionEndDate!.year}'
                            : 'No end date set (runs indefinitely)',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_promotionEndDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _promotionEndDate = null;
                                });
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _promotionEndDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() {
                                  _promotionEndDate = date;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Leave empty for no expiration',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
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
                if (_contactPhoneController.text.trim().isEmpty ||
                    _whatsappPhoneController.text.trim().isEmpty ||
                    _contactEmailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all contact fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _updatePropertyStatus(
                  PropertyStatus.approved,
                  contactPhone: _contactPhoneController.text.trim(),
                  whatsappPhone: _whatsappPhoneController.text.trim(),
                  contactEmail: _contactEmailController.text.trim(),
                  isNewProject: _markAsNewProject,
                  hasActivePromotion: _markAsNewProject && _enablePromotion,
                  promotionEndDate: _enablePromotion ? _promotionEndDate : null,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Approve & Publish'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Property'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Gallery
                  if (widget.property.imageUrls.isNotEmpty)
                    Stack(
                      children: [
                        SizedBox(
                          height: 300,
                          child: PageView.builder(
                            itemCount: widget.property.imageUrls.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final imageUrl = widget.property.imageUrls[index];
                              return Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 64,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${widget.property.imageUrls.length}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Property Details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.property.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.property.type == PropertyType.sale
                                    ? Colors.green
                                    : Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.property.type == PropertyType.sale
                                    ? 'FOR SALE'
                                    : 'FOR RENT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'UGX ${CurrencyFormatter.format(widget.property.price)}${widget.property.type == PropertyType.rent ? '/month' : widget.property.type == PropertyType.hostel ? '/semester' : ''}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.location_on,
                          'Location',
                          widget.property.location,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.home,
                          'Address',
                          widget.property.address,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFeatureCard(
                              Icons.bed,
                              '${widget.property.bedrooms}',
                              'Bedrooms',
                            ),
                            _buildFeatureCard(
                              Icons.bathtub,
                              '${widget.property.bathrooms}',
                              'Bathrooms',
                            ),
                            _buildFeatureCard(
                              Icons.square_foot,
                              '${widget.property.areaSqft.toInt()}',
                              'sq ft',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.property.description,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Owner Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.person,
                          'Name',
                          widget.property.ownerName,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.email,
                          'Email',
                          widget.property.ownerEmail,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.access_time,
                          'Submitted',
                          _formatDate(widget.property.createdAt),
                        ),
                        
                        // Show spotlight promotion request
                        if (widget.property.promotionRequested) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade50, Colors.orange.shade50],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.amber.shade600, Colors.orange.shade600],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spotlight Promotion Requested',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Agent has requested this property to be featured in the Spotlight carousel',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Contact Information (For Customers)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.phone,
                          'Contact Phone',
                          widget.property.contactPhone.isNotEmpty
                              ? widget.property.contactPhone
                              : 'Not set',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.chat,
                          'WhatsApp',
                          widget.property.whatsappPhone.isNotEmpty
                              ? widget.property.whatsappPhone
                              : 'Not set',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.email_outlined,
                          'Contact Email',
                          widget.property.contactEmail.isNotEmpty
                              ? widget.property.contactEmail
                              : 'Not set',
                        ),
                        if (widget.property.status == PropertyStatus.rejected &&
                            widget.property.rejectionReason != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'Rejection Reason',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.property.rejectionReason!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: widget.property.status == PropertyStatus.pending
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showRejectDialog,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showApproveDialog,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
