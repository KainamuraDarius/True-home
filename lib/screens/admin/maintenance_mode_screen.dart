import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/maintenance_service.dart';

class MaintenanceModeScreen extends StatefulWidget {
  final bool embedded;
  const MaintenanceModeScreen({super.key, this.embedded = false});

  @override
  State<MaintenanceModeScreen> createState() => _MaintenanceModeScreenState();
}

class _MaintenanceModeScreenState extends State<MaintenanceModeScreen>
    with SingleTickerProviderStateMixin {
  final MaintenanceService _maintenanceService = MaintenanceService();
  final _messageController = TextEditingController();
  
  bool _isLoading = false;
  bool _allowAdmins = true;
  DateTime? _estimatedEndTime;
  MaintenanceStatus? _currentStatus;
  String? _adminName;
  
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // Modern dark theme colors
  static const Color _primaryDark = Color(0xFF1a1a2e);
  static const Color _secondaryDark = Color(0xFF16213e);
  static const Color _accentPurple = Color(0xFF7c3aed);
  static const Color _accentBlue = Color(0xFF3b82f6);

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
    _loadAdminName();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _animationController.dispose();
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

  Future<void> _loadCurrentStatus() async {
    final status = await _maintenanceService.checkMaintenanceStatus();
    if (mounted) {
      setState(() {
        _currentStatus = status;
        if (status.isEnabled) {
          _messageController.text = status.message;
          _estimatedEndTime = status.estimatedEndTime;
          _allowAdmins = status.allowAdmins;
        }
      });
    }
  }

  Future<void> _toggleMaintenanceMode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_currentStatus?.isEnabled == true) {
      // Disable maintenance mode
      final confirm = await _showConfirmDialog(
        title: 'Disable Maintenance Mode',
        message: 'Are you sure you want to disable maintenance mode? Users will be able to access the app again.',
        confirmText: 'Disable',
        isDestructive: false,
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        
        final success = await _maintenanceService.disableMaintenanceMode(
          adminId: user.uid,
          adminName: _adminName ?? 'Admin',
        );

        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            _showSnackBar('Maintenance mode disabled', Icons.check_circle, Colors.green);
            _loadCurrentStatus();
          } else {
            _showSnackBar('Failed to disable maintenance mode', Icons.error, Colors.red);
          }
        }
      }
    } else {
      // Enable maintenance mode
      if (_messageController.text.trim().isEmpty) {
        _showSnackBar('Please enter a maintenance message', Icons.warning, Colors.orange);
        return;
      }

      final confirm = await _showConfirmDialog(
        title: 'Enable Maintenance Mode',
        message: 'This will block all users from accessing the app${_allowAdmins ? " (except admins)" : ""}. Continue?',
        confirmText: 'Enable',
        isDestructive: true,
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        
        final success = await _maintenanceService.enableMaintenanceMode(
          message: _messageController.text.trim(),
          adminId: user.uid,
          adminName: _adminName ?? 'Admin',
          estimatedEndTime: _estimatedEndTime,
          allowAdmins: _allowAdmins,
        );

        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            _showSnackBar('Maintenance mode enabled', Icons.build, Colors.orange);
            _loadCurrentStatus();
          } else {
            _showSnackBar('Failed to enable maintenance mode', Icons.error, Colors.red);
          }
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDestructive ? Colors.orange : Colors.green).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive ? Icons.warning_amber : Icons.check_circle,
                  color: isDestructive ? Colors.orange : Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
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
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDestructive ? Colors.orange : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _selectEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _estimatedEndTime ?? DateTime.now().add(const Duration(hours: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
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

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _estimatedEndTime ?? DateTime.now().add(const Duration(hours: 2)),
        ),
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

      if (time != null && mounted) {
        setState(() {
          _estimatedEndTime = DateTime(
            date.year, date.month, date.day, time.hour, time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _secondaryDark, Color(0xFF0f3460)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 32),
              
              // Current Status Card
              _buildStatusCard(),
              const SizedBox(height: 24),
              
              // Configuration Card
              _buildConfigurationCard(),
              const SizedBox(height: 24),
              
              // Toggle Button
              _buildToggleButton(),
              const SizedBox(height: 24),
              
              // History Card
              _buildHistoryCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      body: content,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accentPurple.withOpacity(0.2), _accentBlue.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentPurple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade800],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.build_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Maintenance Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Control app availability for all users',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isEnabled = _currentStatus?.isEnabled ?? false;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isEnabled
              ? [Colors.orange.withOpacity(0.4), Colors.red.withOpacity(0.3)]
              : [Colors.green.withOpacity(0.4), Colors.teal.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isEnabled ? Colors.orange : Colors.green).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isEnabled ? Colors.orange : Colors.green).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: isEnabled ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (isEnabled ? Colors.orange : Colors.green).withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isEnabled ? Colors.orange : Colors.green).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isEnabled ? Icons.construction_rounded : Icons.check_circle_rounded,
                    color: isEnabled ? Colors.orange : Colors.green,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnabled ? 'MAINTENANCE ACTIVE' : 'SYSTEM ONLINE',
                      style: TextStyle(
                        color: isEnabled ? Colors.orange.shade300 : Colors.green.shade300,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEnabled
                          ? 'Users cannot access the app'
                          : 'App is running normally',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isEnabled && _currentStatus != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Started by', _currentStatus!.startedBy ?? 'Unknown'),
                  if (_currentStatus!.startedAt != null)
                    _buildInfoRow(
                      'Started at',
                      _formatDateTime(_currentStatus!.startedAt!),
                    ),
                  if (_currentStatus!.estimatedEndTime != null)
                    _buildInfoRow(
                      'Est. End',
                      _formatDateTime(_currentStatus!.estimatedEndTime!),
                    ),
                  if (_currentStatus!.timeRemainingFormatted != null)
                    _buildInfoRow(
                      'Time Remaining',
                      _currentStatus!.timeRemainingFormatted!,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.settings_rounded, color: _accentPurple, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Configuration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Message Input
          const Text(
            'Maintenance Message',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _messageController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'We are performing scheduled maintenance...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
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
          ),
          const SizedBox(height: 20),
          
          // Estimated End Time
          Text(
            'Estimated End Time (Optional)',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectEndTime,
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
                  Icon(Icons.schedule, color: _accentBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _estimatedEndTime != null
                          ? _formatDateTime(_estimatedEndTime!)
                          : 'Select date and time',
                      style: TextStyle(
                        color: _estimatedEndTime != null
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                  if (_estimatedEndTime != null)
                    IconButton(
                      icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.5)),
                      onPressed: () => setState(() => _estimatedEndTime = null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Allow Admins Toggle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: _accentPurple, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Allow Admin Access',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Admins can still use the app',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _allowAdmins,
                  onChanged: (value) => setState(() => _allowAdmins = value),
                  activeColor: _accentPurple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    final isEnabled = _currentStatus?.isEnabled ?? false;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isEnabled ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _toggleMaintenanceMode,
          icon: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Icon(isEnabled ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 28),
          label: Text(
            _isLoading
                ? 'Processing...'
                : isEnabled
                    ? 'DISABLE MAINTENANCE MODE'
                    : 'ENABLE MAINTENANCE MODE',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? Colors.green.shade600 : Colors.orange.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: _accentBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Recent Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _maintenanceService.getMaintenanceHistory(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _accentPurple),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No maintenance history yet',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.map((log) {
                  final isEnabled = log['action'] == 'enabled';
                  final timestamp = DateTime.tryParse(log['timestamp'] ?? '');
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isEnabled ? Colors.orange : Colors.green).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isEnabled ? Icons.pause : Icons.play_arrow,
                            color: isEnabled ? Colors.orange : Colors.green,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEnabled ? 'Maintenance Enabled' : 'Maintenance Disabled',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'by ${log['adminName'] ?? 'Unknown'}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (timestamp != null)
                          Text(
                            _formatDateTime(timestamp),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
