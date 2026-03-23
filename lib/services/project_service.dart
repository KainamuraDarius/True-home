import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';

class ProjectServiceException implements Exception {
  final String message;
  final bool isNetworkError;

  const ProjectServiceException._(this.message, {this.isNetworkError = false});

  factory ProjectServiceException.network() {
    return const ProjectServiceException._(
      'No internet connection. Please check your network and try again.',
      isNetworkError: true,
    );
  }

  @override
  String toString() => message;
}

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _random = Random();

  bool _isNetworkFirestoreError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
          error.code == 'network-request-failed' ||
          error.code == 'deadline-exceeded';
    }
    final text = error.toString().toLowerCase();
    return text.contains('unknownhostexception') ||
        text.contains('unable to resolve host') ||
        text.contains('dns') ||
        text.contains('eai_nodata');
  }

  // Default locations for project advertisements
  List<String> get defaultLocations => [
    // Kampala Central & East
    'Kololo', 'Nakasero', 'Naguru', 'Bugolobi', 'Muyenga', 'Bukoto',
    // Kampala North & Suburbs
    'Ntinda', 'Kyanja', 'Kira', 'Naalya', 'Namugongo', 'Kyaliwajjala',
    'Kulambiro', 'Kisaasi', 'Najjera', 'Kiwatule', 'Kungu',
    // Wakiso District Areas
    'Kansanga', 'Kabalagala', 'Makindye', 'Ggaba', 'Munyonyo',
    'Lubowa', 'Buziga', 'Kigo', 'Seguku', 'Bbunga',
    // Entebbe Road & Airport Area
    'Entebbe', 'Kajjansi', 'Kitende', 'Kisubi', 'Zana', 'Kitooro',
    // Kampala West & Wakiso
    'Lubaga', 'Ndeeba', 'Mengo', 'Namirembe', 'Rubaga',
    'Busega', 'Lungujja', 'Nateete', 'Wakaliga', 'Masanafu',
    // Northern Bypass & Gayaza Road
    'Bweyogerere', 'Kireka', 'Banda', 'Mutungo', 'Luzira',
    'Gayaza', 'Namulonge', 'Mpererwe', 'Kawempe', 'Kalerwe',
    // Wakiso Town & Surroundings
    'Wakiso', 'Namere', 'Kasangati', 'Matugga', 'Kira Town',
    // Others
    'Kampala', 'Bunga', 'Seeta', 'Mukono'
  ]..sort();

  // Get projects for a specific location with rotation logic
  Future<List<Project>> getProjectsByLocation(String location) async {
    try {
      // Query approved projects only, then filter the selected location in memory
      // to avoid exposing pending submissions to guest users.
      final querySnapshot = await _firestore
          .collection('advertised_projects')
          .where('isApproved', isEqualTo: true)
          .get();

      // Get current time
      final now = DateTime.now();

      // Filter approved and non-expired projects in memory
      List<Project> projects = querySnapshot.docs
          .where((doc) => doc.data()['isDeleted'] != true)
          .map((doc) => Project.fromFirestore(doc))
          .where(
          (p) =>
            p.location == location &&
            p.isApproved &&
            p.adExpiresAt.isAfter(now),
          )
          .toList();

      // With flat pricing, all projects are equal
      // Shuffle to give everyone fair visibility (rotational effect)
      projects.shuffle(_random);
      
      return projects;
    } catch (e) {
      if (_isNetworkFirestoreError(e)) {
        throw ProjectServiceException.network();
      }
      print('Error fetching projects: $e');
      return [];
    }
  }

  // Get all available locations that have projects
  Future<List<String>> getAvailableLocations() async {
    try {
      // Query only by isApproved to avoid composite index requirement
      final querySnapshot = await _firestore
          .collection('advertised_projects')
          .where('isApproved', isEqualTo: true)
          .get();

      print('Found ${querySnapshot.docs.length} approved projects');

      final now = DateTime.now();
      Set<String> locations = {};
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        if (data['isDeleted'] == true) {
          continue;
        }
        
        // Filter by expiry date in memory
        if (data['location'] != null && data['adExpiresAt'] != null) {
          final expiresAt = (data['adExpiresAt'] as Timestamp).toDate();
          if (expiresAt.isAfter(now)) {
            locations.add(data['location'] as String);
            print('Added location: ${data['location']}');
          } else {
            print('Project expired: ${data['location']} - expired on $expiresAt');
          }
        }
      }

      print('Total unique locations: ${locations.length}');
      
      // Only return locations that have active projects
      List<String> sortedLocations = locations.toList()..sort();
      
      return sortedLocations;
    } catch (e) {
      if (_isNetworkFirestoreError(e)) {
        throw ProjectServiceException.network();
      }
      print('Error fetching locations: $e');
      return [];
    }
  }

  // Increment view count when project is displayed
  Future<void> incrementViewCount(String projectId) async {
    try {
      await _firestore
          .collection('advertised_projects')
          .doc(projectId)
          .update({'viewCount': FieldValue.increment(1)});
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  // Increment click count when project is clicked
  Future<void> incrementClickCount(String projectId) async {
    try {
      await _firestore
          .collection('advertised_projects')
          .doc(projectId)
          .update({'clickCount': FieldValue.increment(1)});
    } catch (e) {
      print('Error incrementing click count: $e');
    }
  }

  // Admin: Get all projects (for management)
  Future<List<Project>> getAllProjects({bool? isApproved, bool includeDeleted = false}) async {
    try {
      // Simplified query - get all projects first
      final querySnapshot = await _firestore
          .collection('advertised_projects')
          .get();
      
      // Convert to Project objects
      List<Project> projects = querySnapshot.docs
          .map((doc) => Project.fromFirestore(doc))
          .toList();

      // Filter out deleted projects unless includeDeleted is true
      if (!includeDeleted) {
        projects = projects.where((p) {
          final data = querySnapshot.docs.firstWhere((d) => d.id == p.id).data();
          return data['isDeleted'] != true;
        }).toList();
      }

      // Filter by approval status if specified
      if (isApproved != null) {
        projects = projects.where((p) => p.isApproved == isApproved).toList();
      }

      // Sort by creation date (newest first)
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return projects;
    } catch (e) {
      if (_isNetworkFirestoreError(e)) {
        throw ProjectServiceException.network();
      }
      print('Error fetching all projects: $e');
      return [];
    }
  }

  // Get all approved projects
  Future<List<Project>> getAllApprovedProjects() async {
    try {
      final querySnapshot = await _firestore
          .collection('advertised_projects')
          .where('isApproved', isEqualTo: true)
          .get();

      final now = DateTime.now();
      final projects = querySnapshot.docs
          .where((doc) {
            final data = doc.data();
            if (data['isDeleted'] == true) {
              return false;
            }

            final expiresAtRaw = data['adExpiresAt'];
            if (expiresAtRaw is Timestamp) {
              return expiresAtRaw.toDate().isAfter(now);
            }

            return true;
          })
          .map((doc) => Project.fromFirestore(doc))
          .toList();

      projects.shuffle(_random);
      return projects;
    } catch (e) {
      if (_isNetworkFirestoreError(e)) {
        throw ProjectServiceException.network();
      }
      print('Error fetching approved projects: $e');
      return [];
    }
  }

  // Admin: Approve/reject project
  Future<void> updateProjectApproval(String projectId, bool isApproved) async {
    try {
      if (isApproved) {
        // When approving, also initialize view/click counts to ensure accurate tracking
        await _firestore
            .collection('advertised_projects')
            .doc(projectId)
            .update({
              'isApproved': true,
              'viewCount': 0,
              'clickCount': 0,
            });
      } else {
        // Just reject without modifying counts
        await _firestore
            .collection('advertised_projects')
            .doc(projectId)
            .update({'isApproved': false});
      }
    } catch (e) {
      print('Error updating project approval: $e');
      rethrow;
    }
  }

  // Admin: Delete project (soft delete - moves to trash)
  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore
          .collection('advertised_projects')
          .doc(projectId)
          .update({
        'isDeleted': true,
        'deletedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error deleting project: $e');
      rethrow;
    }
  }

  // Create new project (for developers/admins)
  Future<String> createProject(Project project) async {
    try {
      final docRef = await _firestore
          .collection('advertised_projects')
          .add(project.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating project: $e');
      rethrow;
    }
  }

  // Update existing project
  Future<void> updateProject(String projectId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('advertised_projects')
          .doc(projectId)
          .update(updates);
    } catch (e) {
      print('Error updating project: $e');
      rethrow;
    }
  }
}
