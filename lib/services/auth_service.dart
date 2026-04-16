import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _emailActionRedirectUrl =
      'https://truehome-9a244.web.app/';

  ActionCodeSettings get _emailActionCodeSettings => ActionCodeSettings(
    url: _emailActionRedirectUrl,
    handleCodeInApp: true,
    androidPackageName: 'com.truehome.app',
    androidInstallApp: true,
    androidMinimumVersion: '1',
    iOSBundleId: 'com.example.trueHome',
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    required UserRole role,
    String? companyName,
    String? companyAddress,
    String? whatsappNumber,
  }) async {
    try {
      // Block admin email from being used by regular users
      if (email.toLowerCase() == 'truehome376@gmail.com' &&
          role != UserRole.admin) {
        throw Exception('This email address is reserved for system use');
      }

      // Create user in Firebase Auth
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (credential.user == null) {
        throw Exception('Failed to create user');
      }

      // Create user document in Firestore
      // If user is registering as an agent, give them both customer and agent roles
      // so they can switch between them
      final List<UserRole> userRoles = role == UserRole.propertyAgent
          ? [UserRole.customer, UserRole.propertyAgent]
          : [role];

      final UserModel userModel = UserModel(
        id: credential.user!.uid,
        email: email,
        name: name,
        phoneNumber: phoneNumber,
        roles: userRoles, // Initialize with role(s) in array
        activeRole: role, // Set as active role
        companyName: companyName,
        companyAddress: companyAddress,
        whatsappNumber: whatsappNumber,
        profileImageUrl: null,
        isVerified: false,
        termsAccepted: true, // User accepted during registration
        termsAcceptedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(userModel.toJson());

      // Update display name
      await credential.user!.updateDisplayName(name);

      // Send verification email so users can verify later from their profile.
      await credential.user!.sendEmailVerification(_emailActionCodeSettings);

      // Keep user logged in for email verification
      // DO NOT sign out - they need to verify their email

      return userModel;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw Exception('The password is too weak');
        case 'email-already-in-use':
          throw Exception('An account already exists for this email');
        case 'invalid-email':
          throw Exception('The email address is invalid');
        case 'operation-not-allowed':
          throw Exception('Email/password accounts are not enabled');
        default:
          throw Exception('Sign up failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Failed to sign in');
      }

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      // Add the document ID to the data
      final userData = userDoc.data()!;
      userData['id'] = userDoc.id;

      return UserModel.fromJson(userData);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found for this email');
        case 'wrong-password':
          throw Exception('Incorrect password');
        case 'invalid-email':
          throw Exception('The email address is invalid');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        case 'invalid-credential':
          throw Exception('Invalid email or password');
        case 'too-many-requests':
          throw Exception('Too many failed attempts. Please try again later');
        default:
          throw Exception('Login failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Get current user ID
  Future<String?> getCurrentUserId() async {
    return _auth.currentUser?.uid;
  }

  // Get current user role
  Future<UserRole?> getCurrentUserRole() async {
    if (_auth.currentUser == null) return null;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      if (!userDoc.exists) return null;

      final roleString = userDoc.data()?['role'];
      if (roleString == null) return null;

      return UserRole.values.firstWhere(
        (e) => e.name == roleString,
        orElse: () => UserRole.customer,
      );
    } catch (e) {
      return null;
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      return UserModel.fromJson(userDoc.data()!);
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Get current user profile
  Future<UserModel?> getCurrentUser() async {
    if (_auth.currentUser == null) return null;

    try {
      return await getUserData(_auth.currentUser!.uid);
    } catch (e) {
      throw Exception('Failed to get current user: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('No user logged in');
      }

      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update(
            user.toJson()..['updatedAt'] = DateTime.now().toIso8601String(),
          );

      // Update display name if changed
      if (user.name != _auth.currentUser!.displayName) {
        await _auth.currentUser!.updateDisplayName(user.name);
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Update email
  Future<void> updateEmail(String newEmail) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('No user logged in');
      }

      await _auth.currentUser!.verifyBeforeUpdateEmail(
        newEmail,
        _emailActionCodeSettings,
      );
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'email': newEmail,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('This email is already in use');
        case 'invalid-email':
          throw Exception('The email address is invalid');
        case 'requires-recent-login':
          throw Exception('Please re-authenticate and try again');
        default:
          throw Exception('Failed to update email: ${e.message}');
      }
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('No user logged in');
      }

      await _auth.currentUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw Exception('The password is too weak');
        case 'requires-recent-login':
          throw Exception('Please re-authenticate and try again');
        default:
          throw Exception('Failed to update password: ${e.message}');
      }
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await sendPasswordResetEmail(email);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Send password reset email with custom Cloud Function
  Future<void> sendPasswordResetEmail(String email) async {
    email = email.trim();

    try {
      // Get user's name - try to find by email in Firestore
      String userName = 'User';
      try {
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          userName = userQuery.docs.first.data()['name'] ?? 'User';
        }
      } catch (e) {
        // If lookup fails, just use default name
        print('Could not retrieve user name: $e');
      }

      // Call Cloud Function to send custom email
      final callable = FirebaseFunctions.instance.httpsCallable('sendPasswordResetEmail');
      await callable.call({
        'email': email,
        'continueUrl': _emailActionRedirectUrl,
        'userName': userName,
      });
    } on FirebaseException catch (e) {
      // Fallback to Firebase native password reset email when callable email fails.
      try {
        await _auth.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: _emailActionCodeSettings,
        );
      } on FirebaseAuthException catch (authError) {
        switch (authError.code) {
          case 'invalid-email':
            throw Exception('Invalid email address');
          case 'user-not-found':
            throw Exception('No account found with this email');
          default:
            throw Exception(
              'Failed to send reset email: ${authError.message}',
            );
        }
      }
      print('Cloud Function reset email failed, used Firebase fallback: ${e.message}');
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
    }
  }

  // Send email verification link
  Future<void> sendEmailVerificationLink({
    required String email,
    String? userName,
  }) async {
    email = email.trim();

    try {
      // Get user's name if not provided
      String finalUserName = userName ?? 'User';
      if (userName == null) {
        try {
          final userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          
          if (userQuery.docs.isNotEmpty) {
            finalUserName = userQuery.docs.first.data()['name'] ?? 'User';
          }
        } catch (e) {
          print('Could not retrieve user name: $e');
        }
      }

      // Call Cloud Function to send custom email
      final callable = FirebaseFunctions.instance.httpsCallable('sendEmailVerificationLink');
      await callable.call({
        'email': email,
        'continueUrl': _emailActionRedirectUrl,
        'userName': finalUserName,
      });
    } on FirebaseException catch (e) {
      // Fallback to Firebase native verification email when callable email fails.
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.sendEmailVerification(_emailActionCodeSettings);
      } else {
        throw Exception(
          'Could not send verification email fallback because no signed-in user was found.',
        );
      }
      print('Cloud Function verification email failed, used Firebase fallback: ${e.message}');
    } catch (e) {
      throw Exception('Failed to send verification email: $e');
    }
  }

  // Notify user of email address change
  Future<void> notifyEmailChange({
    required String oldEmail,
    required String newEmail,
    String? userName,
    String? changeLink,
  }) async {
    try {
      oldEmail = oldEmail.trim();
      newEmail = newEmail.trim();

      // Get user's name if not provided
      String finalUserName = userName ?? 'User';
      if (userName == null && _auth.currentUser != null) {
        finalUserName = _auth.currentUser!.displayName ?? 'User';
      }

      // Call Cloud Function to send notification
      final callable = FirebaseFunctions.instance.httpsCallable('sendEmailChangeNotification');
      await callable.call({
        'oldEmail': oldEmail,
        'newEmail': newEmail,
        'userName': finalUserName,
        'changeLink': changeLink ?? '',
      });
    } catch (e) {
      throw Exception('Failed to send email change notification: $e');
    }
  }

  // Send security notification (MFA, login alerts, etc.)
  Future<void> sendSecurityNotification({
    required String email,
    required String notificationType, // 'mfa_enrolled', 'login_alert', 'password_changed', 'suspicious_activity'
    String? userName,
    String? actionLink,
    String? deviceInfo,
  }) async {
    try {
      email = email.trim();

      // Get user's name if not provided
      String finalUserName = userName ?? 'User';
      if (userName == null && _auth.currentUser != null) {
        finalUserName = _auth.currentUser!.displayName ?? 'User';
      }

      // Call Cloud Function to send notification
      final callable = FirebaseFunctions.instance.httpsCallable('sendSecurityNotification');
      await callable.call({
        'email': email,
        'notificationType': notificationType,
        'userName': finalUserName,
        'actionLink': actionLink ?? '',
        'deviceInfo': deviceInfo ?? '',
      });
    } catch (e) {
      throw Exception('Failed to send security notification: $e');
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('No user logged in');
      }

      final userId = _auth.currentUser!.uid;

      // Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Delete user from Firebase Auth
      await _auth.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please re-authenticate and try again');
      }
      throw Exception('Failed to delete account: ${e.message}');
    }
  }

  // Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('No user logged in');
      }

      if (!_auth.currentUser!.emailVerified) {
        await _auth.currentUser!.sendEmailVerification(_emailActionCodeSettings);
      }
    } catch (e) {
      throw Exception('Failed to send verification email: $e');
    }
  }

  // Resend verification email from login screen for unverified email/password users.
  Future<void> resendVerificationEmailForLogin({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Unable to resend verification email right now.');
      }

      if (user.emailVerified) {
        await _auth.signOut();
        throw Exception('This email is already verified. Please log in again.');
      }

      await user.sendEmailVerification(_emailActionCodeSettings);
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found for this email');
        case 'wrong-password':
        case 'invalid-credential':
          throw Exception('Invalid email or password');
        case 'too-many-requests':
          throw Exception('Too many attempts. Please try again later.');
        default:
          throw Exception('Failed to resend verification email: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to resend verification email: $e');
    }
  }

  // Reload user to check email verification status
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }
}
