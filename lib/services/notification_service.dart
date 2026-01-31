import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/property_model.dart';
import 'preferences_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PreferencesService _prefs = PreferencesService.instance;
  
  // Local notifications plugin
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Initialize local notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Kampala'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    // Request permissions for iOS
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permissions for Android 13+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Schedule daily notifications
    await _scheduleDailyNotifications();

    _initialized = true;
  }

  // Show local push notification
  Future<void> _showLocalNotification({
    required String title,
    required String message,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'truehome_channel',
        'TrueHome Notifications',
        channelDescription: 'Notifications for property updates and alerts',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        message,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  // Daily notification messages
  static final List<Map<String, String>> _morningMessages = [
    {
      'title': '🌅 Good Morning from TrueHome!',
      'message': 'Start your day right! New properties are waiting for you. Check out the latest listings now!',
    },
    {
      'title': '☀️ Rise & Shine, Property Seeker!',
      'message': 'Your dream home could be just one tap away. Explore fresh property updates today!',
    },
    {
      'title': '🏡 Morning Property Alert!',
      'message': 'Great deals await! Browse new hostels, homes, and rentals added overnight.',
    },
  ];

  static final List<Map<String, String>> _afternoonMessages = [
    {
      'title': '🌤️ Afternoon Check-In!',
      'message': 'Take a quick break! Discover amazing properties available in your area.',
    },
    {
      'title': '🏠 Midday Property Update',
      'message': 'New listings just dropped! Find your perfect space before someone else does.',
    },
    {
      'title': '✨ Perfect Time to Browse',
      'message': 'Lunch break? Check out the hottest property deals on TrueHome right now!',
    },
  ];

  static final List<Map<String, String>> _eveningMessages = [
    {
      'title': '🌙 Evening Property Digest',
      'message': 'Wind down your day by exploring new homes and hostels. Your perfect place is waiting!',
    },
    {
      'title': '⭐ Tonight\'s Top Picks',
      'message': 'Before bed, check out today\'s most popular properties. Don\'t miss out!',
    },
    {
      'title': '🏘️ End Your Day with TrueHome',
      'message': 'New properties added today! Browse, save favorites, and plan your next visit.',
    },
  ];

  // Schedule daily notifications at 8 AM, 2 PM, and 9 PM
  static Future<void> _scheduleDailyNotifications() async {
    try {
      // Cancel any existing scheduled notifications
      await _localNotifications.cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      
      // Schedule morning notification (8:00 AM)
      var morningTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        8, // 8 AM
        0,
      );
      if (morningTime.isBefore(now)) {
        morningTime = morningTime.add(const Duration(days: 1));
      }

      // Schedule afternoon notification (2:00 PM)
      var afternoonTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        14, // 2 PM
        0,
      );
      if (afternoonTime.isBefore(now)) {
        afternoonTime = afternoonTime.add(const Duration(days: 1));
      }

      // Schedule evening notification (9:00 PM)
      var eveningTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        21, // 9 PM
        0,
      );
      if (eveningTime.isBefore(now)) {
        eveningTime = eveningTime.add(const Duration(days: 1));
      }

      // Notification details
      const androidDetails = AndroidNotificationDetails(
        'truehome_daily_channel',
        'TrueHome Daily Updates',
        channelDescription: 'Daily property updates and reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Get random messages
      final morningMsg = _morningMessages[now.day % _morningMessages.length];
      final afternoonMsg = _afternoonMessages[now.day % _afternoonMessages.length];
      final eveningMsg = _eveningMessages[now.day % _eveningMessages.length];

      // Schedule morning notification
      await _localNotifications.zonedSchedule(
        1001, // Unique ID for morning
        morningMsg['title']!,
        morningMsg['message']!,
        morningTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Schedule afternoon notification
      await _localNotifications.zonedSchedule(
        1002, // Unique ID for afternoon
        afternoonMsg['title']!,
        afternoonMsg['message']!,
        afternoonTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Schedule evening notification
      await _localNotifications.zonedSchedule(
        1003, // Unique ID for evening
        eveningMsg['title']!,
        eveningMsg['message']!,
        eveningTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('✅ Daily notifications scheduled: 8 AM, 2 PM, 9 PM');
    } catch (e) {
      print('Error scheduling daily notifications: $e');
    }
  }

  // Send in-app notification (updated to include push notification)
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String? propertyId,
    String? type,
  }) async {
    try {
      // Save to Firestore
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'propertyId': propertyId,
        'type': type ?? 'general',
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Show local push notification
      await _showLocalNotification(
        title: title,
        message: message,
        payload: propertyId,
      );
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

  // Notify property agent about property status
  Future<void> notifyPropertyAgent({
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
      case PropertyStatus.removed:
        title = 'Property Removed';
        message = 'Your property "$propertyTitle" has been removed from the listings.';
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
    // Using only where clause to avoid composite index requirement
    // Sorting will be done in the UI layer
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
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
