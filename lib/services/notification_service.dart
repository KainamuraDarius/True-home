import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../models/property_model.dart';
import 'preferences_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PreferencesService _prefs = PreferencesService.instance;

  // Send in-app notification
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String? propertyId,
    String? type,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'propertyId': propertyId,
        'type': type ?? 'general',
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send notification to all admins
  Future<void> notifyAdmins({
    required String title,
    required String message,
    String? propertyId,
    String? type,
  }) async {
    try {
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      for (var admin in admins.docs) {
        await sendNotification(
          userId: admin.id,
          title: title,
          message: message,
          propertyId: propertyId,
          type: type,
        );
      }
    } catch (e) {
      print('Error notifying admins: $e');
    }
  }

  // Send notification to all customers
  Future<void> notifyAllCustomers({
    required String title,
    required String message,
    String? propertyId,
    String? type,
  }) async {
    try {
      final customers = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();

      for (var customer in customers.docs) {
        // Check if user wants to receive new property notifications
        await sendNotification(
          userId: customer.id,
          title: title,
          message: message,
          propertyId: propertyId,
          type: type,
        );
      }
    } catch (e) {
      print('Error notifying customers: $e');
    }
  }

  // Send weekly digest email (placeholder - would need backend email service)
  Future<void> sendWeeklyDigest() async {
    try {
      // Get users who enabled weekly digest
      final emailDigestEnabled = await _prefs.getEmailWeeklyDigest();
      
      if (!emailDigestEnabled) return;

      // Get new properties from the last week
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final newProperties = await _firestore
          .collection('properties')
          .where('status', isEqualTo: PropertyStatus.approved.name)
          .where('createdAt', isGreaterThan: weekAgo.toIso8601String())
          .get();

      if (newProperties.docs.isEmpty) return;

      // Get users with email digest enabled
      final users = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();

      // For now, create in-app notification about weekly digest
      // In production, this would send actual emails via backend service
      for (var user in users.docs) {
        await sendNotification(
          userId: user.id,
          title: 'Weekly Property Digest',
          message: '${newProperties.docs.length} new properties added this week! Check them out.',
          type: 'weekly_digest',
        );
      }
    } catch (e) {
      print('Error sending weekly digest: $e');
    }
  }

  // Send promotional email (placeholder - would need backend email service)
  Future<void> sendPromotionalEmail({
    required String subject,
    required String body,
    String? propertyId,
  }) async {
    try {
      // Get users who enabled promotional emails
      final promoEnabled = await _prefs.getEmailPromotional();
      
      if (!promoEnabled) return;

      // Get all customers who opted in for promotional emails
      final users = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();

      // For now, create in-app notification
      // In production, this would send actual emails via backend service
      for (var user in users.docs) {
        await sendNotification(
          userId: user.id,
          title: subject,
          message: body,
          propertyId: propertyId,
          type: 'promotional',
        );
      }
    } catch (e) {
      print('Error sending promotional email: $e');
    }
  }

  // Notify property owner/manager about property status
  Future<void> notifyPropertyOwner({
    required String ownerId,
    required String propertyTitle,
    required PropertyStatus status,
    String? reason,
  }) async {
    String title;
    String message;

    switch (status) {
      case PropertyStatus.approved:
        title = 'Property Approved!';
        message = 'Your property "$propertyTitle" has been approved and is now live!';
        break;
      case PropertyStatus.rejected:
        title = 'Property Rejected';
        message = 'Your property "$propertyTitle" was rejected. ${reason != null ? 'Reason: $reason' : ''}';
        break;
      case PropertyStatus.pending:
        title = 'Property Under Review';
        message = 'Your property "$propertyTitle" is being reviewed by our team.';
        break;
    }

    await sendNotification(
      userId: ownerId,
      title: title,
      message: message,
      type: 'property_status',
    );
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Get user notifications stream
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications for user
  Future<void> clearAllNotifications(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }
}
