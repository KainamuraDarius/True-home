import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/property_model.dart';
import '../../utils/app_theme.dart';
import 'edit_property_screen.dart';

class AgentPropertyDetailsScreen extends StatefulWidget {
  final PropertyModel property;

  const AgentPropertyDetailsScreen({super.key, required this.property});

  @override
  State<AgentPropertyDetailsScreen> createState() => _AgentPropertyDetailsScreenState();
}

class _AgentPropertyDetailsScreenState extends State<AgentPropertyDetailsScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Details'),
        backgroundColor: AppColors.primary,
        actions: [
          // Edit button - only show for pending properties
          if (widget.property.status == PropertyStatus.pending)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Property',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPropertyScreen(property: widget.property),
                  ),
                ).then((_) {
                  // Refresh if needed after edit
                  if (mounted) {
                    Navigator.pop(context);
                  }
                });
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Gallery
            if (widget.property.imageUrls.isNotEmpty) ...[
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: widget.property.imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.property.imageUrls[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, size: 50),
                            );
                          },
                        );
                      },
                    ),
                    // Image indicator
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${widget.property.imageUrls.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.property.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.property.status.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.property.type == PropertyType.sale
                              ? 'For Sale'
                              : 'For Rent',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Status Message for Approved/Rejected
                  if (widget.property.status != PropertyStatus.pending)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: widget.property.status == PropertyStatus.approved
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.property.status == PropertyStatus.approved
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                widget.property.status == PropertyStatus.approved
                                    ? Icons.check_circle
                                    : Icons.info,
                                color: widget.property.status == PropertyStatus.approved
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.property.status == PropertyStatus.approved
                                      ? 'Property Approved'
                                      : 'Editing Disabled',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: widget.property.status == PropertyStatus.approved
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.property.status == PropertyStatus.approved
                                ? 'This property is approved and visible to customers. To make changes, please contact the admin.'
                                : 'This property cannot be edited. Please contact the admin for assistance.',
                            style: TextStyle(
                              color: widget.property.status == PropertyStatus.approved
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _contactAdmin(),
                            icon: const Icon(Icons.support_agent),
                            label: const Text('Contact Admin'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Rejection Reason
                  if (widget.property.status == PropertyStatus.rejected &&
                      widget.property.rejectionReason != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.cancel, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Rejection Reason',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.property.rejectionReason!,
                            style: TextStyle(color: Colors.red[800]),
                          ),
                        ],
                      ),
                    ),

                  // Title
                  Text(
                    widget.property.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Text(
                    'UGX ${CurrencyFormatter.format(widget.property.price)}${widget.property.type == PropertyType.rent ? '/month' : widget.property.type == PropertyType.hostel ? '/semester' : ''}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.property.location,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Address
                  Row(
                    children: [
                      const Icon(Icons.home, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.property.address,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Property Details
                  const Text(
                    'Property Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailItem(Icons.bed, '${widget.property.bedrooms}', 'Bedrooms'),
                      _buildDetailItem(Icons.bathroom, '${widget.property.bathrooms}', 'Bathrooms'),
                      _buildDetailItem(Icons.square_foot, '${widget.property.areaSqft.toInt()}', 'sqft'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.property.description,
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Amenities
                  if (widget.property.amenities.isNotEmpty) ...[
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.property.amenities.map((amenity) {
                        return Chip(
                          label: Text(amenity),
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          labelStyle: const TextStyle(color: AppColors.primary),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Contact Information
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (widget.property.contactPhone.isNotEmpty)
                    _buildContactInfo(Icons.phone, 'Phone', widget.property.contactPhone),
                  if (widget.property.whatsappPhone.isNotEmpty)
                    _buildContactInfo(Icons.chat, 'WhatsApp', widget.property.whatsappPhone),
                  if (widget.property.contactEmail.isNotEmpty)
                    _buildContactInfo(Icons.email, 'Email', widget.property.contactEmail),
                  if (widget.property.companyName.isNotEmpty)
                    _buildContactInfo(Icons.business, 'Company', widget.property.companyName),
                  if (widget.property.agentName.isNotEmpty)
                    _buildContactInfo(Icons.person, 'Agent', widget.property.agentName),

                  const SizedBox(height: 24),

                  // Dates
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Created: ${_formatDate(widget.property.createdAt)}',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.update, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Updated: ${_formatDate(widget.property.updatedAt)}',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
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
    );
  }

  Widget _buildDetailItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 32, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildContactInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.pending:
        return Colors.orange;
      case PropertyStatus.approved:
        return Colors.green;
      case PropertyStatus.rejected:
        return Colors.red;
      case PropertyStatus.removed:
        return Colors.grey;
    }
  }

  Future<void> _contactAdmin() async {
    // You can customize this to your admin contact details
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'admin@truehome.com',
      query: 'subject=Property ${widget.property.id} - ${widget.property.title}&body=Hello Admin,%0D%0A%0D%0AI need assistance with my property (ID: ${widget.property.id}).%0D%0A%0D%0AProperty: ${widget.property.title}%0D%0AStatus: ${widget.property.status.name}%0D%0A%0D%0APlease help me with...',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please contact admin at: admin@truehome.com'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please contact admin at: admin@truehome.com'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
