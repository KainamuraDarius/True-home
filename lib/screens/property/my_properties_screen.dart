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
  bool _isFeaturedPromotionFlowBusy = false;
  String? _pendingFeaturedPaymentRef;
  String? _pendingFeaturedPaymentPhone;
  String? _availableFeaturedPaymentRef;

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFeaturedPromotionPlanCard(userId),
          ),
          const SizedBox(height: 12),

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

  Widget _buildFeaturedPromotionPlanCard(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('ownerId', isEqualTo: userId)
          .where('status', isEqualTo: PropertyStatus.approved.name)
          .snapshots(),
      builder: (context, snapshot) {
        int approvedCount = 0;
        int activeFeaturedCount = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          approvedCount = docs.length;
          final now = DateTime.now();
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final hasActivePromotion = data['hasActivePromotion'] == true;
            final endDate = _parseDateTime(data['promotionEndDate']);
            final isActive =
                hasActivePromotion && (endDate == null || endDate.isAfter(now));
            if (isActive) {
              activeFeaturedCount++;
            }
          }
        }

        final hasPaidButNotApplied = _availableFeaturedPaymentRef != null;
        final isBusy = _isFeaturedPromotionFlowBusy;

        final buttonLabel = isBusy
            ? 'Opening promotion flow...'
            : hasPaidButNotApplied
            ? 'Choose Property To Activate'
            : 'Pay & Choose Property';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFFFFF8E8), const Color(0xFFFFEFD2)],
            ),
            border: Border.all(color: const Color(0xFFFFD48D)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC46C).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Featured Property Promotion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'PLAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'UGX 200,000 / month · per property',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pin a specific listing to the top of search results in its area and category. Ideal for high-value properties or listings that need faster visibility.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPlanStatChip(
                    icon: Icons.home_work_outlined,
                    label: '$approvedCount approved',
                    color: const Color(0xFFE65100),
                  ),
                  _buildPlanStatChip(
                    icon: Icons.push_pin_outlined,
                    label: '$activeFeaturedCount active featured',
                    color: const Color(0xFF2E7D32),
                  ),
                  if (hasPaidButNotApplied)
                    _buildPlanStatChip(
                      icon: Icons.verified_outlined,
                      label: 'Payment confirmed',
                      color: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isBusy
                      ? null
                      : () => _openFeaturedPromotionPlanFlow(),
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          hasPaidButNotApplied
                              ? Icons.check_circle_outline
                              : Icons.payment,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: Text(buttonLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
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

  bool _isPaymentSuccessStatus(String status) {
    const successStatuses = {'completed', 'success', 'paid'};
    return successStatuses.contains(status.toLowerCase());
  }

  bool _isPaymentFailureStatus(String status) {
    const failureStatuses = {
      'failed',
      'declined',
      'cancelled',
      'expired',
      'user_cancelled',
      'timeout',
    };
    return failureStatuses.contains(status.toLowerCase());
  }

  void _storePendingFeaturedPayment({
    required String transactionRef,
    required String phoneNumber,
  }) {
    _pendingFeaturedPaymentRef = transactionRef;
    _pendingFeaturedPaymentPhone = phoneNumber;
  }

  void _clearPendingFeaturedPayment() {
    _pendingFeaturedPaymentRef = null;
    _pendingFeaturedPaymentPhone = null;
  }

  Future<bool> _waitForFeaturedPaymentConfirmation({
    required String transactionRef,
    required String phoneNumber,
  }) async {
    if (!mounted) return false;

    bool dialogOpen = true;
    bool cancelledByUser = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Complete Featured Plan Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your PIN on phone to confirm the featured promotion plan.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'Amount: UGX ${CurrencyFormatter.format(_featuredPromotionPrice)} / month',
              ),
              Text('Phone: $phoneNumber'),
              const SizedBox(height: 16),
              const Text(
                'Waiting for payment confirmation...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelledByUser = true;
                if (!dialogOpen) return;
                dialogOpen = false;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    void closeDialogIfOpen() {
      if (!dialogOpen || !mounted) return;
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    const int maxAttempts = 48; // 4 minutes, every 5 seconds
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted || cancelledByUser) break;

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || cancelledByUser) break;

      try {
        final statusResponse = await _pandoraService.checkPaymentStatus(
          transactionRef: transactionRef,
        );
        if (!mounted || cancelledByUser) break;

        final status = statusResponse.status.toLowerCase().trim();

        if (statusResponse.success || _isPaymentSuccessStatus(status)) {
          closeDialogIfOpen();
          return true;
        }

        if (_isPaymentFailureStatus(status)) {
          closeDialogIfOpen();
          _clearPendingFeaturedPayment();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(statusResponse.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      } catch (e) {
        final normalizedError = e.toString().toLowerCase();
        final statusServiceMissing =
            normalizedError.contains('service unavailable') ||
            normalizedError.contains('404');
        if (statusServiceMissing) {
          closeDialogIfOpen();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment status service is not available (HTTP 404). '
                  'Please deploy/enable pandoraPaymentStatus Cloud Function.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }
    }

    closeDialogIfOpen();
    if (!mounted) return false;

    if (cancelledByUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmation cancelled.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment confirmation timed out. Re-open promotion flow to continue.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return false;
  }

  Future<String?> _payForFeaturedPromotionPlan() async {
    if (_availableFeaturedPaymentRef != null) {
      return _availableFeaturedPaymentRef;
    }

    if (_pendingFeaturedPaymentRef != null &&
        _pendingFeaturedPaymentPhone != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment already initiated. Enter PIN on phone to complete.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      final confirmed = await _waitForFeaturedPaymentConfirmation(
        transactionRef: _pendingFeaturedPaymentRef!,
        phoneNumber: _pendingFeaturedPaymentPhone!,
      );
      if (!confirmed) return null;

      final confirmedRef = _pendingFeaturedPaymentRef!;
      _clearPendingFeaturedPayment();
      _availableFeaturedPaymentRef = confirmedRef;
      return _availableFeaturedPaymentRef;
    }

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
              title: const Text('Pay Featured Promotion Plan'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount: UGX ${CurrencyFormatter.format(_featuredPromotionPrice)} / month',
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
                              'FEATUREDPLAN_${DateTime.now().millisecondsSinceEpoch}';
                          try {
                            final response = await _pandoraService
                                .initiatePayment(
                                  phoneNumber: phoneController.text.trim(),
                                  amount: _featuredPromotionPrice,
                                  transactionRef: transactionRef,
                                  narrative: 'Featured Property Promotion Plan',
                                );

                            if (!response.success) {
                              throw PaymentException(response.message);
                            }

                            paymentReference = response.transactionReference;
                            _storePendingFeaturedPayment(
                              transactionRef: response.transactionReference,
                              phoneNumber: phoneController.text.trim(),
                            );
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

    final refToCheck = paymentReference ?? _pendingFeaturedPaymentRef;
    final phoneToCheck = _pendingFeaturedPaymentPhone;
    if (refToCheck == null || phoneToCheck == null) return null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment initiated. Enter your PIN on phone to confirm.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 180));
    final confirmed = await _waitForFeaturedPaymentConfirmation(
      transactionRef: refToCheck,
      phoneNumber: phoneToCheck,
    );
    if (!confirmed) return null;

    _clearPendingFeaturedPayment();
    _availableFeaturedPaymentRef = refToCheck;
    return _availableFeaturedPaymentRef;
  }

  Future<List<PropertyModel>> _loadApprovedPropertiesForPromotion() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: PropertyStatus.approved.name)
        .get();

    final properties = snapshot.docs.map((doc) {
      final propertyData = doc.data();
      return PropertyModel.fromJson({...propertyData, 'id': doc.id});
    }).toList();

    properties.sort((a, b) {
      final activeCompare = (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
      if (activeCompare != 0) return activeCompare;

      final promotedCompare = (_isPromotionCurrentlyActive(b) ? 1 : 0)
          .compareTo(_isPromotionCurrentlyActive(a) ? 1 : 0);
      if (promotedCompare != 0) return promotedCompare;

      return b.updatedAt.compareTo(a.updatedAt);
    });

    return properties;
  }

  Future<PropertyModel?> _showApprovedPropertyPicker(
    List<PropertyModel> properties, {
    String? preferredPropertyId,
  }) async {
    PropertyModel? selectedProperty;
    if (preferredPropertyId != null) {
      for (final property in properties) {
        if (property.id == preferredPropertyId && property.isActive) {
          selectedProperty = property;
          break;
        }
      }
    }
    if (selectedProperty == null) {
      for (final property in properties) {
        if (property.isActive) {
          selectedProperty = property;
          break;
        }
      }
    }

    return showModalBottomSheet<PropertyModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.86,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Choose Property To Promote',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select any approved property. Inactive listings are not eligible.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        final property = properties[index];
                        final isSelectable = property.isActive;
                        final isFeatured = _isPromotionCurrentlyActive(
                          property,
                        );
                        final isSelected = selectedProperty?.id == property.id;

                        return Opacity(
                          opacity: isSelectable ? 1 : 0.58,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: isSelectable
                                ? () => setSheetState(() {
                                    selectedProperty = property;
                                  })
                                : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : Colors.white,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (property.imageUrls.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        property.imageUrls.first,
                                        width: 74,
                                        height: 74,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  width: 74,
                                                  height: 74,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                  ),
                                                ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 74,
                                      height: 74,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.home_work_outlined,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          property.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          property.location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            if (isFeatured)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  property.promotionEndDate !=
                                                          null
                                                      ? 'Featured until ${_formatDate(property.promotionEndDate!)}'
                                                      : 'Featured',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade800,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            if (!isSelectable)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Inactive',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.orange.shade900,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Radio<String>(
                                    value: property.id,
                                    groupValue: selectedProperty?.id,
                                    onChanged: isSelectable
                                        ? (_) => setSheetState(() {
                                            selectedProperty = property;
                                          })
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Later'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: selectedProperty == null
                                ? null
                                : () => Navigator.of(
                                    sheetContext,
                                  ).pop(selectedProperty),
                            icon: const Icon(Icons.local_fire_department),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            label: const Text('Activate Promotion'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _activateFeaturedPromotionForProperty({
    required PropertyModel property,
    required String paymentReference,
  }) async {
    setState(() => _promotingPropertyId = property.id);

    try {
      final now = DateTime.now();
      final currentEnd = property.promotionEndDate;
      final hasCurrentPromotion =
          property.hasActivePromotion &&
          currentEnd != null &&
          currentEnd.isAfter(now);

      final baseDate = hasCurrentPromotion ? currentEnd : now;
      final promotionEndDate = baseDate.add(const Duration(days: 30));

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
            'featuredPromotionAmount': _featuredPromotionPrice,
            'featuredPromotionPeriod': 'monthly',
            'updatedAt': DateTime.now().toIso8601String(),
          });

      if (_availableFeaturedPaymentRef == paymentReference) {
        _availableFeaturedPaymentRef = null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Featured promotion is active until ${_formatDate(promotionEndDate)}.',
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

  Future<void> _openFeaturedPromotionPlanFlow({
    String? preferredPropertyId,
  }) async {
    if (_isFeaturedPromotionFlowBusy) return;

    setState(() => _isFeaturedPromotionFlowBusy = true);
    try {
      final approvedProperties = await _loadApprovedPropertiesForPromotion();
      if (approvedProperties.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You need at least one approved property to use this plan.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      if (!approvedProperties.any((property) => property.isActive)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Activate at least one approved property before promoting.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final paymentReference = await _payForFeaturedPromotionPlan();
      if (paymentReference == null) return;

      final selectedProperty = await _showApprovedPropertyPicker(
        approvedProperties,
        preferredPropertyId: preferredPropertyId,
      );
      if (selectedProperty == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment is confirmed. Reopen Featured Promotion to choose a property.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _activateFeaturedPromotionForProperty(
        property: selectedProperty,
        paymentReference: paymentReference,
      );
    } finally {
      if (mounted) {
        setState(() => _isFeaturedPromotionFlowBusy = false);
      }
    }
  }

  Future<void> _startFeaturedPromotion(PropertyModel property) async {
    await _openFeaturedPromotionPlanFlow(preferredPropertyId: property.id);
  }

  Widget _buildPromotionSection(PropertyModel property) {
    final isActivePromotion = _isPromotionCurrentlyActive(property);
    final hasExpiredPromotion =
        (property.featuredPromotion || property.hasActivePromotion) &&
        !isActivePromotion;
    final isProcessing =
        _promotingPropertyId == property.id || _isFeaturedPromotionFlowBusy;

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

    final canPromote = !isProcessing && property.isActive;

    final buttonText = isProcessing
        ? 'Processing...'
        : _availableFeaturedPaymentRef != null
        ? 'Choose This Property To Activate'
        : isActivePromotion
        ? 'Extend Featured Plan (+30 days)'
        : property.isActive
        ? 'Pay Plan & Promote This Property'
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
            'UGX ${CurrencyFormatter.format(_featuredPromotionPrice)} per month for each promoted property.',
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
                _availableFeaturedPaymentRef != null
                    ? Icons.push_pin
                    : isActivePromotion
                    ? Icons.autorenew
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
