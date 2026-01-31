import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'agent_verification_screen.dart';

class VerificationBenefitsScreen extends StatelessWidget {
  const VerificationBenefitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verification Benefits'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Benefits List
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  
                  // Featured Listings Benefit
                  _buildLargeBenefitCard(
                    context,
                    icon: Icons.auto_awesome,
                    iconColor: const Color(0xFFF59E0B),
                    iconBgColor: const Color(0xFFFEF3C7),
                    title: 'Featured Listings',
                    description: 'Your properties appear at the top of search results, getting more views and inquiries.',
                  ),
                  const SizedBox(height: 24),
                  
                  // Ad Credits Benefit
                  _buildLargeBenefitCard(
                    context,
                    icon: Icons.campaign_outlined,
                    iconColor: const Color(0xFFA855F7),
                    iconBgColor: const Color(0xFFF3E8FF),
                    title: 'Ad Credits',
                    description: 'Run sponsored ads that appear throughout the platform, reaching thousands of potential buyers.',
                  ),
                  const SizedBox(height: 24),
                  
                  // Verified Badge Benefit
                  _buildLargeBenefitCard(
                    context,
                    icon: Icons.verified,
                    iconColor: const Color(0xFF10B981),
                    iconBgColor: const Color(0xFFD1FAE5),
                    title: 'Verified Badge',
                    description: 'Build trust with potential clients by displaying a verified badge on your listings.',
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AgentVerificationScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeBenefitCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String description,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
