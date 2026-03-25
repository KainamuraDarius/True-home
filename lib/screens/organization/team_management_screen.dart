import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/organization_invite_service.dart';
import '../../utils/app_theme.dart';

class TeamManagementScreen extends StatefulWidget {
  final String organizationId;
  final String organizationName;
  final bool showFinishButton;

  const TeamManagementScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
    this.showFinishButton = false,
  });

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _inviteEmailController = TextEditingController();
  final OrganizationInviteService _inviteService = OrganizationInviteService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedRole = 'lister';
  bool _isInviting = false;
  bool _isLoadingRole = true;
  String _myRole = 'viewer';
  String? _processingMemberId;
  String? _processingInviteId;

  bool get _isOwner => _myRole == 'owner';
  bool get _canManageTeam => _myRole == 'owner' || _myRole == 'admin';

  @override
  void initState() {
    super.initState();
    _loadCurrentMemberRole();
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentMemberRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _myRole = 'viewer';
          _isLoadingRole = false;
        });
      }
      return;
    }

    try {
      final memberDoc = await _firestore
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('members')
          .doc(uid)
          .get();
      final role = (memberDoc.data()?['role'] ?? 'viewer').toString();
      if (mounted) {
        setState(() {
          _myRole = role;
          _isLoadingRole = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _myRole = 'viewer';
          _isLoadingRole = false;
        });
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Admin';
      case 'lister':
        return 'Lister';
      case 'viewer':
      default:
        return 'Viewer';
    }
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

  List<String> _availableRoleOptions(String targetRole) {
    // Only owner can assign owner role, admin can assign admin/lister/viewer
    if (_isOwner) {
      return const ['owner', 'admin', 'lister', 'viewer'];
    }
    if (targetRole == 'owner') return const <String>[];
    return const ['admin', 'lister', 'viewer'];
  }

  Future<void> _logAuditAction(String action, Map<String, dynamic> details) async {
    try {
      await _firestore
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('audit_logs')
          .add({
        'action': action,
        'details': details,
        'actorId': FirebaseAuth.instance.currentUser?.uid,
        'actorRole': _myRole,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _sendInvite() async {
    if (!_canManageTeam) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only owner/admin can invite team members.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final email = _inviteEmailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid email address.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.email?.toLowerCase() == email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are already part of this workspace.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isInviting = true);
    try {
      final result = await _inviteService.createInvite(
        organizationId: widget.organizationId,
        organizationName: widget.organizationName,
        email: email,
        role: _selectedRole,
      );
      _inviteEmailController.clear();
      await _logAuditAction('invite_sent', {
        'invitee': email,
        'role': _selectedRole,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite created successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      await _showInviteCodeDialog(
        verificationCode: result.verificationCode,
        email: email,
        emailSent: result.emailSent,
        emailError: result.emailError,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _showInviteCodeDialog({
    required String verificationCode,
    required String email,
    required bool emailSent,
    String? emailError,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invitee: $email'),
            const SizedBox(height: 10),
            const Text(
              'Verification code:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                verificationCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              emailSent
                  ? 'Code email sent successfully.'
                  : 'Email not sent. Share this code manually for now.',
              style: TextStyle(
                color: emailSent
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
            if (!emailSent && (emailError ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                emailError!,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: verificationCode));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite code copied.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy Code'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendInviteCode(
    OrganizationInviteItem invite,
    String verificationCode,
  ) async {
    setState(() => _processingInviteId = invite.id);
    try {
      await _inviteService.resendInviteCode(invite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code email resent.'),
          backgroundColor: Colors.green,
        ),
      );
      if (verificationCode.isNotEmpty) {
        await _showInviteCodeDialog(
          verificationCode: verificationCode,
          email: invite.email,
          emailSent: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingInviteId = null);
    }
  }

  Future<void> _revokeInvite(String inviteId) async {
    setState(() => _processingInviteId = inviteId);
    try {
      await _firestore
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('invites')
          .doc(inviteId)
          .update({
            'status': 'revoked',
            'updatedAt': DateTime.now().toIso8601String(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite revoked.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingInviteId = null);
    }
  }

  Future<void> _changeMemberRole({
    required String memberId,
    required String currentRole,
    required String newRole,
  }) async {
    if (!_canManageTeam || currentRole == newRole) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    if (!_isOwner && (currentRole == 'owner' || newRole == 'owner')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only workspace owners can assign owner role.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _processingMemberId = memberId);
    try {
      final permissions = _permissionsForRole(newRole);
      await _firestore
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('members')
          .doc(memberId)
          .update({
            'role': newRole,
            'canListProperty': permissions.canListProperty,
            'canListProject': permissions.canListProject,
            'updatedAt': DateTime.now().toIso8601String(),
          });

      bool userRolePromoted = true;
      if (newRole == 'owner' || newRole == 'admin' || newRole == 'lister') {
        try {
          await _firestore.collection('users').doc(memberId).update({
            'roles': FieldValue.arrayUnion(['propertyAgent']),
            'activeRole': 'propertyAgent',
            'updatedAt': DateTime.now().toIso8601String(),
          });
        } catch (_) {
          userRolePromoted = false;
        }
      }

      await _logAuditAction('role_changed', {
        'memberId': memberId,
        'oldRole': currentRole,
        'newRole': newRole,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userRolePromoted
                ? 'Role updated to ${_roleLabel(newRole)}.'
                : 'Role updated. User may need to switch to Agent role manually.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingMemberId = null);
    }
  }

  Future<void> _deactivateMember({
    required String memberId,
    required String currentRole,
  }) async {
    if (!_canManageTeam) return;
    if (memberId == FirebaseAuth.instance.currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot remove yourself from this screen.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_isOwner && currentRole == 'owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only workspace owners can remove owners.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _processingMemberId = memberId);
    try {
      await _firestore
          .collection('organizations')
          .doc(widget.organizationId)
          .collection('members')
          .doc(memberId)
          .update({
            'status': 'inactive',
            'removedAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member removed from workspace.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove member: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingMemberId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersStream = _firestore
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .snapshots();
    final invitesStream = _firestore
        .collection('organizations')
        .doc(widget.organizationId)
        .collection('invites')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.organizationName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Invite teammates with email code verification and assign role permissions.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            if (_isLoadingRole)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (!_canManageTeam)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'You are ${_roleLabel(_myRole)}. Only owner/admin can invite or edit team members.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (_canManageTeam) ...[
                TextField(
                  controller: _inviteEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Member Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'lister', child: Text('Lister')),
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedRole = value);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isInviting ? null : _sendInvite,
                    icon: _isInviting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isInviting ? 'Sending...' : 'Send Invite Code Email',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: [
                  const Text(
                    'Team Members',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: membersStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Text('No active members yet.'),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      return Column(
                        children: docs.map((memberDoc) {
                          final data = memberDoc.data();
                          final memberId = memberDoc.id;
                          final memberRole = (data['role'] ?? 'viewer')
                              .toString();
                          final canListProperty =
                              data['canListProperty'] == true;
                          final canListProject = data['canListProject'] == true;
                          final isProcessing = _processingMemberId == memberId;
                          final roleOptions = _availableRoleOptions(memberRole);

                          return FutureBuilder<
                            DocumentSnapshot<Map<String, dynamic>>
                          >(
                            future: _firestore
                                .collection('users')
                                .doc(memberId)
                                .get(),
                            builder: (context, userSnapshot) {
                              final userData = userSnapshot.data?.data();
                              final memberName = (userData?['name'] ?? '')
                                  .toString();
                              final memberEmail = (userData?['email'] ?? '')
                                  .toString();

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            child: const Icon(
                                              Icons.person_outline,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  memberName.isEmpty
                                                      ? memberId
                                                      : memberName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (memberEmail.isNotEmpty)
                                                  Text(
                                                    memberEmail,
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildBadge(
                                            'Role: ${_roleLabel(memberRole)}',
                                          ),
                                          _buildBadge(
                                            canListProperty
                                                ? 'Can list properties'
                                                : 'No property listing',
                                          ),
                                          _buildBadge(
                                            canListProject
                                                ? 'Can list projects'
                                                : 'No project listing',
                                          ),
                                        ],
                                      ),
                                      if (_canManageTeam) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            if (roleOptions.isNotEmpty)
                                              PopupMenuButton<String>(
                                                onSelected: isProcessing
                                                    ? null
                                                    : (newRole) =>
                                                          _changeMemberRole(
                                                            memberId: memberId,
                                                            currentRole:
                                                                memberRole,
                                                            newRole: newRole,
                                                          ),
                                                itemBuilder: (context) =>
                                                    roleOptions
                                                        .map(
                                                          (role) =>
                                                              PopupMenuItem(
                                                                value: role,
                                                                child: Text(
                                                                  _roleLabel(
                                                                    role,
                                                                  ),
                                                                ),
                                                              ),
                                                        )
                                                        .toList(),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.black26,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.swap_horiz,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text('Change Role'),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 10),
                                            if (memberId !=
                                                FirebaseAuth
                                                    .instance
                                                    .currentUser
                                                    ?.uid)
                                              TextButton.icon(
                                                onPressed: isProcessing
                                                    ? null
                                                    : () => _deactivateMember(
                                                        memberId: memberId,
                                                        currentRole: memberRole,
                                                      ),
                                                icon: isProcessing
                                                    ? const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons
                                                            .person_remove_outlined,
                                                      ),
                                                label: const Text('Remove'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Recent Invites',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: invitesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Text('No invites yet.'),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;
                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data();
                          final invite = OrganizationInviteItem.fromSnapshot(
                            doc,
                          );
                          final status = (data['status'] ?? 'pending')
                              .toString();
                          final code = (data['verificationCode'] ?? '')
                              .toString();
                          final delivery = (data['emailDeliveryStatus'] ?? '')
                              .toString();
                          final isPending = status == 'pending';
                          final isProcessing = _processingInviteId == invite.id;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['email'] ?? 'No email',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildBadge(
                                        'Role: ${_roleLabel((data['role'] ?? 'viewer').toString())}',
                                      ),
                                      _buildBadge('Status: $status'),
                                      if (delivery.isNotEmpty)
                                        _buildBadge('Email: $delivery'),
                                    ],
                                  ),
                                  if (_canManageTeam && code.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Code: $code',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.6,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Copy Code',
                                          onPressed: () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: code),
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Invite code copied.',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.copy_outlined),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_canManageTeam && isPending) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          onPressed: isProcessing
                                              ? null
                                              : () => _resendInviteCode(
                                                  invite,
                                                  code,
                                                ),
                                          icon: const Icon(
                                            Icons.mark_email_read_outlined,
                                          ),
                                          label: const Text('Resend Code'),
                                        ),
                                        const SizedBox(width: 6),
                                        TextButton.icon(
                                          onPressed: isProcessing
                                              ? null
                                              : () => _revokeInvite(invite.id),
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                          ),
                                          label: const Text('Revoke'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (widget.showFinishButton) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Finish Setup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
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
