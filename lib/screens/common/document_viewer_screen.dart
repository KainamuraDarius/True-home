import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String documentType;

  const DocumentViewerScreen({
    super.key,
    required this.documentType,
  });

  @override
  Widget build(BuildContext context) {
    final doc = _getDocument();

    return Scaffold(
      appBar: AppBar(
        title: Text(doc['title']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc['title'],
              style: const TextStyle(
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
            if (doc['subtitle'] != null) ...[
              const SizedBox(height: 16),
              Text(
                doc['subtitle'],
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ...doc['sections'].map<Widget>((section) {
              return _buildSection(
                section['title'],
                section['content'],
              );
            }).toList(),
            const SizedBox(height: 32),
            if (doc['footer'] != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  doc['footer'],
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

  Map<String, dynamic> _getDocument() {
    switch (documentType) {
      case 'terms':
        return _getTermsOfService();
      case 'privacy':
        return _getPrivacyPolicy();
      case 'user_terms':
        return _getUserTerms();
      case 'agent_agreement':
        return _getAgentAgreement();
      default:
        return _getTermsOfService();
    }
  }

  Map<String, dynamic> _getTermsOfService() {
    return {
      'title': 'TRUEHOME – TERMS OF SERVICE',
      'subtitle':
          'Welcome to TrueHome, a digital platform owned and operated by Trume Company Limited, a company incorporated in the Republic of Uganda.\n\nBy accessing or using the TrueHome mobile application or website (the "Service"), you agree to be bound by these Terms of Service. If you do not agree, please do not use the Service.',
      'sections': [
        {
          'title': '1. About TrueHome',
          'content':
              'TrueHome is a platform that enables users to:\n\n• Discover and browse property listings\n• Connect with property owners, agents, or service providers\n• Access real-estate-related information and services\n\nTrueHome does not directly own listed properties unless explicitly stated.',
        },
        {
          'title': '2. Eligibility',
          'content':
              'You must:\n\n• Be at least 18 years old, or\n• Use the Service under parent/guardian supervision\n\nYou agree to provide accurate and truthful information when creating an account.',
        },
        {
          'title': '3. User Accounts',
          'content':
              'You are responsible for:\n\n• Maintaining the confidentiality of your login details\n• All activities that occur under your account\n\nTrume Company Limited may suspend or terminate accounts that:\n\n• Provide false information\n• Violate these Terms\n• Engage in fraud, abuse, or illegal activity',
        },
        {
          'title': '4. Property Listings & Transactions',
          'content':
              '• Listings are provided by third parties (owners, agents, developers).\n• TrueHome does not guarantee:\n  ○ Accuracy of listings\n  ○ Availability of property\n  ○ Pricing correctness\n\nAny transaction or agreement made is solely between users and the listing party.',
        },
        {
          'title': '5. Acceptable Use',
          'content':
              'You agree not to:\n\n• Use the platform for illegal purposes\n• Upload false, misleading, or harmful content\n• Attempt to hack, disrupt, or reverse-engineer the app\n• Harass or scam other users\n\nViolation may result in permanent account termination and possible legal action.',
        },
        {
          'title': '6. Fees and Payments',
          'content':
              'Some services may require service fees, subscriptions, or commissions. All applicable charges will be clearly communicated before payment.\n\nPayments are non-refundable unless required by law.',
        },
        {
          'title': '7. Intellectual Property',
          'content':
              'All rights in:\n\n• The TrueHome app\n• Software, design, branding, and content\n\nAre owned by Trume Company Limited.\n\nYou may not copy, modify, distribute, or reuse any part without written permission.',
        },
        {
          'title': '8. Limitation of Liability',
          'content':
              'To the maximum extent permitted by law, Trume Company Limited shall not be liable for:\n\n• Property disputes between users\n• Financial losses from transactions\n• Inaccurate listings or third-party conduct\n• Service interruptions or technical failures\n\nUse of TrueHome is at your own risk.',
        },
        {
          'title': '9. Termination',
          'content':
              'We may suspend or terminate access:\n\n• If you violate these Terms\n• If required by law\n• To protect users or the platform',
        },
        {
          'title': '10. Changes to Terms',
          'content':
              'We may update these Terms from time to time. Continued use of TrueHome after updates means you accept the revised Terms.',
        },
        {
          'title': '11. Governing Law',
          'content':
              'These Terms are governed by the laws of the Republic of Uganda. Any disputes shall be resolved in Ugandan courts unless otherwise agreed.',
        },
        {
          'title': '12. Contact Information',
          'content':
              'Trume Company Limited\nEmail: support@truehome.com.ug\nAddress: Kampala, Uganda',
        },
      ],
      'footer':
          'By using TrueHome, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
    };
  }

  Map<String, dynamic> _getPrivacyPolicy() {
    return {
      'title': 'TRUEHOME – PRIVACY POLICY',
      'subtitle':
          'This Privacy Policy explains how Trume Company Limited collects, uses, and protects your personal information when you use TrueHome.',
      'sections': [
        {
          'title': '1. Information We Collect',
          'content':
              'a) Information you provide:\n\n• Name\n• Phone number\n• Email address\n• Account details\n• Messages or inquiries sent through the app\n\nb) Automatically collected data:\n\n• Device information\n• IP address\n• App usage activity\n• Location data (if permission granted)',
        },
        {
          'title': '2. How We Use Your Information',
          'content':
              'We use your data to:\n\n• Provide and improve TrueHome services\n• Connect you with property listings or agents\n• Communicate updates, alerts, or support\n• Prevent fraud and ensure platform safety\n• Comply with legal obligations',
        },
        {
          'title': '3. Sharing of Information',
          'content':
              'We may share limited information with:\n\n• Property agents or listing owners (to enable contact)\n• Service providers supporting app operations\n• Authorities when required by law\n\nWe do not sell personal data to third parties.',
        },
        {
          'title': '4. Data Security',
          'content':
              'We implement reasonable technical and organizational measures to:\n\n• Protect personal data\n• Prevent unauthorized access, loss, or misuse\n\nHowever, no system is 100% secure.',
        },
        {
          'title': '5. Data Retention',
          'content':
              'We keep personal data only as long as necessary to:\n\n• Provide services\n• Meet legal or regulatory requirements\n• Resolve disputes and enforce agreements',
        },
        {
          'title': '6. Your Rights',
          'content':
              'You may:\n\n• Request access to your personal data\n• Request correction or deletion\n• Withdraw consent to certain processing\n\nRequests can be sent to our contact email below.',
        },
        {
          'title': '7. Children\'s Privacy',
          'content':
              'TrueHome is not intended for children under 18 without parental supervision. We do not knowingly collect data from minors.',
        },
        {
          'title': '8. Third-Party Links',
          'content':
              'TrueHome may contain links to external websites or services. We are not responsible for their privacy practices.',
        },
        {
          'title': '9. Updates to This Policy',
          'content':
              'We may update this Privacy Policy periodically. Changes become effective once posted in the app or website.',
        },
        {
          'title': '10. Contact Us',
          'content':
              'Trume Company Limited\nEmail: support@truehome.com.ug\nLocation: Kampala, Uganda',
        },
      ],
      'footer': null,
    };
  }

  Map<String, dynamic> _getUserTerms() {
    return {
      'title': 'TRUEHOME USER TERMS\n(Buyers & Renters)',
      'subtitle':
          'Owned by Trume Company Limited\n\nThese User Terms ("Terms") govern your access to and use of the TrueHome mobile application, website, and related services (the "Platform"), operated by Trume Company Limited, a company incorporated in Uganda.\n\nBy creating an account, browsing listings, or using TrueHome, you agree to these Terms. If you do not agree, please do not use the Platform.',
      'sections': [
        {
          'title': '1. Nature of the Service',
          'content':
              'TrueHome is a digital property marketplace that enables users to:\n\n• View property listings\n• Contact agents, landlords, or developers\n• Receive real-estate-related information\n\nTrueHome is NOT:\n\n• A property owner (unless stated)\n• A real estate broker in the transaction\n• A party to any rental or sale agreement\n\nAll agreements are strictly between users and the listing party.',
        },
        {
          'title': '2. Eligibility',
          'content':
              'To use TrueHome, you must:\n\n• Be 18 years or older, or\n• Use the Platform under parent/guardian supervision\n\nYou agree to provide accurate personal information.',
        },
        {
          'title': '3. User Responsibilities',
          'content':
              'You agree to:\n\n• Use the Platform only for lawful purposes\n• Provide truthful information in inquiries or applications\n• Communicate respectfully with agents and other users\n• Independently verify property details before making payments\n\nYou must not:\n\n• Impersonate another person\n• Attempt fraud or scams\n• Harass agents or other users\n• Misuse platform messaging',
        },
        {
          'title': '4. Property Listings Disclaimer',
          'content':
              'Listings are created by third-party agents or owners.\n\nTrueHome does not guarantee:\n\n• Accuracy of prices, photos, or descriptions\n• Ownership legitimacy\n• Availability of the property\n• Safety or quality of the property\n\nUsers must perform their own due diligence before:\n\n• Paying deposits\n• Signing agreements\n• Moving into any property',
        },
        {
          'title': '5. Payments & Financial Risk',
          'content':
              'TrueHome:\n\n• Does not handle property payments unless explicitly stated\n• Is not responsible for money sent to agents or landlords\n• Does not guarantee refunds for failed transactions\n\nUsers send money at their own risk.',
        },
        {
          'title': '6. Communication Through the Platform',
          'content':
              'TrueHome may allow:\n\n• Messaging with agents\n• Notifications and alerts\n• Customer support communication\n\nYou consent to receiving:\n\n• Service messages\n• Important updates\n• Safety notices\n\nYou may opt out of marketing messages.',
        },
        {
          'title': '7. Account Suspension or Termination',
          'content':
              'TrueHome may suspend or terminate accounts that:\n\n• Violate these Terms\n• Engage in fraud or abuse\n• Provide false information\n\nSerious violations may be reported to authorities.',
        },
        {
          'title': '8. Limitation of Liability',
          'content':
              'To the maximum extent allowed by Ugandan law, Trume Company Limited and TrueHome are not liable for:\n\n• Loss of money in property transactions\n• Disputes between users and agents\n• Fake or misleading listings\n• Property condition or safety\n• Failed negotiations or agreements\n\nUse of the Platform is at your own risk.',
        },
        {
          'title': '9. Privacy',
          'content':
              'Your personal data is handled according to the TrueHome Privacy Policy.\n\nBy using the Platform, you consent to:\n\n• Collection of necessary account data\n• Sharing with agents when you send inquiries\n• Security and fraud-prevention measures',
        },
        {
          'title': '10. Changes to the Terms',
          'content':
              'We may update these Terms from time to time. Continued use of TrueHome means you accept the updated Terms.',
        },
        {
          'title': '11. Governing Law',
          'content':
              'These Terms are governed by the laws of Uganda. Disputes shall be resolved in Ugandan courts.',
        },
        {
          'title': '12. Contact Information',
          'content':
              'Trume Company Limited\nKampala, Uganda\nEmail: support@truehome.com.ug',
        },
      ],
      'footer': null,
    };
  }

  Map<String, dynamic> _getAgentAgreement() {
    return {
      'title': 'TRUEHOME REAL ESTATE\nAGENT & LISTING AGREEMENT',
      'subtitle':
          'Owned and Operated by Trume Company Limited\n\nThis Real Estate Agent & Listing Agreement ("Agreement") is entered into between Trume Company Limited, a company incorporated in the Republic of Uganda and owner of the TrueHome platform (the "Platform"), AND the registered real estate agent, broker, developer, landlord, or property representative creating an account on TrueHome (the "Agent" or "Listing Party").\n\nBy creating an account or posting a listing on TrueHome, the Agent agrees to be bound by this Agreement.',
      'sections': [
        {
          'title': '1. Purpose of the Platform',
          'content':
              'TrueHome provides a digital marketplace that enables:\n\n• Property advertising and discovery\n• Communication between Agents and users\n• Promotion of real estate opportunities\n\nTrueHome does not own, sell, rent, or manage properties unless explicitly stated. All transactions occur directly between the Agent and the user.',
        },
        {
          'title': '2. Agent Eligibility & Verification',
          'content':
              'To list properties, the Agent must:\n\n• Provide accurate identification and contact details\n• Hold any required licenses or authority to advertise the property\n• Have legal permission from the property owner (if not the owner)\n\nTrueHome may:\n\n• Request verification documents at any time\n• Suspend or remove unverified Agents\n• Refuse listings at its sole discretion',
        },
        {
          'title': '3. Accuracy of Listings',
          'content':
              'The Agent is fully responsible for:\n\n• Correct property descriptions\n• Accurate pricing and availability\n• Genuine photos and location details\n• Legal authority to advertise\n\nThe Agent must not post:\n\n• Fake or misleading listings\n• Duplicate spam listings\n• Properties already sold/rented without updating\n• Content that violates Ugandan law\n\nTrueHome is not liable for incorrect or fraudulent listings.',
        },
        {
          'title': '4. Agent Responsibilities Toward Users',
          'content':
              'The Agent agrees to:\n\n• Respond honestly to inquiries\n• Conduct lawful and ethical transactions\n• Avoid scams, hidden charges, or misrepresentation\n• Respect user privacy and data\n\nAny dispute between Agent and user is their sole responsibility.',
        },
        {
          'title': '5. Fees, Commissions & Paid Features',
          'content':
              'TrueHome may introduce:\n\n• Listing fees\n• Featured/sponsored property promotions\n• Subscription plans for Agents\n• Commission on successful deals (future feature)\n\nAll charges will be:\n\n• Clearly communicated in advance\n• Non-refundable unless required by law',
        },
        {
          'title': '6. Prohibited Conduct',
          'content':
              'Agents must NOT:\n\n• Bypass the platform to avoid agreed fees (if applicable)\n• Use TrueHome for fraud, money laundering, or illegal sales\n• Upload copyrighted images without permission\n• Harass users or send spam messages\n\nViolation may result in:\n\n• Immediate listing removal\n• Permanent account ban\n• Reporting to authorities where necessary',
        },
        {
          'title': '7. Platform Limitation of Liability',
          'content':
              'To the maximum extent permitted by Ugandan law, Trume Company Limited and TrueHome shall not be liable for:\n\n• Property ownership disputes\n• Financial losses between Agents and users\n• Fraud committed by third parties\n• Errors in listing information\n• Failed or cancelled transactions\n\nAgents use the Platform at their own risk.',
        },
        {
          'title': '8. Intellectual Property',
          'content':
              'Agents grant TrueHome a non-exclusive right to:\n\n• Display property listings\n• Use listing photos for marketing TrueHome\n• Promote listings across digital channels\n\nOwnership of the platform and brand remains with Trume Company Limited.',
        },
        {
          'title': '9. Suspension or Termination',
          'content':
              'TrueHome may suspend or terminate an Agent account if:\n\n• This Agreement is violated\n• Fraud or complaints are reported\n• Required verification is not provided\n• Required fees remain unpaid (if applicable)\n\nTermination may occur without prior notice for serious violations.',
        },
        {
          'title': '10. Dispute Resolution',
          'content':
              'Any dispute related to this Agreement shall:\n\n• First attempt amicable resolution\n• If unresolved, be handled under the laws of Uganda\n• Be subject to Ugandan courts',
        },
        {
          'title': '11. Changes to This Agreement',
          'content':
              'TrueHome may update this Agreement at any time. Continued use of the Platform means the Agent accepts the updated terms.',
        },
        {
          'title': '12. Contact Information',
          'content':
              'Trume Company Limited\nOwner of TrueHome\nKampala, Uganda\nEmail: support@truehome.com.ug',
        },
        {
          'title': '13. Acceptance',
          'content':
              'By creating an Agent account or posting a listing on TrueHome, the Agent confirms that they:\n\n• Have read this Agreement\n• Understand it\n• Agree to be legally bound by it',
        },
      ],
      'footer':
          'IMPORTANT: By posting listings on TrueHome, you confirm your acceptance of these terms and your commitment to ethical property advertising.',
    };
  }
}
