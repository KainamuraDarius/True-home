import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AddAdminRoleScreen extends StatefulWidget {
  final bool embedded;
  const AddAdminRoleScreen({super.key, this.embedded = false});

  @override
  State<AddAdminRoleScreen> createState() => _AddAdminRoleScreenState();
}

class _AddAdminRoleScreenState extends State<AddAdminRoleScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {required bool isError}) {
    setState(() {
      _message = isError ? '❌ $message' : '✅ $message';
    });
    
    // Also show a SnackBar for immediate feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _addAdminRoleByEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    
    if (email.isEmpty) {
      _showMessage('Please enter an email address', isError: true);
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Check if current user is the master admin
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showMessage('You must be logged in to grant admin roles', isError: true);
        setState(() => _isLoading = false);
        return;
      }
      
      if (currentUser.email?.toLowerCase() != 'truehome376@gmail.com') {
        _showMessage('Only the master admin can grant admin roles', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // Find user by email - they must have created an account first
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        _showMessage('User not found. The user must create an account first before being granted admin access.', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final userDoc = usersQuery.docs.first;
      final userData = userDoc.data();
      
      // Check if user is already an admin
      final existingRoles = userData['roles'];
      if (existingRoles is List && existingRoles.contains('admin')) {
        _showMessage('$email already has admin privileges', isError: true);
        setState(() => _isLoading = false);
        return;
      }
      
      // Update the user's role to admin
      await userDoc.reference.update({
        'role': 'admin',
        'roles': FieldValue.arrayUnion(['admin']),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Admin role granted to $email successfully!', isError: false);
      _emailController.clear();
      setState(() => _isLoading = false);
    } on FirebaseException catch (e) {
      _showMessage('Firebase error: ${e.message ?? e.code}', isError: true);
      setState(() => _isLoading = false);
    } catch (e) {
      _showMessage('Unexpected error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addAdminRoleToSelf() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        _showMessage('No user is currently logged in', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final email = currentUser.email ?? '';
      final userId = currentUser.uid;
      
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userDocRef.get();
      
      if (!userDoc.exists) {
        await userDocRef.set({
          'email': email,
          'role': 'admin',
          'roles': ['admin'],
          'name': 'Admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _showMessage('Admin user document created for $email!', isError: false);
        setState(() => _isLoading = false);
      } else {
        await userDocRef.update({
          'roles': FieldValue.arrayUnion(['admin']),
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _showMessage('Admin role added to $email!', isError: false);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showMessage('Error: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    final isMasterAdmin = currentEmail == 'truehome376@gmail.com';

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.orange.shade700, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Role Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Grant admin privileges to users',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Grant admin by email (master admin only)
          if (isMasterAdmin) ...[
            const Text(
              'Grant Admin Role to User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the email address of the user you want to make an admin:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'User Email',
                hintText: 'example@email.com',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _addAdminRoleByEmail,
                icon: const Icon(Icons.person_add),
                label: const Text('Grant Admin Role'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
          ],
          
          // Add admin to self
          const Text(
            'Add Admin Role to Current Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Logged in as: ${FirebaseAuth.instance.currentUser?.email ?? "Unknown"}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _addAdminRoleToSelf,
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Add Admin Role to My Account'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          // Loading indicator
          if (_isLoading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          
          // Message
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
                  color: _message.contains('✅') ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _message.contains('✅') ? Icons.check_circle : Icons.error,
                    color: _message.contains('✅') ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _message.replaceAll('✅ ', '').replaceAll('❌ ', ''),
                      style: TextStyle(
                        color: _message.contains('✅')
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Admin Role'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }
}
