import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'enterprise_setup_screen.dart';
import 'team_management_screen.dart';
import 'plan_select_screen.dart';

class PlanTeamManagementScreen extends StatefulWidget {
  const PlanTeamManagementScreen({super.key});

  @override
  State<PlanTeamManagementScreen> createState() => _PlanTeamManagementScreenState();
}

class _PlanTeamManagementScreenState extends State<PlanTeamManagementScreen> {

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

  String _normalizedPlanId({
    required String rawPlan,
    required String organizationId,
  }) {
    final normalized = rawPlan.trim().toLowerCase();
    if (normalized.contains('enterprise')) return 'enterprise';
    if (normalized.contains('agent')) return 'agent';
    if (organizationId.trim().isNotEmpty) return 'enterprise';
    if (normalized.contains('starter') || normalized == 'free') return 'free';
    if (normalized == 'monthly' ||
        normalized == 'annual' ||
        normalized == 'yearly') {
      return 'agent';
    }
    return normalized.isEmpty ? 'free' : normalized;
  }

  String _resolvePlanId(
    Map<String, dynamic> userData, {
    required String organizationId,
  }) {
    final rawPlan = _readString(userData, [
      'selectedPlan',
      'plan',
      'planType',
      'plan_type',
      'subscriptionPlan',
      'activePlan',
    ], fallback: 'free');
    return _normalizedPlanId(rawPlan: rawPlan, organizationId: organizationId);
  }

  String _resolvePlanStatus(Map<String, dynamic> userData) {
    return _readString(userData, [
      'selectedPlanStatus',
      'planStatus',
      'subscriptionStatus',
      'status',
    ], fallback: 'active').toLowerCase();
  }

  String _resolveBillingPeriod(Map<String, dynamic> userData) {
    final period = _readString(userData, [
      'selectedPlanPeriod',
      'planPeriod',
      'billingCycle',
      'subscriptionPeriod',
      'subscriptionInterval',
    ]);
    if (period.isNotEmpty) return period.toLowerCase();

    final maybePeriodInPlan = _readString(userData, [
      'selectedPlan',
    ]).toLowerCase();
    if (maybePeriodInPlan == 'monthly' ||
        maybePeriodInPlan == 'annual' ||
        maybePeriodInPlan == 'yearly') {
      return maybePeriodInPlan;
    }
    return 'monthly';
  }

  int _resolvePrice(Map<String, dynamic> userData) {
    return _readInt(userData, [
      'selectedPlanPrice',
      'planPrice',
      'subscriptionPrice',
      'price',
      'amount',
    ]);
  }

  bool _isPaidPlanActive(
    Map<String, dynamic> userData, {
    required String planId,
    required String status,
    required int price,
    required String organizationId,
  }) {
    final normalizedStatus = status.trim().toLowerCase();
    final statusActive =
        normalizedStatus != 'inactive' &&
        normalizedStatus != 'expired' &&
        normalizedStatus != 'cancelled';
    final planLooksPaid = planId == 'agent' || planId == 'enterprise';
    final explicitPaid = _readBool(userData, ['hasPaidPlan', 'isPlanActive']);

    return statusActive &&
        (planLooksPaid ||
            explicitPaid ||
            price > 0 ||
            organizationId.trim().isNotEmpty);
  }

  String _planTitle(String planId) {
    switch (planId.trim().toLowerCase()) {
      case 'agent':
        return 'Agent';
      case 'enterprise':
        return 'Enterprise';
      case 'free':
      default:
        return 'Starter';
    }
  }

  String _periodTitle(String periodValue) {
    final normalized = periodValue.trim().toLowerCase();
    if (normalized == 'annual' ||
        normalized == 'yearly' ||
        normalized == 'year') {
      return 'Yearly';
    }
    return 'Monthly';
  }

  String _statusTitle(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return 'Active';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String _formatCurrency(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Plan & Team'),
          backgroundColor: AppColors.primary,
        ),
        body: const Center(child: Text('Please log in again.')),
      );
    }

    Future<void> cancelPlan(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Cancellation'),
          content: const Text('Are you absolutely sure you want to cancel your plan? You will lose access to premium features.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Yes, Cancel Plan'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'planStatus': 'cancelled',
            'subscriptionStatus': 'cancelled',
            'selectedPlanStatus': 'cancelled',
            // Add other relevant fields if needed
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Plan cancelled successfully.')),
            );
            Navigator.pop(context, 'planCancelled');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to cancel plan: $e')),
            );
          }
        }
      }
    }

    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Plan & Team'),
          backgroundColor: AppColors.primary,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Plan'),
              Tab(text: 'Team'),
            ],
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('User profile not found.'));
            }

            final userData = snapshot.data!.data() ?? <String, dynamic>{};
            final selectedPeriod = _resolveBillingPeriod(userData);
            final selectedStatus = _resolvePlanStatus(userData);
            final selectedPrice = _resolvePrice(userData);
            final isVerified = userData['isVerified'] == true;
            final orgId = (userData['activeOrganizationId'] ?? '')
                .toString()
                .trim();
            final selectedPlan = _resolvePlanId(
              userData,
              organizationId: orgId,
            );
            final paidPlanActive = _isPaidPlanActive(
              userData,
              planId: selectedPlan,
              status: selectedStatus,
              price: selectedPrice,
              organizationId: orgId,
            );

            return TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _planTitle(selectedPlan),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Billing: ${_periodTitle(selectedPeriod)}'),
                            const SizedBox(height: 4),
                            Text('Status: ${_statusTitle(selectedStatus)}'),
                            const SizedBox(height: 4),
                            Text(
                              'Price: UGX ${_formatCurrency(selectedPrice)}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isVerified
                                  ? 'Verification: Automatic verification active.'
                                  : (paidPlanActive
                                        ? 'Verification will be set automatically for active paid plans.'
                                        : 'Verification is not active on starter plan.'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isVerified
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OrganizationPlanSelectScreen(),
                              ),
                            );
                            if (!mounted) return;
                            if (result is Map) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Plan updated successfully.')),
                              );
                              // Optionally, trigger a reload or setState here if needed
                            }
                          },
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: const Text('Change / Upgrade Plan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => cancelPlan(context),
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                          label: const Text('Cancel Plan', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tip: Set up your workspace to start managing team members.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _TeamTab(
                  selectedPlan: selectedPlan,
                  organizationId: orgId,
                  paidPlanActive: paidPlanActive,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  final String selectedPlan;
  final String organizationId;
  final bool paidPlanActive;

  const _TeamTab({
    required this.selectedPlan,
    required this.organizationId,
    required this.paidPlanActive,
  });

  @override
  Widget build(BuildContext context) {
    if (!paidPlanActive) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                'Activate a paid plan to start team management.',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop('openPlanChooser'),
                icon: const Icon(Icons.upgrade_outlined),
                label: const Text('Choose Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (organizationId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                'Create your workspace to start inviting and managing agents.',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnterpriseSetupScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.apartment_outlined),
                label: const Text('Set Up Team Workspace'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final orgStream = FirebaseFirestore.instance
        .collection('organizations')
        .doc(organizationId)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: orgStream,
      builder: (context, snapshot) {
        final orgData = snapshot.data?.data() ?? <String, dynamic>{};
        final orgName = (orgData['name'] ?? 'Enterprise Workspace')
            .toString()
            .trim();
        final displayName = orgName.isEmpty ? 'Enterprise Workspace' : orgName;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Invite agents by email verification code and assign role-based access.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamManagementScreen(
                          organizationId: organizationId,
                          organizationName: displayName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Open Team Workspace'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
