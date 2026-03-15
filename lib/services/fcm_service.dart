import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  late final FirebaseMessaging _fcm;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Lazy getter for FCM instance - only initializes when first accessed
  FirebaseMessaging get _fcmInstance {
    if (!_initialized) {
      _fcm = FirebaseMessaging.instance;
    }
    return _fcm;
  }

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return; // Skip on web entirely

    try {
      // Request notification permissions
      await _requestPermissions();

      // For non-web platforms, initialize local notifications
      if (!kIsWeb) {
        await _initializeLocalNotifications();
        
        // Set up background message handler (not supported on web)
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      RemoteMessage? initialMessage = await _fcmInstance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // Get and save FCM token
      await _saveFCMToken();

      // Subscribe to topics based on user role
      await _subscribeToTopicsBasedOnRole();

      // Listen for token refresh
      _fcmInstance.onTokenRefresh.listen(_saveFCMTokenToFirestore);

      _initialized = true;
      print('✅ FCM Service initialized successfully');
    } catch (e) {
      print('❌ FCM Service initialization error: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _fcmInstance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('FCM Permission granted: ${settings.authorizationStatus}');
      
      // For Android 13+, also request local notification permission
      if (!kIsWeb) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
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
        print('Local notification tapped: ${response.payload}');
        // TODO: Navigate to appropriate screen based on payload
      },
    );
  }

  /// Handle foreground messages (show as local notification)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 Foreground message received: ${message.notification?.title}');

    RemoteNotification? notification = message.notification;

    if (notification != null) {
      // On web, browser shows notification automatically via service worker
      // On mobile, show local notification
      if (!kIsWeb) {
        await _showLocalNotification(
          title: notification.title ?? 'TrueHome',
          body: notification.body ?? '',
          payload: message.data.toString(),
        );
      }
      
      // Also store notification in Firestore for in-app viewing
      await _storeNotificationInApp(message);
    }
  }
  
  /// Store notification in Firestore for in-app viewing
  Future<void> _storeNotificationInApp(RemoteMessage message) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'title': message.notification?.title ?? 'TrueHome',
        'message': message.notification?.body ?? '',
        'type': message.data['type'] ?? 'general',
        'propertyId': message.data['propertyId'],
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error storing notification: $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('📱 Notification tapped: ${message.data}');
    
    // TODO: Navigate based on notification type
    String? notificationType = message.data['type'];
    String? propertyId = message.data['propertyId'];
    
    // Navigate to specific screen based on type
    switch (notificationType) {
      case 'property_approved':
      case 'property_rejected':
      case 'new_property':
        // Navigate to property details
        print('Navigate to property: $propertyId');
        break;
      case 'new_message':
        // Navigate to messages
        print('Navigate to messages');
        break;
      case 'reservation_confirmed':
        // Navigate to reservations
        print('Navigate to reservations');
        break;
      default:
        // Navigate to home
        print('Navigate to home');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'truehome_fcm_channel',
      'TrueHome Push Notifications',
      channelDescription: 'Push notifications from TrueHome',
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
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Get and save FCM token
  Future<void> _saveFCMToken() async {
    try {
      String? token = await _fcmInstance.getToken();
      if (token != null) {
        await _saveFCMTokenToFirestore(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        });
        print('✅ FCM token saved: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Subscribe to topic (e.g., 'all_users', 'agents', 'customers')
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcmInstance.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcmInstance.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    return await _fcmInstance.getToken();
  }

  /// Auto-subscribe to topics based on user role
  Future<void> _subscribeToTopicsBasedOnRole() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      // Get user document to check role
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data();
      final role = userData?['role'] as String?;

      // Subscribe to all_users for everyone
      await subscribeToTopic('all_users');

      // Subscribe to specific role topic
      if (role == 'propertyAgent' || role == 'agent') {
        await subscribeToTopic('agents');
        print('✅ Subscribed to agents topic');
      } else if (role == 'customer') {
        await subscribeToTopic('customers');
        print('✅ Subscribed to customers topic');
      } else if (role == 'admin') {
        await subscribeToTopic('agents');
        await subscribeToTopic('customers');
        print('✅ Admin subscribed to all topics');
      }
    } catch (e) {
      print('Error auto-subscribing to topics: $e');
    }
  }
}
