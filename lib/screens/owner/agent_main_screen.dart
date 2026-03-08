import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../services/notification_service.dart';
import '../../services/role_service.dart';
import '../../widgets/role_switcher.dart';
import '../../models/user_model.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  Future<void> _loadCurrentUser() async {
    final user = await _roleService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
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

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  List<Widget> get _screens => [
        const OwnerDashboardScreen(isTabView: true),
        const MyPropertiesScreen(isTabView: true),
        const MyProjectsScreen(isTabView: true),
        const ProfileScreen(showWebFooter: true),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        toolbarHeight: 70,
        automaticallyImplyLeading: false,
        leading: kIsWeb
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.menu, size: 32),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              )
            : null,
        title: Text(_getAppBarTitle()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: RoleSwitcher(
                user: _currentUser!,
                onRoleChanged: () => _loadCurrentUser(),
              ),
            ),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 28),
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
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
      drawer: kIsWeb ? _buildDrawer() : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: kIsWeb ? null : BottomNavigationBar(
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

  Widget _buildDrawer() {
    return Drawer(
        width: 300,
      child: Column(
        children: [
          // Header with user info
          UserAccountsDrawerHeader(
                         margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
              ),
            ),
            accountName: Text(
              _currentUser?.name ?? 'Agent',
              style: const TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: 20,
              ),
            ),
            accountEmail: Text(
              _currentUser?.email ?? '',
               style: const TextStyle(fontSize: 15),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
                             radius: 32,
              child: Text(
                (_currentUser?.name ?? 'A')[0].toUpperCase(),
                style: TextStyle(
                   fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          // Navigation items
          Expanded(
             child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Dashboard',
                    index: 0,
                  ),
                  _buildDrawerItem(
                    icon: Icons.home,
                    title: 'Properties',
                    index: 1,
                  ),
                  _buildDrawerItem(
                    icon: Icons.campaign,
                    title: 'Advertise Projects',
                    index: 2,
                  ),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Profile',
                    index: 3,
                  ),
                ],
             ),
          ),

          // Footer
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'True Home Agent',
              style: TextStyle(
                color: Colors.grey.shade600,
                 fontSize: 13,
                 fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Icon(
        icon,
        size: 28,
        color: isSelected ? AppColors.primary : Colors.grey.shade700,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isSelected ? AppColors.primary : Colors.grey.shade800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: () {
        _onTabTapped(index);
         // Close drawer using the main scaffold key
         _scaffoldKey.currentState?.closeDrawer();
      },
    );
  }
}
