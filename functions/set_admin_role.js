const admin = require('firebase-admin');

// Initialize with project ID
admin.initializeApp({
  projectId: 'truehome-9a244'
});

const db = admin.firestore();

// Get your email from command line argument
const userEmail = process.argv[2];

if (!userEmail) {
  console.error('❌ Please provide your email: node set_admin_role.js your@email.com');
  process.exit(1);
}

async function setAdminRole() {
  try {
    // Find user by email
    const userRecord = await admin.auth().getUserByEmail(userEmail);
    const uid = userRecord.uid;
    
    console.log(`✅ Found user: ${userEmail} (${uid})`);
    
    // Get current user data
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.data();
    
    console.log('Current roles:', userData?.roles || 'none');
    
    // Update Firestore user document
    await db.collection('users').doc(uid).set({
      roles: admin.firestore.FieldValue.arrayUnion('admin')
    }, { merge: true });
    
    console.log('✅ Admin role added successfully!');
    console.log('You can now send notifications from the admin panel.');
    console.log('\n👉 Please refresh your browser and try again.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

setAdminRole();
