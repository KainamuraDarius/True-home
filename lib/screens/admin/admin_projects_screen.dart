import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:intl/intl.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../utils/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminProjectsScreen extends StatefulWidget {
  final bool embedded;
  const AdminProjectsScreen({super.key, this.embedded = false});

  @override
  State<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends State<AdminProjectsScreen>
    with SingleTickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();
  static const int _expiringSoonThresholdDays = 10;
  late TabController _tabController;

  List<Project> _pendingProjects = [];
  List<Project> _approvedProjects = [];
  List<Project> _expiredProjects = [];
  List<Project> _allProjects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
    });

    try {
      final all = await _projectService.getAllProjects();
      final now = DateTime.now();

      final pending = all.where((project) => !project.isApproved).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final approved =
          all
              .where(
                (project) => project.isApproved && !_isExpired(project, now),
              )
              .toList()
            ..sort((a, b) => a.adExpiresAt.compareTo(b.adExpiresAt));
      final expired =
          all
              .where(
                (project) => project.isApproved && _isExpired(project, now),
              )
              .toList()
            ..sort((a, b) => b.adExpiresAt.compareTo(a.adExpiresAt));

      if (mounted) {
        setState(() {
          _pendingProjects = pending;
          _approvedProjects = approved;
          _expiredProjects = expired;
          _allProjects = all;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading projects: $e')));
      }
    }
  }

  bool _isExpired(Project project, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return !project.adExpiresAt.isAfter(now);
  }

  int _daysRemaining(Project project, [DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return project.adExpiresAt.difference(now).inDays;
  }

  bool _isExpiringSoon(Project project, [DateTime? reference]) {
    final remaining = _daysRemaining(project, reference);
    return remaining >= 0 && remaining <= _expiringSoonThresholdDays;
  }

  Future<void> _approveProject(String projectId) async {
    try {
      await _projectService.updateProjectApproval(projectId, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project approved successfully')),
      );
      await _loadProjects();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error approving project: $e')));
    }
  }

  Future<void> _rejectProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Project'),
        content: const Text('Are you sure you want to reject this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await _projectService.updateProjectApproval(projectId, false);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Project rejected')));
        await _loadProjects();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error rejecting project: $e')));
      }
    }
  }

  Future<void> _deleteProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'Are you sure you want to delete this project? It will be moved to trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await _projectService.deleteProject(projectId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted successfully')),
        );
        await _loadProjects();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting project: $e')));
      }
    }
  }

  Future<int?> _showDaySelectionDialog({
    required String title,
    required String message,
    required String confirmLabel,
    int initialDays = 30,
  }) async {
    final controller = TextEditingController(text: '$initialDays');
    String? errorText;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Number of days',
                  hintText: 'Enter extra days',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final days = int.tryParse(controller.text.trim());
                if (days == null || days <= 0) {
                  setState(() {
                    errorText = 'Enter a valid number of days';
                  });
                  return;
                }
                Navigator.pop(context, days);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _extendProject(Project project) async {
    final days = await _showDaySelectionDialog(
      title: 'Add Advertisement Days',
      message:
          'Choose how many extra days to add to "${project.name}". The new duration will be added on top of the current expiry date.',
      confirmLabel: 'Add Days',
      initialDays: 10,
    );

    if (days == null) return;

    try {
      final newExpiry = await _projectService.extendProjectAdvertisement(
        project.id,
        currentExpiry: project.adExpiresAt,
        additionalDays: days,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $days day${days == 1 ? '' : 's'}. New expiry: ${DateFormat('MMM dd, yyyy').format(newExpiry)}',
            ),
          ),
        );
      }
      await _loadProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error extending project: $e')));
      }
    }
  }

  Future<void> _restoreProject(Project project) async {
    final days = await _showDaySelectionDialog(
      title: 'Restore Expired Project',
      message:
          'Choose how many days "${project.name}" should be active again for customers.',
      confirmLabel: 'Restore Project',
      initialDays: 30,
    );

    if (days == null) return;

    try {
      final newExpiry = await _projectService.restoreExpiredProject(
        project.id,
        activeDays: days,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Project restored successfully. Customers can see it until ${DateFormat('MMM dd, yyyy').format(newExpiry)}.',
            ),
          ),
        );
      }
      await _loadProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error restoring project: $e')));
      }
    }
  }

  Widget _buildTabLabel(
    String label,
    int count, {
    Color badgeColor = Colors.red,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: widget.embedded
          ? Theme.of(context).primaryColor
          : Colors.white,
      unselectedLabelColor: widget.embedded ? Colors.grey : Colors.white70,
      indicatorColor: widget.embedded
          ? Theme.of(context).primaryColor
          : Colors.white,
      tabs: [
        Tab(child: _buildTabLabel('Pending', _pendingProjects.length)),
        const Tab(text: 'Approved'),
        Tab(
          child: _buildTabLabel(
            'Expired Projects',
            _expiredProjects.length,
            badgeColor: Colors.deepOrange,
          ),
        ),
        const Tab(text: 'All Projects'),
      ],
    );

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadProjects,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectList(
                  _pendingProjects,
                  emptyMessage: 'No pending projects',
                ),
                _buildProjectList(
                  _approvedProjects,
                  emptyMessage: 'No approved projects',
                ),
                _buildProjectList(
                  _expiredProjects,
                  emptyMessage: 'No expired projects',
                ),
                _buildProjectList(
                  _allProjects,
                  emptyMessage: 'No projects yet',
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.apartment, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Advertised Projects',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadProjects,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Tab Bar
          tabBar,
          // Tab Content
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Advertised Projects'),
        bottom: tabBar,
      ),
      body: body,
    );
  }

  Widget _buildProjectList(
    List<Project> projects, {
    required String emptyMessage,
  }) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        return _buildProjectCard(projects[index]);
      },
    );
  }

  Widget _buildProjectCard(Project project) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final now = DateTime.now();
    final isExpired = _isExpired(project, now);
    final daysRemaining = _daysRemaining(project, now);
    final isExpiringSoon = project.isApproved && _isExpiringSoon(project, now);
    final expiredDays = now.difference(project.adExpiresAt).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Image
          if (project.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: project.imageUrls.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    memCacheWidth: 1600,
                    memCacheHeight: 900,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 100),
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  ),
                  // Status badges
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: project.isApproved
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        project.isApproved ? 'APPROVED' : 'PENDING',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (isExpired)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'EXPIRED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (!isExpired && isExpiringSoon)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          daysRemaining == 0
                              ? 'EXPIRES TODAY'
                              : '$daysRemaining DAY${daysRemaining == 1 ? '' : 'S'} LEFT',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (project.isFirstPlaceSubscriber &&
                      !isExpired &&
                      !isExpiringSoon)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'FEATURED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Project Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        project.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProject(project.id),
                      tooltip: 'Delete Project',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'By ${project.developerName}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      project.location,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      'Ad Tier: ${project.adTier.toString().split('.').last}',
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      'UGX ${CurrencyFormatter.format(project.paymentAmount)}',
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Created: ${dateFormat.format(project.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 14,
                      color: isExpired ? Colors.red : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpired
                          ? 'Expired: ${dateFormat.format(project.adExpiresAt)}'
                          : 'Expires: ${dateFormat.format(project.adExpiresAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpired ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (project.isApproved && isExpiringSoon) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            daysRemaining == 0
                                ? 'This project expires today. Add more days now so customers keep seeing it.'
                                : 'This project is about to expire in $daysRemaining day${daysRemaining == 1 ? '' : 's'}. Add more days to keep it available to customers.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (project.isApproved && isExpired) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            expiredDays <= 0
                                ? 'This project expired today and is hidden from customers until it is restored.'
                                : 'This project expired $expiredDays day${expiredDays == 1 ? '' : 's'} ago and is hidden from customers until it is restored.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${project.viewCount} views',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${project.clickCount} clicks',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Action buttons
                const SizedBox(height: 16),
                if (!project.isApproved)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveProject(project.id),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (project.isApproved && isExpiringSoon) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _extendProject(project),
                      icon: const Icon(Icons.add_alarm, size: 18),
                      label: const Text('Add More Days'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (project.isApproved && isExpired) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _restoreProject(project),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Restore Project'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (project.isApproved)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectProject(project.id),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Unapprove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
