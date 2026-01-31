import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../utils/app_theme.dart';
import 'property_review_screen.dart';
import 'manage_room_availability_screen.dart';

class AdminPropertiesScreen extends StatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  State<AdminPropertiesScreen> createState() => _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends State<AdminPropertiesScreen> {
  PropertyStatus _selectedFilter = PropertyStatus.pending;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('status', isEqualTo: PropertyStatus.pending.name)
        .get();
    if (mounted) {
      setState(() {
        _pendingCount = snapshot.docs.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Property Reviews'),
            if (_pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Pending', PropertyStatus.pending),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', PropertyStatus.approved),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', PropertyStatus.rejected),                  const SizedBox(width: 8),
                  _buildFilterChip('Removed', PropertyStatus.removed),                ],
              ),
            ),
          ),

          // Properties List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('properties')
                  .where('status', isEqualTo: _selectedFilter.name)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final properties = snapshot.data!.docs;

                if (properties.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_work_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter.name} properties',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final data = properties[index].data() as Map<String, dynamic>;
                    final property = PropertyModel.fromJson({
                      ...data,
                      'id': properties[index].id,
                    });
                    return _buildPropertyCard(property);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, PropertyStatus status) {
    final isSelected = _selectedFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = status;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPropertyCard(PropertyModel property) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PropertyReviewScreen(property: property),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Property Image
                if (property.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    child: Image.network(
                      property.imageUrls.first,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 240,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 240,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 64),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              property.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: property.type == PropertyType.sale
                                  ? Colors.green
                                  : Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              property.type == PropertyType.sale ? 'SALE' : 'RENT',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'UGX ${CurrencyFormatter.format(property.price)}${property.type == PropertyType.rent ? '/month' : property.type == PropertyType.hostel ? '/semester' : ''}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.location,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildFeature(Icons.bed, '${property.bedrooms} Beds'),
                          const SizedBox(width: 16),
                          _buildFeature(Icons.bathtub, '${property.bathrooms} Baths'),
                          const SizedBox(width: 16),
                          _buildFeature(Icons.square_foot, '${property.areaSqft.toInt()} sqft'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Submitted by: ${property.ownerName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      // Show spotlight promotion request badge
                      if (property.promotionRequested)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade600, Colors.orange.shade600],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Spotlight Promotion Requested',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action buttons for approved properties
          if (property.status == PropertyStatus.approved)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Promotion status badges
                      if (property.isNewProject)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'New Project',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      if (property.hasActivePromotion)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Promoted',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Manage Promotion button
                      ElevatedButton.icon(
                        onPressed: () => _showPromotionDialog(property),
                        icon: const Icon(Icons.campaign, size: 18),
                        label: const Text('Promotion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Remove button
                      IconButton(
                        onPressed: () => _showDeleteDialog(property),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Remove Property',
                      ),
                    ],
                  ),
                  // Manage Rooms button for hostels only
                  if (property.type == PropertyType.hostel && property.roomTypes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageRoomAvailabilityScreen(
                                property: property,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.meeting_room, size: 18),
                        label: const Text('Manage Room Availability'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty(PropertyModel property) async {
    try {
      // Update property status to 'removed' instead of deleting
      // This allows admin to view removed properties later
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .update({
        'status': PropertyStatus.removed.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Send notification to property owner
      await _sendDeletionNotification(property);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing property: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendDeletionNotification(PropertyModel property) async {
    try {
      final notification = {
        'userId': property.ownerId,
        'title': 'Property Removed',
        'message': 'Your property "${property.title}" has been removed from the listings by admin.',
        'propertyId': property.id,
        'type': 'property_removed',
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance.collection('notifications').add(notification);
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
  
  void _showPromotionDialog(PropertyModel property) {
    bool markAsNewProject = property.isNewProject;
    bool enablePromotion = property.hasActivePromotion;
    DateTime? promotionEndDate = property.promotionEndDate;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Manage Promotion'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Mark as New Project'),
                      subtitle: const Text('Show in \"New Projects from Developers\" carousel'),
                      value: markAsNewProject,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setState(() {
                          markAsNewProject = value ?? false;
                          if (!markAsNewProject) {
                            enablePromotion = false;
                            promotionEndDate = null;
                          }
                        });
                      },
                    ),
                    if (markAsNewProject) ...[
                      CheckboxListTile(
                        title: const Text('Enable Promotion'),
                        subtitle: const Text('Feature this project in the carousel'),
                        value: enablePromotion,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            enablePromotion = value ?? false;
                            if (!enablePromotion) {
                              promotionEndDate = null;
                            }
                          });
                        },
                      ),
                      if (enablePromotion) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          title: const Text('Promotion End Date'),
                          subtitle: Text(
                            promotionEndDate != null
                                ? 'Ends: ${promotionEndDate!.day}/${promotionEndDate!.month}/${promotionEndDate!.year}'
                                : 'No end date (runs indefinitely)',
                            style: const TextStyle(fontSize: 13),
                          ),
                          contentPadding: EdgeInsets.zero,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (promotionEndDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      promotionEndDate = null;
                                    });
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.calendar_today, size: 20),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: promotionEndDate ?? DateTime.now().add(const Duration(days: 30)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      promotionEndDate = date;
                                    });
                                  }
                                },
                              ),
                            ],
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
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updatePromotionStatus(
                      property,
                      markAsNewProject,
                      enablePromotion,
                      promotionEndDate,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Future<void> _updatePromotionStatus(
    PropertyModel property,
    bool isNewProject,
    bool hasActivePromotion,
    DateTime? promotionEndDate,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(property.id)
          .update({
        'isNewProject': isNewProject,
        'hasActivePromotion': hasActivePromotion,
        'promotionEndDate': promotionEndDate?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promotion settings updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating promotion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(PropertyModel property) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Property'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to remove this property?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Property: ${property.title}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'The property will be moved to "Removed" status and hidden from customers. You can view it later in the Removed tab.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteProperty(property);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeature(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
