const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure email transporter
// For Gmail: Enable 2FA and create an App Password
// Or use SendGrid, AWS SES, etc.
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().email?.user || process.env.EMAIL_USER,
    pass: functions.config().email?.password || process.env.EMAIL_PASSWORD
  }
});

// Trigger when a verification code document is created
exports.sendVerificationEmail = functions.firestore
  .document('verification_codes/{userId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const code = data.code;
    const email = data.email;

    const mailOptions = {
      from: `True Home <${functions.config().email?.user || 'noreply@truehome.com'}>`,
      to: email,
      subject: 'Verify Your True Home Account',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { 
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
              color: white; 
              padding: 30px; 
              text-align: center; 
              border-radius: 10px 10px 0 0; 
            }
            .content { 
              background: #f9f9f9; 
              padding: 30px; 
              border-radius: 0 0 10px 10px; 
            }
            .code-box { 
              background: white; 
              border: 2px dashed #667eea; 
              padding: 20px; 
              text-align: center; 
              margin: 20px 0; 
              border-radius: 8px; 
            }
            .code { 
              font-size: 36px; 
              font-weight: bold; 
              letter-spacing: 10px; 
              color: #667eea; 
              font-family: 'Courier New', monospace;
            }
            .footer { 
              text-align: center; 
              margin-top: 20px; 
              color: #666; 
              font-size: 14px; 
            }
            .warning { 
              background: #fff3cd; 
              border-left: 4px solid #ffc107; 
              padding: 15px; 
              margin: 20px 0; 
              border-radius: 4px;
            }
            h1 { margin: 0; font-size: 28px; }
            h2 { color: #333; margin-top: 0; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🏠 True Home</h1>
              <p style="margin: 5px 0 0 0; font-size: 16px;">Welcome to Your New Home Journey</p>
            </div>
            <div class="content">
              <h2>Verify Your Email Address</h2>
              <p>Thank you for registering with True Home! To complete your registration, please enter the verification code below in the app:</p>
              
              <div class="code-box">
                <p style="margin: 0 0 10px 0; color: #666; font-size: 14px;">Your Verification Code</p>
                <div class="code">${code}</div>
              </div>
              
              <div class="warning">
                <strong>⚠️ Important:</strong> This code will expire in <strong>10 minutes</strong>. Please verify your account promptly.
              </div>
              
              <p style="color: #666;">If you didn't create an account with True Home, please ignore this email.</p>
              
              <div class="footer">
                <p style="margin: 5px 0;">© ${new Date().getFullYear()} True Home. All rights reserved.</p>
                <p style="margin: 5px 0; color: #667eea; font-weight: 500;">Find your dream home with us!</p>
              </div>
            </div>
          </div>
        </body>
        </html>
      `
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log(`✅ Verification email sent to ${email}`);
      return null;
    } catch (error) {
      console.error('❌ Error sending email:', error);
      // Still return success so the user can use the code from console
      return null;
    }
  });

// HTTP function to send verification email (alternative method)
exports.sendVerificationEmailHttp = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { email, code } = data;

  if (!email || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and code are required');
  }

  const mailOptions = {
    from: `True Home <${functions.config().email?.user || 'noreply@truehome.com'}>`,
    to: email,
    subject: 'Verify Your True Home Account',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            padding: 30px; 
            text-align: center; 
            border-radius: 10px 10px 0 0; 
          }
          .content { 
            background: #f9f9f9; 
            padding: 30px; 
            border-radius: 0 0 10px 10px; 
          }
          .code-box { 
            background: white; 
            border: 2px dashed #667eea; 
            padding: 20px; 
            text-align: center; 
            margin: 20px 0; 
            border-radius: 8px; 
          }
          .code { 
            font-size: 36px; 
            font-weight: bold; 
            letter-spacing: 10px; 
            color: #667eea; 
            font-family: 'Courier New', monospace;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🏠 True Home</h1>
            <p style="margin: 5px 0 0 0;">Welcome to Your New Home Journey</p>
          </div>
          <div class="content">
            <h2>Verify Your Email Address</h2>
            <p>Your verification code is:</p>
            <div class="code-box">
              <div class="code">${code}</div>
            </div>
            <p style="color: #999; font-size: 14px;">This code expires in 10 minutes.</p>
          </div>
        </div>
      </body>
      </html>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});

// Automatically notify hostel custodians when a new reservation is created.
exports.onReservationCreatedNotifyCustodian = functions.firestore
  .document('reservations/{reservationId}')
  .onCreate(async (snap, context) => {
    const reservation = snap.data();
    const reservationId = context.params.reservationId;

    const custodianEmail = reservation.hostelManagerEmail;
    const fallbackAdminEmail = functions.config().email?.user || process.env.EMAIL_USER;
    const recipient = custodianEmail || fallbackAdminEmail;

    if (!recipient) {
      console.log('No custodian/admin recipient email configured for reservation', reservationId);
      return null;
    }

    const mailOptions = {
      from: `True Home <${functions.config().email?.user || 'noreply@truehome.com'}>`,
      to: recipient,
      subject: `New Hostel Booking: ${reservation.propertyTitle || 'Hostel Reservation'}`,
      html: `
        <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #222; max-width: 620px; margin: 0 auto;">
          <h2 style="margin-bottom: 8px;">New Hostel Booking</h2>
          <p style="margin-top: 0; color: #666;">Reservation ID: <strong>${reservationId}</strong></p>
          <table style="width: 100%; border-collapse: collapse; margin-top: 12px;">
            <tr><td style="padding: 8px; border: 1px solid #eee;"><strong>Hostel</strong></td><td style="padding: 8px; border: 1px solid #eee;">${reservation.propertyTitle || ''}</td></tr>
            <tr><td style="padding: 8px; border: 1px solid #eee;"><strong>Room Type</strong></td><td style="padding: 8px; border: 1px solid #eee;">${reservation.roomTypeName || ''}</td></tr>
            <tr><td style="padding: 8px; border: 1px solid #eee;"><strong>Student Name</strong></td><td style="padding: 8px; border: 1px solid #eee;">${reservation.studentName || ''}</td></tr>
            <tr><td style="padding: 8px; border: 1px solid #eee;"><strong>Student Phone</strong></td><td style="padding: 8px; border: 1px solid #eee;">${reservation.studentPhone || ''}</td></tr>
            <tr><td style="padding: 8px; border: 1px solid #eee;"><strong>Student Email</strong></td><td style="padding: 8px; border: 1px solid #eee;">${reservation.studentEmail || 'N/A'}</td></tr>
            <tr><td style="padding: 8px; border: 1px solid #eee;"><strong>Payment Status</strong></td><td style="padding: 8px; border: 1px solid #eee;">${reservation.paymentStatus || 'pending'}</td></tr>
          </table>
          <p style="margin-top: 16px;">Please follow up with the student for room allocation and records.</p>
        </div>
      `,
    };

    try {
      await transporter.sendMail(mailOptions);
      console.log(`Custodian booking notification sent for reservation ${reservationId} to ${recipient}`);

      await admin.firestore().collection('custodian_notifications_log').add({
        reservationId,
        recipient,
        sentAt: new Date().toISOString(),
        status: 'sent',
      });
    } catch (error) {
      console.error('Error sending custodian reservation email:', error);
      await admin.firestore().collection('custodian_notifications_log').add({
        reservationId,
        recipient,
        sentAt: new Date().toISOString(),
        status: 'failed',
        errorMessage: error.message,
      });
    }

    return null;
  });

// ============================================
// PUSH NOTIFICATIONS (FCM)
// ============================================

// Send notification when property is approved
exports.onPropertyApproved = functions.firestore
  .document('properties/{propertyId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if status changed to approved
    if (before.status !== 'approved' && after.status === 'approved') {
      const ownerId = after.ownerId;
      
      // Get owner's FCM token
      const userDoc = await admin.firestore().collection('users').doc(ownerId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (fcmToken) {
        const message = {
          notification: {
            title: '✅ Property Approved!',
            body: `Your property "${after.title}" has been approved and is now live!`
          },
          data: {
            type: 'property_approved',
            propertyId: context.params.propertyId
          },
          token: fcmToken
        };
        
        try {
          await admin.messaging().send(message);
          console.log('Approval notification sent to:', ownerId);
        } catch (error) {
          console.error('Error sending notification:', error);
        }
      }
    }
    
    // Check if status changed to rejected
    if (before.status !== 'rejected' && after.status === 'rejected') {
      const ownerId = after.ownerId;
      const userDoc = await admin.firestore().collection('users').doc(ownerId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (fcmToken) {
        const message = {
          notification: {
            title: '❌ Property Update Required',
            body: `Your property "${after.title}" needs review. ${after.rejectionReason || 'Please check details.'}`
          },
          data: {
            type: 'property_rejected',
            propertyId: context.params.propertyId
          },
          token: fcmToken
        };
        
        try {
          await admin.messaging().send(message);
        } catch (error) {
          console.error('Error sending notification:', error);
        }
      }
    }
  });

// Send notification when new property is added (to all customers)
exports.onNewProperty = functions.firestore
  .document('properties/{propertyId}')
  .onCreate(async (snap, context) => {
    const property = snap.data();
    
    if (property.status === 'approved') {
      const message = {
        notification: {
          title: '🏠 New Property Available!',
          body: `${property.title} in ${property.location} - ${property.currency} ${property.price.toLocaleString()}`
        },
        data: {
          type: 'new_property',
          propertyId: context.params.propertyId
        },
        topic: 'all_customers'
      };
      
      try {
        await admin.messaging().send(message);
        console.log('New property notification sent');
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }
  });

// Callable function to send custom notification
exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const roles = userDoc.data()?.roles || [];
  
  if (!roles.includes('admin')) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can send notifications');
  }
  
  const { userId, title, body, type, propertyId } = data;
  
  // Get user's FCM token
  const targetUserDoc = await admin.firestore().collection('users').doc(userId).get();
  const fcmToken = targetUserDoc.data()?.fcmToken;
  
  if (!fcmToken) {
    throw new functions.https.HttpsError('not-found', 'User has no FCM token');
  }
  
  const message = {
    notification: {
      title: title,
      body: body
    },
    data: {
      type: type || 'custom',
      propertyId: propertyId || ''
    },
    token: fcmToken
  };
  
  try {
    await admin.messaging().send(message);
    return { success: true, message: 'Notification sent successfully' };
  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});

// Send notification to topic (all users, agents, customers)
exports.sendTopicNotification = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const roles = userDoc.data()?.roles || [];
  
  if (!roles.includes('admin')) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can send notifications');
  }
  
  const { topic, title, body, type } = data;
  
  // Send FCM push notification to topic
  const message = {
    notification: {
      title: title,
      body: body
    },
    data: {
      type: type || 'announcement',
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    topic: topic
  };
  
  try {
    await admin.messaging().send(message);
    console.log(`✅ Push notification sent to topic: ${topic}`);
    
    // Store notifications in Firestore for in-app viewing
    const usersRef = admin.firestore().collection('users');
    let usersSnapshot;
    
    // Get users based on topic
    if (topic === 'all_users') {
      usersSnapshot = await usersRef.get();
    } else if (topic === 'agents') {
      usersSnapshot = await usersRef.where('roles', 'array-contains', 'propertyAgent').get();
    } else if (topic === 'customers') {
      usersSnapshot = await usersRef.where('roles', 'array-contains', 'customer').get();
    } else {
      usersSnapshot = await usersRef.get();
    }
    
    // Create notification document for each user
    const batch = admin.firestore().batch();
    const notificationsRef = admin.firestore().collection('notifications');
    
    usersSnapshot.docs.forEach(userDoc => {
      const notificationRef = notificationsRef.doc();
      batch.set(notificationRef, {
        userId: userDoc.id,
        title: title,
        message: body,
        type: type || 'announcement',
        isRead: false,
        createdAt: new Date().toISOString()
      });
    });
    
    await batch.commit();
    console.log(`✅ In-app notifications stored for ${usersSnapshot.docs.length} users`);
    
    return { 
      success: true, 
      message: `Notification sent to ${topic} (${usersSnapshot.docs.length} users)` 
    };
  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification: ' + error.message);
  }
});

// Send notification for new hostel added (triggered when a hostel property is created/approved)
exports.onNewHostelApproved = functions.firestore
  .document('properties/{propertyId}')
  .onWrite(async (change, context) => {
    // Skip if document was deleted
    if (!change.after.exists) return null;
    
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.data();
    
    // Check if this is a new approval (status changed to approved)
    const isNewApproval = (!before || before.status !== 'approved') && after.status === 'approved';
    
    // Check if it's a hostel
    if (!isNewApproval || after.propertyType !== 'hostel') return null;
    
    console.log(`🏠 New hostel approved: ${after.title}`);
    
    // Send push notification to all customers about new hostel
    const message = {
      notification: {
        title: '🏠 New Hostel Available!',
        body: `${after.title} in ${after.location} - ${after.currency} ${after.price?.toLocaleString() || 'N/A'}`
      },
      data: {
        type: 'new_hostel',
        propertyId: context.params.propertyId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      topic: 'customers'
    };
    
    try {
      await admin.messaging().send(message);
      console.log('✅ New hostel notification sent to customers');
      
      // Store in-app notifications for customers
      const customersSnapshot = await admin.firestore()
        .collection('users')
        .where('roles', 'array-contains', 'customer')
        .get();
      
      const batch = admin.firestore().batch();
      const notificationsRef = admin.firestore().collection('notifications');
      
      customersSnapshot.docs.forEach(userDoc => {
        const notificationRef = notificationsRef.doc();
        batch.set(notificationRef, {
          userId: userDoc.id,
          title: '🏠 New Hostel Available!',
          message: `${after.title} in ${after.location} - ${after.currency} ${after.price?.toLocaleString() || 'N/A'}`,
          type: 'new_hostel',
          propertyId: context.params.propertyId,
          isRead: false,
          createdAt: new Date().toISOString()
        });
      });
      
      await batch.commit();
      console.log(`✅ In-app notifications created for ${customersSnapshot.docs.length} customers`);
    } catch (error) {
      console.error('Error sending new hostel notification:', error);
    }
    
    return null;
  });

// Process scheduled notifications - runs every minute
exports.processScheduledNotifications = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const now = new Date();
    console.log(`⏰ Checking scheduled notifications at ${now.toISOString()}`);
    
    try {
      // Get all pending notifications that are due
      const pendingSnapshot = await admin.firestore()
        .collection('scheduled_notifications')
        .where('status', '==', 'pending')
        .where('scheduledTime', '<=', now.toISOString())
        .get();
      
      if (pendingSnapshot.empty) {
        console.log('No scheduled notifications to process');
        return null;
      }
      
      console.log(`📬 Processing ${pendingSnapshot.docs.length} scheduled notification(s)`);
      
      for (const doc of pendingSnapshot.docs) {
        const notification = doc.data();
        
        try {
          // Send FCM push notification
          const message = {
            notification: {
              title: notification.title,
              body: notification.body
            },
            data: {
              type: notification.type || 'scheduled',
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            topic: notification.topic
          };
          
          await admin.messaging().send(message);
          console.log(`✅ Sent scheduled notification: ${notification.title}`);
          
          // Store notifications in Firestore for in-app viewing
          const usersRef = admin.firestore().collection('users');
          let usersSnapshot;
          
          if (notification.topic === 'all_users') {
            usersSnapshot = await usersRef.get();
          } else if (notification.topic === 'agents') {
            usersSnapshot = await usersRef.where('roles', 'array-contains', 'propertyAgent').get();
          } else if (notification.topic === 'customers') {
            usersSnapshot = await usersRef.where('roles', 'array-contains', 'customer').get();
          } else {
            usersSnapshot = await usersRef.get();
          }
          
          // Create notification document for each user
          const batch = admin.firestore().batch();
          const notificationsRef = admin.firestore().collection('notifications');
          
          usersSnapshot.docs.forEach(userDoc => {
            const notificationRef = notificationsRef.doc();
            batch.set(notificationRef, {
              userId: userDoc.id,
              title: notification.title,
              message: notification.body,
              type: notification.type || 'scheduled',
              isRead: false,
              createdAt: new Date().toISOString()
            });
          });
          
          await batch.commit();
          console.log(`✅ Created in-app notifications for ${usersSnapshot.docs.length} users`);
          
          // Mark as sent
          await doc.ref.update({
            status: 'sent',
            sentAt: new Date().toISOString()
          });
          
        } catch (error) {
          console.error(`❌ Failed to send notification ${doc.id}:`, error);
          
          // Mark as failed
          await doc.ref.update({
            status: 'failed',
            errorMessage: error.message
          });
        }
      }
      
    } catch (error) {
      console.error('Error processing scheduled notifications:', error);
    }
    
    return null;
  });

// Callable function to manually process scheduled notifications (for testing)
exports.processScheduledNotificationsManual = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const roles = userDoc.data()?.roles || [];
  
  if (!roles.includes('admin')) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can process notifications');
  }
  
  const now = new Date();
  let processed = 0;
  let failed = 0;
  
  try {
    const pendingSnapshot = await admin.firestore()
      .collection('scheduled_notifications')
      .where('status', '==', 'pending')
      .where('scheduledTime', '<=', now.toISOString())
      .get();
    
    for (const doc of pendingSnapshot.docs) {
      const notification = doc.data();
      
      try {
        const message = {
          notification: {
            title: notification.title,
            body: notification.body
          },
          data: {
            type: notification.type || 'scheduled',
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          },
          topic: notification.topic
        };
        
        await admin.messaging().send(message);
        
        // Store in-app notifications
        const usersRef = admin.firestore().collection('users');
        let usersSnapshot;
        
        if (notification.topic === 'all_users') {
          usersSnapshot = await usersRef.get();
        } else if (notification.topic === 'agents') {
          usersSnapshot = await usersRef.where('roles', 'array-contains', 'propertyAgent').get();
        } else if (notification.topic === 'customers') {
          usersSnapshot = await usersRef.where('roles', 'array-contains', 'customer').get();
        } else {
          usersSnapshot = await usersRef.get();
        }
        
        const batch = admin.firestore().batch();
        const notificationsRef = admin.firestore().collection('notifications');
        
        usersSnapshot.docs.forEach(userDoc => {
          const notificationRef = notificationsRef.doc();
          batch.set(notificationRef, {
            userId: userDoc.id,
            title: notification.title,
            message: notification.body,
            type: notification.type || 'scheduled',
            isRead: false,
            createdAt: new Date().toISOString()
          });
        });
        
        await batch.commit();
        
        await doc.ref.update({
          status: 'sent',
          sentAt: new Date().toISOString()
        });
        
        processed++;
      } catch (error) {
        await doc.ref.update({
          status: 'failed',
          errorMessage: error.message
        });
        failed++;
      }
    }
    
    return {
      success: true,
      message: `Processed ${processed} notification(s), ${failed} failed`,
      processed,
      failed
    };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to process: ' + error.message);
  }
});
