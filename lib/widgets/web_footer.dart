import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/customer/customer_home_screen.dart';
import '../screens/property/add_property_screen.dart';
import '../screens/owner/agent_main_screen.dart';
import '../screens/common/submit_project_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../models/property_model.dart';

class WebFooter extends StatefulWidget {
  const WebFooter({super.key});

  @override
  State<WebFooter> createState() => _WebFooterState();
}

class _WebFooterState extends State<WebFooter> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late GlobalKey _expandedContentKey;

  @override
  void initState() {
    super.initState();
    _expandedContentKey = GlobalKey();
  }

  void _scrollToContent() {
    // Delay to allow the expanded content to render
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        // Try to find and scroll to the expanded content
        final RenderObject? renderObject = _expandedContentKey.currentContext?.findRenderObject();
        if (renderObject != null) {
          // Find the nearest scroll view and scroll to make content visible
          Scrollable.ensureVisible(
            _expandedContentKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
        }
      } catch (e) {
        print('Scroll error: $e');
      }
    });
  }

  void _navigateToProperties(BuildContext context, PropertyType type) {
    // Navigate to customer home screen
    // This will work if already on customer home, otherwise push new instance
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const CustomerHomeScreen(),
      ),
      (route) => false,
    );
  }

  void _navigateToAddProperty(BuildContext context) {
    if (!_requireAuthentication(context,
        title: 'Login Required',
        message: 'Property management tools are available only to signed-in accounts.')) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddPropertyScreen(),
      ),
    );
  }

  void _navigateToAgentDashboard(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const AgentMainScreen(),
        ),
      );
      return;
    }

    _requireAuthentication(
      context,
      title: 'Agent Login Required',
      message: 'Agent tools are available only after logging in.',
    );
  }

  void _navigateToProjects(BuildContext context) {
    if (!_requireAuthentication(context,
        title: 'Login Required',
        message: 'Project submission requires an account so we can review and manage your listing.')) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubmitProjectScreen(),
      ),
    );
  }

  void _launchUrl(String url) {
    // TODO: Implement URL launching when social media accounts are available
    print('Opening: $url');
  }

  bool _requireAuthentication(
    BuildContext outerContext, {
    required String title,
    required String message,
  }) {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }

    showDialog(
      context: outerContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(outerContext).push(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              );
            },
            child: const Text('Create Account'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(outerContext).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: const Color(0xFF1a1d2e),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Footer (Always Visible)
          _buildCompactFooter(context),
          
          // Expanded Content (Collapsible)
          if (_isExpanded) _buildExpandedContent(context),
        ],
      ),
    );
  }

  Widget _buildCompactFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade900, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 980;

          final brand = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'TrueHome',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          );

          final legal = Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '© ${DateTime.now().year} TrueHome. All Rights Reserved',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
              Text('•', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade300,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Text('•', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Terms of Service',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade300,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          );

          final expandButton = Tooltip(
            message: _isExpanded ? 'Show Less' : 'Show More',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                  // Scroll to show expanded content
                  if (_isExpanded) {
                    _scrollToContent();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade600, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Less' : 'More',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    brand,
                    const Spacer(),
                    expandButton,
                  ],
                ),
                const SizedBox(height: 12),
                legal,
              ],
            );
          }

          return Row(
            children: [
              brand,
              const SizedBox(width: 24),
              Expanded(child: legal),
              const SizedBox(width: 16),
              expandButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        key: _expandedContentKey,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade800,
              width: 1,
            ),
          ),
        ),
        child: Wrap(
          spacing: 60,
          runSpacing: 40,
          children: [
            // Brand Section
            SizedBox(
              width: 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About TrueHome',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Uganda's premier real estate marketplace connecting you with your dream property.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Social Media Icons
                  Row(
                    children: [
                      _brandIconButton(
                        label: 'f',
                        brandColor: const Color(0xFF1877F2), // Facebook Blue
                        onTap: () => _launchUrl('https://facebook.com/truehomeuganda'),
                      ),
                      const SizedBox(width: 12),
                      _brandIconButton(
                        label: 'X',
                        brandColor: const Color(0xFF000000), // X Black
                        onTap: () => _launchUrl('https://x.com/truehomeuganda'),
                      ),
                      const SizedBox(width: 12),
                      _brandIconButton(
                        label: '●',
                        brandColor: const Color(0xFFE1306C), // Instagram Pink
                        onTap: () => _launchUrl('https://instagram.com/truehomeuganda'),
                      ),
                      const SizedBox(width: 12),
                      _brandIconButton(
                        label: 'in',
                        brandColor: const Color(0xFF0A66C2), // LinkedIn Blue
                        onTap: () => _launchUrl('https://linkedin.com/company/truehomeuganda'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick Links
            SizedBox(
              width: 180,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Links',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _clickableLink(
                      context: context,
                      label: 'Buy Property',
                      onTap: () => _navigateToProperties(context, PropertyType.sale),
                    ),
                    const SizedBox(height: 10),
                    _clickableLink(
                      context: context,
                      label: 'Rent Property',
                      onTap: () => _navigateToProperties(context, PropertyType.rent),
                    ),
                    const SizedBox(height: 10),
                    _clickableLink(
                      context: context,
                      label: 'Student Hostels',
                      onTap: () => _navigateToProperties(context, PropertyType.hostel),
                    ),
                    const SizedBox(height: 10),
                    _clickableLink(
                      context: context,
                      label: 'List Property',
                      onTap: () => _navigateToAddProperty(context),
                    ),
                  ],
                ),
            ),

            // For Agents
            SizedBox(
              width: 180,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'For Agents',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _clickableLink(
                      context: context,
                      label: 'Agent Dashboard',
                      onTap: () => _navigateToAgentDashboard(context),
                    ),
                    const SizedBox(height: 10),
                    _clickableLink(
                      context: context,
                      label: 'Advertising Packages',
                      onTap: () => _navigateToProjects(context),
                    ),
                    const SizedBox(height: 10),
                    _clickableLink(
                      context: context,
                      label: 'Get Verified',
                      onTap: () => _navigateToAgentDashboard(context),
                    ),
                  ],
                ),
            ),

            // Contact Us
            SizedBox(
              width: 180,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Us',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Kampala, Uganda',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.phone,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '+256 702 021 112',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _clickableLink({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade300,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _brandIconButton({
    required String label,
    required Color brandColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: brandColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: brandColor.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: brandColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
