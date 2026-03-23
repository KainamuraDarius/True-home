import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../../models/property_model.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/role_service.dart';
import '../../services/pandora_payment_service.dart';
import '../../widgets/role_switcher.dart';
import '../common/profile_screen.dart';
import '../common/notifications_screen.dart';
import '../property/add_property_screen.dart';
import '../property/my_properties_screen.dart';
import '../property/choose_plan_screen.dart';
import '../common/submit_project_screen.dart';
import '../common/my_projects_screen.dart';
import 'verification_benefits_screen.dart';
import '../organization/enterprise_setup_screen.dart';
import '../organization/team_management_screen.dart';
import '../organization/plan_team_management_screen.dart';
import '../admin/admin_verification_requests_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final bool isTabView;

  const OwnerDashboardScreen({super.key, this.isTabView = false});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final NotificationService _notificationService = NotificationService();
  final RoleService _roleService = RoleService();
  final PandoraPaymentService _pandoraService = PandoraPaymentService();
  int _unreadCount = 0;
  UserModel? _currentUser;
  int _refreshKey = 0; // Used to force rebuild of verification banner
  Map<String, int>? _cachedCounts; // Cache counts to avoid reloading
  bool _isLoadingCounts = false;
  bool _isPayingPlan = false;
  bool _hasManagePlanAndTeamAccess = false;

  @override
  void initState() {
    super.initState();

    // Load counts immediately in background
    Future.microtask(() {
      _loadUnreadCount();
      _loadCurrentUser();
      _loadCounts();
      _loadPlanAccess();
    });
  }

  Future<void> _loadCounts() async {
    if (_isLoadingCounts) return;

    setState(() {
      _isLoadingCounts = true;
    });

    try {
      final counts = await _getCounts();
      if (mounted) {
        setState(() {
          _cachedCounts = counts;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading counts: $e');
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
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

    // Get total properties count and calculate total views
    final propertiesSnapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: userId)
        .get();

    // Calculate total views across all properties
    int totalViews = 0;
    for (var doc in propertiesSnapshot.docs) {
      final data = doc.data();
      totalViews += (data['viewCount'] ?? 0) as int;
    }

    // Get pending submissions count
    final pendingSnapshot = await FirebaseFirestore.instance
        .collection('properties')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: PropertyStatus.pending.name)
        .get();

    return {
      'properties': propertiesSnapshot.docs.length,
      'submissions': pendingSnapshot.docs.length,
      'totalViews': totalViews,
    };
  }

  Future<void> _saveSelectedPlan({
    required String plan,
    required String period,
    required int price,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{
      'selectedPlan': plan,
      'selectedPlanPeriod': period,
      'selectedPlanPrice': price,
      'selectedPlanStatus': 'active',
      'selectedPlanActivatedAt': DateTime.now().toIso8601String(),
      'planUpdatedAt': DateTime.now().toIso8601String(),
    };

    final normalizedPlan = plan.trim().toLowerCase();
    if (normalizedPlan == 'agent' || normalizedPlan == 'enterprise') {
      updates.addAll({
        'isVerified': true,
        'verificationStatus': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(updates);

    await _loadPlanAccess();
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  int _readInt(
    Map<String, dynamic> data,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value != null) {
        final parsed = int.tryParse(value.toString().trim());
        if (parsed != null) return parsed;
      }
    }
    return fallback;
  }

  bool _readBool(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
      if (value != null) {
        final normalized = value.toString().trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
    }
    return false;
  }

  String _resolvePlanStatus(Map<String, dynamic> userData) {
    return _readString(userData, [
      'selectedPlanStatus',
      'planStatus',
      'subscriptionStatus',
      'status',
    ], fallback: 'active').toLowerCase();
  }

  String _resolveEffectivePlanId(Map<String, dynamic> userData) {
    final activeOrganizationId = (userData['activeOrganizationId'] ?? '')
        .toString()
        .trim();
    final rawPlan = _readString(userData, [
      'selectedPlan',
      'plan',
      'planType',
      'plan_type',
      'subscriptionPlan',
      'activePlan',
    ], fallback: 'free');

    final normalized = _normalizedPlanId(
      rawPlan: rawPlan,
      activeOrganizationId: activeOrganizationId,
    );
    if (normalized == 'agent' || normalized == 'enterprise') {
      return normalized;
    }

    final explicitPaid = _readBool(userData, ['hasPaidPlan', 'isPlanActive']);
    final price = _readInt(userData, [
      'selectedPlanPrice',
      'planPrice',
      'subscriptionPrice',
      'price',
      'amount',
    ]);
    if (activeOrganizationId.isNotEmpty) return 'enterprise';
    if (explicitPaid || price > 0) return 'agent';
    return normalized;
  }

  String _normalizedPlanId({
    required String rawPlan,
    String activeOrganizationId = '',
  }) {
    final normalized = rawPlan.trim().toLowerCase();
    if (normalized.contains('enterprise')) return 'enterprise';
    if (normalized.contains('agent')) return 'agent';
    if (activeOrganizationId.trim().isNotEmpty) return 'enterprise';
    if (normalized.contains('starter') || normalized == 'free') return 'free';
    if (normalized == 'monthly' ||
        normalized == 'annual' ||
        normalized == 'yearly') {
      return 'agent';
    }
    return normalized;
  }

  bool _hasActivePaidPlan(Map<String, dynamic> userData) {
    final selectedPlan = _resolveEffectivePlanId(userData);
    final planStatus = _resolvePlanStatus(userData);

    final isStatusActive =
        planStatus != 'inactive' &&
        planStatus != 'expired' &&
        planStatus != 'cancelled';
    final isPaidPlan = selectedPlan == 'agent' || selectedPlan == 'enterprise';

    return isPaidPlan && isStatusActive;
  }

  Future<bool> _loadPlanAccess() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final hasAccess = _hasActivePaidPlan(userData);

      if (hasAccess && userData['isVerified'] != true) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isVerified': true,
          'verificationStatus': 'approved',
          'verifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        setState(() {
          _hasManagePlanAndTeamAccess = hasAccess;
        });
      }
      return hasAccess;
    } catch (e) {
      debugPrint('Error loading plan access: $e');
      return _hasManagePlanAndTeamAccess;
    }
  }

  Future<bool> _isPlanAlreadyActive(String plan) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!userDoc.exists) return false;

    final data = userDoc.data() ?? <String, dynamic>{};
    final selectedPlan = _resolveEffectivePlanId(data);
    final requestedPlan = _normalizedPlanId(rawPlan: plan);
    final planStatus = _resolvePlanStatus(data);

    if (selectedPlan != requestedPlan) return false;
    return planStatus != 'inactive' &&
        planStatus != 'expired' &&
        planStatus != 'cancelled';
  }

  Future<void> _openManagePlanAndTeam() async {
    if (!mounted) return;
    final hasAccess = await _loadPlanAccess();
    if (!mounted) return;
    if (!hasAccess && !_hasManagePlanAndTeamAccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activate Agent or Enterprise plan using Upgrade to Entreprise.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PlanTeamManagementScreen()),
    );

    if (!mounted) return;
    if (action == 'openPlanChooser') {
      await _openPlanManagement();
      await _loadPlanAccess();
    }
  }

  Future<bool> _showPlanPaymentDialog({
    required String plan,
    required String period,
    required int price,
  }) async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool paymentSuccess = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.payment,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Text('Confirm Payment'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan: ${plan.toUpperCase()}'),
                    const SizedBox(height: 8),
                    Text(
                      'Period: ${(period == 'annual' || period == 'yearly') ? 'Yearly (Save 20%)' : 'Monthly'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Amount: UGX ${price.toString().replaceAllMapped(RegExp(r"\B(?=(\d{3})+(?!\d))"), (match) => ",")}',
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: formKey,
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Money Number',
                          hintText: 'e.g. 2567XXXXXXXX',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter phone number'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isPayingPlan
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _isPayingPlan
                      ? null
                      : () {
                          paymentSuccess = true;
                          Navigator.pop(context);
                        },
                  child: const Text('Skip Payment (Test)'),
                ),
                ElevatedButton(
                  onPressed: _isPayingPlan
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => _isPayingPlan = true);

                          final transactionRef =
                              'AGENTPLAN_${DateTime.now().millisecondsSinceEpoch}';
                          final narrative =
                              'Agent Plan: ${plan.toUpperCase()} (${(period == 'annual' || period == 'yearly') ? 'Yearly' : 'Monthly'})';

                          try {
                            final response = await _pandoraService
                                .initiatePayment(
                                  phoneNumber: phoneController.text.trim(),
                                  amount: price.toDouble(),
                                  transactionRef: transactionRef,
                                  narrative: narrative,
                                );
                            if (!response.success) {
                              throw PaymentException(response.message);
                            }

                            if (context.mounted) {
                              await showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text(
                                        'Check your phone to complete payment...',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            await Future.delayed(const Duration(seconds: 3));
                            paymentSuccess = true;

                            if (context.mounted) {
                              Navigator.pop(context); // Close waiting dialog
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Payment Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => _isPayingPlan = false);
                            if (paymentSuccess && context.mounted) {
                              Navigator.pop(context); // Close payment dialog
                            }
                          }
                        },
                  child: _isPayingPlan
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Proceed to Pay'),
                ),
              ],
            );
          },
        );
      },
    );

    return paymentSuccess;
  }

  Future<void> _openPlanManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChoosePlanScreen(
          onCancel: () => Navigator.of(context).pop(),
          onSkip: () => Navigator.of(context).pop(),
          onPlanSelected: (plan, period, price) async {
            final alreadyActive = await _isPlanAlreadyActive(plan);
            if (alreadyActive) {
              if (!mounted) return;
              Navigator.of(this.context).pop();

              if (plan == 'enterprise') {
                await _openEnterpriseWorkspace(requireSetupCompletion: false);
              }

              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${plan.toUpperCase()} plan is already active.',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
              return;
            }

            if (plan == 'free') {
              await _saveSelectedPlan(plan: plan, period: period, price: price);
              if (!mounted) return;
              Navigator.of(this.context).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Starter plan selected.'),
                  backgroundColor: Colors.green,
                ),
              );
              return;
            }

            if (plan == 'enterprise') {
              if (!mounted) return;
              Navigator.of(this.context).pop();

              final workspaceReady = await _openEnterpriseWorkspace(
                requireSetupCompletion: true,
              );
              if (!workspaceReady || !mounted) return;

              final paymentSuccess = await _showPlanPaymentDialog(
                plan: plan,
                period: period,
                price: price,
              );
              if (!paymentSuccess || !mounted) return;

              await _saveSelectedPlan(plan: plan, period: period, price: price);
              if (!mounted) return;

              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Enterprise plan activated successfully.'),
                  backgroundColor: Colors.green,
                ),
              );
              return;
            }

            final paymentSuccess = await _showPlanPaymentDialog(
              plan: plan,
              period: period,
              price: price,
            );
            if (!paymentSuccess || !mounted) return;

            await _saveSelectedPlan(plan: plan, period: period, price: price);
            if (!mounted) return;

            Navigator.of(this.context).pop();

            ScaffoldMessenger.of(this.context).showSnackBar(
              SnackBar(
                content: Text(
                  '${plan.toUpperCase()} plan activated successfully.',
                ),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<bool> _openEnterpriseWorkspace({
    required bool requireSetupCompletion,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final orgId = (userDoc.data()?['activeOrganizationId'] ?? '')
        .toString()
        .trim();
    if (orgId.isEmpty) {
      if (!mounted) return false;
      if (requireSetupCompletion) {
        final setupFinished = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const EnterpriseSetupScreen(completeInFlow: true),
          ),
        );
        if (setupFinished != true) {
          return false;
        }
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnterpriseSetupScreen()),
        );
      }
    } else {
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      if (!orgDoc.exists) {
        if (!mounted) return false;
        if (requireSetupCompletion) {
          final setupFinished = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const EnterpriseSetupScreen(completeInFlow: true),
            ),
          );
          if (setupFinished != true) {
            return false;
          }
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EnterpriseSetupScreen()),
          );
        }
      } else {
        final orgName = (orgDoc.data()?['name'] ?? 'Enterprise Workspace')
            .toString()
            .trim();
        if (!mounted) return false;
        if (requireSetupCompletion) {
          final setupFinished = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TeamManagementScreen(
                organizationId: orgId,
                organizationName: orgName.isEmpty
                    ? 'Enterprise Workspace'
                    : orgName,
                showFinishButton: true,
              ),
            ),
          );
          if (setupFinished != true) {
            return false;
          }
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamManagementScreen(
                organizationId: orgId,
                organizationName: orgName.isEmpty
                    ? 'Enterprise Workspace'
                    : orgName,
              ),
            ),
          );
        }
      }
    }

    if (!requireSetupCompletion) {
      return true;
    }

    final refreshedUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final refreshedOrgId =
        (refreshedUserDoc.data()?['activeOrganizationId'] ?? '')
            .toString()
            .trim();
    if (refreshedOrgId.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete enterprise workspace setup before payment.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _cachedCounts == null && _isLoadingCounts
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) {
              final counts =
                  _cachedCounts ??
                  {'properties': 0, 'submissions': 0, 'totalViews': 0};

              if (kIsWeb && widget.isTabView) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: IntrinsicHeight(
                      child: _buildDashboardContent(counts),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildDashboardContent(counts),
              );
            },
          );

    return Scaffold(
      appBar: widget.isTabView
          ? null
          : AppBar(
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
                        builder: (context) =>
                            const ProfileScreen(showWebFooter: false),
                      ),
                    );
                  },
                ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(child: bodyContent),
          if (!_hasManagePlanAndTeamAccess)
            Positioned(
              top: 12,
              right: 12,
              child: FloatingActionButton.extended(
                heroTag: 'upgrade_plan_fab',
                tooltip: 'Upgrade to Entreprise',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: _openPlanManagement,
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Upgrade to Entreprise'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(Map<String, int> counts) {
    return Column(
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
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
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
        const SizedBox(height: 12),
        if (_hasManagePlanAndTeamAccess)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openManagePlanAndTeam,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Manage Plan & Team'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
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
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Views',
                '${counts['totalViews']}',
                Icons.visibility_outlined,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Pending',
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
                          Colors.blue.withValues(alpha: 0.1),
                          Colors.blue.withValues(alpha: 0.05),
                        ]
                      : [
                          const Color(0xFF10B981).withValues(alpha: 0.1),
                          const Color(0xFF059669).withValues(alpha: 0.1),
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
                          color: isVerified
                              ? Colors.blue
                              : const Color(0xFF10B981),
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
                              isVerified
                                  ? '✓ Verified Agent'
                                  : 'Verify Your Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isVerified
                                    ? Colors.blue.shade900
                                    : const Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isVerified
                                  ? 'Your profile has been verified and you have access to all premium features'
                                  : 'Build trust and unlock premium features',
                              style: TextStyle(
                                fontSize: 13,
                                color: isVerified
                                    ? Colors.blue.shade700
                                    : const Color(0xFF047857),
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
                                  builder: (context) =>
                                      const VerificationBenefitsScreen(),
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

        // Quick Actions - Only show if not in tab view
        if (!widget.isTabView) ...[
          const SizedBox(height: 8),
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
        ],

        // Admin Only: Verification Requests
        if (!widget.isTabView &&
            (_currentUser?.roles.contains(UserRole.admin) ?? false)) ...[
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
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  color: color.withValues(alpha: 0.1),
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
