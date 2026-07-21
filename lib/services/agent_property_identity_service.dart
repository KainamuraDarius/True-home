import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/property_model.dart';

class AgentPropertyIdentity {
  final String uid;
  final String? email;
  final String? emailLower;
  final String? phone;
  final String? phoneKey;
  final String? name;
  final String? profileImageUrl;

  const AgentPropertyIdentity({
    required this.uid,
    this.email,
    this.emailLower,
    this.phone,
    this.phoneKey,
    this.name,
    this.profileImageUrl,
  });

  bool matchesStablePropertyIdentity(PropertyModel property) {
    final propertyEmailLower =
        AgentPropertyIdentityService.normalizeEmailLower(
          property.ownerEmailLower,
        ) ??
        AgentPropertyIdentityService.normalizeEmailLower(property.ownerEmail) ??
        AgentPropertyIdentityService.normalizeEmailLower(property.contactEmail);
    final propertyPhoneKey =
        AgentPropertyIdentityService.normalizePhoneKey(property.ownerPhoneKey) ??
        AgentPropertyIdentityService.normalizePhoneKey(property.contactPhone) ??
        AgentPropertyIdentityService.normalizePhoneKey(property.whatsappPhone);

    return (emailLower != null && propertyEmailLower == emailLower) ||
        (phoneKey != null && propertyPhoneKey == phoneKey);
  }
}

class AgentPropertyIdentityService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AgentPropertyIdentityService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  static String? normalizeEmailLower(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? normalizePhoneKey(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '');
    if (digits == null || digits.isEmpty) return null;
    if (digits.startsWith('0') && digits.length == 10) {
      return '256${digits.substring(1)}';
    }
    return digits;
  }

  Future<AgentPropertyIdentity?> loadCurrentIdentity() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    Map<String, dynamic> userData = {};
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      userData = userDoc.data() ?? {};
    } catch (_) {
      userData = {};
    }

    final email = _firstNonEmptyString([user.email, userData['email']]);
    final phone = _firstNonEmptyString([
      user.phoneNumber,
      userData['phoneNumber'],
      userData['whatsappNumber'],
    ]);

    return AgentPropertyIdentity(
      uid: user.uid,
      email: email,
      emailLower: normalizeEmailLower(
        _firstNonEmptyString([userData['emailLower'], email]),
      ),
      phone: phone,
      phoneKey: normalizePhoneKey(
        _firstNonEmptyString([userData['phoneKey'], phone]),
      ),
      name: _firstNonEmptyString([userData['name'], user.displayName]),
      profileImageUrl: _firstNonEmptyString([userData['profileImageUrl']]),
    );
  }

  Stream<List<PropertyModel>> watchPropertiesForIdentity(
    AgentPropertyIdentity identity,
  ) {
    return _propertiesQuery(identity).snapshots().map((snapshot) {
      return _propertiesFromDocs(snapshot.docs);
    });
  }

  Future<List<PropertyModel>> getPropertiesForIdentity(
    AgentPropertyIdentity identity,
  ) async {
    final snapshot = await _propertiesQuery(identity).get();
    return _propertiesFromDocs(snapshot.docs);
  }

  Future<void> claimPropertiesForIdentity({
    required AgentPropertyIdentity identity,
    required Iterable<PropertyModel> properties,
  }) async {
    final batch = _firestore.batch();
    var claimCount = 0;

    for (final property in properties) {
      if (property.ownerId == identity.uid) continue;
      if (!identity.matchesStablePropertyIdentity(property)) continue;

      final updates = <String, dynamic>{
        'ownerId': identity.uid,
        'createdByUserId': identity.uid,
        'claimedByUserId': identity.uid,
        'claimedAt': FieldValue.serverTimestamp(),
      };

      if (identity.email != null) updates['ownerEmail'] = identity.email;
      if (identity.emailLower != null) {
        updates['ownerEmailLower'] = identity.emailLower;
      }
      if (identity.phoneKey != null) updates['ownerPhoneKey'] = identity.phoneKey;
      if (identity.name != null) updates['ownerName'] = identity.name;
      if (identity.profileImageUrl != null) {
        updates['agentProfileImageUrl'] = identity.profileImageUrl;
      }

      batch.update(_firestore.collection('properties').doc(property.id), updates);
      claimCount++;
    }

    if (claimCount == 0) return;
    await batch.commit();
  }

  Query<Map<String, dynamic>> _propertiesQuery(
    AgentPropertyIdentity identity,
  ) {
    final filters = <Filter>[
      Filter('ownerId', isEqualTo: identity.uid),
      Filter('createdByUserId', isEqualTo: identity.uid),
    ];

    if (identity.emailLower != null) {
      filters.add(Filter('ownerEmailLower', isEqualTo: identity.emailLower));
    }
    if (identity.email != null) {
      filters.add(Filter('ownerEmail', isEqualTo: identity.email));
      filters.add(Filter('contactEmail', isEqualTo: identity.email));
    }
    if (identity.phoneKey != null) {
      filters.add(Filter('ownerPhoneKey', isEqualTo: identity.phoneKey));
    }
    if (identity.phone != null) {
      filters.add(Filter('contactPhone', isEqualTo: identity.phone));
      filters.add(Filter('whatsappPhone', isEqualTo: identity.phone));
    }

    return _firestore.collection('properties').where(_combineFilters(filters));
  }

  Filter _combineFilters(List<Filter> filters) {
    switch (filters.length) {
      case 1:
        return filters[0];
      case 2:
        return Filter.or(filters[0], filters[1]);
      case 3:
        return Filter.or(filters[0], filters[1], filters[2]);
      case 4:
        return Filter.or(filters[0], filters[1], filters[2], filters[3]);
      case 5:
        return Filter.or(
          filters[0],
          filters[1],
          filters[2],
          filters[3],
          filters[4],
        );
      case 6:
        return Filter.or(
          filters[0],
          filters[1],
          filters[2],
          filters[3],
          filters[4],
          filters[5],
        );
      case 7:
        return Filter.or(
          filters[0],
          filters[1],
          filters[2],
          filters[3],
          filters[4],
          filters[5],
          filters[6],
        );
      case 8:
        return Filter.or(
          filters[0],
          filters[1],
          filters[2],
          filters[3],
          filters[4],
          filters[5],
          filters[6],
          filters[7],
        );
      default:
        return Filter.or(filters[0], filters[1]);
    }
  }

  List<PropertyModel> _propertiesFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final propertiesById = <String, PropertyModel>{};
    for (final doc in docs) {
      propertiesById[doc.id] = PropertyModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      });
    }
    return propertiesById.values.toList();
  }

  String? _firstNonEmptyString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}
