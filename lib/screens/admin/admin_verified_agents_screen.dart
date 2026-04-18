import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/agent_name_with_badge.dart';

class AdminVerifiedAgentsScreen extends StatefulWidget {
  final bool embedded;

  const AdminVerifiedAgentsScreen({super.key, this.embedded = false});

  @override
  State<AdminVerifiedAgentsScreen> createState() =>
      _AdminVerifiedAgentsScreenState();
}

class _AdminVerifiedAgentsScreenState extends State<AdminVerifiedAgentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _withListingsOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Unknown';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String _normalizeArea(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  List<String> _mergeOperatingAreas(
    UserModel user,
    List<_AgentListingPreview> listings,
  ) {
    final merged = <String>[];
    final seen = <String>{};

    void addArea(String value, {bool split = false}) {
      final values = split ? value.split(',') : [value];
      for (final item in values) {
        final normalized = _normalizeArea(item);
        if (normalized.isEmpty) continue;
        final key = normalized.toLowerCase();
        if (seen.add(key)) {
          merged.add(normalized);
        }
      }
    }

    for (final area in user.operatingAreas) {
      addArea(area);
    }

    for (final listing in listings) {
      addArea(listing.location);
    }

    if (merged.isEmpty && user.companyAddress != null) {
      addArea(user.companyAddress!, split: true);
    }

    return merged;
  }

  Future<void> _confirmUnverify(_VerifiedAgentEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Unverify Agent'),
          ],
        ),
        content: Text(
          'Remove verification from ${entry.user.name}? They will need to submit documents again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unverify'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(entry.user.id)
          .update({
            'isVerified': false,
            'verificationStatus': 'unverified',
            'unverifiedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.user.name} has been unverified.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not unverify agent: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style.copyWith(height: 1.5),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaChip(String area) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        area,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildListingTile(_AgentListingPreview listing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${listing.typeLabel} • ${listing.location}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(_VerifiedAgentEntry entry) {
    final user = entry.user;
    final subtitleParts = <String>[
      if (user.companyName != null && user.companyName!.trim().isNotEmpty)
        user.companyName!.trim(),
      'Verified on ${_formatDate(entry.verifiedAt)}',
    ];

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Text(
            user.name.isEmpty ? 'A' : user.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: AgentNameWithBadge(
          name: user.name,
          isVerified: true,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          iconColor: AppColors.primary,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitleParts.join(' • '),
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildAreaChip(
                '${entry.listingCount} ${entry.listingCount == 1 ? "active listing" : "active listings"}',
              ),
              if (user.averageRating != null && user.totalRatings > 0)
                _buildAreaChip(
                  'Rating ${user.averageRating!.toStringAsFixed(1)} (${user.totalRatings})',
                ),
              _buildAreaChip(
                '${entry.operatingAreas.length} ${entry.operatingAreas.length == 1 ? "area" : "areas"} covered',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Email', user.email, icon: Icons.email_outlined),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Phone',
            user.phoneNumber.isEmpty ? 'Not provided' : user.phoneNumber,
            icon: Icons.phone_outlined,
          ),
          if (user.whatsappNumber != null &&
              user.whatsappNumber!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              'WhatsApp',
              user.whatsappNumber!,
              icon: Icons.chat_outlined,
            ),
          ],
          if (user.companyAddress != null &&
              user.companyAddress!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              'Office',
              user.companyAddress!,
              icon: Icons.location_on_outlined,
            ),
          ],
          if (entry.operatingAreas.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Areas of operation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.operatingAreas.map(_buildAreaChip).toList(),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Recent listings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${entry.listingCount} total',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entry.recentListings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.18)),
              ),
              child: const Text(
                'This verified agent does not have any active approved listings right now.',
              ),
            )
          else
            Column(
              children: entry.recentListings.map(_buildListingTile).toList(),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _confirmUnverify(entry),
              icon: const Icon(Icons.remove_moderator_outlined),
              label: const Text('Unverify Agent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .snapshots(),
      builder: (context, usersSnapshot) {
        if (usersSnapshot.hasError) {
          return Center(
            child: Text(
              'Error loading verified agents: ${usersSnapshot.error}',
            ),
          );
        }

        if (!usersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('properties')
              .where('status', isEqualTo: 'approved')
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, propertiesSnapshot) {
            if (propertiesSnapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading agent listings: ${propertiesSnapshot.error}',
                ),
              );
            }

            if (!propertiesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final listingsByOwner = <String, List<_AgentListingPreview>>{};
            for (final doc in propertiesSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ownerId = (data['ownerId'] ?? data['agentId'] ?? '')
                  .toString()
                  .trim();
              if (ownerId.isEmpty) continue;

              listingsByOwner.putIfAbsent(
                ownerId,
                () => <_AgentListingPreview>[],
              );
              listingsByOwner[ownerId]!.add(
                _AgentListingPreview(
                  title: (data['title'] ?? 'Untitled property').toString(),
                  location: (data['location'] ?? 'Unknown area').toString(),
                  typeLabel: _typeLabel((data['type'] ?? '').toString()),
                ),
              );
            }

            final allAgents = usersSnapshot.data!.docs
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final user = UserModel.fromJson({...data, 'id': doc.id});
                  if (!user.roles.contains(UserRole.propertyAgent)) {
                    return null;
                  }

                  final listings = listingsByOwner[doc.id] ?? const [];
                  final operatingAreas = _mergeOperatingAreas(user, listings);

                  return _VerifiedAgentEntry(
                    user: user.copyWith(operatingAreas: operatingAreas),
                    verifiedAt: _parseDate(data['verifiedAt']),
                    recentListings: listings.take(3).toList(),
                    listingCount: listings.length,
                    operatingAreas: operatingAreas,
                  );
                })
                .whereType<_VerifiedAgentEntry>()
                .toList();

            allAgents.sort((a, b) {
              final aDate =
                  a.verifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate =
                  b.verifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

            final query = _searchController.text.trim().toLowerCase();
            final filteredAgents = allAgents.where((entry) {
              if (_withListingsOnly && entry.listingCount == 0) {
                return false;
              }

              if (query.isEmpty) return true;

              final searchableFields = <String>[
                entry.user.name,
                entry.user.email,
                entry.user.phoneNumber,
                entry.user.companyName ?? '',
                entry.user.companyAddress ?? '',
                entry.user.whatsappNumber ?? '',
                ...entry.operatingAreas,
              ];

              return searchableFields.any(
                (field) => field.toLowerCase().contains(query),
              );
            }).toList();

            final totalListings = allAgents.fold<int>(
              0,
              (sum, entry) => sum + entry.listingCount,
            );
            final ratedAgents = allAgents
                .where((entry) => entry.user.averageRating != null)
                .toList();
            final avgRating = ratedAgents.isEmpty
                ? 0.0
                : ratedAgents
                          .map((entry) => entry.user.averageRating!)
                          .reduce((a, b) => a + b) /
                      ratedAgents.length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name, company, or area',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () => _searchController.clear(),
                                  icon: const Icon(Icons.close),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('With listings only'),
                            selected: _withListingsOnly,
                            onSelected: (selected) {
                              setState(() {
                                _withListingsOnly = selected;
                              });
                            },
                          ),
                          const Spacer(),
                          Text(
                            '${filteredAgents.length} shown',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatCard(
                              title: 'Verified Agents',
                              value: '${allAgents.length}',
                              icon: Icons.workspace_premium_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              title: 'Active Listings',
                              value: '$totalListings',
                              icon: Icons.home_work_outlined,
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 12),
                            _buildStatCard(
                              title: 'Average Rating',
                              value: avgRating == 0
                                  ? 'N/A'
                                  : avgRating.toStringAsFixed(1),
                              icon: Icons.star_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredAgents.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 72,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No verified agents found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Verified agents will appear here for admin monitoring and management.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filteredAgents.length,
                          itemBuilder: (context, index) {
                            return _buildAgentCard(filteredAgents[index]);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _typeLabel(String rawType) {
    switch (rawType.trim().toLowerCase()) {
      case 'sale':
        return 'Sale';
      case 'rent':
        return 'Rent';
      case 'hostel':
        return 'Hostel';
      case 'commercial':
        return 'Commercial';
      default:
        return 'Property';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verified Agents')),
      body: _buildBody(),
    );
  }
}

class _VerifiedAgentEntry {
  final UserModel user;
  final DateTime? verifiedAt;
  final List<_AgentListingPreview> recentListings;
  final int listingCount;
  final List<String> operatingAreas;

  const _VerifiedAgentEntry({
    required this.user,
    required this.verifiedAt,
    required this.recentListings,
    required this.listingCount,
    required this.operatingAreas,
  });
}

class _AgentListingPreview {
  final String title;
  final String location;
  final String typeLabel;

  const _AgentListingPreview({
    required this.title,
    required this.location,
    required this.typeLabel,
  });
}
