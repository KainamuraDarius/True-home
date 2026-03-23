import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/property_model.dart';
import '../../services/pandora_payment_service.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';
import '../../widgets/web_footer.dart';
import 'agent_property_details_screen.dart';
import 'add_property_screen.dart';

class MyPropertiesScreen extends StatefulWidget {
  final bool isTabView;

  const MyPropertiesScreen({super.key, this.isTabView = false});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  PropertyStatus? _selectedFilter;
  final PandoraPaymentService _pandoraService = PandoraPaymentService();
  static const double _featuredPromotionPrice = 200000;
  String? _promotingPropertyId;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: widget.isTabView
          ? null
          : AppBar(
              title: const Text('My Properties'),
              backgroundColor: AppColors.primary,
            ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedFilter == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = null;
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending'),
                  selected: _selectedFilter == PropertyStatus.pending,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = PropertyStatus.pending;
                    });
                  },
                  selectedColor: Colors.orange.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Approved'),
                  selected: _selectedFilter == PropertyStatus.approved,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = PropertyStatus.approved;
                    });
                  },
                  selectedColor: Colors.green.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Rejected'),
                  selected: _selectedFilter == PropertyStatus.rejected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = PropertyStatus.rejected;
                    });
                  },
                  selectedColor: Colors.red.withOpacity(0.3),
                ),
              ],
            ),
          ),

          // Properties List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedFilter == null
                  ? FirebaseFirestore.instance
                        .collection('properties')
                        .where('ownerId', isEqualTo: userId)
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('properties')
                        .where('ownerId', isEqualTo: userId)
                        .where('status', isEqualTo: _selectedFilter!.name)
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final propertyDocs = snapshot.data?.docs ?? [];
                final properties = propertyDocs.map((doc) {
                  final propertyData = doc.data() as Map<String, dynamic>;
                  return PropertyModel.fromJson({
                    ...propertyData,
                    'id': doc.id,
                  });
                }).toList();

                // Always keep newest at the top.
                // For approved items, sort by last update (approval/edit) first.
                properties.sort((a, b) {
                  if (_selectedFilter == PropertyStatus.approved) {
                    final updatedCompare = b.updatedAt.compareTo(a.updatedAt);
                    if (updatedCompare != 0) return updatedCompare;
                  }
                  return b.createdAt.compareTo(a.createdAt);
                });

                if (properties.isEmpty) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        Icon(
                          Icons.home_work_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No properties found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 24),
                          const WebFooter(),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: properties.length + (kIsWeb ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (kIsWeb && index == properties.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: WebFooter(),
                      );
                    }

                    final property = properties[index];

                    return Dismissible(
                      key: Key(property.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await _showDeleteConfirmDialog(property);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AgentPropertyDetailsScreen(
                                property: property,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Property Image
                              if (property.imageUrls.isNotEmpty)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: Image.network(
                                        property.imageUrls.first,
                                        height: 240,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return Container(
                                                height: 240,
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                height: 240,
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  size: 50,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                    // Delete button overlay
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete),
                                        color: Colors.white,
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.red
                                              .withOpacity(0.8),
                                        ),
                                        onPressed: () =>
                                            _showDeleteConfirmDialog(property),
                                      ),
                                    ),
                                  ],
                                ),

                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Status Badge and Active/Inactive Toggle
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              property.status,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            property.status.name.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Sold Out Badge if deactivated
                                        if (!property.isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[700],
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'SOLD OUT',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            property.type == PropertyType.sale
                                                ? 'For Sale'
                                                : property.type ==
                                                      PropertyType.rent
                                                ? 'For Rent'
                                                : 'Hostel',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Active/Inactive Toggle (only for approved properties)
                                    if (property.status ==
                                        PropertyStatus.approved)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Row(
                                          children: [
                                            Icon(
                                              property.isActive
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              size: 16,
                                              color: property.isActive
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              property.isActive
                                                  ? 'Active'
                                                  : 'Deactivated',
                                              style: TextStyle(
                                                color: property.isActive
                                                    ? Colors.green
                                                    : Colors.grey,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Spacer(),
                                            Switch(
                                              value: property.isActive,
                                              onChanged: (value) async {
                                                await _togglePropertyStatus(
                                                  property.id,
                                                  value,
                                                );
                                              },
                                              activeThumbColor:
                                                  AppColors.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 12),

                                    // Title
                                    Text(
                                      property.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Location
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          property.location,
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Price
                                    Text(
                                      '${property.currency} ${CurrencyFormatter.format(property.price)}${property.type == PropertyType.rent
                                          ? '/month'
                                          : property.type == PropertyType.hostel
                                          ? '/semester'
                                          : ''}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Property Details
                                    Row(
                                      children: [
                                        _buildFeature(
                                          Icons.bed,
                                          '${property.bedrooms} Beds',
                                        ),
                                        const SizedBox(width: 16),
                                        _buildFeature(
                                          Icons.bathroom,
                                          '${property.bathrooms} Baths',
                                        ),
                                        const SizedBox(width: 16),
                                        _buildFeature(
                                          Icons.square_foot,
                                          '${property.areaSqft.toInt()} sqft',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // View Count
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${property.viewCount} ${property.viewCount == 1 ? 'view' : 'views'}',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (property.status ==
                                        PropertyStatus.approved) ...[
                                      const SizedBox(height: 12),
                                      _buildPromotionSection(property),
                                    ],

                                    // Rejection Reason
                                    if (property.status ==
                                            PropertyStatus.rejected &&
                                        property.rejectionReason != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Rejection Reason:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              property.rejectionReason!,
                                              style: const TextStyle(
                                                color: Colors.red,
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isTabView
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddPropertyScreen(),
                  ),
                );
                if (!mounted) return;
                setState(() {});
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_home),
              label: const Text('Add Property'),
              heroTag: 'addPropertyFAB',
            )
          : null,
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _isPromotionCurrentlyActive(PropertyModel property) {
    if (!property.hasActivePromotion) return false;
    final endDate = property.promotionEndDate;
    if (endDate == null) return true;
    return endDate.isAfter(DateTime.now());
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<Map<String, dynamic>?> _findAnotherActivePromotion({
    required String ownerId,
    required String excludingPropertyId,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: ownerId)
        .where('hasActivePromotion', isEqualTo: true)
        .get();

    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      if (doc.id == excludingPropertyId) continue;
      final data = doc.data();
      final endDate = _parseDateTime(data['promotionEndDate']);
      final isActive = endDate == null || endDate.isAfter(now);
      if (!isActive) continue;

      return {
        'title': (data['title'] as String?) ?? 'Another property',
        'endDate': endDate,
      };
    }

    return null;
  }

  Future<String?> _payForFeaturedPromotion(PropertyModel property) async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isPaying = false;
    String? paymentReference;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Pay Featured Promotion'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Property: ${property.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Amount: UGX ${CurrencyFormatter.format(_featuredPromotionPrice)} / month',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Money Number',
                          hintText: 'e.g. 2567XXXXXXXX',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter phone number';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isPaying
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed: isPaying
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isPaying = true);

                          final transactionRef =
                              'FEATURED_${property.id}_${DateTime.now().millisecondsSinceEpoch}';
                          try {
                            final response = await _pandoraService
                                .initiatePayment(
                                  phoneNumber: phoneController.text.trim(),
                                  amount: _featuredPromotionPrice,
                                  transactionRef: transactionRef,
                                  narrative: 'Featured Property Promotion',
                                );

                            if (!response.success) {
                              throw PaymentException(response.message);
                            }

                            paymentReference = response.transactionReference;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Payment initiated. Complete it on your phone to activate promotion.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Payment failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            setDialogState(() => isPaying = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isPaying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Pay Now'),
                ),
              ],
            );
          },
        );
      },
    );

    return paymentReference;
  }

  Future<void> _startFeaturedPromotion(PropertyModel property) async {
    if (_promotingPropertyId != null) return;

    if (!property.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activate this property before promoting it.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isPromotionCurrentlyActive(property)) {
      final endDate = property.promotionEndDate;
      final until = endDate != null ? ' until ${_formatDate(endDate)}' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This property is already featured$until.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final activePromotion = await _findAnotherActivePromotion(
        ownerId: property.ownerId,
        excludingPropertyId: property.id,
      );
      if (activePromotion != null) {
        final title = activePromotion['title'] as String;
        final endDate = activePromotion['endDate'] as DateTime?;
        final until = endDate != null ? ' until ${_formatDate(endDate)}' : '';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only one property can be featured per month. "$title" is active$until.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking promotion eligibility: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Featured Property Promotion'),
        content: Text(
          'Promote "${property.title}" for UGX ${CurrencyFormatter.format(_featuredPromotionPrice)} for 30 days?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final paymentReference = await _payForFeaturedPromotion(property);
    if (paymentReference == null) return;

    setState(() => _promotingPropertyId = property.id);
    try {
      final promotionEndDate = DateTime.now().add(const Duration(days: 30));
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .update({
            'featuredPromotion': true,
            'hasActivePromotion': true,
            'promotionRequested': false,
            'promotionEndDate': Timestamp.fromDate(promotionEndDate),
            'featuredPromotionPaidAt': Timestamp.now(),
            'featuredPromotionPaymentRef': paymentReference,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Featured promotion activated until ${_formatDate(promotionEndDate)}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating featured promotion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _promotingPropertyId = null);
      }
    }
  }

  Widget _buildPromotionSection(PropertyModel property) {
    final isActivePromotion = _isPromotionCurrentlyActive(property);
    final hasExpiredPromotion =
        (property.featuredPromotion || property.hasActivePromotion) &&
        !isActivePromotion;
    final isProcessing = _promotingPropertyId == property.id;

    String statusText = 'No active featured promotion';
    Color statusColor = Colors.grey.shade700;

    if (isActivePromotion) {
      if (property.promotionEndDate != null) {
        statusText =
            'Featured until ${_formatDate(property.promotionEndDate!)}';
      } else {
        statusText = 'Featured promotion is active';
      }
      statusColor = Colors.green.shade700;
    } else if (hasExpiredPromotion) {
      statusText = 'Previous featured promotion has expired';
      statusColor = Colors.orange.shade700;
    }

    final canPromote = !isProcessing && !isActivePromotion && property.isActive;

    final buttonText = isProcessing
        ? 'Processing payment...'
        : isActivePromotion
        ? 'Featured Promotion Active'
        : property.isActive
        ? 'Promote This Property • UGX ${CurrencyFormatter.format(_featuredPromotionPrice)} / month'
        : 'Activate Property To Promote';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 6),
              const Text(
                'Featured Property Promotion',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One promoted property per account at a time.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canPromote
                  ? () => _startFeaturedPromotion(property)
                  : null,
              icon: Icon(
                isActivePromotion
                    ? Icons.check_circle
                    : Icons.local_fire_department,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              label: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePropertyStatus(String propertyId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .update({
            'isActive': isActive,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? 'Property activated successfully'
                  : 'Property marked as sold out',
            ),
            backgroundColor: isActive ? Colors.green : Colors.grey[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating property: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
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

  Future<bool?> _showDeleteConfirmDialog(PropertyModel property) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property'),
        content: Text(
          'Are you sure you want to delete "${property.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              _deleteProperty(property);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty(PropertyModel property) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting property...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Delete property from Firestore
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting property: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
