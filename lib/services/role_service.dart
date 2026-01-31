import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class RoleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Switch the user's active role
  Future<void> switchActiveRole(UserRole newRole) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get current user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');

    final userData = userDoc.data()!;
    final userModel = UserModel.fromJson(userData);

    // Check if user has the role they're trying to switch to
    if (!userModel.roles.contains(newRole)) {
      throw Exception('You do not have permission to access this role');
    }

    // Update active role in Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'activeRole': newRole.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Add a role to the user's roles list
  Future<void> addRole(UserRole role) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get current user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');

    final userData = userDoc.data()!;
    final userModel = UserModel.fromJson(userData);

    // Check if user already has this role
    if (userModel.roles.contains(role)) {
      throw Exception('You already have this role');
    }

    // Add the new role
    final updatedRoles = [...userModel.roles, role];

    await _firestore.collection('users').doc(user.uid).update({
      'roles': updatedRoles.map((r) => r.name).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get the current user's model
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return null;

    return UserModel.fromJson(userDoc.data()!);
  }

  /// Stream of current user data
  Stream<UserModel?> get currentUserStream {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromJson(snapshot.data()!);
    });
  }

  /// Check if user has a specific role
  Future<bool> hasRole(UserRole role) async {
    final userModel = await getCurrentUser();
    if (userModel == null) return false;
    return userModel.roles.contains(role);
  }

  /// Upgrade user to agent (add propertyAgent role)
  Future<void> becomeAgent({
    required String companyName,
    String? companyAddress,
    String? whatsappNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get current user data
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User data not found');

    final userData = userDoc.data()!;
    final userModel = UserModel.fromJson(userData);

    // Check if user already has agent role
    if (userModel.roles.contains(UserRole.propertyAgent)) {
      throw Exception('You are already an agent');
    }

    // Add agent role and update profile
    final updatedRoles = [...userModel.roles, UserRole.propertyAgent];

    await _firestore.collection('users').doc(user.uid).update({
      'roles': updatedRoles.map((r) => r.name).toList(),
      'activeRole': UserRole.propertyAgent.name, // Switch to agent role
      'companyName': companyName,
      'companyAddress': companyAddress,
      'whatsappNumber': whatsappNumber,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Migrate old users with single role to new multi-role format
  Future<void> migrateUserToMultiRole(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    
    // Check if already migrated
    if (data['roles'] != null && data['activeRole'] != null) {
      return; // Already migrated
    }

    // Get old role
    final oldRole = data['role'] as String?;
    if (oldRole == null) return;

    // Convert to new format
    await _firestore.collection('users').doc(userId).update({
      'roles': [oldRole],
      'activeRole': oldRole,
    });
  }
}
