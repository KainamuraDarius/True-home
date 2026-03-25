import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/pandora_payment_service.dart';
import '../../utils/app_theme.dart';
import '../organization/enterprise_setup_screen.dart';
import '../organization/team_management_screen.dart';

enum _UpgradeStep { choosePlan, chooseBilling }

class _PlanBenefit {
  final String id;
  final String title;
  final String tagline;
  final String description;
  final String monthlyLabel;
  final String yearlyLabel;
  final String badge;
  final IconData icon;
  final int monthlyPrice;
  final int yearlyPrice;
  final int listingLimit;
  final List<String> features;

  const _PlanBenefit({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.monthlyLabel,
    required this.yearlyLabel,
    required this.badge,
    required this.icon,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.listingLimit,
    required this.features,
  });
}

class PlanBenefitsScreen extends StatefulWidget {
  final String? initialPlanId;

  const PlanBenefitsScreen({super.key, this.initialPlanId});

  @override
  State<PlanBenefitsScreen> createState() => _PlanBenefitsScreenState();
}

class _PlanBenefitsScreenState extends State<PlanBenefitsScreen> {
  static const double _annualDiscount = 0.20;
  static const int _agentMonthlyPrice = 150000;
  static const int _enterpriseMonthlyPrice = 250000;

  final PandoraPaymentService _pandoraService = PandoraPaymentService();

  static int _annualPriceFromMonthly(int monthlyPrice) {
    return (monthlyPrice * 12 * (1 - _annualDiscount)).round();
  }

  static final List<_PlanBenefit> _plans = [
    _PlanBenefit(
      id: 'agent',
      title: 'Agent Plan',
      tagline: 'Best for individual professionals',
      description:
          'For individual agents and landlords managing an active portfolio.',
      monthlyLabel: 'UGX 150,000 / month',
      yearlyLabel: 'UGX 1,440,000 / year',
      badge: 'Professional',
      icon: Icons.workspace_premium_outlined,
      monthlyPrice: _agentMonthlyPrice,
      yearlyPrice: _annualPriceFromMonthly(_agentMonthlyPrice),
      listingLimit: 50,
      features: const [
        'Up to 50 properties',
        'Verified agent profile badge',
        'Enhanced search placement',
        'Full listing management on dashboard',
      ],
    ),
    _PlanBenefit(
      id: 'enterprise',
      title: 'Enterprise Plan',
      tagline: 'For real estate companies and teams',
      description:
          'For companies managing multiple agents and a large property portfolio.',
      monthlyLabel: 'UGX 250,000 / month',
      yearlyLabel: 'UGX 2,400,000 / year',
      badge: 'Most Popular',
      icon: Icons.apartment_outlined,
      monthlyPrice: _enterpriseMonthlyPrice,
      yearlyPrice: _annualPriceFromMonthly(_enterpriseMonthlyPrice),
      listingLimit: 100,
      features: const [
        'Up to 100 listings',
        'Branded company profile',
        'Multi-agent account management',
        'Priority placement and dedicated support',
      ],
    ),
  ];

  _UpgradeStep _step = _UpgradeStep.choosePlan;
  String _selectedPlanId = 'agent';
  String _selectedBillingPeriod = 'monthly';

  bool _isLoadingProfile = true;
  bool _isPaying = false;
  Map<String, dynamic> _userData = const <String, dynamic>{};

  // Prevent duplicate payment initiations for the same plan selection.
  String? _pendingPlanPaymentRef;
  String? _pendingPlanPaymentPhone;
  String? _pendingPlanPaymentPlanId;
  String? _pendingPlanPaymentPeriod;
  int? _pendingPlanPaymentPrice;

  @override
  void initState() {
    super.initState();
    final normalized = (widget.initialPlanId ?? 'agent').trim().toLowerCase();
    if (normalized == 'enterprise') {
      _selectedPlanId = 'enterprise';
    }
    _loadUserProfile();
  }

  _PlanBenefit get _selectedPlan {
    return _plans.firstWhere(
      (plan) => plan.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
  }

  _PlanBenefit? _findPlanById(String? planId) {
    if (planId == null || planId.trim().isEmpty) return null;
    for (final plan in _plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  bool _hasPendingPaymentFor({
    required _PlanBenefit plan,
    required String period,
    required int price,
  }) {
    return _pendingPlanPaymentRef != null &&
        _pendingPlanPaymentPlanId == plan.id &&
        _pendingPlanPaymentPeriod == period &&
        _pendingPlanPaymentPrice == price;
  }

  void _storePendingPlanPayment({
    required String transactionRef,
    required String phoneNumber,
    required String planId,
    required String period,
    required int price,
  }) {
    _pendingPlanPaymentRef = transactionRef;
    _pendingPlanPaymentPhone = phoneNumber;
    _pendingPlanPaymentPlanId = planId;
    _pendingPlanPaymentPeriod = period;
    _pendingPlanPaymentPrice = price;
  }

  void _clearPendingPlanPayment() {
    _pendingPlanPaymentRef = null;
    _pendingPlanPaymentPhone = null;
    _pendingPlanPaymentPlanId = null;
    _pendingPlanPaymentPeriod = null;
    _pendingPlanPaymentPrice = null;
  }

  String _pendingPaymentDescription() {
    final pendingPlan = _findPlanById(_pendingPlanPaymentPlanId);
    final title = pendingPlan?.title ?? 'selected plan';
    final billing = _pendingPlanPaymentPeriod == 'annual'
        ? 'Yearly'
        : 'Monthly';
    return '$title ($billing)';
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _userData = const <String, dynamic>{};
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _userData = doc.data() ?? <String, dynamic>{};
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _userData = const <String, dynamic>{};
      });
    }
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

  String _resolveCurrentPlanId(Map<String, dynamic> data) {
    final rawPlan = _readString(data, [
      'selectedPlan',
      'plan',
      'planType',
      'plan_type',
      'subscriptionPlan',
      'activePlan',
    ]).toLowerCase();

    if (rawPlan.contains('enterprise')) return 'enterprise';
    if (rawPlan.contains('agent')) return 'agent';
    return 'starter';
  }

  String _resolveCurrentPlanStatus(Map<String, dynamic> data) {
    return _readString(data, [
      'selectedPlanStatus',
      'planStatus',
      'subscriptionStatus',
      'status',
    ], fallback: 'active').toLowerCase();
  }

  String _resolveCurrentBillingPeriod(Map<String, dynamic> data) {
    final period = _readString(data, [
      'selectedPlanPeriod',
      'planPeriod',
      'billingCycle',
      'subscriptionPeriod',
      'subscriptionInterval',
    ]).toLowerCase();
    if (period == 'annual' || period == 'yearly' || period == 'year') {
      return 'annual';
    }
    return 'monthly';
  }

  bool _isCurrentSelectionActive() {
    final currentPlanId = _resolveCurrentPlanId(_userData);
    final currentStatus = _resolveCurrentPlanStatus(_userData);
    final currentPeriod = _resolveCurrentBillingPeriod(_userData);

    final isStatusActive =
        currentStatus != 'inactive' &&
        currentStatus != 'expired' &&
        currentStatus != 'cancelled';

    return isStatusActive &&
        currentPlanId == _selectedPlanId &&
        currentPeriod == _selectedBillingPeriod;
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

  int _selectedPrice() {
    if (_selectedBillingPeriod == 'annual') {
      return _selectedPlan.yearlyPrice;
    }
    return _selectedPlan.monthlyPrice;
  }

  int _selectedAnnualSavings() {
    final fullYear = _selectedPlan.monthlyPrice * 12;
    return fullYear - _selectedPlan.yearlyPrice;
  }

  bool _isPaymentSuccessStatus(String status) {
    const successStatuses = {'completed', 'success', 'paid'};
    return successStatuses.contains(status.toLowerCase());
  }

  bool _isPaymentFailureStatus(String status) {
    const failureStatuses = {
      'failed',
      'declined',
      'cancelled',
      'expired',
      'user_cancelled',
      'timeout',
    };
    return failureStatuses.contains(status.toLowerCase());
  }

  Future<bool> _waitForPlanPaymentConfirmation({
    required String transactionRef,
    required _PlanBenefit plan,
    required String period,
    required int price,
    required String phoneNumber,
  }) async {
    if (!mounted) return false;

    bool dialogOpen = true;
    bool cancelledByUser = false;
    final billingLabel = period == 'annual' ? 'Yearly' : 'Monthly';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Complete Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your PIN on phone to confirm ${plan.title}.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text('Billing: $billingLabel'),
              Text('Amount: UGX ${_formatCurrency(price)}'),
              Text('Phone: $phoneNumber'),
              const SizedBox(height: 16),
              const Text(
                'Waiting for payment confirmation...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelledByUser = true;
                if (!dialogOpen) return;
                dialogOpen = false;
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    void closeDialogIfOpen() {
      if (!dialogOpen || !mounted) return;
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    const int maxAttempts = 48; // 4 minutes with 5-second interval
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted || cancelledByUser) break;

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted || cancelledByUser) break;

      try {
        final statusResponse = await _pandoraService.checkPaymentStatus(
          transactionRef: transactionRef,
        );
        if (!mounted || cancelledByUser) break;

        final status = statusResponse.status.toLowerCase().trim();

        if (statusResponse.success || _isPaymentSuccessStatus(status)) {
          closeDialogIfOpen();
          return true;
        }

        if (_isPaymentFailureStatus(status)) {
          closeDialogIfOpen();
          _clearPendingPlanPayment();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(statusResponse.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      } catch (e) {
        debugPrint('Plan payment status check error: $e');
        final normalizedError = e.toString().toLowerCase();
        final statusServiceMissing =
            normalizedError.contains('service unavailable') ||
            normalizedError.contains('404');
        if (statusServiceMissing) {
          closeDialogIfOpen();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment status service is not available (HTTP 404). '
                  'Please deploy/enable pandoraPaymentStatus Cloud Function.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }
    }

    closeDialogIfOpen();
    if (!mounted) return false;

    if (cancelledByUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmation cancelled.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment confirmation timed out. Please complete payment and try again.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    return false;
  }

  Future<bool> _showPaymentDialog({
    required _PlanBenefit plan,
    required String period,
    required int price,
  }) async {
    if (_hasPendingPaymentFor(plan: plan, period: period, price: price)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment was already initiated. Enter PIN on phone to complete.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return _waitForPlanPaymentConfirmation(
        transactionRef: _pendingPlanPaymentRef!,
        plan: plan,
        period: period,
        price: price,
        phoneNumber: _pendingPlanPaymentPhone ?? 'N/A',
      );
    }

    if (_pendingPlanPaymentRef != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'A payment request is already pending for '
              '${_pendingPaymentDescription()}. Complete it first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? pendingTransactionRef;
    String? selectedPhoneNumber;

    final periodLabel = period == 'annual' ? 'Yearly (Save 20%)' : 'Monthly';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: !_isPaying,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      Icons.payment,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Confirm Payment')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Plan: ${plan.title}'),
                      const SizedBox(height: 6),
                      Text('Billing: $periodLabel'),
                      const SizedBox(height: 6),
                      Text(
                        'Amount: UGX ${_formatCurrency(price)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter phone number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isPaying
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: _isPaying
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            bool closedDialog = false;

                            if (dialogContext.mounted) {
                              setDialogState(() => _isPaying = true);
                            }
                            if (mounted) {
                              setState(() {});
                            }

                            selectedPhoneNumber = phoneController.text.trim();
                            final transactionRef =
                                'AGENTPLAN_${DateTime.now().millisecondsSinceEpoch}';
                            final narrative =
                                '${plan.title} (${period == 'annual' ? 'Yearly' : 'Monthly'})';

                            try {
                              final response = await _pandoraService
                                  .initiatePayment(
                                    phoneNumber: selectedPhoneNumber!,
                                    amount: price.toDouble(),
                                    transactionRef: transactionRef,
                                    narrative: narrative,
                                  );

                              if (!response.success) {
                                throw PaymentException(response.message);
                              }

                              pendingTransactionRef =
                                  response.transactionReference;
                              _storePendingPlanPayment(
                                transactionRef: response.transactionReference,
                                phoneNumber: selectedPhoneNumber!,
                                planId: plan.id,
                                period: period,
                                price: price,
                              );

                              if (dialogContext.mounted) {
                                closedDialog = true;
                                Navigator.of(dialogContext).pop();
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text('Payment Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (!closedDialog && dialogContext.mounted) {
                                setDialogState(() => _isPaying = false);
                              } else {
                                _isPaying = false;
                              }
                              if (mounted) {
                                setState(() {});
                              }
                            }
                          },
                    child: _isPaying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Proceed to Pay'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final refToCheck = pendingTransactionRef ?? _pendingPlanPaymentRef;
    final phoneToCheck = selectedPhoneNumber ?? _pendingPlanPaymentPhone;

    if (refToCheck == null || phoneToCheck == null) {
      return false;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment initiated. Enter your PIN on phone to confirm.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Allow the previous dialog route to fully close before opening
    // the payment-confirmation waiting dialog.
    await Future.delayed(const Duration(milliseconds: 180));

    final confirmed = await _waitForPlanPaymentConfirmation(
      transactionRef: refToCheck,
      plan: plan,
      period: period,
      price: price,
      phoneNumber: phoneToCheck,
    );
    if (confirmed) {
      _clearPendingPlanPayment();
    }
    return confirmed;
  }

  Future<void> _activatePlan({
    required _PlanBenefit plan,
    required String period,
    required int price,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now().toIso8601String();

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'selectedPlan': plan.id,
      'selectedPlanPeriod': period,
      'selectedPlanPrice': price,
      'selectedPlanStatus': 'active',
      'plan': plan.id,
      'planPeriod': period,
      'planPrice': price,
      'planStatus': 'active',
      'subscriptionStatus': 'active',
      'selectedPlanActivatedAt': now,
      'planUpdatedAt': now,
      'updatedAt': now,
      'planPaymentStatus': 'paid',
      'planPaymentCompletedAt': FieldValue.serverTimestamp(),
      'planPaymentPlanId': plan.id,
      'planPaymentPeriod': period,
      'planPaymentAmount': price,
      'verificationPaymentStatus': 'paid',
      'verificationPaymentCompletedAt': FieldValue.serverTimestamp(),
      'verificationPaymentPlanId': plan.id,
      'verificationPaymentPeriod': period,
      'verificationPaymentAmount': price,
    }, SetOptions(merge: true));

    final verificationRequestRef = FirebaseFirestore.instance
        .collection('verification_requests')
        .doc(uid);
    final verificationRequest = await verificationRequestRef.get();
    if (verificationRequest.exists) {
      await verificationRequestRef.set({
        'paymentStatus': 'paid',
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'paymentPlanId': plan.id,
        'paymentPlanTitle': plan.title,
        'paymentBillingPeriod': period,
        'paymentAmount': price,
      }, SetOptions(merge: true));
    }

    await _loadUserProfile();
  }

  Future<void> _openEnterpriseWorkspaceFlow() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final activeOrganizationId = (userData['activeOrganizationId'] ?? '')
        .toString()
        .trim();

    if (!mounted) return;

    if (activeOrganizationId.isEmpty) {
      final setupDone = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const EnterpriseSetupScreen(completeInFlow: true),
        ),
      );

      if (!mounted) return;

      if (setupDone == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enterprise workspace ready. Team invites are now enabled.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Enterprise plan activated. You can finish workspace setup from Manage Plan & Team.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final orgDoc = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(activeOrganizationId)
        .get();
    final organizationName = (orgDoc.data()?['name'] ?? 'Enterprise Workspace')
        .toString()
        .trim();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamManagementScreen(
          organizationId: activeOrganizationId,
          organizationName: organizationName.isEmpty
              ? 'Enterprise Workspace'
              : organizationName,
        ),
      ),
    );
  }

  Future<void> _handleProceedToPayment() async {
    if (_isCurrentSelectionActive()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This plan and billing cycle is already active.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final plan = _selectedPlan;
    final period = _selectedBillingPeriod;
    final price = _selectedPrice();

    final paymentSuccess = await _showPaymentDialog(
      plan: plan,
      period: period,
      price: price,
    );

    if (!paymentSuccess) return;

    await _activatePlan(plan: plan, period: period, price: price);

    if (!mounted) return;

    final billingLabel = period == 'annual' ? 'yearly' : 'monthly';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Congratulations! You are now on ${plan.title} with $billingLabel billing.',
        ),
        backgroundColor: Colors.green,
      ),
    );

    if (plan.id == 'enterprise') {
      final continueSetup = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set Up Enterprise Workspace'),
          content: const Text(
            'Enterprise is managed by one workspace owner who invites workers by email. Continue now to set up your company workspace?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (continueSetup == true) {
        await _openEnterpriseWorkspaceFlow();
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop('planActivated');
  }

  Future<void> _cancelPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Plan'),
        content: const Text(
          'Are you sure you want to cancel your active paid plan? You will lose premium access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final now = DateTime.now().toIso8601String();
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'selectedPlan': 'starter',
      'selectedPlanPeriod': null,
      'selectedPlanPrice': 0,
      'selectedPlanStatus': 'cancelled',
      'planStatus': 'cancelled',
      'subscriptionStatus': 'cancelled',
      'planUpdatedAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    _clearPendingPlanPayment();

    if (!mounted) return;

    Navigator.of(context).pop('planCancelled');
  }

  Widget _buildStepChip({
    required int stepNumber,
    required String title,
    required bool active,
    required bool done,
  }) {
    final color = active || done ? AppColors.primary : Colors.grey.shade400;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color,
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$stepNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: active || done ? AppColors.textPrimary : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanChoiceCard(_PlanBenefit plan) {
    final bool isSelected = _selectedPlanId == plan.id;
    final bool isEnterprise = plan.id == 'enterprise';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
                  Colors.white,
                ],
              )
            : null,
        color: isSelected ? null : Colors.white,
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.16),
          width: isSelected ? 2 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  plan.icon,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.tagline,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isEnterprise
                      ? const Color(0xFF0BAA8C).withValues(alpha: 0.14)
                      : AppColors.primary.withValues(alpha: 0.14),
                ),
                child: Text(
                  plan.badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isEnterprise
                        ? const Color(0xFF067A66)
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(plan.description, style: const TextStyle(height: 1.3)),
          const SizedBox(height: 10),
          Text(
            plan.monthlyLabel,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${plan.yearlyLabel}  •  Save 20%',
            style: TextStyle(
              color: const Color(0xFF0A8F77),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...plan.features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                setState(() {
                  _selectedPlanId = plan.id;
                  _step = _UpgradeStep.chooseBilling;
                });
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Continue with ${plan.id == 'agent' ? 'Agent' : 'Enterprise'}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCard({
    required String period,
    required String title,
    required String subtitle,
    required int amount,
    required bool selected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedBillingPeriod = period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.14),
                      Colors.white,
                    ],
                  )
                : null,
            color: selected ? null : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'UGX ${_formatCurrency(amount)}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoosePlanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.84),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upgrade Your Visibility',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Choose Agent or Enterprise. You will review billing (monthly/yearly) in the next step before payment.',
                style: TextStyle(color: Color(0xFFE3EBFF), height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._plans.map(_buildPlanChoiceCard),
      ],
    );
  }

  Widget _buildChooseBillingStep() {
    final selectedPrice = _selectedPrice();
    final isAnnual = _selectedBillingPeriod == 'annual';
    final savings = _selectedAnnualSavings();
    final currentPlanId = _resolveCurrentPlanId(_userData);
    final currentPeriod = _resolveCurrentBillingPeriod(_userData);
    final isSamePlanFamily = currentPlanId == _selectedPlan.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedPlan.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedPlan.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.3),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildBadge('Up to ${_selectedPlan.listingLimit} listings'),
                  const SizedBox(width: 8),
                  _buildBadge('Verified profile included'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildBillingCard(
              period: 'monthly',
              title: 'Monthly',
              subtitle: 'Billed every month',
              amount: _selectedPlan.monthlyPrice,
              selected: _selectedBillingPeriod == 'monthly',
            ),
            const SizedBox(width: 12),
            _buildBillingCard(
              period: 'annual',
              title: 'Yearly',
              subtitle: 'Save 20% annually',
              amount: _selectedPlan.yearlyPrice,
              selected: _selectedBillingPeriod == 'annual',
            ),
          ],
        ),
        if (isAnnual)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'You save UGX ${_formatCurrency(savings)} per year with yearly billing.',
              style: const TextStyle(
                color: Color(0xFF0A8F77),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 14),
        if (_selectedPlan.id == 'enterprise')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enterprise Structure',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text('1. One owner creates and manages the company workspace.'),
                SizedBox(height: 3),
                Text('2. Owner invites team members by email.'),
                SizedBox(height: 3),
                Text('3. Invited members accept and join your company plan.'),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Summary',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text('Plan: ${_selectedPlan.title}'),
              Text('Billing: ${isAnnual ? 'Yearly' : 'Monthly'}'),
              Text(
                'Amount to pay: UGX ${_formatCurrency(selectedPrice)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (isSamePlanFamily)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Current: ${currentPeriod == 'annual' ? 'Yearly' : 'Monthly'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _step = _UpgradeStep.choosePlan),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isPaying ? null : _handleProceedToPayment,
                icon: const Icon(Icons.lock_outline_rounded),
                label: Text(
                  _isCurrentSelectionActive()
                      ? 'Already Active'
                      : 'Proceed to Payment',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.primary.withValues(alpha: 0.1),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPlanId = _resolveCurrentPlanId(_userData);
    final currentStatus = _resolveCurrentPlanStatus(_userData);
    final isPaidCurrentPlan =
        currentPlanId == 'agent' || currentPlanId == 'enterprise';
    final isStatusActive =
        currentStatus != 'inactive' &&
        currentStatus != 'expired' &&
        currentStatus != 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Plan'),
        backgroundColor: AppColors.primary,
        actions: [
          if (isPaidCurrentPlan && isStatusActive)
            TextButton(
              onPressed: _cancelPlan,
              child: const Text(
                'Cancel Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF7FAFF),
                    AppColors.primary.withValues(alpha: 0.05),
                    const Color(0xFFF4F7FE),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoadingProfile
                ? const Center(child: CircularProgressIndicator())
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 14,
                              runSpacing: 10,
                              children: [
                                _buildStepChip(
                                  stepNumber: 1,
                                  title: 'Select Plan',
                                  active: _step == _UpgradeStep.choosePlan,
                                  done: _step == _UpgradeStep.chooseBilling,
                                ),
                                _buildStepChip(
                                  stepNumber: 2,
                                  title: 'Billing & Payment',
                                  active: _step == _UpgradeStep.chooseBilling,
                                  done: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _step == _UpgradeStep.choosePlan
                                  ? _buildChoosePlanStep()
                                  : _buildChooseBillingStep(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
