const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'truehome-9a244',
});

const db = admin.firestore();

async function addAdminRole() {
  try {
    // Get user by email
    const email = 'truehome376@gmail.com';
    
    console.log(`Searching for user with email: ${email}`);
    
    const usersSnapshot = await db.collection('users')
      .where('email', '==', email)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('No user found with that email');
      return;
    }
    
    const userDoc = usersSnapshot.docs[0];
    console.log(`Found user: ${userDoc.id}`);
    
    // Update user with admin role
    await userDoc.ref.update({
      roles: admin.firestore.FieldValue.arrayUnion('admin'),
      role: 'admin',
    });
    
    console.log('✅ Admin role added successfully!');
    
    // Verify the update
    const updatedDoc = await userDoc.ref.get();
    console.log('Updated user data:', updatedDoc.data());
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

addAdminRole();
