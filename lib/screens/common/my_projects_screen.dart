import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../utils/app_theme.dart';
import 'edit_project_screen.dart';
import 'submit_project_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyProjectsScreen extends StatefulWidget {
  final bool isTabView;
  
  const MyProjectsScreen({super.key, this.isTabView = false});

  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _projectService = ProjectService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isTabView ? null : AppBar(
        title: const Text('My Project Advertisements'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Show tabs in body when in tab view mode
          if (widget.isTabView)
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
                Tab(text: 'All'),
              ],
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectsList(status: 'pending'),
                _buildProjectsList(status: 'approved'),
                _buildProjectsList(status: 'all'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubmitProjectScreen(),
                  ),
                ).then((_) => setState(() {}));
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
              heroTag: 'newProjectFAB',
            ),
    );
  }

  Widget _buildProjectsList({required String status}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return StreamBuilder<List<Project>>(
      stream: _getProjectsStream(user.uid, status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? 'No pending projects'
                      : status == 'approved'
                          ? 'No approved projects'
                          : 'No projects yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first project advertisement',
                  style: TextStyle(color: Colors.grey),
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
      },
    );
  }

  Stream<List<Project>> _getProjectsStream(String userId, String status) {
    return FirebaseFirestore.instance
        .collection('advertised_projects')
        .where('developerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final sortedDocs = [...snapshot.docs]
        ..sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aDate = _resolveProjectSortDate(aData, status);
          final bDate = _resolveProjectSortDate(bData, status);
          return bDate.compareTo(aDate);
        });

      final projects = sortedDocs.map((doc) => Project.fromFirestore(doc)).toList();
      
      // Filter by status
      if (status == 'pending') {
        return projects.where((p) => !p.isApproved).toList();
      } else if (status == 'approved') {
        return projects.where((p) => p.isApproved).toList();
      }
      
      return projects;
    });
  }

  DateTime _resolveProjectSortDate(Map<String, dynamic> data, String status) {
    if (status == 'approved') {
      final approvedDate = _parseFirestoreDate(data['approvedAt']);
      if (approvedDate != null) return approvedDate;

      final updatedDate = _parseFirestoreDate(data['updatedAt']);
      if (updatedDate != null) return updatedDate;
    }

    return _parseFirestoreDate(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } catch (_) {
        return null;
      }
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Widget _buildProjectCard(Project project) {
    final daysRemaining = project.adExpiresAt.difference(DateTime.now()).inDays;
    final isExpired = daysRemaining < 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (project.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: project.imageUrls.first,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 900,
                memCacheHeight: 450,
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: const Duration(milliseconds: 100),
                placeholder: (context, url) => Container(
                  height: 240,
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
                  height: 240,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image_not_supported, size: 50),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Row(
                  children: [
                    _buildStatusBadge(project.isApproved, isExpired),
                    const Spacer(),
                    _buildAdTierBadge(project.adTier),
                  ],
                ),
                const SizedBox(height: 12),

                // Project Name
                Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      project.location,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description Preview
                Text(
                  project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),

                // Stats Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(Icons.visibility, 'Views', project.viewCount.toString()),
                      _buildStat(Icons.touch_app, 'Clicks', project.clickCount.toString()),
                      _buildStat(
                        Icons.calendar_today,
                        isExpired ? 'Expired' : 'Days Left',
                        isExpired ? '0' : daysRemaining.toString(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Amount:',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'UGX ${CurrencyFormatter.format(project.paymentAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),

                if (!project.isApproved) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Awaiting admin approval and payment verification',
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

                if (isExpired && project.isApproved) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Advertisement expired. Contact admin to renew.',
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
              ],
            ),
          ),

          // ── Edit / Delete action buttons ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProjectScreen(project: project),
                        ),
                      );
                      if (updated == true) setState(() {});
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(project),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
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

  Future<void> _confirmDelete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
          'Are you sure you want to delete "${project.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _projectService.deleteProject(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting project: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusBadge(bool isApproved, bool isExpired) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isExpired 
            ? Colors.red.shade100 
            : isApproved 
                ? Colors.green.shade100 
                : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isExpired 
            ? 'EXPIRED' 
            : isApproved 
                ? 'APPROVED' 
                : 'PENDING',
        style: TextStyle(
          color: isExpired 
              ? Colors.red.shade700 
              : isApproved 
                  ? Colors.green.shade700 
                  : Colors.orange.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAdTierBadge(AdTier adTier) {
    String label;
    Color color;
    Color textColor;

    switch (adTier) {
      case AdTier.basic:
        label = 'BASIC';
        color = Colors.blue;
        textColor = Colors.blue.shade700;
        break;
      case AdTier.premium:
        label = 'PREMIUM';
        color = Colors.purple;
        textColor = Colors.purple.shade700;
        break;
      case AdTier.firstPlaceRotational:
        label = 'FIRST PLACE';
        color = Colors.amber;
        textColor = Colors.amber.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
