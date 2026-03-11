import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/property_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';

class AdminTrashScreen extends StatefulWidget {
  const AdminTrashScreen({super.key});

  @override
  State<AdminTrashScreen> createState() => _AdminTrashScreenState();
}

class _AdminTrashScreenState extends State<AdminTrashScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Trash'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Properties'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.apartment), text: 'Projects'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Empty All Trash',
            onPressed: _confirmEmptyAllTrash,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPropertiesTab(),
                _buildUsersTab(),
                _buildProjectsTab(),
              ],
            ),
    );
  }

  // ==================== PROPERTIES TAB ====================
  Widget _buildPropertiesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('status', isEqualTo: PropertyStatus.removed.name)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final properties = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return PropertyModel.fromJson(data);
        }).toList();

        if (properties.isEmpty) {
          return _buildEmptyState('No deleted properties', Icons.home_outlined);
        }

        return _buildTrashList(
          itemCount: properties.length,
          itemBuilder: (index) => _buildPropertyItem(properties[index]),
        );
      },
    );
  }

  Widget _buildPropertyItem(PropertyModel property) {
    final deletedAt = property.updatedAt;
    final daysSinceDeleted = DateTime.now().difference(deletedAt).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: property.imageUrls.isNotEmpty
                    ? Image.network(
                        property.imageUrls.first,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(Icons.broken_image),
                      )
                    : _buildPlaceholder(Icons.home),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(property.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(property.location, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(CurrencyFormatter.formatWithCurrency(property.price, currency: property.currency), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_formatDeletedTime(daysSinceDeleted), style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildActionButtons(
            onRestore: () => _restoreProperty(property),
            onDelete: () => _confirmPermanentDeleteProperty(property),
          ),
        ],
      ),
    );
  }

  // ==================== USERS TAB ====================
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isDeleted', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return _buildEmptyState('No deleted users', Icons.people_outlined);
        }

        return _buildTrashList(
          itemCount: users.length,
          itemBuilder: (index) => _buildUserItem(users[index]),
        );
      },
    );
  }

  Widget _buildUserItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? '';
    final role = data['role'] ?? 'customer';
    final deletedAt = data['deletedAt'] != null ? DateTime.parse(data['deletedAt']) : DateTime.now();
    final daysSinceDeleted = DateTime.now().difference(deletedAt).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(role),
              child: Icon(_getRoleIcon(role), color: Colors.white),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email),
                Text('Role: ${_formatRole(role)}', style: TextStyle(color: _getRoleColor(role), fontSize: 12)),
                Text(_formatDeletedTime(daysSinceDeleted), style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
            isThreeLine: true,
          ),
          _buildActionButtons(
            onRestore: () => _restoreUser(doc.id, name),
            onDelete: () => _confirmPermanentDeleteUser(doc.id, name),
          ),
        ],
      ),
    );
  }

  // ==================== PROJECTS TAB ====================
  Widget _buildProjectsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('advertised_projects')
          .where('isDeleted', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snapshot.data!.docs;

        if (projects.isEmpty) {
          return _buildEmptyState('No deleted projects', Icons.apartment_outlined);
        }

        return _buildTrashList(
          itemCount: projects.length,
          itemBuilder: (index) => _buildProjectItem(projects[index]),
        );
      },
    );
  }

  Widget _buildProjectItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['projectName'] ?? 'Unknown Project';
    final location = data['location'] ?? '';
    final developer = data['developerName'] ?? '';
    final deletedAt = data['deletedAt'] != null ? DateTime.parse(data['deletedAt']) : DateTime.now();
    final daysSinceDeleted = DateTime.now().difference(deletedAt).inDays;
    final images = List<String>.from(data['images'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: images.isNotEmpty
                    ? Image.network(
                        images.first,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(Icons.broken_image),
                      )
                    : _buildPlaceholder(Icons.apartment),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(location, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('By: $developer', style: const TextStyle(color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text(_formatDeletedTime(daysSinceDeleted), style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildActionButtons(
            onRestore: () => _restoreProject(doc.id, name),
            onDelete: () => _confirmPermanentDeleteProject(doc.id, name),
          ),
        ],
      ),
    );
  }

  // ==================== SHARED UI HELPERS ====================
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Deleted items will appear here', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildTrashList({required int itemCount, required Widget Function(int) itemBuilder}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(index),
    );
  }

  Widget _buildPlaceholder(IconData icon) {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[200],
      child: Icon(icon, size: 40, color: Colors.grey[400]),
    );
  }

  Widget _buildActionButtons({required VoidCallback onRestore, required VoidCallback onDelete}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Restore'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete Forever'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  String _formatDeletedTime(int days) {
    if (days == 0) return 'Deleted today';
    if (days == 1) return 'Deleted yesterday';
    return 'Deleted $days days ago';
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'propertyAgent': return Colors.green;
      default: return Colors.blue;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings;
      case 'propertyAgent': return Icons.business;
      default: return Icons.person;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'propertyAgent': return 'Property Agent';
      case 'admin': return 'Admin';
      default: return 'Customer';
    }
  }

  // ==================== RESTORE ACTIONS ====================
  Future<void> _restoreProperty(PropertyModel property) async {
    try {
      setState(() => _isLoading = true);

      final doc = await FirebaseFirestore.instance.collection('properties').doc(property.id).get();
      final data = doc.data();
      final previousStatus = data?['previousStatus'] ?? 'pending';

      await FirebaseFirestore.instance.collection('properties').doc(property.id).update({
        'status': previousStatus,
        'updatedAt': DateTime.now().toIso8601String(),
        'previousStatus': null,
      });

      // Notify owner
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': property.ownerId,
        'title': 'Property Restored',
        'message': 'Your property "${property.title}" has been restored by admin.',
        'propertyId': property.id,
        'type': 'property_restored',
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Property "${property.title}" restored'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _handleError('restoring property', e);
    }
  }

  Future<void> _restoreUser(String userId, String userName) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isDeleted': false,
        'deletedAt': null,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User "$userName" restored'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _handleError('restoring user', e);
    }
  }

  Future<void> _restoreProject(String projectId, String projectName) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance.collection('advertised_projects').doc(projectId).update({
        'isDeleted': false,
        'deletedAt': null,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project "$projectName" restored'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _handleError('restoring project', e);
    }
  }

  // ==================== DELETE CONFIRMATIONS ====================
  void _confirmPermanentDeleteProperty(PropertyModel property) {
    _showDeleteConfirmation(
      title: property.title,
      onConfirm: () => _permanentlyDeleteProperty(property),
    );
  }

  void _confirmPermanentDeleteUser(String userId, String userName) {
    _showDeleteConfirmation(
      title: userName,
      onConfirm: () => _permanentlyDeleteUser(userId, userName),
    );
  }

  void _confirmPermanentDeleteProject(String projectId, String projectName) {
    _showDeleteConfirmation(
      title: projectName,
      onConfirm: () => _permanentlyDeleteProject(projectId, projectName),
    );
  }

  void _showDeleteConfirmation({required String title, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Permanent Delete')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This action cannot be undone!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            Text('Permanently delete "$title"?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); onConfirm(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  // ==================== PERMANENT DELETE ACTIONS ====================
  Future<void> _permanentlyDeleteProperty(PropertyModel property) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance.collection('properties').doc(property.id).delete();

      // Delete bookmarks
      final bookmarks = await FirebaseFirestore.instance.collection('bookmarks').where('propertyId', isEqualTo: property.id).get();
      for (final doc in bookmarks.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Property "${property.title}" permanently deleted'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _handleError('deleting property', e);
    }
  }

  Future<void> _permanentlyDeleteUser(String userId, String userName) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User "$userName" permanently deleted'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _handleError('deleting user', e);
    }
  }

  Future<void> _permanentlyDeleteProject(String projectId, String projectName) async {
    try {
      setState(() => _isLoading = true);

      await FirebaseFirestore.instance.collection('advertised_projects').doc(projectId).delete();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Project "$projectName" permanently deleted'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _handleError('deleting project', e);
    }
  }

  // ==================== EMPTY ALL TRASH ====================
  void _confirmEmptyAllTrash() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('Empty All Trash')]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete ALL items in trash!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            SizedBox(height: 12),
            Text('This includes all deleted properties, users, and projects.'),
            SizedBox(height: 8),
            Text('This action cannot be undone.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _emptyAllTrash(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Empty All Trash'),
          ),
        ],
      ),
    );
  }

  Future<void> _emptyAllTrash() async {
    try {
      setState(() => _isLoading = true);

      int totalDeleted = 0;

      // Delete properties
      final properties = await FirebaseFirestore.instance.collection('properties').where('status', isEqualTo: PropertyStatus.removed.name).get();
      for (final doc in properties.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Delete users
      final users = await FirebaseFirestore.instance.collection('users').where('isDeleted', isEqualTo: true).get();
      for (final doc in users.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      // Delete projects
      final projects = await FirebaseFirestore.instance.collection('advertised_projects').where('isDeleted', isEqualTo: true).get();
      for (final doc in projects.docs) {
        await doc.reference.delete();
        totalDeleted++;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$totalDeleted items permanently deleted'), backgroundColor: Colors.green));
      }
    } catch (e) {
      _handleError('emptying trash', e);
    }
  }

  void _handleError(String action, Object e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error $action: $e'), backgroundColor: Colors.red));
    }
  }
}
