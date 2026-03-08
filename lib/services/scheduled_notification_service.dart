import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a scheduled notification
class ScheduledNotification {
  final String? id;
  final String title;
  final String body;
  final String topic;
  final String type;
  final DateTime scheduledTime;
  final String status; // 'pending', 'sent', 'cancelled', 'failed'
  final DateTime createdAt;
  final String createdBy;
  final String? createdByName;
  final DateTime? sentAt;
  final String? errorMessage;
  
  ScheduledNotification({
    this.id,
    required this.title,
    required this.body,
    required this.topic,
    this.type = 'scheduled',
    required this.scheduledTime,
    this.status = 'pending',
    required this.createdAt,
    required this.createdBy,
    this.createdByName,
    this.sentAt,
    this.errorMessage,
  });
  
  factory ScheduledNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduledNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      topic: data['topic'] ?? 'all_users',
      type: data['type'] ?? 'scheduled',
      scheduledTime: DateTime.parse(data['scheduledTime']),
      status: data['status'] ?? 'pending',
      createdAt: DateTime.parse(data['createdAt']),
      createdBy: data['createdBy'] ?? '',
      createdByName: data['createdByName'],
      sentAt: data['sentAt'] != null ? DateTime.parse(data['sentAt']) : null,
      errorMessage: data['errorMessage'],
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'topic': topic,
      'type': type,
      'scheduledTime': scheduledTime.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'sentAt': sentAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }
  
  String get topicDisplayName {
    switch (topic) {
      case 'all_users':
        return 'All Users';
      case 'agents':
        return 'Agents Only';
      case 'customers':
        return 'Customers Only';
      default:
        return topic;
    }
  }
  
  bool get isPending => status == 'pending' && scheduledTime.isAfter(DateTime.now());
  bool get isOverdue => status == 'pending' && scheduledTime.isBefore(DateTime.now());
}

/// Service for managing scheduled notifications
class ScheduledNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const String _collection = 'scheduled_notifications';
  
  /// Create a new scheduled notification
  Future<String?> createScheduledNotification({
    required String title,
    required String body,
    required String topic,
    required DateTime scheduledTime,
    required String adminId,
    String? adminName,
    String type = 'scheduled',
  }) async {
    try {
      final doc = await _firestore.collection(_collection).add({
        'title': title,
        'body': body,
        'topic': topic,
        'type': type,
        'scheduledTime': scheduledTime.toIso8601String(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': adminId,
        'createdByName': adminName,
        'sentAt': null,
        'errorMessage': null,
      });
      
      return doc.id;
    } catch (e) {
      print('Error creating scheduled notification: $e');
      return null;
    }
  }
  
  /// Get all scheduled notifications
  Stream<List<ScheduledNotification>> getScheduledNotificationsStream({
    String? statusFilter,
    int? limit,
  }) {
    Query query = _firestore
        .collection(_collection)
        .orderBy('scheduledTime', descending: true);
    
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ScheduledNotification.fromFirestore(doc))
          .toList();
    });
  }
  
  /// Get pending notifications
  Future<List<ScheduledNotification>> getPendingNotifications() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .orderBy('scheduledTime')
          .get();
      
      return snapshot.docs
          .map((doc) => ScheduledNotification.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }
  
  /// Cancel a scheduled notification
  Future<bool> cancelNotification(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'status': 'cancelled',
      });
      return true;
    } catch (e) {
      print('Error cancelling notification: $e');
      return false;
    }
  }
  
  /// Delete a scheduled notification
  Future<bool> deleteNotification(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }
  
  /// Update a scheduled notification
  Future<bool> updateNotification({
    required String id,
    String? title,
    String? body,
    String? topic,
    DateTime? scheduledTime,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (title != null) updates['title'] = title;
      if (body != null) updates['body'] = body;
      if (topic != null) updates['topic'] = topic;
      if (scheduledTime != null) {
        updates['scheduledTime'] = scheduledTime.toIso8601String();
      }
      
      if (updates.isNotEmpty) {
        await _firestore.collection(_collection).doc(id).update(updates);
      }
      
      return true;
    } catch (e) {
      print('Error updating notification: $e');
      return false;
    }
  }
  
  /// Get notification by ID
  Future<ScheduledNotification?> getNotification(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return ScheduledNotification.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting notification: $e');
      return null;
    }
  }
  
  /// Mark notification as sent
  Future<bool> markAsSent(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'status': 'sent',
        'sentAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error marking notification as sent: $e');
      return false;
    }
  }
  
  /// Mark notification as failed
  Future<bool> markAsFailed(String id, String errorMessage) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'status': 'failed',
        'errorMessage': errorMessage,
      });
      return true;
    } catch (e) {
      print('Error marking notification as failed: $e');
      return false;
    }
  }
  
  /// Get statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      final pending = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      
      final sent = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'sent')
          .count()
          .get();
      
      final cancelled = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'cancelled')
          .count()
          .get();
      
      final failed = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'failed')
          .count()
          .get();
      
      return {
        'pending': pending.count ?? 0,
        'sent': sent.count ?? 0,
        'cancelled': cancelled.count ?? 0,
        'failed': failed.count ?? 0,
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {'pending': 0, 'sent': 0, 'cancelled': 0, 'failed': 0};
    }
  }
}
