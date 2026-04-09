import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/project_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/fullscreen_image_viewer.dart';
import '../../services/view_tracking_service.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  int _currentImageIndex = 0;
  final ViewTrackingService _viewTrackingService = ViewTrackingService();

  String? get _contactPhone {
    final phone = widget.project.contactPhone?.trim();
    return (phone == null || phone.isEmpty) ? null : phone;
  }

  String? get _contactEmail {
    final email = widget.project.contactEmail?.trim();
    return (email == null || email.isEmpty) ? null : email;
  }

  String? get _websiteUrl {
    final website = widget.project.websiteUrl?.trim();
    return (website == null || website.isEmpty) ? null : website;
  }

  bool get _hasPricingInfo =>
      (widget.project.startingPrice?.trim().isNotEmpty ?? false) ||
      (widget.project.priceDescriptor?.trim().isNotEmpty ?? false) ||
      widget.project.bookingDeposit != null ||
      (widget.project.bookingDepositDescription?.trim().isNotEmpty ?? false);

  bool get _hasDeveloperInfo =>
      widget.project.developerName.trim().isNotEmpty ||
      (widget.project.developerTagline?.trim().isNotEmpty ?? false) ||
      widget.project.operationalAreas.isNotEmpty ||
      (widget.project.companyAbout?.trim().isNotEmpty ?? false) ||
      (widget.project.companyIconUrl?.trim().isNotEmpty ?? false);

  bool get _hasContactInfo =>
      _contactPhone != null || _contactEmail != null || _websiteUrl != null;

  String _currencyCode(Currency currency) {
    switch (currency) {
      case Currency.UGX:
        return 'UGX';
      case Currency.USD:
        return 'USD';
      case Currency.EUR:
        return 'EUR';
      case Currency.GBP:
        return 'GBP';
      case Currency.ZAR:
        return 'ZAR';
      case Currency.KES:
        return 'KES';
    }
  }

  String _formatStartingPrice() {
    final raw = widget.project.startingPrice?.trim();
    if (raw == null || raw.isEmpty) return 'Price on request';

    final code = _currencyCode(widget.project.currency).toUpperCase();
    final upperRaw = raw.toUpperCase();
    final alreadyHasCurrency =
        upperRaw.contains(code) ||
        raw.contains('\$') ||
        raw.contains('€') ||
        raw.contains('£');

    return alreadyHasCurrency ? raw : '$code $raw';
  }

  String _formatBookingDeposit() {
    final deposit = widget.project.bookingDeposit;
    if (deposit == null) return 'Flexible plans';
    return '${_currencyCode(widget.project.currency)} ${CurrencyFormatter.format(deposit)}';
  }

  String _operationalAreasText() {
    final cleanedAreas = widget.project.operationalAreas
        .map((area) => area.trim())
        .where((area) => area.isNotEmpty)
        .toList();
    if (cleanedAreas.isEmpty) return '';
    return cleanedAreas.join(' • ');
  }

  String _developerInitial() {
    final name = widget.project.customerVisibleDeveloperName.trim();
    if (name.isEmpty) return 'D';
    return name.substring(0, 1).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _trackProjectView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchProjectImages();
    });
  }

  Future<void> _trackProjectView() async {
    try {
      await _viewTrackingService.trackProjectView(
        projectId: widget.project.id,
        developerId: widget.project.developerId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking project view: $e');
    }
  }

  Future<void> _prefetchProjectImages() async {
    if (!mounted || widget.project.imageUrls.isEmpty) return;

    final initialImages = widget.project.imageUrls.take(6);
    for (final imageUrl in initialImages) {
      try {
        await precacheImage(CachedNetworkImageProvider(imageUrl), context);
      } catch (_) {
        // Ignore prefetch errors.
      }
    }
  }

  Future<void> _prefetchAroundIndex(int index) async {
    if (!mounted || widget.project.imageUrls.isEmpty) return;

    final indexes = {
      index - 1,
      index,
      index + 1,
    }.where((i) => i >= 0 && i < widget.project.imageUrls.length);

    for (final i in indexes) {
      try {
        await precacheImage(
          CachedNetworkImageProvider(widget.project.imageUrls[i]),
          context,
        );
      } catch (_) {
        // Ignore prefetch errors.
      }
    }
  }

  void _openImageZoom(int initialIndex) {
    if (widget.project.imageUrls.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          imageUrls: widget.project.imageUrls,
          initialIndex: initialIndex,
          title: widget.project.name,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    String normalizedUrl = urlString.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }

    final Uri url = Uri.parse(normalizedUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
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

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$cleanNumber?text=Hi, I\'m interested in ${widget.project.name}',
    );
    if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  Widget _buildPricingSection() {
    final descriptor = widget.project.priceDescriptor?.trim().isNotEmpty == true
        ? widget.project.priceDescriptor!.trim()
        : 'Contact developer for available unit types';
    final depositTerms =
        widget.project.bookingDepositDescription?.trim().isNotEmpty == true
        ? widget.project.bookingDepositDescription!.trim()
        : 'Contact developer for booking terms';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1628), Color(0xFF1B1F36)],
        ),
        border: Border.all(
          color: const Color(0xFFD4B35A).withOpacity(0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFFD4B35A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STARTING FROM',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.0,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatStartingPrice(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4B35A),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descriptor,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 96,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: const Color(0xFFD4B35A).withOpacity(0.3),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BOOK WITH',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.0,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatBookingDeposit(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      depositTerms,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF71D7A7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperSection() {
    final companyAbout = widget.project.companyAbout?.trim();
    final operationalAreas = _operationalAreasText();
    final iconUrl = widget.project.companyIconUrl?.trim();
    final displayName = widget.project.customerVisibleDeveloperName;
    final agentName = widget.project.developerName.trim();
    final showListedByAgent =
        widget.project.hasDeveloperTagline &&
        agentName.isNotEmpty &&
        agentName != displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Developer',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Color(0xFFD4B35A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101827), Color(0xFF1A2333)],
            ),
            border: Border.all(
              color: const Color(0xFFD4B35A).withOpacity(0.28),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4B35A),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: iconUrl != null && iconUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: iconUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Center(
                          child: Text(
                            _developerInitial(),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A2333),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _developerInitial(),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2333),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    if (showListedByAgent) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Listed by $agentName',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (operationalAreas.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF71D7A7),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Operational: $operationalAreas',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF71D7A7),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (companyAbout != null && companyAbout.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        companyAbout,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
                            _prefetchAroundIndex(index);
                          },
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openImageZoom(index),
                              child: CachedNetworkImage(
                                imageUrl: widget.project.imageUrls[index],
                                fit: BoxFit.cover,
                                memCacheWidth: 1600,
                                maxWidthDiskCache: 1600,
                                fadeInDuration: Duration.zero,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: Icon(Icons.apartment, size: 60),
                                    ),
                                  );
                                },
                              ),
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
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
                                  Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.white,
                                  ),
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
                    widget.project.hasDeveloperTagline
                        ? widget.project.customerVisibleDeveloperName
                        : 'By ${widget.project.customerVisibleDeveloperName}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Project Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: switch (widget.project.projectStatus) {
                        ProjectStatus.underConstruction =>
                          Colors.orange.shade50,
                        ProjectStatus.offPlan => Colors.blue.shade50,
                        ProjectStatus.ready => Colors.green.shade50,
                      },
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: switch (widget.project.projectStatus) {
                          ProjectStatus.underConstruction =>
                            Colors.orange.shade300,
                          ProjectStatus.offPlan => Colors.blue.shade300,
                          ProjectStatus.ready => Colors.green.shade300,
                        },
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          switch (widget.project.projectStatus) {
                            ProjectStatus.underConstruction =>
                              Icons.construction,
                            ProjectStatus.offPlan => Icons.architecture,
                            ProjectStatus.ready => Icons.check_circle,
                          },
                          size: 16,
                          color: switch (widget.project.projectStatus) {
                            ProjectStatus.underConstruction =>
                              Colors.orange.shade700,
                            ProjectStatus.offPlan => Colors.blue.shade700,
                            ProjectStatus.ready => Colors.green.shade700,
                          },
                        ),
                        const SizedBox(width: 6),
                        Text(
                          switch (widget.project.projectStatus) {
                            ProjectStatus.underConstruction =>
                              'Under Construction',
                            ProjectStatus.offPlan => 'Off-Plan',
                            ProjectStatus.ready => 'Ready',
                          },
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: switch (widget.project.projectStatus) {
                              ProjectStatus.underConstruction =>
                                Colors.orange.shade700,
                              ProjectStatus.offPlan => Colors.blue.shade700,
                              ProjectStatus.ready => Colors.green.shade700,
                            },
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
                  if (_hasPricingInfo) ...[
                    const SizedBox(height: 24),
                    _buildPricingSection(),
                  ],
                  if (_hasDeveloperInfo) ...[
                    const SizedBox(height: 24),
                    _buildDeveloperSection(),
                  ],
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
                  if (_hasContactInfo) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_contactPhone != null)
                      _buildContactTile(
                        icon: Icons.phone,
                        title: 'Phone',
                        subtitle: _contactPhone!,
                        onTap: () => _makePhoneCall(_contactPhone!),
                      ),
                    if (_contactEmail != null)
                      _buildContactTile(
                        icon: Icons.email,
                        title: 'Email',
                        subtitle: _contactEmail!,
                        onTap: () => _sendEmail(_contactEmail!),
                      ),
                    if (_websiteUrl != null)
                      _buildContactTile(
                        icon: Icons.language,
                        title: 'Website',
                        subtitle: _websiteUrl!,
                        onTap: () => _launchUrl(_websiteUrl!),
                      ),
                    const SizedBox(height: 32),
                    if (_websiteUrl != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchUrl(_websiteUrl!),
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
                    if (_websiteUrl != null) const SizedBox(height: 12),
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
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _contactPhone != null
                                ? () => _makePhoneCall(_contactPhone!)
                                : null,
                            icon: const Icon(Icons.phone, size: 20),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _contactPhone != null
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              foregroundColor: _contactPhone != null
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
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _contactEmail != null
                                ? () => _sendEmail(_contactEmail!)
                                : null,
                            icon: const Icon(Icons.email, size: 20),
                            label: const Text('Email'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _contactEmail != null
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                              foregroundColor: _contactEmail != null
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
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _contactPhone != null
                                ? () => _openWhatsApp(_contactPhone!)
                                : null,
                            icon: const Icon(Icons.chat, size: 20),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _contactPhone != null
                                  ? const Color(0xFF25D366)
                                  : Colors.grey.shade300,
                              foregroundColor: _contactPhone != null
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
                  ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
