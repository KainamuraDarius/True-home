import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';
import '../property/property_details_screen.dart';
import '../../models/property_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await _markAllAsRead();
              } else if (value == 'clear_all') {
                await _clearAll();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Text('Mark all as read'),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear all'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getUserNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final title = data['title'] ?? '';
              final message = data['message'] ?? '';
              final type = data['type'] ?? 'general';
              final propertyId = data['propertyId'];
              final createdAt = data['createdAt'] as String?;

              return Dismissible(
                key: Key(notification.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  _notificationService.deleteNotification(notification.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification deleted')),
                  );
                },
                child: Container(
                  color: isRead ? null : Colors.blue.withOpacity(0.05),
                  child: ListTile(
                    leading: _getNotificationIcon(type, isRead),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(message),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(DateTime.parse(createdAt)),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () async {
                      if (!isRead) {
                        await _notificationService.markAsRead(notification.id);
                      }

                      if (propertyId != null) {
                        _navigateToProperty(propertyId);
                      }
                    },
                    trailing: !isRead
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getNotificationIcon(String type, bool isRead) {
    IconData iconData;
    Color color;

    switch (type) {
      case 'property_submission':
        iconData = Icons.home_work;
        color = Colors.orange;
        break;
      case 'new_property':
        iconData = Icons.new_releases;
        color = Colors.green;
        break;
      case 'property_status':
      case 'approval':
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case 'rejection':
        iconData = Icons.cancel;
        color = Colors.red;
        break;
      case 'property_removed':
        iconData = Icons.remove_circle;
        color = Colors.red;
        break;
      case 'weekly_digest':
        iconData = Icons.email;
        color = Colors.blue;
        break;
      case 'promotional':
        iconData = Icons.local_offer;
        color = Colors.purple;
        break;
      case 'feedback':
        iconData = Icons.feedback;
        color = Colors.teal;
        break;
      default:
        iconData = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isRead ? color.withOpacity(0.2) : color.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _navigateToProperty(String propertyId) async {
    try {
      final propertyDoc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .get();

      if (!propertyDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Property not found')),
          );
        }
        return;
      }

      final property = PropertyModel.fromJson({
        ...propertyDoc.data() as Map<String, dynamic>,
        'id': propertyDoc.id,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropertyDetailsScreen(property: property),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading property: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        await _notificationService.markAsRead(doc.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notificationService.clearAllNotifications(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications cleared')),
        );
      }
    }
  }
}
