import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/property_model.dart';
import '../auth/admin_login_screen.dart';
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
import 'maintenance_mode_screen.dart';
import 'scheduled_notifications_screen.dart';
import 'admin_trash_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;
  String _selectedSection = 'dashboard';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Modern gradient colors
  static const Color _primaryDark = Color(0xFF1a1a2e);
  static const Color _primaryMid = Color(0xFF16213e);
  static const Color _primaryBlue = Color(0xFF0f3460);
  static const Color _accentPurple = Color(0xFF7c3aed);
  static const Color _accentBlue = Color(0xFF3b82f6);

  // Menu sections
  final List<MenuSection> _menuSections = [
    MenuSection(
      id: 'dashboard',
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      color: _accentBlue,
    ),
    MenuSection(
      id: 'users',
      title: 'User Management',
      icon: Icons.people_rounded,
      color: const Color(0xFF10b981),
      subItems: [
        MenuItem(id: 'all_users', title: 'All Users', icon: Icons.group_rounded),
        MenuItem(id: 'verification', title: 'Verification Requests', icon: Icons.verified_user_rounded),
        MenuItem(id: 'create_admin', title: 'Create Admin', icon: Icons.person_add_rounded),
        MenuItem(id: 'add_admin_role', title: 'Add Admin Role', icon: Icons.admin_panel_settings_rounded),
      ],
    ),
    MenuSection(
      id: 'properties',
      title: 'Property Management',
      icon: Icons.home_work_rounded,
      color: const Color(0xFF06b6d4),
      subItems: [
        MenuItem(id: 'review_properties', title: 'Review Properties', icon: Icons.rate_review_rounded),
        MenuItem(id: 'manage_projects', title: 'Advertised Projects', icon: Icons.apartment_rounded),
        MenuItem(id: 'admin_trash', title: 'Trash', icon: Icons.delete_outline),
      ],
    ),
    MenuSection(
      id: 'hostels',
      title: 'Hostel Management',
      icon: Icons.school_rounded,
      color: _accentPurple,
      subItems: [
        MenuItem(id: 'add_hostel', title: 'Add New Hostel', icon: Icons.add_home_rounded),
        MenuItem(id: 'manage_hostels', title: 'Manage Hostels', icon: Icons.edit_rounded),
        MenuItem(id: 'hostel_reservations', title: 'Reservations', icon: Icons.calendar_today_rounded),
        MenuItem(id: 'room_availability', title: 'Room Availability', icon: Icons.bed_rounded),
      ],
    ),
    MenuSection(
      id: 'communications',
      title: 'Communications',
      icon: Icons.notifications_active_rounded,
      color: const Color(0xFFf59e0b),
      subItems: [
        MenuItem(id: 'send_notifications', title: 'Send Notifications', icon: Icons.send_rounded),
        MenuItem(id: 'scheduled_notifications', title: 'Scheduled Notifications', icon: Icons.schedule_send_rounded),
      ],
    ),
    MenuSection(
      id: 'system',
      title: 'System',
      icon: Icons.settings_applications_rounded,
      color: const Color(0xFFef4444),
      subItems: [
        MenuItem(id: 'maintenance_mode', title: 'Maintenance Mode', icon: Icons.build_rounded),
      ],
    ),
    MenuSection(
      id: 'profile',
      title: 'Profile & Settings',
      icon: Icons.settings_rounded,
      color: const Color(0xFF6b7280),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            size: 40,
                            color: Colors.red.shade400,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a1a2e),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to sign out of the admin panel?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade500,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      appBar: _buildModernAppBar(),
      drawer: isWideScreen ? null : _buildDrawer(),
      body: Row(
        children: [
          // Modern Sidebar for wide screens
          if (isWideScreen) _buildModernSidebar(),
          // Main content
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _primaryDark,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentBlue, _accentPurple],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'True Home Admin',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        // Notification button with badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            alignment: Alignment.center,
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
                tooltip: 'Notifications',
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
        ),
        // Logout button
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ),
      ],
    );
  }

  Widget _buildModernSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryDark, _primaryMid, _primaryBlue],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Admin Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accentBlue, _accentPurple],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _accentPurple.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    size: 35,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Admin Console',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Menu List
          Expanded(
            child: _buildModernMenuList(),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              '© ${DateTime.now().year} True Home',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _primaryDark,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accentBlue, _accentPurple],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _accentPurple.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Admin Console',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'True Home',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(child: _buildModernMenuList()),
          ],
        ),
      ),
    );
  }

  Widget _buildModernMenuList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      children: _menuSections.map((section) {
        final isSelected = _selectedSection == section.id ||
            section.subItems?.any((item) => _selectedSection == item.id) == true;

        if (section.subItems == null || section.subItems!.isEmpty) {
          return _buildModernMenuItem(
            section.id,
            section.title,
            section.icon,
            section.color,
            isSelected,
          );
        }

        // Expandable menu section
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: section.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(section.icon, color: section.color, size: 20),
              ),
              title: Text(
                section.title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                ),
              ),
              iconColor: Colors.white54,
              collapsedIconColor: Colors.white38,
              initiallyExpanded: isSelected,
              childrenPadding: const EdgeInsets.only(left: 20, bottom: 8),
              children: section.subItems!.map((subItem) {
                final isSubSelected = _selectedSection == subItem.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: Icon(
                      subItem.icon,
                      size: 18,
                      color: isSubSelected ? section.color : Colors.white54,
                    ),
                    title: Text(
                      subItem.title,
                      style: TextStyle(
                        fontWeight:
                            isSubSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSubSelected ? Colors.white : Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSubSelected,
                    selectedTileColor: section.color.withOpacity(0.2),
                    onTap: () {
                      setState(() {
                        _selectedSection = subItem.id;
                      });
                      if (MediaQuery.of(context).size.width <= 800) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildModernMenuItem(
    String id,
    String title,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isSelected ? color : color.withOpacity(0.8), size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.white.withOpacity(0.1),
        onTap: () {
          setState(() {
            _selectedSection = id;
          });
          if (MediaQuery.of(context).size.width <= 800) {
            Navigator.pop(context);
          }
        },
      ),
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
      case 'admin_trash':
        return const AdminTrashScreen();
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
      case 'scheduled_notifications':
        return const ScheduledNotificationsScreen(embedded: true);
      case 'maintenance_mode':
        return const MaintenanceModeScreen(embedded: true);
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primaryMid, _primaryBlue],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryDark.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back, Admin',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Here\'s what\'s happening with your platform today',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Stats Grid
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                return _buildErrorCard('Error loading stats: ${userSnapshot.error}');
              }
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('properties').snapshots(),
                builder: (context, propertySnapshot) {
                  if (propertySnapshot.hasError) {
                    return _buildErrorCard('Error loading properties: ${propertySnapshot.error}');
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
                      _buildModernStatCard('Total Users', '${users.length}',
                          Icons.people_rounded, _accentBlue, '+12%'),
                      _buildModernStatCard('Customers', '$customers',
                          Icons.person_rounded, const Color(0xFF10b981), '+8%'),
                      _buildModernStatCard('Agents', '$agents',
                          Icons.business_rounded, const Color(0xFFf59e0b), '+5%'),
                      _buildModernStatCard('Properties', '${properties.length}',
                          Icons.home_rounded, const Color(0xFF06b6d4), '+3%'),
                      _buildModernStatCard('Hostels', '$hostels',
                          Icons.school_rounded, _accentPurple, '+15%'),
                      _buildModernStatCard('Pending Review', '$pendingProperties',
                          Icons.pending_actions_rounded, Colors.red.shade400, ''),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Quick Actions Section
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a2e),
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildModernQuickAction('Add Hostel', Icons.add_home_rounded,
                  _accentPurple, () => setState(() => _selectedSection = 'add_hostel')),
              _buildModernQuickAction('Review Properties', Icons.rate_review_rounded,
                  const Color(0xFF10b981), () => setState(() => _selectedSection = 'review_properties')),
              _buildModernQuickAction('Verification', Icons.verified_user_rounded,
                  const Color(0xFFf59e0b), () => setState(() => _selectedSection = 'verification')),
              _buildModernQuickAction('Send Notification', Icons.send_rounded,
                  const Color(0xFF06b6d4), () => setState(() => _selectedSection = 'send_notifications')),
            ],
          ),

          const SizedBox(height: 32),

          // Recent Hostels Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Hostels',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a1a2e),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedSection = 'manage_hostels'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: _accentPurple,
                ),
              ),
            ],
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
                return _buildErrorCard('Index building. Please wait...');
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final hostels = snapshot.data!.docs;
              if (hostels.isEmpty) {
                return _buildEmptyHostelsCard();
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: hostels.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _accentPurple.withOpacity(0.8),
                                  _accentPurple,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.school_rounded,
                                color: Colors.white, size: 24),
                          ),
                          title: Text(
                            data['title'] ?? 'Unnamed',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                data['location'] ?? 'No location',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _accentPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Manage',
                              style: TextStyle(
                                color: _accentPurple,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () =>
                              setState(() => _selectedSection = 'manage_hostels'),
                        ),
                        if (index < hostels.length - 1)
                          Divider(
                              height: 1,
                              indent: 20,
                              endIndent: 20,
                              color: Colors.grey.shade200),
                      ],
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

  Widget _buildModernStatCard(
      String label, String value, IconData icon, Color color, String trend) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (trend.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernQuickAction(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.8), color],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade800,
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

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.error_outline_rounded,
                color: Colors.red.shade400, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHostelsCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accentPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.school_rounded, size: 48, color: _accentPurple),
          ),
          const SizedBox(height: 20),
          const Text(
            'No hostels added yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a1a2e),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first student hostel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() => _selectedSection = 'add_hostel'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Hostel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
