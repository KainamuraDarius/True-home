import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class CreateAdminAccountScreen extends StatefulWidget {
  const CreateAdminAccountScreen({super.key});

  @override
  State<CreateAdminAccountScreen> createState() => _CreateAdminAccountScreenState();
}

class _CreateAdminAccountScreenState extends State<CreateAdminAccountScreen> {
  bool _isCreating = false;
  String? _result;

  Future<void> _createAdminAccount() async {
    setState(() {
      _isCreating = true;
      _result = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // Admin credentials
      const email = 'truehome376@gmail.com';
      const password = 'truehomeadmin@565';

      // Check if admin already exists
      final userDoc = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userDoc.docs.isNotEmpty) {
        setState(() {
          _result = 'Admin account already exists in Firestore!\n\nEmail: $email\nPassword: $password';
          _isCreating = false;
        });
        return;
      }

      // Try to sign in first to check if account exists in Auth
      try {
        final signInResult = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Account exists in Auth, create Firestore document
        final userModel = UserModel(
          id: signInResult.user!.uid,
          email: email,
          name: 'System Administrator',
          phoneNumber: '+256000000000',
          roles: [UserRole.admin],
          activeRole: UserRole.admin,
          companyName: 'TrueHome',
          companyAddress: 'Uganda',
          whatsappNumber: '+256000000000',
          profileImageUrl: null,
          isVerified: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await firestore
            .collection('users')
            .doc(signInResult.user!.uid)
            .set(userModel.toJson());

        await auth.signOut();

        setState(() {
          _result = 'Admin account Firestore document created!\n\nEmail: $email\nPassword: $password';
        });
      } catch (e) {
        // Account doesn't exist, create it
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final userModel = UserModel(
          id: credential.user!.uid,
          email: email,
          name: 'System Administrator',
          phoneNumber: '+256000000000',
          roles: [UserRole.admin],
          activeRole: UserRole.admin,
          companyName: 'TrueHome',
          companyAddress: 'Uganda',
          whatsappNumber: '+256000000000',
          profileImageUrl: null,
          isVerified: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userModel.toJson());

        await auth.signOut();

        setState(() {
          _result = 'Admin account created successfully!\n\nEmail: $email\nPassword: $password';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Admin Account'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Setup Admin Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'This will create or verify the admin account:\n\nEmail: truehome376@gmail.com\nPassword: truehomeadmin@565',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isCreating ? null : _createAdminAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create/Verify Admin Account',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _result!.contains('Error')
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _result!.contains('Error')
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                child: Text(
                  _result!,
                  style: TextStyle(
                    fontSize: 14,
                    color: _result!.contains('Error')
                        ? Colors.red
                        : Colors.green.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
