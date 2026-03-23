import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

String _normalizedText(dynamic value) {
  return (value ?? '').toString().trim().toLowerCase();
}

String _normalizedInviteStatus(dynamic value) {
  final normalized = _normalizedText(value);
  if (normalized.isEmpty || normalized == 'sent') {
    return 'pending';
  }
  return normalized;
}

bool _isPendingInviteStatus(dynamic value) {
  return _normalizedInviteStatus(value) == 'pending';
}

class OrganizationInviteItem {
  final String id;
  final String organizationId;
  final String organizationName;
  final String email;
  final String role;
  final String status;
  final bool codeRequired;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const OrganizationInviteItem({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.email,
    required this.role,
    required this.status,
    required this.codeRequired,
    this.expiresAt,
    this.createdAt,
  });

  factory OrganizationInviteItem.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final parentOrg = snapshot.reference.parent.parent;
    return OrganizationInviteItem(
      id: snapshot.id,
      organizationId:
          parentOrg?.id ?? (data['organizationId'] ?? '').toString(),
      organizationName: (data['organizationName'] ?? '').toString(),
      email: (data['emailLower'] ?? data['email'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      role: (data['role'] ?? 'viewer').toString(),
      status: _normalizedInviteStatus(data['status']),
      codeRequired:
          data['codeRequired'] == true ||
          ((data['verificationCode'] ?? '').toString().trim().isNotEmpty),
      expiresAt: _parseDate(data['expiresAt']),
      createdAt: _parseDate(data['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class OrganizationInviteCreationResult {
  final String inviteId;
  final String verificationCode;
  final bool emailSent;
  final String? emailError;

  const OrganizationInviteCreationResult({
    required this.inviteId,
    required this.verificationCode,
    required this.emailSent,
    this.emailError,
  });
}

class OrganizationInviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> _persistUserEmailLowerBestEffort({
    required String userId,
    required String emailLower,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'emailLower': emailLower,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best effort only; invite matching should still proceed.
    }
  }

  List<OrganizationInviteItem> _parsePendingInvites(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final invites = <OrganizationInviteItem>[];
    for (final doc in snapshot.docs) {
      try {
        final invite = OrganizationInviteItem.fromSnapshot(doc);
        if (_isPendingInviteStatus(invite.status)) {
          invites.add(invite);
        }
      } catch (_) {
        // Ignore malformed invite docs and continue.
      }
    }
    invites.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return invites;
  }

  List<OrganizationInviteItem> _mergePendingInvites(
    List<OrganizationInviteItem> primary,
    List<OrganizationInviteItem> secondary,
  ) {
    final mergedByKey = <String, OrganizationInviteItem>{};
    for (final invite in [...primary, ...secondary]) {
      if (!_isPendingInviteStatus(invite.status)) continue;
      final key = '${invite.organizationId}::${invite.id}';
      mergedByKey[key] = invite;
    }
    final merged = mergedByKey.values.toList();
    merged.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return merged;
  }

  Future<String?> getCurrentUserEmailLower() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final fromAuth = user.email?.trim();
    if (fromAuth != null && fromAuth.isNotEmpty) {
      final emailLower = fromAuth.toLowerCase();
      await _persistUserEmailLowerBestEffort(
        userId: user.uid,
        emailLower: emailLower,
      );
      return emailLower;
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final fromProfile = (userDoc.data()?['email'] ?? '').toString().trim();
    if (fromProfile.isEmpty) return null;
    final emailLower = fromProfile.toLowerCase();
    await _persistUserEmailLowerBestEffort(
      userId: user.uid,
      emailLower: emailLower,
    );
    return emailLower;
  }

  Stream<List<OrganizationInviteItem>> streamMyPendingInvites({
    required String emailLower,
  }) {
    final normalizedEmail = _normalizedText(emailLower);
    if (normalizedEmail.isEmpty) {
      return Stream<List<OrganizationInviteItem>>.value(
        const <OrganizationInviteItem>[],
      );
    }

    final controller = StreamController<List<OrganizationInviteItem>>();
    List<OrganizationInviteItem> fromEmailLower = const [];
    List<OrganizationInviteItem> fromEmail = const [];
    bool emailLowerErrored = false;
    bool emailErrored = false;

    void emitMerged() {
      if (controller.isClosed) return;
      controller.add(_mergePendingInvites(fromEmailLower, fromEmail));
    }

    void handleError(
      Object error,
      StackTrace stackTrace, {
      required bool fromEmailLowerQuery,
    }) {
      if (fromEmailLowerQuery) {
        emailLowerErrored = true;
        fromEmailLower = const [];
      } else {
        emailErrored = true;
        fromEmail = const [];
      }

      emitMerged();
      if (emailLowerErrored && emailErrored && !controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    }

    final emailLowerSub = _firestore
        .collectionGroup('invites')
        .where('emailLower', isEqualTo: normalizedEmail)
        .snapshots()
        .listen(
          (snapshot) {
            emailLowerErrored = false;
            fromEmailLower = _parsePendingInvites(snapshot);
            emitMerged();
          },
          onError: (Object error, StackTrace stackTrace) {
            handleError(
              error,
              stackTrace,
              fromEmailLowerQuery: true,
            );
          },
        );

    final emailSub = _firestore
        .collectionGroup('invites')
        .where('email', isEqualTo: normalizedEmail)
        .snapshots()
        .listen(
          (snapshot) {
            emailErrored = false;
            fromEmail = _parsePendingInvites(snapshot);
            emitMerged();
          },
          onError: (Object error, StackTrace stackTrace) {
            handleError(
              error,
              stackTrace,
              fromEmailLowerQuery: false,
            );
          },
        );

    controller.onCancel = () async {
      await emailLowerSub.cancel();
      await emailSub.cancel();
    };

    return controller.stream;
  }

  String _generateInviteCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<bool> _sendInviteCodeEmail({
    required String email,
    required String verificationCode,
    required String organizationName,
    required String role,
  }) async {
    final callable = _functions.httpsCallable('sendTeamInviteCodeEmail');
    final result = await callable.call(<String, dynamic>{
      'email': email,
      'code': verificationCode,
      'organizationName': organizationName,
      'role': role,
    });
    final data = result.data;
    if (data is Map<String, dynamic>) {
      return data['success'] == true;
    }
    return true;
  }

  Future<OrganizationInviteCreationResult> createInvite({
    required String organizationId,
    required String organizationName,
    required String email,
    required String role,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please log in again.');

    final emailLower = email.trim().toLowerCase();
    if (emailLower.isEmpty || !emailLower.contains('@')) {
      throw Exception('Enter a valid email address.');
    }

    final orgRef = _firestore.collection('organizations').doc(organizationId);
    final nowIso = DateTime.now().toIso8601String();

    final existingPendingSnapshot = await orgRef
        .collection('invites')
        .where('emailLower', isEqualTo: emailLower)
        .get();
    final hasPendingInvite = existingPendingSnapshot.docs.any((doc) {
      return _isPendingInviteStatus(doc.data()['status']);
    });
    if (hasPendingInvite) {
      throw Exception(
        'A pending invite for this email already exists. Resend it instead.',
      );
    }

    final verificationCode = _generateInviteCode();
    final inviteRef = orgRef.collection('invites').doc();

    await inviteRef.set({
      'id': inviteRef.id,
      'email': emailLower,
      'emailLower': emailLower,
      'role': role,
      'status': 'pending',
      'organizationId': organizationId,
      'organizationName': organizationName,
      'createdBy': user.uid,
      'createdAt': nowIso,
      'updatedAt': nowIso,
      'expiresAt': DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String(),
      'codeRequired': true,
      'verificationCode': verificationCode,
      'emailDeliveryStatus': 'pending',
      'codeLastSentAt': nowIso,
    });

    bool emailSent = false;
    String? emailError;
    try {
      emailSent = await _sendInviteCodeEmail(
        email: emailLower,
        verificationCode: verificationCode,
        organizationName: organizationName,
        role: role,
      );
    } catch (e) {
      emailError = e.toString().replaceFirst('Exception: ', '');
      emailSent = false;
    }

    await inviteRef.update({
      'emailDeliveryStatus': emailSent ? 'sent' : 'failed',
      'emailDeliveryError': emailError ?? '',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return OrganizationInviteCreationResult(
      inviteId: inviteRef.id,
      verificationCode: verificationCode,
      emailSent: emailSent,
      emailError: emailError,
    );
  }

  Future<void> resendInviteCode(OrganizationInviteItem invite) async {
    final inviteRef = _firestore
        .collection('organizations')
        .doc(invite.organizationId)
        .collection('invites')
        .doc(invite.id);

    final inviteSnap = await inviteRef.get();
    if (!inviteSnap.exists) {
      throw Exception('Invite no longer exists.');
    }
    final data = inviteSnap.data() ?? <String, dynamic>{};
    final status = (data['status'] ?? '').toString();
    if (status != 'pending') {
      throw Exception('Only pending invites can be resent.');
    }

    final verificationCode = (data['verificationCode'] ?? '').toString().trim();
    if (verificationCode.isEmpty) {
      throw Exception('Invite code is missing for this invite.');
    }

    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final organizationName = (data['organizationName'] ?? '').toString().trim();
    final role = (data['role'] ?? 'viewer').toString().trim();

    bool emailSent = false;
    String? emailError;
    try {
      emailSent = await _sendInviteCodeEmail(
        email: email,
        verificationCode: verificationCode,
        organizationName: organizationName,
        role: role,
      );
    } catch (e) {
      emailError = e.toString().replaceFirst('Exception: ', '');
      emailSent = false;
    }

    await inviteRef.update({
      'emailDeliveryStatus': emailSent ? 'sent' : 'failed',
      'emailDeliveryError': emailError ?? '',
      'codeLastSentAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    if (!emailSent) {
      throw Exception(
        emailError?.isNotEmpty == true
            ? emailError!
            : 'Failed to resend invite code email.',
      );
    }
  }

  Future<void> acceptInvite(
    OrganizationInviteItem invite, {
    required String verificationCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please log in again.');

    final emailLower = await getCurrentUserEmailLower();
    if (emailLower == null || emailLower.isEmpty) {
      throw Exception('Your account has no email address for invite matching.');
    }

    final orgRef = _firestore
        .collection('organizations')
        .doc(invite.organizationId);
    final inviteRef = orgRef.collection('invites').doc(invite.id);
    final memberRef = orgRef.collection('members').doc(user.uid);
    final userRef = _firestore.collection('users').doc(user.uid);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final normalizedCode = verificationCode.trim();

    await _firestore.runTransaction((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        throw Exception('This invite no longer exists.');
      }
      final inviteData = inviteSnap.data() ?? <String, dynamic>{};

      final inviteStatus = _normalizedInviteStatus(inviteData['status']);
      if (inviteStatus != 'pending') {
        throw Exception('This invite is no longer pending.');
      }

      final inviteEmail = _normalizedText(
        inviteData['emailLower'] ?? inviteData['email'],
      );
      if (inviteEmail != emailLower) {
        throw Exception('This invite does not belong to your account.');
      }

      final expiresAt = OrganizationInviteItem._parseDate(
        inviteData['expiresAt'],
      );
      if (expiresAt != null && expiresAt.isBefore(now)) {
        throw Exception('This invite has expired.');
      }

      final expectedCode = (inviteData['verificationCode'] ?? '')
          .toString()
          .trim();
      if (expectedCode.isNotEmpty && expectedCode != normalizedCode) {
        throw Exception('Invalid invite verification code.');
      }

      final role = (inviteData['role'] ?? 'viewer').toString();
      final permissions = _permissionsForRole(role);
      final orgPlan = (inviteData['organizationPlan'] ??
              inviteData['plan'] ??
              'enterprise')
          .toString()
          .trim()
          .toLowerCase();

      tx.set(memberRef, {
        'userId': user.uid,
        'role': role,
        'status': 'active',
        'canListProperty': permissions.canListProperty,
        'canListProject': permissions.canListProject,
        'joinedAt': nowIso,
        'sourceInviteId': invite.id,
      }, SetOptions(merge: true));

      tx.update(inviteRef, {
        'status': 'accepted',
        'acceptedBy': user.uid,
        'acceptedAt': nowIso,
        'updatedAt': nowIso,
      });

      final userUpdate = <String, dynamic>{
        'activeOrganizationId': invite.organizationId,
        'selectedPlan': orgPlan.isEmpty ? 'enterprise' : orgPlan,
        'selectedPlanStatus': 'active',
        'selectedPlanActivatedAt': nowIso,
        'planUpdatedAt': nowIso,
        'isVerified': true,
        'verificationStatus': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': nowIso,
      };
      final organizationName = (inviteData['organizationName'] ?? '')
          .toString()
          .trim();
      if (organizationName.isNotEmpty) {
        userUpdate['companyName'] = organizationName;
      }

      if (role == 'admin' || role == 'lister') {
        userUpdate['roles'] = FieldValue.arrayUnion(['propertyAgent']);
        userUpdate['activeRole'] = 'propertyAgent';
      }

      tx.update(userRef, userUpdate);
    });
  }

  Future<void> declineInvite(OrganizationInviteItem invite) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please log in again.');

    final emailLower = await getCurrentUserEmailLower();
    if (emailLower == null || emailLower.isEmpty) {
      throw Exception('Your account has no email address for invite matching.');
    }

    final inviteRef = _firestore
        .collection('organizations')
        .doc(invite.organizationId)
        .collection('invites')
        .doc(invite.id);

    final nowIso = DateTime.now().toIso8601String();
    await _firestore.runTransaction((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        throw Exception('This invite no longer exists.');
      }
      final inviteData = inviteSnap.data() ?? <String, dynamic>{};
      final inviteStatus = _normalizedInviteStatus(inviteData['status']);
      if (inviteStatus != 'pending') {
        throw Exception('This invite is no longer pending.');
      }
      final inviteEmail = _normalizedText(
        inviteData['emailLower'] ?? inviteData['email'],
      );
      if (inviteEmail != emailLower) {
        throw Exception('This invite does not belong to your account.');
      }

      tx.update(inviteRef, {
        'status': 'declined',
        'declinedBy': user.uid,
        'declinedAt': nowIso,
        'updatedAt': nowIso,
      });
    });
  }

  _RolePermissions _permissionsForRole(String role) {
    switch (role) {
      case 'owner':
      case 'admin':
      case 'lister':
        return const _RolePermissions(
          canListProperty: true,
          canListProject: true,
        );
      case 'viewer':
      default:
        return const _RolePermissions(
          canListProperty: false,
          canListProject: false,
        );
    }
  }
}

class _RolePermissions {
  final bool canListProperty;
  final bool canListProject;

  const _RolePermissions({
    required this.canListProperty,
    required this.canListProject,
  });
}
