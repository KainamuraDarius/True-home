import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import '../../models/property_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/database_helper.dart';
import 'property_details_screen.dart';

class CustomerPropertiesScreen extends StatefulWidget {
  const CustomerPropertiesScreen({super.key});

  @override
  State<CustomerPropertiesScreen> createState() => _CustomerPropertiesScreenState();
}

class _CustomerPropertiesScreenState extends State<CustomerPropertiesScreen> {
  PropertyType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Properties'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Filter
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('For Sale'),
                    selected: _selectedType == PropertyType.sale,
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = selected ? PropertyType.sale : null;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('For Rent'),
                    selected: _selectedType == PropertyType.rent,
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = selected ? PropertyType.rent : null;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedType == null,
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = null;
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          // Properties List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedType == null
                  ? FirebaseFirestore.instance
                      .collection('properties')
                      .where('status', isEqualTo: PropertyStatus.approved.name)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('properties')
                      .where('status', isEqualTo: PropertyStatus.approved.name)
                      .where('type', isEqualTo: _selectedType!.name)
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
                          'No properties available',
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

  Widget _buildPropertyCard(PropertyModel property) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image
            if (property.imageUrls.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    child: Image.network(
                      property.imageUrls.first,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 64),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: property.type == PropertyType.sale
                            ? Colors.green
                            : Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        property.type == PropertyType.sale ? 'FOR SALE' : 'FOR RENT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'UGX ${property.price.toStringAsFixed(0)}${property.type == PropertyType.rent ? '/month' : ''}',
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFeature(Icons.bed, '${property.bedrooms}'),
                      const SizedBox(width: 16),
                      _buildFeature(Icons.bathtub, '${property.bathrooms}'),
                      const SizedBox(width: 16),
                      _buildFeature(Icons.square_foot, '${property.areaSqft.toInt()} sqft'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
