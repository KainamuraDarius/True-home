import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/pandora_payment_service.dart';
import 'package:flutter/material.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _PlanBenefit {
  final String id;
  final String title;
  final String price;
  final String description;
  final List<String> features;

  const _PlanBenefit({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    required this.features,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PlanBenefitsScreen extends StatefulWidget {
  final String? initialPlanId;

  const PlanBenefitsScreen({Key? key, this.initialPlanId}) : super(key: key);

  @override
  State<PlanBenefitsScreen> createState() => _PlanBenefitsScreenState();
}

class _PlanBenefitsScreenState extends State<PlanBenefitsScreen> {
  final PandoraPaymentService _pandoraService = PandoraPaymentService();

  // FIX: isPaying lives in State so StatefulBuilder dialogs reflect it correctly.
  bool _isPaying = false;

  static const _plans = [
    _PlanBenefit(
      id: 'starter',
      title: 'Starter',
      price: 'Free',
      description: 'Perfect for getting started. No cost, basic listing features.',
      features: [
        'Submit listings for free',
        'No subscription required',
        'Basic support',
      ],
    ),
    _PlanBenefit(
      id: 'agent',
      title: 'Agent',
      price: 'UGX 150,000/mo',
      description:
          'For individual professionals who want more exposure and features.',
      features: [
        'Up to 50 live properties',
        'Verified agent badge',
        'Priority listing review',
        'Access to premium support',
      ],
    ),
    _PlanBenefit(
      id: 'enterprise',
      title: 'Enterprise',
      price: 'UGX 250,000/mo',
      description: 'For agencies and growing teams needing advanced tools.',
      features: [
        'Up to 100 live properties',
        'Multi-agent account support',
        'Company branded presence',
        'Dedicated account manager',
      ],
    ),
  ];

  // ── Cancel plan ─────────────────────────────────────────────────────────────

  Future<void> _cancelPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Plan'),
        content: const Text(
          'Are you sure you want to cancel your current plan? '
          'You will be downgraded to the Starter plan.',
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

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'selectedPlan': 'starter',
      'selectedPlanPeriod': null,
      'selectedPlanPrice': 0,
      'selectedPlanStatus': 'active',
      'selectedPlanActivatedAt': DateTime.now().toIso8601String(),
      'planUpdatedAt': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    Navigator.of(context).pop('planCancelled');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan cancelled. You are now on the Starter plan.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ── Payment dialog ───────────────────────────────────────────────────────────

  Future<void> _showPaymentDialog(
    _PlanBenefit plan,
    String? currentPlanId,
  ) async {
    // Starter is always free — just show an info dialog.
    if (plan.id == 'starter') {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Starter Plan'),
          content: const Text(
            'The Starter plan is free and already active. '
            'No subscription or payment is required.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool paymentSuccess = false;

    final int price = plan.id == 'agent' ? 150000 : 250000;
    const String period = 'monthly';

    // FIX: formatted amount string built once, correctly (no double-escaped regex).
    final String formattedPrice = price
        .toString()
        .replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.payment,
                      color: Theme.of(dialogContext).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('Pay for ${plan.title} Plan'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan: ${plan.title}'),
                    const SizedBox(height: 8),
                    const Text('Period: Monthly'),
                    const SizedBox(height: 8),
                    Text('Amount: UGX $formattedPrice'),
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
                        validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Enter phone number'
                                : null,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      _isPaying ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _isPaying
                      ? null
                      : () {
                          paymentSuccess = true;
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Test (Simulate Payment)'),
                ),
                ElevatedButton(
                  onPressed: _isPaying
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => _isPaying = true);
                          setState(() {}); // sync outer state too

                          final transactionRef =
                              '${plan.id.toUpperCase()}PLAN_'
                              '${DateTime.now().millisecondsSinceEpoch}';
                          final narrative = '${plan.title} Plan Payment';

                          try {
                            final response =
                                await _pandoraService.initiatePayment(
                              phoneNumber: phoneController.text.trim(),
                              amount: price.toDouble(),
                              transactionRef: transactionRef,
                              narrative: narrative,
                            );

                            if (!response.success) {
                              throw Exception(response.message);
                            }

                            // Show "waiting for phone confirmation" dialog.
                            if (dialogContext.mounted) {
                              await showDialog(
                                context: dialogContext,
                                barrierDismissible: false,
                                builder: (_) => const AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text(
                                          'Check your phone to complete payment...'),
                                    ],
                                  ),
                                ),
                              );
                            }

                            await Future.delayed(const Duration(seconds: 3));
                            paymentSuccess = true;

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text('Payment Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => _isPaying = false);
                            setState(() {});
                            if (paymentSuccess && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
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
            );
          },
        );
      },
    );

    if (!paymentSuccess) return;

    // Persist the new plan.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'selectedPlan': plan.id,
        'selectedPlanPeriod': period,
        'selectedPlanPrice': price,
        'selectedPlanStatus': 'active',
        'selectedPlanActivatedAt': DateTime.now().toIso8601String(),
        'planUpdatedAt': DateTime.now().toIso8601String(),
        'isVerified': true,
        'verificationStatus': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${plan.title} plan activated successfully.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selectedPlanId = widget.initialPlanId ?? 'agent';
    final selectedPlan = _plans.firstWhere(
      (p) => p.id == selectedPlanId,
      orElse: () => _plans[1],
    );

    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: user != null
          ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
          : Future.value(null),
      builder: (context, snapshot) {
        String? currentPlanId;
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() ?? {};
          currentPlanId =
              (data['selectedPlan'] ?? data['plan'] ?? '').toString().toLowerCase();
          if (currentPlanId!.isEmpty) currentPlanId = 'starter';
        }

        final isPaidPlan =
            currentPlanId == 'agent' || currentPlanId == 'enterprise';
        final isCurrent = selectedPlan.id == (currentPlanId ?? 'starter');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Plan Benefits'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedPlan.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedPlan.price,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedPlan.description,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                const Text('Features:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...selectedPlan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (isPaidPlan) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _cancelPlan,
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text('Cancel Plan',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: selectedPlan.id == 'starter'
                      ? ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                          ),
                          child: Text(isCurrent
                              ? 'Current Plan (Free)'
                              : 'Select Starter (Free)'),
                        )
                      : ElevatedButton(
                          onPressed: isCurrent
                              ? null
                              : () => _showPaymentDialog(
                                    selectedPlan,
                                    currentPlanId,
                                  ),
                          child: Text(isCurrent
                              ? 'Current Plan'
                              : 'Upgrade to ${selectedPlan.title}'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // FIX: removed ~80 lines of dead widget code that appeared after this return.
  }
}