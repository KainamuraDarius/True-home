import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/role_service.dart';
import '../../widgets/role_switcher.dart';
import '../common/profile_screen.dart';
import '../common/notifications_screen.dart';
import '../property/add_property_screen.dart';
import '../property/my_properties_screen.dart';
import '../common/submit_project_screen.dart';
import '../common/my_projects_screen.dart';
import 'verification_benefits_screen.dart';
import '../admin/admin_verification_requests_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final NotificationService _notificationService = NotificationService();
  final RoleService _roleService = RoleService();
  int _unreadCount = 0;
  UserModel? _currentUser;
  int _refreshKey = 0; // Used to force rebuild of verification banner

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _roleService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _refreshKey++; // Increment to force rebuild
        });
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
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

  Future<Map<String, int>> _getCounts() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    
    // Get total properties count
    final propertiesSnapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: userId)
        .get();
    
    // Get pending submissions count
    final pendingSnapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: PropertyStatus.pending.name)
        .get();
    
    return {
      'properties': propertiesSnapshot.docs.length,
      'submissions': pendingSnapshot.docs.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        actions: [
          // Show role switcher when user data is loaded
          StreamBuilder<UserModel?>(
            stream: _roleService.currentUserStream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return RoleSwitcher(
                  user: snapshot.data!,
                  onRoleChanged: () => _loadCurrentUser(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
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
                  _loadUnreadCount(); // Refresh count after returning
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
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
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
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _getCounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final counts = snapshot.data ?? {'properties': 0, 'submissions': 0};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Submit your properties for listing',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // Add Property Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddPropertyScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_home),
                    label: const Text('Add New Property'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Properties',
                        '${counts['properties']}',
                        Icons.home_outlined,
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Submissions',
                        '${counts['submissions']}',
                        Icons.pending_outlined,
                        AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Verification Status Banner - Always show
                FutureBuilder<UserModel?>(
                  key: ValueKey('verification_banner_$_refreshKey'),
                  future: _roleService.getCurrentUser(),
                  builder: (context, snapshot) {
                    // Get user from future or fallback to state
                    final user = snapshot.data ?? _currentUser;
                    
                    // Don't show if no user data
                    if (user == null) return const SizedBox.shrink();
                    
                    final isVerified = user.isVerified == true;
                    
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isVerified
                              ? [
                                  Colors.blue.withOpacity(0.1),
                                  Colors.blue.withOpacity(0.05),
                                ]
                              : [
                                  const Color(0xFF10B981).withOpacity(0.1),
                                  const Color(0xFF059669).withOpacity(0.1),
                                ],
                        ),
                        border: Border.all(
                          color: isVerified ? Colors.blue : const Color(0xFF10B981),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isVerified ? Colors.blue : const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isVerified ? Icons.verified : Icons.verified_user,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVerified ? '✓ Verified Agent' : 'Verify Your Profile',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isVerified ? Colors.blue.shade900 : const Color(0xFF065F46),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isVerified
                                          ? 'Your profile has been verified and you have access to all premium features'
                                          : 'Build trust and unlock premium features',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isVerified ? Colors.blue.shade700 : const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!isVerified) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const VerificationBenefitsScreen(),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Learn More',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                const SizedBox(height: 8),
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
                _buildActionCard(
                  context,
                  'My Properties',
                  'View and manage all your properties',
                  Icons.list_outlined,
                  AppColors.secondary,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyPropertiesScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  'Advertise Project',
                  'Promote your ongoing project to customers',
                  Icons.campaign_outlined,
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubmitProjectScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  'My Project Ads',
                  'View and track your project advertisements',
                  Icons.analytics_outlined,
                  Colors.purple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyProjectsScreen(),
                      ),
                    );
                  },
                ),
                
                // Admin Only: Verification Requests
                if (_currentUser?.roles.contains(UserRole.admin) ?? false) ...[
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'Verification Requests',
                    'Review and approve agent verifications',
                    Icons.verified_user,
                    const Color(0xFF10B981),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminVerificationRequestsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
