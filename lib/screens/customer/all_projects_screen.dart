import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/project_model.dart';
import '../../services/view_tracking_service.dart';
import '../../utils/app_theme.dart';
import 'project_details_screen.dart';

class AllProjectsScreen extends StatelessWidget {
  final String location;
  final List<Project> projects;

  const AllProjectsScreen({
    super.key,
    required this.location,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    final viewTrackingService = ViewTrackingService();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Projects in $location'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
          return _buildProjectListCard(context, project, viewTrackingService);
        },
      ),
    );
  }

  Widget _buildProjectListCard(
    BuildContext context,
    Project project,
    ViewTrackingService viewTrackingService,
  ) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          await viewTrackingService.trackProjectClick(
            projectId: project.id,
            developerId: project.developerId,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailsScreen(project: project),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  project.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: project.imageUrls.first,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: 1000,
                          memCacheHeight: 500,
                          fadeInDuration: const Duration(milliseconds: 300),
                          fadeOutDuration: const Duration(milliseconds: 100),
                          placeholder: (context, url) => Container(
                            height: 240,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 240,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(Icons.apartment, size: 60),
                            ),
                          ),
                        )
                      : Container(
                          height: 240,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.apartment, size: 60),
                          ),
                        ),
                  // Featured badge
                  if (project.isFirstPlaceSubscriber)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'FEATURED',
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
                  // Project status badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: project.projectStatus == ProjectStatus.underConstruction
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            project.projectStatus == ProjectStatus.underConstruction
                                ? Icons.construction
                                : Icons.architecture,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            project.projectStatus == ProjectStatus.underConstruction
                                ? 'Under Construction'
                                : 'Off-Plan',
                            style: const TextStyle(
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
            // Project details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.hasDeveloperTagline
                        ? project.customerVisibleDeveloperName
                        : 'By ${project.customerVisibleDeveloperName}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          project.location,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
