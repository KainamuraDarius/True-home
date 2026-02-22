import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  String _selectedTopic = 'all_users';
  String _selectedType = 'announcement';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _topics = [
    {
      'value': 'all_users',
      'label': 'All Users',
      'icon': Icons.people,
      'description': 'Send to everyone (agents + customers)',
    },
    {
      'value': 'agents',
      'label': 'Agents Only',
      'icon': Icons.business_center,
      'description': 'Send to all property agents',
    },
    {
      'value': 'customers',
      'label': 'Customers Only',
      'icon': Icons.person,
      'description': 'Send to all customers',
    },
  ];

  final List<Map<String, String>> _types = [
    {'value': 'announcement', 'label': '📢 Announcement'},
    {'value': 'promotion', 'label': '🎉 Promotion'},
    {'value': 'alert', 'label': '⚠️ Alert'},
    {'value': 'update', 'label': '🔔 Update'},
    {'value': 'reminder', 'label': '⏰ Reminder'},
  ];

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Use different approach for web vs mobile
      if (kIsWeb) {
        // For web, use direct HTTP call to avoid dart2js Int64 issues
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not authenticated');

        final idToken = await user.getIdToken();
        final response = await http.post(
          Uri.parse('https://us-central1-truehome-9a244.cloudfunctions.net/sendTopicNotification'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: json.encode({
            'data': {
              'topic': _selectedTopic,
              'title': _titleController.text.trim(),
              'body': _bodyController.text.trim(),
              'type': _selectedType,
            }
          }),
        );

        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${result['result']['message'] ?? 'Notification sent successfully'}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to send notification: ${response.body}');
        }
      } else {
        // For mobile, use Cloud Functions package
        final callable = FirebaseFunctions.instance.httpsCallable(
          'sendTopicNotification',
        );

        final result = await callable.call({
          'topic': _selectedTopic,
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'type': _selectedType,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result.data['message']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Clear form on success
      if (mounted) {
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _selectedTopic = 'all_users';
          _selectedType = 'announcement';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notification'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Topic Selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Audience',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._topics.map((topic) {
                        final isSelected = _selectedTopic == topic['value'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected
                                ? Theme.of(context).primaryColor.withOpacity(0.1)
                                : null,
                          ),
                          child: RadioListTile<String>(
                            value: topic['value'] as String,
                            groupValue: _selectedTopic,
                            onChanged: (value) {
                              setState(() => _selectedTopic = value!);
                            },
                            title: Row(
                              children: [
                                Icon(
                                  topic['icon'] as IconData,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  topic['label'] as String,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(left: 40, top: 4),
                              child: Text(
                                topic['description'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Notification Type
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notification Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _types.map((type) {
                          return DropdownMenuItem(
                            value: type['value'],
                            child: Text(type['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedType = value!);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Notification Content
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Message Content',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                          hintText: 'Enter notification title',
                        ),
                        maxLength: 50,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.message),
                          hintText: 'Enter notification message',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        maxLength: 200,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a message';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Preview Card
              if (_titleController.text.isNotEmpty || _bodyController.text.isNotEmpty)
                Card(
                  elevation: 2,
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.preview, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Preview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_titleController.text.isNotEmpty)
                                Text(
                                  _titleController.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              if (_bodyController.text.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _bodyController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Send Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendNotification,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isLoading ? 'Sending...' : 'Send Notification',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
