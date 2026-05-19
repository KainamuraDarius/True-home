import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformConfig {
  final bool requireEmailVerificationForCustomers;
  final bool requireEmailVerificationForAgents;

  PlatformConfig({
    required this.requireEmailVerificationForCustomers,
    required this.requireEmailVerificationForAgents,
  });

  factory PlatformConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return PlatformConfig(
        requireEmailVerificationForCustomers: false,
        requireEmailVerificationForAgents: false,
      );
    }
    return PlatformConfig(
      requireEmailVerificationForCustomers:
          map['requireEmailVerificationForCustomers'] ?? false,
      requireEmailVerificationForAgents:
          map['requireEmailVerificationForAgents'] ?? false,
    );
  }
}

class PlatformConfigService {
  static final PlatformConfigService _instance =
      PlatformConfigService._internal();
  factory PlatformConfigService() => _instance;
  PlatformConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _configCollection = 'app_config';
  final String _platformDoc = 'platform';

  Future<PlatformConfig> getConfig() async {
    try {
      final doc = await _firestore.collection(_configCollection).doc(_platformDoc).get();
      if (!doc.exists) return PlatformConfig.fromMap(null);
      return PlatformConfig.fromMap(doc.data());
    } catch (e) {
      print('Error loading platform config: $e');
      return PlatformConfig.fromMap(null);
    }
  }

  Stream<PlatformConfig> configStream() {
    return _firestore.collection(_configCollection).doc(_platformDoc).snapshots().map((doc) {
      return PlatformConfig.fromMap(doc.data());
    });
  }

  Future<bool> updateConfig({
    bool? requireEmailVerificationForCustomers,
    bool? requireEmailVerificationForAgents,
  }) async {
    try {
      final Map<String, dynamic> update = {};
      if (requireEmailVerificationForCustomers != null) {
        update['requireEmailVerificationForCustomers'] = requireEmailVerificationForCustomers;
      }
      if (requireEmailVerificationForAgents != null) {
        update['requireEmailVerificationForAgents'] = requireEmailVerificationForAgents;
      }
      if (update.isEmpty) return true;
      await _firestore.collection(_configCollection).doc(_platformDoc).set(update, SetOptions(merge: true));
      return true;
    } catch (e) {
      print('Error updating platform config: $e');
      return false;
    }
  }
}
