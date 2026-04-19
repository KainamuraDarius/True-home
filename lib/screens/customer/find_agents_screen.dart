import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/agent_name_with_badge.dart';
import 'agent_profile_screen.dart';

class FindAgentsScreen extends StatefulWidget {
  const FindAgentsScreen({super.key});

  @override
  State<FindAgentsScreen> createState() => _FindAgentsScreenState();
}

class _FindAgentsScreenState extends State<FindAgentsScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _authRequired = false;
  String? _selectedArea;
  List<_AgentDirectoryEntry> _agents = [];
  List<String> _availableAreas = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadAgents();
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

  String _normalizeArea(String value) {
    final trimmed = value.trim();
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
    List<String> explicitAreas,
    List<String> listingAreas,
    String? companyAddress,
  ) {
    final merged = <String>[];
    final seen = <String>{};

    void addArea(String raw, {bool splitCommas = false}) {
      final values = splitCommas ? raw.split(',') : [raw];
      for (final value in values) {
        final normalized = _normalizeArea(value);
        if (normalized.isEmpty) continue;
        final key = normalized.toLowerCase();
        if (seen.add(key)) {
          merged.add(normalized);
        }
      }
    }

    for (final area in explicitAreas) {
      addArea(area);
    }

    for (final area in listingAreas) {
      addArea(area);
    }

    if (merged.isEmpty && companyAddress != null && companyAddress.isNotEmpty) {
      addArea(companyAddress, splitCommas: true);
    }

    return merged;
  }

  Future<void> _loadAgents() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _authRequired = false;
      });
    }

    if (FirebaseAuth.instance.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _authRequired = true;
        _agents = [];
        _availableAreas = [];
      });
      return;
    }

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isVerified', isEqualTo: true)
          .get();

      final propertiesSnapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .get();

      final listingCountByOwner = <String, int>{};
      final listingAreasByOwner = <String, Set<String>>{};

      for (final doc in propertiesSnapshot.docs) {
        final data = doc.data();
        final ownerId = (data['ownerId'] ?? data['agentId'] ?? '')
            .toString()
            .trim();
        if (ownerId.isEmpty) continue;

        listingCountByOwner[ownerId] = (listingCountByOwner[ownerId] ?? 0) + 1;

        final location = _normalizeArea((data['location'] ?? '').toString());
        if (location.isEmpty) continue;

        listingAreasByOwner
            .putIfAbsent(ownerId, () => <String>{})
            .add(location);
      }

      final agents = <_AgentDirectoryEntry>[];
      final areas = <String>{};

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final roles = List<String>.from(
          data['roles'] ??
              (data['role'] != null ? [data['role']] : const <String>[]),
        );

        final isAgent =
            roles.contains(UserRole.propertyAgent.name) ||
            data['activeRole'] == UserRole.propertyAgent.name ||
            data['role'] == UserRole.propertyAgent.name;

        if (!isAgent) continue;

        final user = UserModel.fromJson({...data, 'id': doc.id});
        final mergedAreas = _mergeOperatingAreas(
          user.operatingAreas,
          listingAreasByOwner[doc.id]?.toList() ?? const <String>[],
          user.companyAddress,
        );

        for (final area in mergedAreas) {
          areas.add(area);
        }

        agents.add(
          _AgentDirectoryEntry(
            user: user.copyWith(operatingAreas: mergedAreas),
            listingCount: listingCountByOwner[doc.id] ?? 0,
            operatingAreas: mergedAreas,
          ),
        );
      }

      agents.sort((a, b) {
        final ratingCompare = (b.user.averageRating ?? 0).compareTo(
          a.user.averageRating ?? 0,
        );
        if (ratingCompare != 0) return ratingCompare;

        final listingsCompare = b.listingCount.compareTo(a.listingCount);
        if (listingsCompare != 0) return listingsCompare;

        return a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
      });

      final availableAreas = areas.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;

      setState(() {
        _agents = agents;
        _availableAreas = availableAreas;
        _authRequired = false;
        if (_selectedArea != null &&
            !_availableAreas.any(
              (area) => area.toLowerCase() == _selectedArea!.toLowerCase(),
            )) {
          _selectedArea = null;
        }
        _isLoading = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;

      final permissionDenied = e.code == 'permission-denied';
      setState(() {
        _isLoading = false;
        _authRequired = permissionDenied;
      });

      if (!permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load verified agents: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load verified agents: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<_AgentDirectoryEntry> get _filteredAgents {
    final query = _searchController.text.trim().toLowerCase();

    return _agents.where((agent) {
      final matchesArea =
          _selectedArea == null ||
          agent.operatingAreas.any(
            (area) => area.toLowerCase() == _selectedArea!.toLowerCase(),
          );

      if (!matchesArea) return false;

      if (query.isEmpty) return true;

      final searchableFields = <String>[
        agent.user.name,
        agent.user.companyName ?? '',
        agent.user.companyAddress ?? '',
        ...agent.operatingAreas,
      ];

      return searchableFields.any(
        (field) => field.toLowerCase().contains(query),
      );
    }).toList();
  }

  void _showAreaFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filter by area',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedArea = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_availableAreas.isEmpty)
                  Text(
                    'No operating areas have been added yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _availableAreas.map((area) {
                      final isSelected =
                          _selectedArea?.toLowerCase() == area.toLowerCase();
                      return ChoiceChip(
                        label: Text(area),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        onSelected: (_) {
                          Navigator.pop(context);
                          setState(() {
                            _selectedArea = area;
                          });
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAgentProfile(UserModel agent) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgentProfileScreen(agent: agent)),
    );
  }

  Widget _buildAgentAvatar(UserModel user) {
    final imageUrl = user.profileImageUrl;

    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl.startsWith('http')) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 68,
            height: 68,
            color: AppColors.primary.withOpacity(0.08),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => _buildInitialAvatar(user),
        ),
      );
    }

    return _buildInitialAvatar(user);
  }

  Widget _buildInitialAvatar(UserModel user) {
    final initial = user.name.trim().isEmpty ? 'A' : user.name.trim()[0];
    return CircleAvatar(
      radius: 34,
      backgroundColor: AppColors.primary.withOpacity(0.12),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaChip(String area) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.16)),
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

  Widget _buildAgentCard(_AgentDirectoryEntry agent) {
    final user = agent.user;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openAgentProfile(user),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAgentAvatar(user),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AgentNameWithBadge(
                          name: user.name,
                          isVerified: true,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          iconColor: AppColors.primary,
                        ),
                        if (user.companyName != null &&
                            user.companyName!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.companyName!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMetricChip(
                              Icons.verified_rounded,
                              'Verified',
                              AppColors.primary,
                            ),
                            _buildMetricChip(
                              Icons.home_work_outlined,
                              '${agent.listingCount} ${agent.listingCount == 1 ? "listing" : "listings"}',
                              Colors.orange.shade700,
                            ),
                            if (user.averageRating != null &&
                                user.totalRatings > 0)
                              _buildMetricChip(
                                Icons.star_rounded,
                                '${user.averageRating!.toStringAsFixed(1)} (${user.totalRatings})',
                                Colors.amber.shade800,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (agent.operatingAreas.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Areas of operation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: agent.operatingAreas
                      .take(6)
                      .map(_buildAreaChip)
                      .toList(),
                ),
              ],
              if (user.companyAddress != null &&
                  user.companyAddress!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        user.companyAddress!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openAgentProfile(user),
                  icon: const Icon(Icons.person_search_rounded),
                  label: const Text('View Agent Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchController.text.trim().isNotEmpty || _selectedArea != null;

    if (_authRequired) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Login required to find agents',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in first, then open this page again to browse verified agents.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.person_search_outlined, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No verified agents match that search'
                : 'No verified agents available yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try a different area, company, or agent name.'
                : 'Verified agents will appear here once they complete approval.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAgents = _filteredAgents;

    return Scaffold(
      appBar: AppBar(title: const Text('Find Agents')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find a verified agent',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search by area, company, or name when the exact listing is not on the platform yet.',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.88),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by area or agent name',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade600,
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () => _searchController.clear(),
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: IconButton(
                        onPressed: _showAreaFilterSheet,
                        icon: const Icon(Icons.tune, color: Colors.white),
                        tooltip: 'Filter by area',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${filteredAgents.length} verified ${filteredAgents.length == 1 ? "agent" : "agents"}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_selectedArea != null)
                      InputChip(
                        label: Text(_selectedArea!),
                        selected: true,
                        showCheckmark: false,
                        backgroundColor: Colors.white,
                        onDeleted: () {
                          setState(() {
                            _selectedArea = null;
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAgents,
                    child: filteredAgents.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              _buildEmptyState(),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: filteredAgents.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              return _buildAgentCard(filteredAgents[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgentDirectoryEntry {
  final UserModel user;
  final int listingCount;
  final List<String> operatingAreas;

  const _AgentDirectoryEntry({
    required this.user,
    required this.listingCount,
    required this.operatingAreas,
  });
}
