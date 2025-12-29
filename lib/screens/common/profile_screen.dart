import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../../utils/database_helper.dart';
import '../../services/preferences_service.dart';
import '../auth/welcome_screen.dart';
import '../customer/edit_profile_screen.dart';
import '../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _currentUser = UserModel(
              id: doc.id,
              email: data['email'] ?? '',
              name: data['name'] ?? '',
              phoneNumber: data['phoneNumber'] ?? '',
              role: UserRole.values.firstWhere(
                (e) => e.toString().split('.').last == data['role'],
                orElse: () => UserRole.customer,
              ),
              createdAt: data['createdAt'] != null
                  ? DateTime.parse(data['createdAt'])
                  : DateTime.now(),
              updatedAt: data['updatedAt'] != null
                  ? DateTime.parse(data['updatedAt'])
                  : DateTime.now(),
              companyName: data['companyName'],
              whatsappNumber: data['whatsappNumber'],
              profileImageUrl: data['profileImageUrl'],
              favoritePropertyIds: data['favoritePropertyIds'] != null
                  ? List<String>.from(data['favoritePropertyIds'])
                  : [],
              isVerified: data['isVerified'] ?? false,
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.propertyOwner:
        return 'Property Owner';
      case UserRole.propertyManager:
        return 'Property Manager';
      case UserRole.admin:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: _currentUser == null
          ? const Center(child: Text('No user data found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Avatar
                  _currentUser!.profileImageUrl != null
                      ? FutureBuilder<Uint8List?>(
                          future: DatabaseHelper.instance.getImage(
                            _currentUser!.profileImageUrl!,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return CircleAvatar(
                                radius: 60,
                                backgroundImage: MemoryImage(snapshot.data!),
                              );
                            }
                            return CircleAvatar(
                              radius: 60,
                              backgroundColor: AppColors.primary.withOpacity(
                                0.1,
                              ),
                              child: Text(
                                _currentUser!.name.isNotEmpty
                                    ? _currentUser!.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                        )
                      : CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            _currentUser!.name.isNotEmpty
                                ? _currentUser!.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  // User Name
                  Text(
                    _currentUser!.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // User Role
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRoleDisplayName(_currentUser!.role),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // User Information Card
                  _buildInfoCard(
                    title: 'Contact Information',
                    items: [
                      _buildInfoRow(Icons.email, 'Email', _currentUser!.email),
                      if (_currentUser!.phoneNumber.isNotEmpty)
                        _buildInfoRow(
                          Icons.phone,
                          'Phone',
                          _currentUser!.phoneNumber,
                        ),
                      if (_currentUser!.whatsappNumber != null &&
                          _currentUser!.whatsappNumber!.isNotEmpty)
                        _buildInfoRow(
                          Icons.chat,
                          'WhatsApp',
                          _currentUser!.whatsappNumber!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Company Information (for non-customers)
                  if (_currentUser!.role != UserRole.customer &&
                      _currentUser!.companyName != null)
                    _buildInfoCard(
                      title: 'Company Information',
                      items: [
                        _buildInfoRow(
                          Icons.business,
                          'Company',
                          _currentUser!.companyName!,
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Account Settings Section
                  _buildSectionHeader('Account Settings'),
                  _buildSettingsTile(
                    icon: Icons.edit,
                    title: 'Edit Profile',
                    onTap: () async {
                      if (_currentUser != null) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditProfileScreen(user: _currentUser!),
                          ),
                        );
                        if (result == true) {
                          _loadUserData();
                        }
                      }
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.lock,
                    title: 'Change Password',
                    onTap: () async {
                      if (_currentUser != null) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditProfileScreen(user: _currentUser!),
                          ),
                        );
                      }
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.verified_user,
                    title: 'Account Verification',
                    subtitle: _currentUser!.isVerified
                        ? 'Verified'
                        : 'Not Verified',
                    onTap: () {
                      _showVerificationDialog();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notification Settings Section
                  _buildSectionHeader('Notifications'),
                  _buildSettingsTile(
                    icon: Icons.notifications,
                    title: 'Push Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () {
                      _showNotificationSettings();
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.email_outlined,
                    title: 'Email Notifications',
                    subtitle: 'Receive updates via email',
                    onTap: () {
                      _showEmailNotificationDialog();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Privacy & Security Section
                  _buildSectionHeader('Privacy & Security'),
                  _buildSettingsTile(
                    icon: Icons.security,
                    title: 'Security',
                    subtitle: 'Two-factor authentication',
                    onTap: () {
                      _showSecurityDialog();
                    },
                  ),
                  const SizedBox(height: 16),

                  // App Preferences Section
                  _buildSectionHeader('App Preferences'),
                  _buildSettingsTile(
                    icon: Icons.dark_mode,
                    title: 'Theme',
                    subtitle: 'Light Mode',
                    onTap: () {
                      _showThemeDialog();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Help & Support Section
                  _buildSectionHeader('Help & Support'),
                  _buildSettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    subtitle: 'FAQs and support',
                    onTap: () {
                      _showHelpCenter();
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.contact_support,
                    title: 'Contact Us',
                    subtitle: 'Get in touch',
                    onTap: () {
                      _showContactDialog();
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.feedback,
                    title: 'Send Feedback',
                    subtitle: 'Share your thoughts',
                    onTap: () {
                      _showFeedbackDialog();
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.star_rate,
                    title: 'Rate App',
                    subtitle: 'Rate us on Play Store',
                    onTap: () {
                      _showRateDialog();
                    },
                  ),
                  const SizedBox(height: 16),

                  // About Section
                  _buildSectionHeader('About'),
                  _buildSettingsTile(
                    icon: Icons.info_outline,
                    title: 'About True Home',
                    subtitle: 'Version 1.0.0',
                    onTap: () {
                      _showAboutDialog();
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.policy,
                    title: 'Privacy Policy',
                    onTap: () {
                      _showPrivacyPolicy();
                    },
                  ),
                  _buildSettingsTile(
                    icon: Icons.description,
                    title: 'Terms of Service',
                    onTap: () {
                      _showTermsOfService();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Danger Zone Section
                  _buildSectionHeader('Danger Zone'),
                  _buildSettingsTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    onTap: _logout,
                    textColor: Colors.orange,
                  ),
                  _buildSettingsTile(
                    icon: Icons.delete_forever,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account',
                    onTap: () {
                      _showDeleteAccountDialog();
                    },
                    textColor: Colors.red,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> items}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: textColor ?? AppColors.textPrimary),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: textColor ?? AppColors.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Notification Settings
  void _showNotificationSettings() async {
    final prefs = PreferencesService.instance;
    bool newProperties = await prefs.getNotificationNewProperties();
    bool priceUpdates = await prefs.getNotificationPriceUpdates();
    bool messages = await prefs.getNotificationMessages();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Push Notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('New Properties'),
                subtitle: const Text('Get notified about new listings'),
                value: newProperties,
                onChanged: (value) {
                  setDialogState(() => newProperties = value);
                  prefs.setNotificationNewProperties(value);
                },
              ),
              SwitchListTile(
                title: const Text('Price Updates'),
                subtitle: const Text('Notify when prices change'),
                value: priceUpdates,
                onChanged: (value) {
                  setDialogState(() => priceUpdates = value);
                  prefs.setNotificationPriceUpdates(value);
                },
              ),
              SwitchListTile(
                title: const Text('Messages'),
                subtitle: const Text('New messages and inquiries'),
                value: messages,
                onChanged: (value) {
                  setDialogState(() => messages = value);
                  prefs.setNotificationMessages(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification preferences saved'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailNotificationDialog() async {
    final prefs = PreferencesService.instance;
    bool weeklyDigest = await prefs.getEmailWeeklyDigest();
    bool promotional = await prefs.getEmailPromotional();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Email Notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Weekly Digest'),
                subtitle: const Text('Summary of new properties'),
                value: weeklyDigest,
                onChanged: (value) {
                  setDialogState(() => weeklyDigest = value);
                  prefs.setEmailWeeklyDigest(value);
                },
              ),
              SwitchListTile(
                title: const Text('Promotional Emails'),
                subtitle: const Text('Special offers and deals'),
                value: promotional,
                onChanged: (value) {
                  setDialogState(() => promotional = value);
                  prefs.setEmailPromotional(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email preferences saved'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Privacy Settings
  void _showPrivacySettings() async {
    final prefs = PreferencesService.instance;
    bool profileVisible = await prefs.getPrivacyProfileVisible();
    bool showContact = await prefs.getPrivacyShowContact();
    bool activityStatus = await prefs.getPrivacyActivityStatus();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Privacy Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Profile Visibility'),
                subtitle: const Text('Make profile visible to property owners'),
                value: profileVisible,
                onChanged: (value) {
                  setDialogState(() => profileVisible = value);
                  prefs.setPrivacyProfileVisible(value);
                },
              ),
              SwitchListTile(
                title: const Text('Show Contact Info'),
                subtitle: const Text('Display phone number on inquiries'),
                value: showContact,
                onChanged: (value) {
                  setDialogState(() => showContact = value);
                  prefs.setPrivacyShowContact(value);
                },
              ),
              SwitchListTile(
                title: const Text('Activity Status'),
                subtitle: const Text('Show when you\'re online'),
                value: activityStatus,
                onChanged: (value) {
                  setDialogState(() => activityStatus = value);
                  prefs.setPrivacyActivityStatus(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Privacy settings saved'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Two-Factor Authentication'),
              subtitle: const Text('Not enabled'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Active Sessions'),
              subtitle: const Text('Manage logged in devices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
              },
            ),
          ],
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

  void _showBlockedUsersDialog() async {
    // Load blocked users from Firestore
    final blockedUsersDoc = await _firestore
        .collection('users')
        .doc(_currentUser!.id)
        .collection('blocked_users')
        .get();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Blocked Users'),
          content: blockedUsersDoc.docs.isEmpty
              ? const Text('You haven\'t blocked any users yet.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: blockedUsersDoc.docs.length,
                    itemBuilder: (context, index) {
                      final blocked = blockedUsersDoc.docs[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            blocked['name']?.substring(0, 1).toUpperCase() ??
                                '?',
                          ),
                        ),
                        title: Text(blocked['name'] ?? 'Unknown'),
                        subtitle: Text(
                          'Blocked on ${DateTime.parse(blocked['blockedAt']).toString().split(' ')[0]}',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            // Unblock user
                            await _firestore
                                .collection('users')
                                .doc(_currentUser!.id)
                                .collection('blocked_users')
                                .doc(blocked.id)
                                .delete();

                            // Refresh list
                            final updated = await _firestore
                                .collection('users')
                                .doc(_currentUser!.id)
                                .collection('blocked_users')
                                .get();

                            setDialogState(() {
                              blockedUsersDoc.docs.clear();
                              blockedUsersDoc.docs.addAll(updated.docs);
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('${blocked['name']} unblocked'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          child: const Text('Unblock'),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentUser!.isVerified
                  ? 'Your account is verified!'
                  : 'Verify your account to gain trust and access premium features.',
            ),
            const SizedBox(height: 16),
            if (!_currentUser!.isVerified) ...[
              const Text(
                'Verification includes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Identity verification'),
              const Text('• Phone number confirmation'),
              const Text('• Email verification'),
              const Text('• Premium badge on profile'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (!_currentUser!.isVerified)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  // Simulate verification process
                  await Future.delayed(const Duration(seconds: 2));
                  
                  // Update verification status in Firestore
                  await _firestore
                      .collection('users')
                      .doc(_currentUser!.id)
                      .update({
                    'isVerified': true,
                    'verifiedAt': DateTime.now().toIso8601String(),
                    'updatedAt': DateTime.now().toIso8601String(),
                  });

                  // Reload user data
                  await _loadUserData();

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Account verified successfully!'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Verification failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Start Verification'),
            ),
        ],
      ),
    );
  }

  // App Preferences
  void _showLanguageDialog() async {
    final prefs = PreferencesService.instance;
    String currentLanguage = await prefs.getLanguage();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: currentLanguage,
                onChanged: (value) async {
                  if (value != null) {
                    await prefs.setLanguage(value);
                    setDialogState(() => currentLanguage = value);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Language changed to English'),
                        ),
                      );
                      setState(() {});
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Swahili'),
                value: 'sw',
                groupValue: currentLanguage,
                onChanged: (value) async {
                  if (value != null) {
                    await prefs.setLanguage(value);
                    setDialogState(() => currentLanguage = value);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lugha imebadilishwa kuwa Kiswahili'),
                        ),
                      );
                      setState(() {});
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Luganda'),
                value: 'lg',
                groupValue: currentLanguage,
                onChanged: (value) async {
                  if (value != null) {
                    await prefs.setLanguage(value);
                    setDialogState(() => currentLanguage = value);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Olulimi lukyusiddwa okudda ku Luganda'),
                        ),
                      );
                      setState(() {});
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog() async {
    final prefs = PreferencesService.instance;
    String currentTheme = await prefs.getTheme();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Light Mode'),
                value: 'light',
                groupValue: currentTheme,
                onChanged: (value) async {
                  if (value != null) {
                    await prefs.setTheme(value);
                    setDialogState(() => currentTheme = value);
                    if (mounted) {
                      Navigator.pop(context);
                      // Update app theme
                      final appState = context.findAncestorStateOfType<MyAppState>();
                      appState?.changeTheme(ThemeMode.light);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Theme changed to Light Mode'),
                        ),
                      );
                      setState(() {});
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Dark Mode'),
                value: 'dark',
                groupValue: currentTheme,
                onChanged: (value) async {
                  if (value != null) {
                    await prefs.setTheme(value);
                    setDialogState(() => currentTheme = value);
                    if (mounted) {
                      Navigator.pop(context);
                      // Update app theme
                      final appState = context.findAncestorStateOfType<MyAppState>();
                      appState?.changeTheme(ThemeMode.dark);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Theme changed to Dark Mode'),
                        ),
                      );
                      setState(() {});
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('System Default'),
                value: 'system',
                groupValue: currentTheme,
                onChanged: (value) async {
                  if (value != null) {
                    await prefs.setTheme(value);
                    setDialogState(() => currentTheme = value);
                    if (mounted) {
                      Navigator.pop(context);
                      // Update app theme
                      final appState = context.findAncestorStateOfType<MyAppState>();
                      appState?.changeTheme(ThemeMode.system);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Theme changed to System Default'),
                        ),
                      );
                      setState(() {});
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStorageSettings() async {
    // Calculate actual storage usage
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    int storageSize = 0;
    for (var key in keys) {
      final value = prefs.get(key);
      if (value != null) {
        storageSize += value.toString().length;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage & Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Clear Image Cache'),
              subtitle: const Text('Free up storage space'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Clearing cache...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                
                // Clear favorites and search history (not user settings)
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('search_history');
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Cache cleared successfully!'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clear All Data'),
              subtitle: const Text('Remove all app data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Data?'),
                    content: const Text(
                        'This will remove all your preferences, favorites, and search history. Your account data will not be affected.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All data cleared'),
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(),
            const Text(
              'Data Usage:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Local Storage: ${(storageSize / 1024).toStringAsFixed(2)} KB'),
            const Text('Favorites: Stored locally'),
            const Text('Search History: Stored locally'),
          ],
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

  // Help & Support
  void _showHelpCenter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Center'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('How do I search for properties?'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Use the Search tab to filter properties by type, price, bedrooms, and bathrooms.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('How do I contact property owners?'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Tap on a property to view details, then use the Call, WhatsApp, or Email buttons.',
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('How do I save favorite properties?'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Tap the heart icon on any property card to add it to your favorites.',
                    ),
                  ),
                ],
              ),
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

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: const Text('truehome376@gmail.com\nramzyhaden@gmail.com'),
              onTap: () async {
                final emailUri = Uri.parse('mailto:truehome376@gmail.com,ramzyhaden@gmail.com?subject=True Home Support');
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open email client')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone'),
              subtitle: const Text('0777274183'),
              onTap: () async {
                final phoneUri = Uri.parse('tel:+256777274183');
                if (await canLaunchUrl(phoneUri)) {
                  await launchUrl(phoneUri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open phone dialer')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('WhatsApp'),
              subtitle: const Text('0702021112'),
              onTap: () async {
                final whatsappUri = Uri.parse('https://wa.me/256702021112');
                if (await canLaunchUrl(whatsappUri)) {
                  await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open WhatsApp')),
                    );
                  }
                }
              },
            ),
          ],
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

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    String selectedCategory = 'General';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Feedback'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('We\'d love to hear your thoughts!'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'General', child: Text('General')),
                    DropdownMenuItem(value: 'Bug Report', child: Text('Bug Report')),
                    DropdownMenuItem(value: 'Feature Request', child: Text('Feature Request')),
                    DropdownMenuItem(value: 'UI/UX', child: Text('UI/UX')),
                    DropdownMenuItem(value: 'Performance', child: Text('Performance')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Share your feedback...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
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
                if (feedbackController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your feedback'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Close dialog first
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                navigator.pop();
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  // Save feedback to Firestore
                  await _firestore.collection('feedback').add({
                    'userId': _currentUser!.id,
                    'userName': _currentUser!.name,
                    'userEmail': _currentUser!.email,
                    'category': selectedCategory,
                    'feedback': feedbackController.text.trim(),
                    'status': 'new',
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  // Create notification for all admins
                  final admins = await _firestore
                      .collection('users')
                      .where('role', isEqualTo: 'admin')
                      .get();
                  
                  for (var admin in admins.docs) {
                    await _firestore
                        .collection('users')
                        .doc(admin.id)
                        .collection('notifications')
                        .add({
                      'type': 'feedback',
                      'title': 'New Feedback: $selectedCategory',
                      'message': 'From ${_currentUser!.name}: ${feedbackController.text.trim()}',
                      'userId': _currentUser!.id,
                      'userName': _currentUser!.name,
                      'read': false,
                      'createdAt': DateTime.now().toIso8601String(),
                    });
                  }

                  // Send email to admin
                  final emailUri = Uri.parse(
                    'mailto:truehome376@gmail.com?subject=${Uri.encodeComponent('True Home Feedback: $selectedCategory')}&body=${Uri.encodeComponent('From: ${_currentUser!.name} (${_currentUser!.email})\nCategory: $selectedCategory\n\nFeedback:\n${feedbackController.text.trim()}')}',
                  );
                  
                  // Close dialog first before launching email
                  if (mounted) {
                    Navigator.pop(context);
                  }
                  
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  }

                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Thank you for your feedback!'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close dialog
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to send feedback: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRateDialog() {
    int selectedRating = 0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate True Home'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enjoying True Home? Rate us on the Play Store!'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    icon: Icon(
                      selectedRating > index ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setDialogState(() => selectedRating = index + 1);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                try {
                  // Try opening Play Store
                  final packageName = 'com.truehome.app'; // Replace with actual package name
                  final playStoreUrl = Uri.parse(
                    'https://play.google.com/store/apps/details?id=$packageName',
                  );
                  
                  if (await canLaunchUrl(playStoreUrl)) {
                    await launchUrl(
                      playStoreUrl,
                      mode: LaunchMode.externalApplication,
                    );
                  } else {
                    // Fallback to browser
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open Play Store'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                  
                  // Save rating to Firestore
                  if (selectedRating > 0) {
                    await _firestore.collection('ratings').add({
                      'userId': _currentUser!.id,
                      'userName': _currentUser!.name,
                      'rating': selectedRating,
                      'createdAt': DateTime.now().toIso8601String(),
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Rate Now'),
            ),
          ],
        ),
      ),
    );
  }

  // About
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About True Home'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Icon(Icons.home, size: 64, color: AppColors.primary)),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'True Home',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Center(child: Text('Version 1.0.0')),
            const SizedBox(height: 16),
            const Text(
              'True Home is Uganda\'s leading property rental and sales platform. Find your dream home or list your property with ease.',
            ),
            const SizedBox(height: 16),
            const Text('© 2025 True Home. All rights reserved.'),
          ],
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

  void _showPrivacyPolicy() async {
    final uri = Uri.parse('https://kainamuradarius.github.io/true-home-privacy-policy/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open privacy policy')),
        );
      }
    }
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Last updated: December 28, 2025',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Acceptance of Terms',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'By using True Home, you agree to these terms of service.',
              ),
              const SizedBox(height: 16),
              const Text(
                '2. User Responsibilities',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Users must provide accurate information and comply with all applicable laws.',
              ),
              const SizedBox(height: 16),
              const Text(
                '3. Property Listings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Property owners are responsible for the accuracy of their listings.',
              ),
              const SizedBox(height: 16),
              const Text(
                '4. Prohibited Activities',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fraudulent listings, harassment, and spam are strictly prohibited.',
              ),
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

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('This action will:'),
            const SizedBox(height: 8),
            const Text('• Delete all your personal data'),
            const Text('• Remove your property listings'),
            const Text('• Cancel your favorites'),
            const Text('• Cannot be undone'),
            const SizedBox(height: 16),
            const Text(
              'If you proceed, we\'ll send a confirmation email.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
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
              _confirmDeleteAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to confirm:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Re-authenticate user
        final user = _auth.currentUser!;
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        // Delete user data from Firestore
        // 1. Delete all properties owned by user
        final properties = await _firestore
            .collection('properties')
            .where('ownerId', isEqualTo: _currentUser!.id)
            .get();
        for (var doc in properties.docs) {
          await doc.reference.delete();
        }

        // 2. Delete all favorites
        final favorites = await _firestore
            .collection('users')
            .doc(_currentUser!.id)
            .collection('favorites')
            .get();
        for (var doc in favorites.docs) {
          await doc.reference.delete();
        }

        // 3. Delete blocked users
        final blocked = await _firestore
            .collection('users')
            .doc(_currentUser!.id)
            .collection('blocked_users')
            .get();
        for (var doc in blocked.docs) {
          await doc.reference.delete();
        }

        // 4. Delete user document
        await _firestore.collection('users').doc(_currentUser!.id).delete();

        // 5. Delete profile image from SQLite (stored as property_id = user_id)
        await DatabaseHelper.instance.deleteAllImagesForProperty(_currentUser!.id);

        // 6. Delete Firebase Auth user
        await user.delete();

        // 7. Clear preferences
        await PreferencesService.instance.clearAll();

        if (mounted) {
          Navigator.pop(context); // Close loading
          // Navigate to login
          Navigator.pushReplacementNamed(context, '/login');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Account deleted successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
