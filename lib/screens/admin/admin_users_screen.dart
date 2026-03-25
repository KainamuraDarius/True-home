import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../widgets/agent_name_with_badge.dart';

class AdminUsersScreen extends StatefulWidget {
  final bool embedded;
  const AdminUsersScreen({super.key, this.embedded = false});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _selectedFilter = 'all';
  // Key to force StreamBuilder to rebuild
  Key _userListKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        // Filter Tabs and Refresh Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Users', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Customers', 'customer'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Property Agents', 'propertyAgent'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Admins', 'admin'),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh user list',
                onPressed: () {
                  setState(() {
                    _userListKey = UniqueKey();
                  });
                },
              ),
            ],
          ),
        ),
        // Users List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            key: _userListKey,
            stream: _selectedFilter == 'all'
                ? _firestore.collection('users').orderBy('createdAt', descending: true).snapshots()
                : _firestore
                    .collection('users')
                    .where('role', isEqualTo: _selectedFilter)
                    .snapshots(),
            builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        const Text('Error loading users'),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter out deleted users
                final activeDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isDeleted'] != true;
                }).toList();

                if (activeDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeDocs.length,
                  itemBuilder: (context, index) {
                    final doc = activeDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildUserCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      );

    if (widget.embedded) {
      return content;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: content,
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      backgroundColor: AppColors.surfaceLight,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
        width: 2,
      ),
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> data) {
    final role = (data['role'] ?? data['activeRole'] ?? 'customer').toString();
    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);
    
    // Get the user's available roles
    final List<String> roles = _getUserRoles(data);
    final bool isAgent = roles.contains('propertyAgent');
    final bool isAdmin = roles.contains('admin');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          child: Icon(roleIcon, color: roleColor, size: 24),
        ),
        title: AgentNameWithBadge(
          name: data['name'] ?? 'Unknown',
          isVerified: data['isVerified'] == true,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          iconColor: Colors.lightBlueAccent,
          iconSize: 18,
        ),
        subtitle: Text(
          data['email'] ?? '',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _getRoleDisplayName(role),
            style: TextStyle(
              color: roleColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('User ID', userId),
                const SizedBox(height: 8),
                _buildInfoRow('Phone', data['phoneNumber'] ?? 'N/A'),
                if (data['whatsappNumber'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('WhatsApp', data['whatsappNumber']),
                ],
                if (data['companyName'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Company', data['companyName']),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Verified',
                  (data['isVerified'] ?? false) ? 'Yes' : 'No',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Joined',
                  _formatDate(data['createdAt']),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Available Roles',
                  roles.map((r) => _getRoleDisplayName(r)).join(', '),
                ),
                const SizedBox(height: 16),
                // Role Management Section
                if (!isAdmin) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Role Management',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!isAgent)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _promoteToAgent(userId, data['name']),
                              icon: const Icon(Icons.upgrade, size: 18),
                              label: const Text('Promote to Agent'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _demoteToCustomer(userId, data['name']),
                              icon: const Icon(Icons.arrow_downward, size: 18),
                              label: const Text('Demote to Customer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showUserDetails(userId, data);
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Details'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: !isAdmin
                            ? () => _deleteUser(userId, data['name'])
                            : null,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                      ),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'customer':
        return Colors.blue;
      case 'propertyAgent':
        return Colors.green;
      case 'admin':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'customer':
        return Icons.person;
      case 'propertyAgent':
        return Icons.business;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person_outline;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'customer':
        return 'Customer';
      case 'propertyAgent':
        return 'Agent';
      case 'admin':
        return 'Admin';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showUserDetails(String userId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['name'] ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User ID: $userId'),
              const SizedBox(height: 8),
              Text('Email: ${data['email']}'),
              const SizedBox(height: 8),
              Text('Phone: ${data['phoneNumber'] ?? 'N/A'}'),
              if (data['favoritePropertyIds'] != null) ...[
                const SizedBox(height: 8),
                Text('Favorites: ${(data['favoritePropertyIds'] as List).length}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete "$userName"? The user will be moved to trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Soft delete - move to trash instead of permanent deletion
        await _firestore.collection('users').doc(userId).update({
          'isDeleted': true,
          'deletedAt': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User "$userName" moved to trash'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// Get all roles for a user from Firestore data
  List<String> _getUserRoles(Map<String, dynamic> data) {
    final List<String> roles = [];
    
    // Check 'roles' array field
    if (data['roles'] != null && data['roles'] is List) {
      for (var r in data['roles']) {
        final roleStr = r.toString();
        if (!roles.contains(roleStr)) {
          roles.add(roleStr);
        }
      }
    }
    
    // Check legacy 'role' field
    if (data['role'] != null) {
      final roleStr = data['role'].toString();
      if (!roles.contains(roleStr)) {
        roles.add(roleStr);
      }
    }
    
    // Check 'activeRole' field
    if (data['activeRole'] != null) {
      final roleStr = data['activeRole'].toString();
      if (!roles.contains(roleStr)) {
        roles.add(roleStr);
      }
    }
    
    // Default to customer if no roles found
    if (roles.isEmpty) {
      roles.add('customer');
    }
    
    return roles;
  }

  /// Promote a customer to agent
  Future<void> _promoteToAgent(String userId, String? userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote to Agent'),
        content: Text(
          'Are you sure you want to promote "${userName ?? 'this user'}" to Property Agent?\n\n'
          'This will allow them to list properties on the platform.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Get current user data
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        
        // Get current roles
        List<String> currentRoles = _getUserRoles(userData);
        
        // Add propertyAgent if not already present
        if (!currentRoles.contains('propertyAgent')) {
          currentRoles.add('propertyAgent');
        }
        
        // Update user document
        await _firestore.collection('users').doc(userId).update({
          'roles': currentRoles,
          'role': 'propertyAgent', // Update legacy field
          'activeRole': 'propertyAgent', // Set as active role
          'updatedAt': DateTime.now().toIso8601String(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${userName ?? 'User'} has been promoted to Property Agent'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to promote user: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// Demote an agent to customer only
  Future<void> _demoteToCustomer(String userId, String? userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demote to Customer'),
        content: Text(
          'Are you sure you want to demote "${userName ?? 'this user'}" to Customer only?\n\n'
          'This will remove their ability to list properties. Their existing listings will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Demote'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Update user document - remove propertyAgent role
        await _firestore.collection('users').doc(userId).update({
          'roles': ['customer'],
          'role': 'customer',
          'activeRole': 'customer',
          'updatedAt': DateTime.now().toIso8601String(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${userName ?? 'User'} has been demoted to Customer'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to demote user: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
