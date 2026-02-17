import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/property_model.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';
import 'agent_property_details_screen.dart';

class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  PropertyStatus? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
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

                final properties = snapshot.data?.docs ?? [];

                if (properties.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final propertyData = properties[index].data() as Map<String, dynamic>;
                    propertyData['id'] = properties[index].id;
                    final property = PropertyModel.fromJson(propertyData);

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AgentPropertyDetailsScreen(property: property),
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
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
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
                                    child: const Icon(Icons.image_not_supported, size: 50),
                                  );
                                },
                              ),
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
                                        color: _getStatusColor(property.status),
                                        borderRadius: BorderRadius.circular(20),
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
                                          borderRadius: BorderRadius.circular(20),
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
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        property.type == PropertyType.sale
                                            ? 'For Sale'
                                            : property.type == PropertyType.rent
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
                                if (property.status == PropertyStatus.approved)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          property.isActive ? Icons.check_circle : Icons.cancel,
                                          size: 16,
                                          color: property.isActive ? Colors.green : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          property.isActive ? 'Active' : 'Deactivated',
                                          style: TextStyle(
                                            color: property.isActive ? Colors.green : Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Switch(
                                          value: property.isActive,
                                          onChanged: (value) async {
                                            await _togglePropertyStatus(property.id, value);
                                          },
                                          activeColor: AppColors.primary,
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
                                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      property.location,
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Price
                                Text(
                                  'UGX ${CurrencyFormatter.format(property.price)}${property.type == PropertyType.rent ? '/month' : property.type == PropertyType.hostel ? '/semester' : ''}',
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
                                    _buildFeature(Icons.bed, '${property.bedrooms} Beds'),
                                    const SizedBox(width: 16),
                                    _buildFeature(Icons.bathroom, '${property.bathrooms} Baths'),
                                    const SizedBox(width: 16),
                                    _buildFeature(Icons.square_foot, '${property.areaSqft.toInt()} sqft'),
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

                                // Rejection Reason
                                if (property.status == PropertyStatus.rejected &&
                                    property.rejectionReason != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                          style: const TextStyle(color: Colors.red),
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
                  },
                );
              },
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
}
