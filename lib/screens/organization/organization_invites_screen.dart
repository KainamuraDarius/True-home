import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/organization_invite_service.dart';
import '../../utils/app_theme.dart';

class OrganizationInvitesScreen extends StatefulWidget {
  const OrganizationInvitesScreen({super.key});

  @override
  State<OrganizationInvitesScreen> createState() =>
      _OrganizationInvitesScreenState();
}

class _OrganizationInvitesScreenState extends State<OrganizationInvitesScreen> {
  final OrganizationInviteService _inviteService = OrganizationInviteService();
  String? _emailLower;
  bool _isLoadingEmail = true;
  String? _processingInviteId;
  final Map<String, TextEditingController> _inviteCodeControllers = {};
  List<OrganizationInviteItem> _cachedInvites = const [];
  Stream<List<OrganizationInviteItem>>? _invitesStream;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    try {
      final email = await _inviteService.getCurrentUserEmailLower();
      final normalizedEmail = (email ?? '').trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        _emailLower = normalizedEmail;
        _isLoadingEmail = false;
        _invitesStream = normalizedEmail.isEmpty
            ? null
            : _inviteService.streamMyPendingInvites(
                emailLower: normalizedEmail,
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingEmail = false;
        _invitesStream = null;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _inviteCodeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerForInvite(String inviteId) {
    return _inviteCodeControllers.putIfAbsent(
      inviteId,
      () => TextEditingController(),
    );
  }

  Future<void> _acceptInvite(OrganizationInviteItem invite) async {
    String verificationCode = '';
    if (invite.codeRequired) {
      final code = _controllerForInvite(invite.id).text.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter the invite code from your email first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      verificationCode = code;
    }

    setState(() => _processingInviteId = invite.id);
    try {
      await _inviteService.acceptInvite(
        invite,
        verificationCode: verificationCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invite accepted. Your company workspace is now active.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      final controller = _inviteCodeControllers.remove(invite.id);
      controller?.dispose();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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

  Future<void> _declineInvite(OrganizationInviteItem invite) async {
    setState(() => _processingInviteId = invite.id);
    try {
      await _inviteService.declineInvite(invite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite declined.'),
          backgroundColor: Colors.orange,
        ),
      );
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

  String _formatRole(String role) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Invites'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoadingEmail
          ? const Center(child: CircularProgressIndicator())
          : (_emailLower == null || _emailLower!.isEmpty || _invitesStream == null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.mark_email_unread_outlined, size: 56),
                    SizedBox(height: 12),
                    Text(
                      'No account email found. Company invites are matched by email.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<List<OrganizationInviteItem>>(
              stream: _invitesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _cachedInvites.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  if (_cachedInvites.isNotEmpty) {
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'Connection issue detected. Showing your latest invite data.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(child: _buildInvitesList(_cachedInvites)),
                      ],
                    );
                  }

                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Failed to load invites right now. Please reopen this page.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final invites = snapshot.data ?? _cachedInvites;
                if (snapshot.hasData) {
                  _cachedInvites = invites;
                }
                if (invites.isEmpty) {
                  return const Center(
                    child: Text('No pending invites right now.'),
                  );
                }

                return _buildInvitesList(invites);
              },
            ),
    );
  }

  Widget _buildInvitesList(List<OrganizationInviteItem> invites) {
    return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: invites.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    final isProcessing = _processingInviteId == invite.id;
                    final inviteCodeController = _controllerForInvite(
                      invite.id,
                    );

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invite.organizationName.isEmpty
                                  ? 'Enterprise Workspace'
                                  : invite.organizationName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Role: ${_formatRole(invite.role)}',
                              style: const TextStyle(color: Colors.black87),
                            ),
                            if (invite.codeRequired) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Invite code required. Enter it below from your email.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: inviteCodeController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: const InputDecoration(
                                  labelText: 'Invite Code',
                                  hintText: 'Enter 6-digit code',
                                  counterText: '',
                                  prefixIcon: Icon(
                                    Icons.verified_user_outlined,
                                  ),
                                ),
                              ),
                            ],
                            if (invite.expiresAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Expires: ${invite.expiresAt!.toLocal()}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _declineInvite(invite),
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _acceptInvite(invite),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: isProcessing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Accept'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
  }
}
