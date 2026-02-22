import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddAdminRoleScreen extends StatefulWidget {
  const AddAdminRoleScreen({super.key});

  @override
  State<AddAdminRoleScreen> createState() => _AddAdminRoleScreenState();
}

class _AddAdminRoleScreenState extends State<AddAdminRoleScreen> {
  bool _isLoading = false;
  String _message = '';

  Future<void> _addAdminRole() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Get current logged-in user
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _message = '❌ No user is currently logged in';
          _isLoading = false;
        });
        return;
      }

      final email = currentUser.email ?? 'truehome376@gmail.com';
      final userId = currentUser.uid;
      
      // Reference to user document
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
      
      // Check if document exists
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        // Create the document if it doesn't exist
        await userDocRef.set({
          'email': email,
          'role': 'admin',
          'roles': ['admin'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _message = '✅ Admin user created successfully for $email!';
          _isLoading = false;
        });
      } else {
        // Update existing document
        await userDocRef.update({
          'roles': FieldValue.arrayUnion(['admin']),
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _message = '✅ Admin role added successfully to $email!';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Admin Role'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Add Admin Role to:',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'truehome376@gmail.com',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _addAdminRole,
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Add Admin Role'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _message.contains('✅')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _message.contains('✅')
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Text(
                    _message,
                    style: TextStyle(
                      color: _message.contains('✅')
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
