import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TERMS OF SERVICE SECTION
            const Text(
              'TRUEHOME – TERMS OF SERVICE',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Effective Date: 13 February 2026',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to TrueHome, a digital platform owned and operated by Trume Company Limited, a company incorporated in the Republic of Uganda.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'By accessing or using the TrueHome mobile application or website (the "Service"), you agree to be bound by these Terms of Service. If you do not agree, please do not use the Service.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. About TrueHome',
              'TrueHome is a platform that enables users to:\n\n• Discover and browse property listings\n• Connect with property owners, agents, or service providers\n• Access real-estate-related information and services\n\nTrueHome does not directly own listed properties unless explicitly stated.',
            ),
            
            _buildSection(
              '2. Eligibility',
              'You must:\n\n• Be at least 18 years old, or\n• Use the Service under parent/guardian supervision\n\nYou agree to provide accurate and truthful information when creating an account.',
            ),
            
            _buildSection(
              '3. User Accounts',
              'You are responsible for:\n\n• Maintaining the confidentiality of your login details\n• All activities that occur under your account\n\nTrume Company Limited may suspend or terminate accounts that:\n\n• Provide false information\n• Violate these Terms\n• Engage in fraud, abuse, or illegal activity',
            ),
            
            _buildSection(
              '4. Property Listings & Transactions',
              '• Listings are provided by third parties (owners, agents, developers).\n• TrueHome does not guarantee:\n  ○ Accuracy of listings\n  ○ Availability of property\n  ○ Pricing correctness\n\nAny transaction or agreement made is solely between users and the listing party.',
            ),
            
            _buildSection(
              '5. Acceptable Use',
              'You agree not to:\n\n• Use the platform for illegal purposes\n• Upload false, misleading, or harmful content\n• Attempt to hack, disrupt, or reverse-engineer the app\n• Harass or scam other users\n\nViolation may result in permanent account termination and possible legal action.',
            ),
            
            _buildSection(
              '6. Fees and Payments',
              'Some services may:\n\n• Require service fees, subscriptions, or commissions\n\nAll applicable charges will be clearly communicated before payment.\nPayments are non-refundable unless required by law.',
            ),
            
            _buildSection(
              '7. Intellectual Property',
              'All rights in:\n\n• The TrueHome app\n• Software, design, branding, and content\n\nAre owned by Trume Company Limited.\n\nYou may not copy, modify, distribute, or reuse any part without written permission.',
            ),
            
            _buildSection(
              '8. Limitation of Liability',
              'To the maximum extent permitted by law:\n\nTrume Company Limited shall not be liable for:\n\n• Property disputes between users\n• Financial losses from transactions\n• Inaccurate listings or third-party conduct\n• Service interruptions or technical failures\n\nUse of TrueHome is at your own risk.',
            ),
            
            _buildSection(
              '9. Termination',
              'We may suspend or terminate access:\n\n• If you violate these Terms\n• If required by law\n• To protect users or the platform',
            ),
            
            _buildSection(
              '10. Changes to Terms',
              'We may update these Terms from time to time.\nContinued use of TrueHome after updates means you accept the revised Terms.',
            ),
            
            _buildSection(
              '11. Governing Law',
              'These Terms are governed by the laws of the Republic of Uganda.\nAny disputes shall be resolved in Ugandan courts unless otherwise agreed.',
            ),
            
            _buildSection(
              '12. Contact Information',
              'Trume Company Limited\nEmail: support@truehome.com.ug\nAddress: Kampala, Uganda',
            ),
            
            const SizedBox(height: 32),
            const Divider(thickness: 2),
            const SizedBox(height: 32),
            
            // PRIVACY POLICY SECTION
            const Text(
              'TRUEHOME – PRIVACY POLICY',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Effective Date: 13 February 2026',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This Privacy Policy explains how Trume Company Limited collects, uses, and protects your personal information when you use TrueHome.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              '1. Information We Collect',
              'a) Information you provide:\n\n• Name\n• Phone number\n• Email address\n• Account details\n• Messages or inquiries sent through the app\n\nb) Automatically collected data:\n\n• Device information\n• IP address\n• App usage activity\n• Location data (if permission granted)',
            ),
            
            _buildSection(
              '2. How We Use Your Information',
              'We use your data to:\n\n• Provide and improve TrueHome services\n• Connect you with property listings or agents\n• Communicate updates, alerts, or support\n• Prevent fraud and ensure platform safety\n• Comply with legal obligations',
            ),
            
            _buildSection(
              '3. Sharing of Information',
              'We may share limited information with:\n\n• Property agents or listing owners (to enable contact)\n• Service providers supporting app operations\n• Authorities when required by law\n\nWe do not sell personal data to third parties.',
            ),
            
            _buildSection(
              '4. Data Security',
              'We implement reasonable technical and organizational measures to:\n\n• Protect personal data\n• Prevent unauthorized access, loss, or misuse\n\nHowever, no system is 100% secure.',
            ),
            
            _buildSection(
              '5. Data Retention',
              'We keep personal data only as long as necessary to:\n\n• Provide services\n• Meet legal or regulatory requirements\n• Resolve disputes and enforce agreements',
            ),
            
            _buildSection(
              '6. Your Rights',
              'You may:\n\n• Request access to your personal data\n• Request correction or deletion\n• Withdraw consent to certain processing\n\nRequests can be sent to our contact email below.',
            ),
            
            _buildSection(
              '7. Children\'s Privacy',
              'TrueHome is not intended for children under 18 without parental supervision.\nWe do not knowingly collect data from minors.',
            ),
            
            _buildSection(
              '8. Third-Party Links',
              'TrueHome may contain links to external websites or services.\nWe are not responsible for their privacy practices.',
            ),
            
            _buildSection(
              '9. Updates to This Policy',
              'We may update this Privacy Policy periodically.\nChanges become effective once posted in the app or website.',
            ),
            
            _buildSection(
              '10. Contact Us',
              'Trume Company Limited\nEmail: support@truehome.com.ug\nLocation: Kampala, Uganda',
            ),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                'By using TrueHome, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and Privacy Policy.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
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
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
