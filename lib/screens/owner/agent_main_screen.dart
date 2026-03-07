import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/role_service.dart';
import '../../widgets/role_switcher.dart';
import 'owner_dashboard_screen.dart';
import '../property/my_properties_screen.dart';
import '../common/my_projects_screen.dart';
import '../common/profile_screen.dart';
import '../common/notifications_screen.dart';

class AgentMainScreen extends StatefulWidget {
  const AgentMainScreen({super.key});

  @override
  State<AgentMainScreen> createState() => _AgentMainScreenState();
}

class _AgentMainScreenState extends State<AgentMainScreen> {
  int _currentIndex = 0;
  final NotificationService _notificationService = NotificationService();
  final RoleService _roleService = RoleService();
  int _unreadCount = 0;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadUnreadCount();
      _loadCurrentUser();
    });
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

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _roleService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  List<Widget> get _screens => [
        const OwnerDashboardScreen(isTabView: true),
        const MyPropertiesScreen(isTabView: true),
        const MyProjectsScreen(isTabView: true),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Role Switcher (only shows if user has multiple roles)
          if (_currentUser != null)
            RoleSwitcher(
              user: _currentUser!,
              onRoleChanged: () {
                // Reload after role change
                _loadCurrentUser();
              },
            ),
          // Notifications
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
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
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
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 14,
        unselectedFontSize: 13,
        iconSize: 28,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Properties',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Advertise Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'My Properties';
      case 2:
        return 'Advertise Projects';
      case 3:
        return 'Profile';
      default:
        return 'Dashboard';
    }
  }
}
