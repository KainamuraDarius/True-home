import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _random = Random();

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
      // Simplified query - filter by location only to avoid composite index
      // Then filter approved and non-expired in memory
      final querySnapshot = await _firestore
          .collection('advertised_projects')
          .where('location', isEqualTo: location)
          .get();

      // Get current time
      final now = DateTime.now();

      // Filter approved and non-expired projects in memory
      List<Project> projects = querySnapshot.docs
          .map((doc) => Project.fromFirestore(doc))
          .where((p) => p.isApproved && p.adExpiresAt.isAfter(now))
          .toList();

      // With flat pricing, all projects are equal
      // Shuffle to give everyone fair visibility (rotational effect)
      projects.shuffle(_random);
      
      return projects;
    } catch (e) {
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
  Future<List<Project>> getAllProjects({bool? isApproved}) async {
    try {
      // Simplified query - get all projects first
      final querySnapshot = await _firestore
          .collection('advertised_projects')
          .get();
      
      // Convert to Project objects
      List<Project> projects = querySnapshot.docs
          .map((doc) => Project.fromFirestore(doc))
          .toList();

      // Filter by approval status if specified
      if (isApproved != null) {
        projects = projects.where((p) => p.isApproved == isApproved).toList();
      }

      // Sort by creation date (newest first)
      projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return projects;
    } catch (e) {
      print('Error fetching all projects: $e');
      return [];
    }
  }

  // Admin: Approve/reject project
  Future<void> updateProjectApproval(String projectId, bool isApproved) async {
    try {
      await _firestore
          .collection('advertised_projects')
          .doc(projectId)
          .update({'isApproved': isApproved});
    } catch (e) {
      print('Error updating project approval: $e');
      rethrow;
    }
  }

  // Admin: Delete project
  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore
          .collection('advertised_projects')
          .doc(projectId)
          .delete();
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
