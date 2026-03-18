import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewTrackingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ViewTrackingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // Prevent accidental double-counts from quick re-opens/navigation jitter.
  static const Duration _viewCooldown = Duration(seconds: 20);
  static const Duration _clickCooldown = Duration(seconds: 3);

  Future<void> trackPropertyView({
    required String propertyId,
    required String ownerId,
  }) async {
    await _trackView(
      collection: 'properties',
      docId: propertyId,
      ownerId: ownerId,
      itemType: 'property',
    );
  }

  Future<void> trackProjectView({
    required String projectId,
    required String developerId,
  }) async {
    await _trackView(
      collection: 'advertised_projects',
      docId: projectId,
      ownerId: developerId,
      itemType: 'project',
    );
  }

  Future<void> trackProjectClick({
    required String projectId,
    required String developerId,
  }) async {
    final user = _auth.currentUser;

    // Never count owner self-clicks.
    if (user != null && user.uid == developerId) return;

    // Count only customer-mode traffic.
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final activeRole = (userDoc.data()?['activeRole'] as String?)?.toLowerCase();
      if (activeRole != null && activeRole != 'customer') {
        return;
      }
    }

    final viewerId = user?.uid ?? 'guest';
    final clickKey = 'click_project_${projectId}_$viewerId';
    final canCount = await _canCountEvent(clickKey, _clickCooldown);
    if (!canCount) return;

    await _firestore.collection('advertised_projects').doc(projectId).set({
      'clickCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> _trackView({
    required String collection,
    required String docId,
    required String ownerId,
    required String itemType,
  }) async {
    final user = _auth.currentUser;

    // Never count owner self-views.
    if (user != null && user.uid == ownerId) return;

    // Count only customer-mode traffic as requested.
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final activeRole = (userDoc.data()?['activeRole'] as String?)?.toLowerCase();
      if (activeRole != null && activeRole != 'customer') {
        return;
      }
    }

    final viewerId = user?.uid ?? 'guest';
    final viewKey = 'view_${itemType}_${docId}_$viewerId';
    final canCount = await _canCountEvent(viewKey, _viewCooldown);
    if (!canCount) return;

    await _firestore.collection(collection).doc(docId).set({
      'viewCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<bool> _canCountEvent(String key, Duration cooldown) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = prefs.getInt(key);

    if (lastMs != null) {
      final elapsed = Duration(milliseconds: nowMs - lastMs);
      if (elapsed < cooldown) {
        return false;
      }
    }

    await prefs.setInt(key, nowMs);
    return true;
  }
}
