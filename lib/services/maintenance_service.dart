import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage app maintenance mode
class MaintenanceService {
  static final MaintenanceService _instance = MaintenanceService._internal();
  factory MaintenanceService() => _instance;
  MaintenanceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _configDoc = 'app_config';
  final String _maintenanceDoc = 'maintenance';

  /// Check if app is in maintenance mode
  Future<MaintenanceStatus> checkMaintenanceStatus() async {
    try {
      final doc = await _firestore
          .collection(_configDoc)
          .doc(_maintenanceDoc)
          .get();

      if (!doc.exists) {
        return MaintenanceStatus(
          isEnabled: false,
          message: '',
          estimatedEndTime: null,
          allowAdmins: true,
        );
      }

      final data = doc.data()!;
      return MaintenanceStatus(
        isEnabled: data['isEnabled'] ?? false,
        message: data['message'] ?? 'We are currently performing maintenance. Please check back soon.',
        estimatedEndTime: data['estimatedEndTime'] != null
            ? DateTime.parse(data['estimatedEndTime'])
            : null,
        allowAdmins: data['allowAdmins'] ?? true,
        startedAt: data['startedAt'] != null
            ? DateTime.parse(data['startedAt'])
            : null,
        startedBy: data['startedBy'],
      );
    } catch (e) {
      print('Error checking maintenance status: $e');
      return MaintenanceStatus(isEnabled: false, message: '', allowAdmins: true);
    }
  }

  /// Stream maintenance status for real-time updates
  Stream<MaintenanceStatus> maintenanceStatusStream() {
    return _firestore
        .collection(_configDoc)
        .doc(_maintenanceDoc)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return MaintenanceStatus(isEnabled: false, message: '', allowAdmins: true);
      }

      final data = doc.data()!;
      return MaintenanceStatus(
        isEnabled: data['isEnabled'] ?? false,
        message: data['message'] ?? 'We are currently performing maintenance.',
        estimatedEndTime: data['estimatedEndTime'] != null
            ? DateTime.parse(data['estimatedEndTime'])
            : null,
        allowAdmins: data['allowAdmins'] ?? true,
        startedAt: data['startedAt'] != null
            ? DateTime.parse(data['startedAt'])
            : null,
        startedBy: data['startedBy'],
      );
    });
  }

  /// Enable maintenance mode (Admin only)
  Future<bool> enableMaintenanceMode({
    required String message,
    required String adminId,
    required String adminName,
    DateTime? estimatedEndTime,
    bool allowAdmins = true,
  }) async {
    try {
      await _firestore.collection(_configDoc).doc(_maintenanceDoc).set({
        'isEnabled': true,
        'message': message,
        'estimatedEndTime': estimatedEndTime?.toIso8601String(),
        'allowAdmins': allowAdmins,
        'startedAt': DateTime.now().toIso8601String(),
        'startedBy': adminName,
        'startedByUid': adminId,
      });

      // Log the action
      await _logMaintenanceAction(
        action: 'enabled',
        adminId: adminId,
        adminName: adminName,
        message: message,
      );

      return true;
    } catch (e) {
      print('Error enabling maintenance mode: $e');
      return false;
    }
  }

  /// Disable maintenance mode (Admin only)
  Future<bool> disableMaintenanceMode({
    required String adminId,
    required String adminName,
  }) async {
    try {
      await _firestore.collection(_configDoc).doc(_maintenanceDoc).update({
        'isEnabled': false,
        'endedAt': DateTime.now().toIso8601String(),
        'endedBy': adminName,
        'endedByUid': adminId,
      });

      // Log the action
      await _logMaintenanceAction(
        action: 'disabled',
        adminId: adminId,
        adminName: adminName,
      );

      return true;
    } catch (e) {
      print('Error disabling maintenance mode: $e');
      return false;
    }
  }

  /// Update maintenance message
  Future<bool> updateMaintenanceMessage({
    required String message,
    DateTime? estimatedEndTime,
  }) async {
    try {
      await _firestore.collection(_configDoc).doc(_maintenanceDoc).update({
        'message': message,
        'estimatedEndTime': estimatedEndTime?.toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error updating maintenance message: $e');
      return false;
    }
  }

  /// Log maintenance actions for audit
  Future<void> _logMaintenanceAction({
    required String action,
    required String adminId,
    required String adminName,
    String? message,
  }) async {
    try {
      await _firestore.collection('audit_logs').add({
        'type': 'maintenance',
        'action': action,
        'adminId': adminId,
        'adminName': adminName,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging maintenance action: $e');
    }
  }

  /// Get maintenance history
  Future<List<Map<String, dynamic>>> getMaintenanceHistory({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('type', isEqualTo: 'maintenance')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();
    } catch (e) {
      print('Error getting maintenance history: $e');
      return [];
    }
  }
}

/// Maintenance status model
class MaintenanceStatus {
  final bool isEnabled;
  final String message;
  final DateTime? estimatedEndTime;
  final bool allowAdmins;
  final DateTime? startedAt;
  final String? startedBy;

  MaintenanceStatus({
    required this.isEnabled,
    required this.message,
    this.estimatedEndTime,
    this.allowAdmins = true,
    this.startedAt,
    this.startedBy,
  });

  /// Get time remaining until estimated end
  Duration? get timeRemaining {
    if (estimatedEndTime == null) return null;
    final remaining = estimatedEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Format time remaining as string
  String? get timeRemainingFormatted {
    final remaining = timeRemaining;
    if (remaining == null) return null;
    
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m';
    } else {
      return 'Soon';
    }
  }
}
