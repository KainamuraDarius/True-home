import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ No user logged in');
    return;
  }
  
  print('✅ Current user: ${user.email} (${user.uid})');
  
  // Add admin role
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'roles': FieldValue.arrayUnion(['admin'])
  }, SetOptions(merge: true));
  
  print('✅ Admin role added successfully!');
  print('👉 Refresh your browser and try sending notifications again.');
}
