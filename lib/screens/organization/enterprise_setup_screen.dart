import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'team_management_screen.dart';

class EnterpriseSetupScreen extends StatefulWidget {
  final bool completeInFlow;

  const EnterpriseSetupScreen({super.key, this.completeInFlow = false});

  @override
  State<EnterpriseSetupScreen> createState() => _EnterpriseSetupScreenState();
}

class _EnterpriseSetupScreenState extends State<EnterpriseSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final db = FirebaseFirestore.instance;
      final orgRef = db.collection('organizations').doc();
      final nowIso = DateTime.now().toIso8601String();
      final companyName = _companyNameController.text.trim();
      final companyAddress = _companyAddressController.text.trim();
      final companyPhone = _companyPhoneController.text.trim();

      await orgRef.set({
        'id': orgRef.id,
        'name': companyName,
        'address': companyAddress,
        'phone': companyPhone,
        'plan': 'enterprise',
        'status': 'active',
        'seatLimit': 10,
        'isCompanyVerified': false,
        'createdBy': user.uid,
        'createdAt': nowIso,
        'updatedAt': nowIso,
      });

      final ownerMembershipRef = orgRef.collection('members').doc(user.uid);
      await ownerMembershipRef.set({
        'userId': user.uid,
        'role': 'owner',
        'status': 'active',
        'canListProperty': true,
        'canListProject': true,
        'joinedAt': nowIso,
      });

      final userRef = db.collection('users').doc(user.uid);
      await userRef.update({
        'activeOrganizationId': orgRef.id,
        'companyName': companyName,
        'companyAddress': companyAddress,
        'updatedAt': nowIso,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enterprise organization created successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.completeInFlow) {
        final finished = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => TeamManagementScreen(
              organizationId: orgRef.id,
              organizationName: companyName,
              showFinishButton: true,
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(finished == true);
      } else {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeamManagementScreen(
              organizationId: orgRef.id,
              organizationName: companyName,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to set up enterprise: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise Setup'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
                child: const Text(
                  'Create your company workspace. You can invite your team and assign listing roles in the next step.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Company name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _companyAddressController,
                decoration: const InputDecoration(
                  labelText: 'Company Address *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Company address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _companyPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Company Phone (Optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _createOrganization,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _isSubmitting ? 'Creating...' : 'Create & Continue',
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
        ),
      ),
    );
  }
}
