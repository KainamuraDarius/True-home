import 'package:flutter/material.dart';
import '../../utils/snackbar_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'edit_hostel_screen.dart';

class ManageHostelsScreen extends StatefulWidget {
  const ManageHostelsScreen({super.key});

  @override
  State<ManageHostelsScreen> createState() => _ManageHostelsScreenState();
}

class _ManageHostelsScreenState extends State<ManageHostelsScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with search and filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.purple, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Manage Student Hostels',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() {}),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search and filter row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search hostels...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Status filter
                  DropdownButton<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value ?? 'all';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Hostels list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Query for hostels - the field is 'type' and value is 'hostel'
            stream: _firestore
                .collection('properties')
                .where('type', isEqualTo: 'hostel')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var hostels = snapshot.data!.docs.toList();
              
              // Sort by createdAt descending (newest first) - done in memory to avoid index requirement
              hostels.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['createdAt'];
                final bTime = bData['createdAt'];
                
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                
                // Handle Timestamp or other formats
                DateTime? aDateTime;
                DateTime? bDateTime;
                
                if (aTime is Timestamp) {
                  aDateTime = aTime.toDate();
                } else if (aTime is int) {
                  aDateTime = DateTime.fromMillisecondsSinceEpoch(aTime);
                } else if (aTime is String) {
                  aDateTime = DateTime.tryParse(aTime);
                }
                
                if (bTime is Timestamp) {
                  bDateTime = bTime.toDate();
                } else if (bTime is int) {
                  bDateTime = DateTime.fromMillisecondsSinceEpoch(bTime);
                } else if (bTime is String) {
                  bDateTime = DateTime.tryParse(bTime);
                }
                
                if (aDateTime == null && bDateTime == null) return 0;
                if (aDateTime == null) return 1;
                if (bDateTime == null) return -1;
                
                return bDateTime.compareTo(aDateTime); // descending order
              });

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                hostels = hostels.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final location = (data['location'] ?? '').toString().toLowerCase();
                  final university = (data['nearbyUniversity'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) ||
                      location.contains(_searchQuery) ||
                      university.contains(_searchQuery);
                }).toList();
              }

              // Apply status filter
              if (_filterStatus != 'all') {
                hostels = hostels.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isActive = data['isAvailable'] ?? true;
                  return _filterStatus == 'active' ? isActive : !isActive;
                }).toList();
              }

              if (hostels.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No hostels match your search'
                            : 'No hostels found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try different search terms'
                            : 'Add your first hostel to get started',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: hostels.length,
                itemBuilder: (context, index) {
                  final doc = hostels[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildHostelCard(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHostelCard(String id, Map<String, dynamic> data) {
    final title = data['title'] ?? 'Unnamed Hostel';
    final location = data['location'] ?? 'No location';
    final university = data['nearbyUniversity'] ?? data['university'] ?? 'Not specified';
    final images = List<String>.from(data['imageUrls'] ?? []);
    final isAvailable = data['isAvailable'] ?? data['isActive'] ?? true;
    
    // roomTypes can be either a List (new format) or Map (legacy format)
    List<Map<String, dynamic>> roomTypesList = [];
    final roomTypesData = data['roomTypes'];
    if (roomTypesData is List) {
      for (final e in roomTypesData) {
        if (e is Map) {
          roomTypesList.add(Map<String, dynamic>.from(e));
        }
      }
    } else if (roomTypesData is Map) {
      // Convert legacy Map format to List format
      roomTypesData.forEach((key, value) {
        if (value is Map) {
          roomTypesList.add({
            'name': key.toString(),
            ...Map<String, dynamic>.from(value),
          });
        }
      });
    }
    
    final createdAt = data['createdAt'];

    String createdDate = 'Unknown';
    if (createdAt is Timestamp) {
      createdDate = '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image header
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 180,
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 180,
                          color: Colors.grey.shade200,
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
                        ),
                      )
                    : Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text('No images', style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ),
              ),
              // Status badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAvailable ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Image count badge
              if (images.isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${images.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and ID
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID: ${id.substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // University
                Row(
                  children: [
                    Icon(Icons.school, size: 16, color: Colors.purple.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        university,
                        style: TextStyle(color: Colors.purple.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Created date
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Created: $createdDate',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Room types summary
                if (roomTypesList.isNotEmpty) ...[
                  const Text(
                    'Room Types:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: roomTypesList.map((room) {
                      final name = room['name'] ?? 'Room';
                      final price = room['price'] ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          '$name: UGX ${_formatPrice(price)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(),

                // Action buttons
                Row(
                  children: [
                    // Toggle Availability
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _toggleAvailability(id, isAvailable),
                        icon: Icon(
                          isAvailable ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                        ),
                        label: Text(isAvailable ? 'Deactivate' : 'Activate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isAvailable ? Colors.orange : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Edit
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _editHostel(id, data),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete
                    IconButton(
                      onPressed: () => _confirmDelete(id, title),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                      tooltip: 'Delete Hostel',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num = int.tryParse(price.toString()) ?? 0;
    return num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _toggleAvailability(String id, bool currentStatus) async {
    try {
      await _firestore.collection('properties').doc(id).update({
        'isAvailable': !currentStatus,
      });

      if (mounted) {
        SnackbarHelper.showInfo(
          context,
          currentStatus
              ? 'Hostel deactivated - hidden from customers'
              : 'Hostel activated - visible to customers',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(
          context,
          'Error updating hostel. Please try again.',
          actionLabel: 'Retry',
          onAction: () => _toggleAvailability(id, currentStatus),
        );
      }
    }
  }

  void _editHostel(String id, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditHostelScreen(
          hostelId: id,
          hostelData: data,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Hostel'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$title"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The hostel will be moved to trash. You can restore it later.',
                      style: TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteHostel(id, title);
    }
  }

  Future<void> _deleteHostel(String id, String title) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Soft delete - move to trash by changing status to 'removed'
      await _firestore.collection('properties').doc(id).update({
        'previousStatus': 'approved', // Save current status for restore
        'status': 'removed',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        SnackbarHelper.showSuccess(
          context,
          '"$title" moved to trash',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        SnackbarHelper.showError(
          context,
          'Error deleting hostel. Please try again.',
          actionLabel: 'Retry',
          onAction: () => _deleteHostel(id, title),
        );
      }
    }
  }
}
