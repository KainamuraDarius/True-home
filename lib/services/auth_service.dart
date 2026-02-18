import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // GoogleSignIn configured with serverClientId for Android
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '843422990018-5tkf432tdafu68vml3o2obo7kfcthn85.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
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
      if (email.toLowerCase() == 'truehome376@gmail.com' && role != UserRole.admin) {
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

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Web uses different Google Sign-In flow
      if (kIsWeb) {
        // Create a GoogleAuthProvider instance
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // Trigger the authentication flow
        final UserCredential userCredential = 
            await _auth.signInWithPopup(googleProvider);
        
        if (userCredential.user == null) {
          throw Exception('Google sign in failed - no user');
        }

        // Check if user exists in Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // Create new user in Firestore
          final now = DateTime.now();
          final newUser = UserModel(
            id: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
            name: userCredential.user!.displayName ?? '',
            roles: [UserRole.customer],
            activeRole: UserRole.customer,
            phoneNumber: userCredential.user!.phoneNumber ?? '',
            createdAt: now,
            updatedAt: now,
            favoritePropertyIds: [],
            isVerified: false,
          );

          await _firestore
              .collection('users')
              .doc(newUser.id)
              .set(newUser.toJson());

          return newUser;
        }

        return UserModel.fromJson({
          ...userDoc.data()!,
          'id': userDoc.id,
        });
      }

      // Mobile Google Sign-In flow
      // Sign out first to force account picker to show
      await _googleSignIn.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to sign in with Google');
      }

      // Block admin email from being used with Google Sign-In
      final userEmail = userCredential.user!.email ?? '';
      if (userEmail.toLowerCase() == 'truehome376@gmail.com') {
        await _auth.signOut();
        await _googleSignIn.signOut();
        throw Exception('This email address is reserved for system administrators. Please use the admin login portal.');
      }

      // Check if user document exists in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      UserModel userModel;

      if (!userDoc.exists) {
        // Create new user document for first-time Google sign-in
        userModel = UserModel(
          id: userCredential.user!.uid,
          email: userEmail,
          name: userCredential.user!.displayName ?? 'User',
          phoneNumber: userCredential.user!.phoneNumber ?? '',
          roles: [UserRole.customer],
          activeRole: UserRole.customer,
          profileImageUrl: userCredential.user!.photoURL,
          isVerified: userCredential.user!.emailVerified,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userModel.toJson());
      } else {
        // User already exists, get their data
        final userData = userDoc.data()!;
        userData['id'] = userDoc.id; // Add document ID to data
        userModel = UserModel.fromJson(userData);
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw Exception(
            'An account already exists with a different sign-in method',
          );
        case 'invalid-credential':
          throw Exception('Invalid Google credentials');
        case 'operation-not-allowed':
          throw Exception('Google sign-in is not enabled');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        case 'user-not-found':
          throw Exception('No user found');
        default:
          throw Exception('Google sign-in failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
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

      await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail);
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
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found for this email');
        case 'invalid-email':
          throw Exception('The email address is invalid');
        default:
          throw Exception('Failed to send reset email: ${e.message}');
      }
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'user-not-found':
          throw Exception('No account found with this email');
        default:
          throw Exception('Failed to send reset email: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to send reset email: $e');
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
        await _auth.currentUser!.sendEmailVerification();
      }
    } catch (e) {
      throw Exception('Failed to send verification email: $e');
    }
  }

  // Reload user to check email verification status
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }
}
