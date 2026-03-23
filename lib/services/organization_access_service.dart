import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationAccessResult {
  final bool allowed;
  final String? organizationId;
  final String? message;

  const OrganizationAccessResult({
    required this.allowed,
    this.organizationId,
    this.message,
  });
}

class OrganizationAccessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<OrganizationAccessResult> checkPropertyListingAccess({
    required String userId,
  }) async {
    return _checkAccess(
      userId: userId,
      canListField: 'canListProperty',
      deniedMessage:
          'You do not have permission to list properties for this company.',
    );
  }

  Future<OrganizationAccessResult> checkProjectListingAccess({
    required String userId,
  }) async {
    return _checkAccess(
      userId: userId,
      canListField: 'canListProject',
      deniedMessage:
          'You do not have permission to advertise projects for this company.',
    );
  }

  Future<OrganizationAccessResult> _checkAccess({
    required String userId,
    required String canListField,
    required String deniedMessage,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return const OrganizationAccessResult(
        allowed: false,
        message: 'User profile not found.',
      );
    }

    final userData = userDoc.data() ?? <String, dynamic>{};
    final rawOrgId = userData['activeOrganizationId'];
    final orgId = rawOrgId is String ? rawOrgId.trim() : '';

    // Personal flow (non-enterprise): no org needed.
    if (orgId.isEmpty) {
      return const OrganizationAccessResult(allowed: true);
    }

    final orgDoc = await _firestore
        .collection('organizations')
        .doc(orgId)
        .get();
    if (!orgDoc.exists) {
      return const OrganizationAccessResult(
        allowed: false,
        message: 'Your active company workspace was not found.',
      );
    }

    final orgData = orgDoc.data() ?? <String, dynamic>{};
    final orgStatus = (orgData['status'] ?? '').toString();
    final orgPlan = (orgData['plan'] ?? '').toString();
    if (orgStatus != 'active' || orgPlan != 'enterprise') {
      return const OrganizationAccessResult(
        allowed: false,
        message: 'Your company Enterprise plan is not active.',
      );
    }

    final memberDoc = await _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .doc(userId)
        .get();

    if (!memberDoc.exists) {
      return const OrganizationAccessResult(
        allowed: false,
        message: 'You are not a member of the selected company workspace.',
      );
    }

    final memberData = memberDoc.data() ?? <String, dynamic>{};
    final memberStatus = (memberData['status'] ?? '').toString();
    final canList = memberData[canListField] == true;
    if (memberStatus != 'active' || !canList) {
      return OrganizationAccessResult(allowed: false, message: deniedMessage);
    }

    return OrganizationAccessResult(allowed: true, organizationId: orgId);
  }
}
