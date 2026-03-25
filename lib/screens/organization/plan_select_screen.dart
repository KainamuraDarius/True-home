import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrganizationPlanSelectScreen extends StatefulWidget {
  const OrganizationPlanSelectScreen({super.key});

  @override
  State<OrganizationPlanSelectScreen> createState() => _OrganizationPlanSelectScreenState();
}

class _OrganizationPlanSelectScreenState extends State<OrganizationPlanSelectScreen> {
  String _selectedPeriod = 'monthly';
  String _selectedPlan = 'agent';

  static const int _agentMonthlyPrice = 150000;
  static const int _agentYearlyPrice = 150000 * 12 * 0.8 ~/ 1; // 20% off

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose your plan:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Monthly'),
                    value: 'monthly',
                    groupValue: _selectedPeriod,
                    onChanged: (v) => setState(() => _selectedPeriod = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Yearly (Save 20%)'),
                    value: 'yearly',
                    groupValue: _selectedPeriod,
                    onChanged: (v) => setState(() => _selectedPeriod = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            ListTile(
              title: const Text('Agent Plan'),
              subtitle: Text(_selectedPeriod == 'monthly'
                  ? 'UGX 150,000 / month'
                  : 'UGX 1,440,000 / year (20% off)'),
              leading: Radio<String>(
                value: 'agent',
                groupValue: _selectedPlan,
                onChanged: (v) => setState(() => _selectedPlan = v!),
              ),
            ),
            // Add more plans here if needed
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSelect,
                child: const Text('Select & Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSelect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final planPeriod = _selectedPeriod;
    final planId = _selectedPlan;
    final planPrice = planPeriod == 'monthly' ? _agentMonthlyPrice : _agentYearlyPrice;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'selectedPlan': planId,
        'selectedPlanPeriod': planPeriod,
        'selectedPlanPrice': planPrice,
        'plan': planId,
        'planPeriod': planPeriod,
        'planPrice': planPrice,
        'planStatus': 'active',
      });
      if (mounted) {
        Navigator.of(context).pop({'plan': planId, 'period': planPeriod, 'price': planPrice});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update plan: $e')),
        );
      }
    }
  }
}
