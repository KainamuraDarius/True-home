import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/property_model.dart';
import '../auth/welcome_screen.dart';
import '../common/profile_screen.dart';
import '../common/notifications_screen.dart';
import 'admin_users_screen.dart';
import 'admin_create_user_screen.dart';
import 'admin_properties_screen.dart';
import 'admin_projects_screen.dart';
import 'add_hostel_screen.dart';
import 'manage_hostels_screen.dart';
import 'admin_reservations_screen.dart';
import 'admin_verification_requests_screen.dart';
import 'send_notification_screen.dart';
import 'add_admin_role_screen.dart';
import 'manage_room_availability_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;
  String _selectedSection = 'dashboard';

  // Menu sections
  final List<MenuSection> _menuSections = [
    MenuSection(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard,
      color: AppColors.primary,
    ),
    MenuSection(
      id: 'users',
      title: 'User Management',
      icon: Icons.people,
      color: Colors.blue,
      subItems: [
        MenuItem(id: 'all_users', title: 'All Users', icon: Icons.group),
        MenuItem(id: 'verification', title: 'Verification Requests', icon: Icons.verified_user),
        MenuItem(id: 'create_admin', title: 'Create Admin', icon: Icons.person_add),
        MenuItem(id: 'add_admin_role', title: 'Add Admin Role', icon: Icons.admin_panel_settings),
      ],
    ),
    MenuSection(
      id: 'properties',
      title: 'Property Management',
      icon: Icons.home_work,
      color: Colors.green,
      subItems: [
        MenuItem(id: 'review_properties', title: 'Review Properties', icon: Icons.rate_review),
        MenuItem(id: 'manage_projects', title: 'Advertised Projects', icon: Icons.apartment),
      ],
    ),
    MenuSection(
      id: 'hostels',
      title: 'Hostel Management',
      icon: Icons.school,
      color: Colors.purple,
      subItems: [
        MenuItem(id: 'add_hostel', title: 'Add New Hostel', icon: Icons.add_home),
        MenuItem(id: 'manage_hostels', title: 'Manage Hostels', icon: Icons.edit),
        MenuItem(id: 'hostel_reservations', title: 'Reservations', icon: Icons.calendar_today),
        MenuItem(id: 'room_availability', title: 'Room Availability', icon: Icons.bed),
      ],
    ),
    MenuSection(
      id: 'communications',
      title: 'Communications',
      icon: Icons.notifications_active,
      color: Colors.orange,
      subItems: [
        MenuItem(id: 'send_notifications', title: 'Send Notifications', icon: Icons.send),
      ],
    ),
    MenuSection(
      id: 'profile',
      title: 'Profile & Settings',
      icon: Icons.settings,
      color: Colors.grey,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final count = await _notificationService.getUnreadCount(userId);
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: AppColors.error),
            const SizedBox(width: 8),
            const Text('True Home Admin'),
            const Spacer(),
            // Notification bell
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                    _loadUnreadCount();
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        elevation: 2,
      ),
      drawer: isWideScreen ? null : _buildDrawer(),
      body: Row(
        children: [
          // Sidebar for wide screens
          if (isWideScreen) _buildSidebar(),
          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: _buildMenuList(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'True Home',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildMenuList()),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _menuSections.map((section) {
        final isSelected = _selectedSection == section.id ||
            section.subItems?.any((item) => _selectedSection == item.id) == true;

        if (section.subItems == null || section.subItems!.isEmpty) {
          // Simple menu item
          return _buildMenuItem(
            section.id,
            section.title,
            section.icon,
            section.color,
            isSelected,
          );
        }

        // Expandable menu section
        return ExpansionTile(
          leading: Icon(section.icon, color: section.color),
          title: Text(
            section.title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? section.color : Colors.black87,
            ),
          ),
          initiallyExpanded: isSelected,
          children: section.subItems!.map((subItem) {
            final isSubSelected = _selectedSection == subItem.id;
            return ListTile(
              leading: const SizedBox(width: 24),
              title: Row(
                children: [
                  Icon(
                    subItem.icon,
                    size: 20,
                    color: isSubSelected ? section.color : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    subItem.title,
                    style: TextStyle(
                      fontWeight: isSubSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSubSelected ? section.color : Colors.black87,
                    ),
                  ),
                ],
              ),
              selected: isSubSelected,
              selectedTileColor: section.color.withOpacity(0.1),
              onTap: () {
                setState(() {
                  _selectedSection = subItem.id;
                });
                Navigator.pop(context); // Close drawer on mobile
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildMenuItem(
    String id,
    String title,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? color : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? color : Colors.black87,
        ),
      ),
      selected: isSelected,
      selectedTileColor: color.withOpacity(0.1),
      onTap: () {
        setState(() {
          _selectedSection = id;
        });
        if (MediaQuery.of(context).size.width <= 800) {
          Navigator.pop(context);
        }
      },
    );
  }

  Widget _buildContent() {
    switch (_selectedSection) {
      case 'dashboard':
        return _buildDashboardContent();
      case 'all_users':
        return const AdminUsersScreen(embedded: true);
      case 'verification':
        return const AdminVerificationRequestsScreen(embedded: true);
      case 'create_admin':
        return _buildCreateAdminContent();
      case 'add_admin_role':
        return const AddAdminRoleScreen(embedded: true);
      case 'review_properties':
        return AdminPropertiesScreen(embedded: true);
      case 'manage_projects':
        return const AdminProjectsScreen(embedded: true);
      case 'add_hostel':
        return const AddHostelScreen(embedded: true);
      case 'manage_hostels':
        return const ManageHostelsScreen();
      case 'hostel_reservations':
        return const AdminReservationsScreen(embedded: true);
      case 'room_availability':
        return _buildRoomAvailabilitySelector();
      case 'send_notifications':
        return const SendNotificationScreen(embedded: true);
      case 'profile':
        return const ProfileScreen(embedded: true);
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildCreateAdminContent() {
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    if (currentUserEmail != 'truehome376@gmail.com') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Access Restricted',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only the master admin can create new admin accounts',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return const AdminCreateUserScreen(embedded: true);
  }

  Widget _buildRoomAvailabilitySelector() {
    return StreamBuilder<QuerySnapshot>(
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
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                const Text('Error loading hostels'),
                Text('${snapshot.error}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final hostels = snapshot.data!.docs;
        if (hostels.isEmpty) {
          return const Center(
            child: Text('No hostels found. Add a hostel first.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: hostels.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Select a Hostel to Manage Room Availability',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              );
            }

            final hostel = hostels[index - 1];
            final data = hostel.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: const Icon(Icons.school, color: Colors.purple),
                ),
                title: Text(data['title'] ?? 'Unnamed Hostel'),
                subtitle: Text(data['location'] ?? 'No location'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Create PropertyModel from document data
                  final propertyData = {...data, 'id': hostel.id};
                  final property = PropertyModel.fromJson(propertyData);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageRoomAvailabilityScreen(
                        property: property,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome back, Admin',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                return Center(
                  child: Text('Error loading stats: ${userSnapshot.error}',
                    style: TextStyle(color: Colors.red.shade300)),
                );
              }
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('properties').snapshots(),
                builder: (context, propertySnapshot) {
                  if (propertySnapshot.hasError) {
                    return Center(
                      child: Text('Error loading properties: ${propertySnapshot.error}',
                        style: TextStyle(color: Colors.red.shade300)),
                    );
                  }
                  final users = userSnapshot.data?.docs ?? [];
                  final properties = propertySnapshot.data?.docs ?? [];

                  final customers = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['role'] == 'customer';
                  }).length;

                  final agents = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['role'] == 'propertyAgent';
                  }).length;

                  final hostels = properties.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['type'] == 'hostel';
                  }).length;

                  final pendingProperties = properties.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == 'pending';
                  }).length;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatCard('Total Users', '${users.length}', Icons.people, AppColors.primary),
                      _buildStatCard('Customers', '$customers', Icons.person, Colors.blue),
                      _buildStatCard('Agents', '$agents', Icons.business, Colors.green),
                      _buildStatCard('Properties', '${properties.length}', Icons.home, Colors.orange),
                      _buildStatCard('Hostels', '$hostels', Icons.school, Colors.purple),
                      _buildStatCard('Pending Review', '$pendingProperties', Icons.pending_actions, Colors.red),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickAction('Add Hostel', Icons.add_home, Colors.purple, () {
                setState(() => _selectedSection = 'add_hostel');
              }),
              _buildQuickAction('Review Properties', Icons.rate_review, Colors.green, () {
                setState(() => _selectedSection = 'review_properties');
              }),
              _buildQuickAction('Verification Requests', Icons.verified_user, Colors.amber, () {
                setState(() => _selectedSection = 'verification');
              }),
              _buildQuickAction('Send Notification', Icons.send, Colors.orange, () {
                setState(() => _selectedSection = 'send_notifications');
              }),
            ],
          ),

          const SizedBox(height: 32),

          // Recent Activity
          const Text(
            'Recent Hostels',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('properties')
                .where('type', isEqualTo: 'hostel')
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 32, color: Colors.red.shade400),
                        const SizedBox(height: 8),
                        const Text('Index building...', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Please wait a few minutes for Firestore indexes to build.',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final hostels = snapshot.data!.docs;
              if (hostels.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.school, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('No hostels added yet'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _selectedSection = 'add_hostel'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Hostel'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Card(
                child: Column(
                  children: hostels.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.shade100,
                        child: const Icon(Icons.school, color: Colors.purple),
                      ),
                      title: Text(data['title'] ?? 'Unnamed'),
                      subtitle: Text(data['location'] ?? 'No location'),
                      trailing: TextButton(
                        onPressed: () => setState(() => _selectedSection = 'manage_hostels'),
                        child: const Text('Manage'),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class MenuSection {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<MenuItem>? subItems;

  MenuSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    this.subItems,
  });
}

class MenuItem {
  final String id;
  final String title;
  final IconData icon;

  MenuItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}
