import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/scheduled_notification_service.dart';

class ScheduledNotificationsScreen extends StatefulWidget {
  final bool embedded;
  const ScheduledNotificationsScreen({super.key, this.embedded = false});

  @override
  State<ScheduledNotificationsScreen> createState() => _ScheduledNotificationsScreenState();
}

class _ScheduledNotificationsScreenState extends State<ScheduledNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final ScheduledNotificationService _service = ScheduledNotificationService();
  late TabController _tabController;
  String? _adminName;
  Map<String, int> _stats = {};

  // Modern dark theme colors
  static const Color _primaryDark = Color(0xFF1a1a2e);
  static const Color _secondaryDark = Color(0xFF16213e);
  static const Color _accentPurple = Color(0xFF7c3aed);
  static const Color _accentBlue = Color(0xFF3b82f6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminName();
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && mounted) {
        setState(() {
          _adminName = userDoc.data()?['name'] ?? 'Admin';
        });
      }
    }
  }

  Future<void> _loadStats() async {
    final stats = await _service.getStatistics();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: widget.embedded ? null : const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _secondaryDark, Color(0xFF0f3460)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildTabBar(),
            Expanded(child: _buildTabView()),
          ],
        ),
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(body: content);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (!widget.embedded)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentPurple, _accentBlue],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _accentPurple.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.schedule_send, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scheduled Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Schedule notifications for later',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Pending', _stats['pending'] ?? 0, Colors.orange, Icons.pending),
          const SizedBox(width: 12),
          _buildStatCard('Sent', _stats['sent'] ?? 0, Colors.green, Icons.check_circle),
          const SizedBox(width: 12),
          _buildStatCard('Cancelled', _stats['cancelled'] ?? 0, Colors.grey, Icons.cancel),
          const SizedBox(width: 12),
          _buildStatCard('Failed', _stats['failed'] ?? 0, Colors.red, Icons.error),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _accentPurple,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Pending'),
          Tab(text: 'Sent'),
          Tab(text: 'Cancelled'),
          Tab(text: 'All'),
        ],
      ),
    );
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildNotificationList('pending'),
        _buildNotificationList('sent'),
        _buildNotificationList('cancelled'),
        _buildNotificationList(null),
      ],
    );
  }

  Widget _buildNotificationList(String? statusFilter) {
    return StreamBuilder<List<ScheduledNotification>>(
      stream: _service.getScheduledNotificationsStream(statusFilter: statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _accentPurple),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule,
                  size: 64,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${statusFilter ?? ''} notifications',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                if (statusFilter == 'pending' || statusFilter == null)
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Schedule One'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final notification = snapshot.data![index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(ScheduledNotification notification) {
    Color statusColor;
    IconData statusIcon;
    
    switch (notification.status) {
      case 'pending':
        statusColor = notification.isOverdue ? Colors.red : Colors.orange;
        statusIcon = notification.isOverdue ? Icons.warning : Icons.pending;
        break;
      case 'sent':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.topicDisplayName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(notification.status, notification.isOverdue),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.body,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.white.withOpacity(0.5)),
                    const SizedBox(width: 4),
                    Text(
                      'Scheduled: ${_formatDateTime(notification.scheduledTime)}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    if (notification.createdByName != null) ...[
                      Icon(Icons.person, size: 14, color: Colors.white.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        notification.createdByName!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                if (notification.sentAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.send, size: 14, color: Colors.green.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Sent: ${_formatDateTime(notification.sentAt!)}',
                        style: TextStyle(
                          color: Colors.green.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                if (notification.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notification.errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Actions
          if (notification.status == 'pending')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditDialog(notification),
                    icon: Icon(Icons.edit, size: 16, color: _accentBlue),
                    label: Text('Edit', style: TextStyle(color: _accentBlue)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _cancelNotification(notification),
                    icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                    label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          if (notification.status == 'cancelled' || notification.status == 'failed')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteNotification(notification),
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isOverdue) {
    String label;
    Color color;
    
    if (status == 'pending' && isOverdue) {
      label = 'OVERDUE';
      color = Colors.red;
    } else {
      label = status.toUpperCase();
      switch (status) {
        case 'pending':
          color = Colors.orange;
          break;
        case 'sent':
          color = Colors.green;
          break;
        case 'cancelled':
          color = Colors.grey;
          break;
        case 'failed':
          color = Colors.red;
          break;
        default:
          color = Colors.grey;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _showCreateDialog() {
    _showNotificationDialog(null);
  }

  void _showEditDialog(ScheduledNotification notification) {
    _showNotificationDialog(notification);
  }

  void _showNotificationDialog(ScheduledNotification? existing) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final bodyController = TextEditingController(text: existing?.body ?? '');
    String selectedTopic = existing?.topic ?? 'all_users';
    DateTime selectedTime = existing?.scheduledTime ?? DateTime.now().add(const Duration(hours: 1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _secondaryDark],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accentPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          existing == null ? Icons.schedule_send : Icons.edit,
                          color: _accentPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        existing == null ? 'Schedule Notification' : 'Edit Notification',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  _buildDialogLabel('Title'),
                  const SizedBox(height: 8),
                  _buildDialogTextField(titleController, 'Notification title'),
                  const SizedBox(height: 16),
                  
                  // Body
                  _buildDialogLabel('Message'),
                  const SizedBox(height: 8),
                  _buildDialogTextField(bodyController, 'Notification message', maxLines: 3),
                  const SizedBox(height: 16),
                  
                  // Topic
                  _buildDialogLabel('Target Audience'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTopic,
                        isExpanded: true,
                        dropdownColor: _secondaryDark,
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'all_users', child: Text('All Users')),
                          DropdownMenuItem(value: 'agents', child: Text('Agents Only')),
                          DropdownMenuItem(value: 'customers', child: Text('Customers Only')),
                        ],
                        onChanged: (value) {
                          setDialogState(() => selectedTopic = value!);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Schedule Time
                  _buildDialogLabel('Schedule Time'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: _accentPurple,
                                surface: _secondaryDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedTime),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: _accentPurple,
                                  surface: _secondaryDark,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        
                        if (time != null) {
                          setDialogState(() {
                            selectedTime = DateTime(
                              date.year, date.month, date.day,
                              time.hour, time.minute,
                            );
                          });
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: _accentBlue, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _formatDateTime(selectedTime),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          Icon(Icons.edit, color: Colors.white.withOpacity(0.5), size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white.withOpacity(0.8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (titleController.text.trim().isEmpty ||
                                bodyController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill in all fields')),
                              );
                              return;
                            }
                            
                            Navigator.pop(context);
                            
                            if (existing == null) {
                              await _createNotification(
                                titleController.text.trim(),
                                bodyController.text.trim(),
                                selectedTopic,
                                selectedTime,
                              );
                            } else {
                              await _updateNotification(
                                existing.id!,
                                titleController.text.trim(),
                                bodyController.text.trim(),
                                selectedTopic,
                                selectedTime,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            existing == null ? 'Schedule' : 'Update',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accentPurple),
        ),
      ),
    );
  }

  Future<void> _createNotification(
    String title,
    String body,
    String topic,
    DateTime scheduledTime,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final id = await _service.createScheduledNotification(
      title: title,
      body: body,
      topic: topic,
      scheduledTime: scheduledTime,
      adminId: user.uid,
      adminName: _adminName,
    );

    if (id != null && mounted) {
      _showSnackBar('Notification scheduled successfully', Colors.green);
      _loadStats();
    } else {
      _showSnackBar('Failed to schedule notification', Colors.red);
    }
  }

  Future<void> _updateNotification(
    String id,
    String title,
    String body,
    String topic,
    DateTime scheduledTime,
  ) async {
    final success = await _service.updateNotification(
      id: id,
      title: title,
      body: body,
      topic: topic,
      scheduledTime: scheduledTime,
    );

    if (success && mounted) {
      _showSnackBar('Notification updated', Colors.green);
    } else {
      _showSnackBar('Failed to update notification', Colors.red);
    }
  }

  Future<void> _cancelNotification(ScheduledNotification notification) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _secondaryDark,
        title: const Text('Cancel Notification', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to cancel "${notification.title}"?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel It', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.cancelNotification(notification.id!);
      if (success && mounted) {
        _showSnackBar('Notification cancelled', Colors.orange);
        _loadStats();
      }
    }
  }

  Future<void> _deleteNotification(ScheduledNotification notification) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _secondaryDark,
        title: const Text('Delete Notification', style: TextStyle(color: Colors.white)),
        content: Text(
          'Permanently delete "${notification.title}"?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.deleteNotification(notification.id!);
      if (success && mounted) {
        _showSnackBar('Notification deleted', Colors.grey);
        _loadStats();
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
