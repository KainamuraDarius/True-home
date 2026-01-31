import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms and Conditions',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last Updated: January 27, 2026',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using True Home, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these terms, please do not use our services.',
            ),
            
            _buildSection(
              '2. User Accounts',
              'You are responsible for maintaining the confidentiality of your account credentials. You agree to accept responsibility for all activities that occur under your account. You must notify us immediately of any unauthorized use of your account.',
            ),
            
            _buildSection(
              '3. Property Listings',
              'For Property Agents: You warrant that all property information you provide is accurate, complete, and not misleading. You must have the legal authority to list the properties on our platform. You are responsible for keeping property information up to date.',
            ),
            
            _buildSection(
              '4. User Conduct',
              'You agree not to:\n\n• Violate any applicable laws or regulations\n• Post false, inaccurate, or misleading information\n• Impersonate any person or entity\n• Harass, threaten, or abuse other users\n• Use the service for any fraudulent purposes\n• Attempt to gain unauthorized access to our systems',
            ),
            
            _buildSection(
              '5. Agent Ratings and Reviews',
              'Customers may rate and review property agents based on their experiences. Reviews must be honest, factual, and not defamatory. True Home reserves the right to remove reviews that violate our policies or contain inappropriate content.',
            ),
            
            _buildSection(
              '6. Privacy and Data Protection',
              'We collect and use your personal information in accordance with our Privacy Policy. By using our services, you consent to the collection and use of your information as described in our Privacy Policy.',
            ),
            
            _buildSection(
              '7. Property Transactions',
              'True Home serves as a platform connecting buyers/renters with property agents. We are not a party to any transactions between users. All agreements, negotiations, and transactions are solely between the users involved.',
            ),
            
            _buildSection(
              '8. Limitation of Liability',
              'True Home is not liable for:\n\n• Any indirect, incidental, or consequential damages\n• Loss of profits, revenue, or data\n• Property-related disputes between users\n• Accuracy of property information provided by agents\n• Actions or conduct of users on the platform',
            ),
            
            _buildSection(
              '9. Intellectual Property',
              'All content, features, and functionality of True Home are owned by us and protected by intellectual property laws. You may not copy, modify, distribute, or create derivative works without our express permission.',
            ),
            
            _buildSection(
              '10. Termination',
              'We reserve the right to suspend or terminate your account at any time for violation of these terms or for any other reason. Upon termination, your right to use the service will immediately cease.',
            ),
            
            _buildSection(
              '11. Changes to Terms',
              'We may modify these terms at any time. We will notify users of significant changes. Your continued use of the service after changes constitutes acceptance of the modified terms.',
            ),
            
            _buildSection(
              '12. Governing Law',
              'These terms shall be governed by and construed in accordance with the laws of Uganda. Any disputes shall be subject to the exclusive jurisdiction of the courts of Uganda.',
            ),
            
            _buildSection(
              '13. Contact Information',
              'If you have any questions about these terms, please contact us at:\n\nEmail: support@truehome.com\nPhone: +256 XXX XXX XXX',
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            
            const Text(
              'User Agreement',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. Agreement to Terms',
              'By creating an account on True Home, you agree to comply with and be legally bound by these terms whether or not you become a registered user of the services.',
            ),
            
            _buildSection(
              '2. Service Description',
              'True Home provides a digital platform for property listings, connecting property buyers, renters, and agents. We facilitate communication and information sharing but do not participate in actual property transactions.',
            ),
            
            _buildSection(
              '3. User Responsibilities',
              'As a user, you agree to:\n\n• Provide accurate and truthful information\n• Maintain the security of your account\n• Comply with all applicable laws\n• Respect other users and their privacy\n• Use the platform for legitimate purposes only',
            ),
            
            _buildSection(
              '4. Agent Responsibilities',
              'Property agents must:\n\n• Have proper licensing and authorization\n• Provide accurate property information\n• Respond to inquiries in a timely manner\n• Maintain professional conduct\n• Comply with real estate regulations',
            ),
            
            _buildSection(
              '5. Customer Responsibilities',
              'Customers agree to:\n\n• Provide genuine contact information\n• Engage respectfully with agents\n• Provide honest ratings and reviews\n• Not misuse the platform for spam or fraud',
            ),
            
            _buildSection(
              '6. Payment and Fees',
              'True Home may charge fees for certain services. All fees will be clearly disclosed before you incur any charges. Payment terms will be specified at the time of transaction.',
            ),
            
            _buildSection(
              '7. Dispute Resolution',
              'In case of disputes between users, parties agree to first attempt resolution through direct communication. If resolution is not reached, disputes may be escalated to mediation or legal proceedings as appropriate.',
            ),
            
            _buildSection(
              '8. Acknowledgment',
              'By clicking "I Accept" or by using our services, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions and User Agreement.',
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
