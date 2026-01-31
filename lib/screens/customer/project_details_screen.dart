import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/project_model.dart';
import '../../utils/app_theme.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  int _currentImageIndex = 0;

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(phoneUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make phone call')),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Inquiry about ${widget.project.name}',
    );
    if (!await launchUrl(emailUri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Remove any non-digit characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Add Uganda country code if not present
    if (!cleanNumber.startsWith('+')) {
      // Remove leading 0 if present
      if (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }
      // Add +256 for Uganda
      cleanNumber = '+256$cleanNumber';
    }
    
    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber?text=Hi, I\'m interested in ${widget.project.name}');
    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with images
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.project.imageUrls.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          itemCount: widget.project.imageUrls.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return Image.network(
                              widget.project.imageUrls[index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Icon(Icons.apartment, size: 60),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        // Image indicator
                        if (widget.project.imageUrls.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                widget.project.imageUrls.length,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index
                                        ? AppColors.primary
                                        : Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Featured badge
                        if (widget.project.isFirstPlaceSubscriber)
                          Positioned(
                            top: 60,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'FEATURED PROJECT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.apartment, size: 60),
                      ),
                    ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project name
                  Text(
                    widget.project.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Developer name
                  Text(
                    'By ${widget.project.developerName}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Project Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.project.projectStatus == ProjectStatus.underConstruction
                          ? Colors.orange.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.project.projectStatus == ProjectStatus.underConstruction
                            ? Colors.orange.shade300
                            : Colors.blue.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.project.projectStatus == ProjectStatus.underConstruction
                              ? Icons.construction
                              : Icons.architecture,
                          size: 16,
                          color: widget.project.projectStatus == ProjectStatus.underConstruction
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.project.projectStatus == ProjectStatus.underConstruction
                              ? 'Under Construction'
                              : 'Off-Plan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.project.projectStatus == ProjectStatus.underConstruction
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.project.location,
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Description
                  const Text(
                    'About this Project',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.project.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Contact information
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Phone
                  if (widget.project.contactPhone != null)
                    _buildContactTile(
                      icon: Icons.phone,
                      title: 'Phone',
                      subtitle: widget.project.contactPhone!,
                      onTap: () => _makePhoneCall(widget.project.contactPhone!),
                    ),
                  // Email
                  if (widget.project.contactEmail != null)
                    _buildContactTile(
                      icon: Icons.email,
                      title: 'Email',
                      subtitle: widget.project.contactEmail!,
                      onTap: () => _sendEmail(widget.project.contactEmail!),
                    ),
                  // Website
                  if (widget.project.websiteUrl != null)
                    _buildContactTile(
                      icon: Icons.language,
                      title: 'Website',
                      subtitle: widget.project.websiteUrl!,
                      onTap: () => _launchUrl(widget.project.websiteUrl!),
                    ),
                  const SizedBox(height: 32),
                  // Visit Website button (prominent)
                  if (widget.project.websiteUrl != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchUrl(widget.project.websiteUrl!),
                        icon: const Icon(Icons.language, size: 24),
                        label: const Text('Visit Website for More Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  if (widget.project.websiteUrl != null)
                    const SizedBox(height: 12),
                  // Contact Action Buttons
                  const Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Call Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.project.contactPhone != null
                              ? () => _makePhoneCall(widget.project.contactPhone!)
                              : null,
                          icon: const Icon(Icons.phone, size: 20),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.project.contactPhone != null
                                ? Colors.blue
                                : Colors.grey.shade300,
                            foregroundColor: widget.project.contactPhone != null
                                ? Colors.white
                                : Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Email Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.project.contactEmail != null
                              ? () => _sendEmail(widget.project.contactEmail!)
                              : null,
                          icon: const Icon(Icons.email, size: 20),
                          label: const Text('Email'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.project.contactEmail != null
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            foregroundColor: widget.project.contactEmail != null
                                ? Colors.white
                                : Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // WhatsApp Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.project.contactPhone != null
                              ? () => _openWhatsApp(widget.project.contactPhone!)
                              : null,
                          icon: const Icon(Icons.chat, size: 20),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.project.contactPhone != null
                                ? const Color(0xFF25D366)
                                : Colors.grey.shade300,
                            foregroundColor: widget.project.contactPhone != null
                                ? Colors.white
                                : Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: onTap,
      ),
    );
  }
}
