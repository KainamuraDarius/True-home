import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import 'document_viewer_screen.dart';

class LegalPoliciesScreen extends StatefulWidget {
  const LegalPoliciesScreen({super.key});

  @override
  State<LegalPoliciesScreen> createState() => _LegalPoliciesScreenState();
}

class _LegalPoliciesScreenState extends State<LegalPoliciesScreen> {
  bool _isAgent = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final role = userDoc.data()?['role'] as String?;
          setState(() {
            _isAgent = role == 'owner';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal & Policies'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocumentCard(
            icon: Icons.gavel,
            title: 'Terms of Service',
            subtitle: 'General terms and conditions for using TrueHome',
            onTap: () => _navigateToDocument('terms'),
          ),
          const SizedBox(height: 12),
          _buildDocumentCard(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'How we collect, use, and protect your data',
            onTap: () => _navigateToDocument('privacy'),
          ),
          const SizedBox(height: 12),
          _buildDocumentCard(
            icon: Icons.person,
            title: 'User Terms (Buyers & Renters)',
            subtitle: 'Specific terms for property seekers',
            onTap: () => _navigateToDocument('user_terms'),
          ),
          if (_isAgent) ...[
            const SizedBox(height: 12),
            _buildDocumentCard(
              icon: Icons.business_center,
              title: 'Agent & Listing Agreement',
              subtitle: 'Terms for property agents and listings',
              onTap: () => _navigateToDocument('agent_agreement'),
              isAgent: true,
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These documents are effective as of 13 February 2026 and are governed by the laws of Uganda.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isAgent = false,
  }) {
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
                  color: isAgent 
                      ? Colors.orange.shade50
                      : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isAgent ? Colors.orange.shade700 : AppColors.primary,
                  size: 28,
                ),
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
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDocument(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(documentType: type),
      ),
    );
  }
}
