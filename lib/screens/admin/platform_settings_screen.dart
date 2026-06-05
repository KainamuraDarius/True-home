import 'package:flutter/material.dart';
import '../../services/platform_config_service.dart';

class PlatformSettingsScreen extends StatefulWidget {
  final bool embedded;
  const PlatformSettingsScreen({super.key, this.embedded = false});

  @override
  State<PlatformSettingsScreen> createState() => _PlatformSettingsScreenState();
}

class _PlatformSettingsScreenState extends State<PlatformSettingsScreen> {
  final PlatformConfigService _service = PlatformConfigService();
  bool _loading = true;
  bool _forCustomers = false;
  bool _forAgents = false;

  static const Color _primaryDark = Color(0xFF1a1a2e);
  static const Color _secondaryDark = Color(0xFF16213e);
  static const Color _accentBlue = Color(0xFF3b82f6);
  static const Color _accentCyan = Color(0xFF06b6d4);

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final cfg = await _service.getConfig();
    if (!mounted) return;
    setState(() {
      _forCustomers = cfg.requireEmailVerificationForCustomers;
      _forAgents = cfg.requireEmailVerificationForAgents;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final ok = await _service.updateConfig(
      requireEmailVerificationForCustomers: _forCustomers,
      requireEmailVerificationForAgents: _forAgents,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(ok ? 'Settings saved successfully' : 'Failed to save settings'),
          ],
        ),
        backgroundColor: ok ? const Color(0xFF10b981) : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0f172a),
                        ),
                      ),
                    ),
                    Switch(
                      value: value,
                      onChanged: onChanged,
                      activeColor: Colors.white,
                      activeTrackColor: accentColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey.shade300,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
        child: Container(
          decoration: widget.embedded
              ? null
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_primaryDark, _secondaryDark],
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryDark, _secondaryDark],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accentCyan, _accentBlue],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Platform Settings',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Control when email verification is required for property submissions.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.white.withOpacity(0.72),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _StatusChip(
                                  label: _forCustomers ? 'Customers Verified' : 'Customers Open',
                                  color: _forCustomers ? const Color(0xFF10b981) : _accentCyan,
                                ),
                                _StatusChip(
                                  label: _forAgents ? 'Agents Verified' : 'Agents Open',
                                  color: _forAgents ? const Color(0xFF10b981) : _accentBlue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_loading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: widget.embedded ? _accentBlue : Colors.white,
                      ),
                    ),
                  )
                else ...[
                  _buildSettingCard(
                    icon: Icons.people_alt_rounded,
                    accentColor: _accentBlue,
                    title: 'Require verification for Customers',
                    description: 'When enabled, customers must verify their email before they can submit a property listing.',
                    value: _forCustomers,
                    onChanged: (v) => setState(() => _forCustomers = v),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingCard(
                    icon: Icons.business_center_rounded,
                    accentColor: _accentCyan,
                    title: 'Require verification for Agents',
                    description: 'When enabled, property agents must verify their email before they can submit a property listing.',
                    value: _forAgents,
                    onChanged: (v) => setState(() => _forAgents = v),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: widget.embedded ? Colors.white : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: widget.embedded
                            ? Colors.grey.shade200
                            : Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: widget.embedded ? _accentBlue : Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Default behavior keeps verification off, so users can still submit properties unless you explicitly enable it here.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: widget.embedded ? Colors.grey.shade700 : Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        'Save Settings',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      body: SafeArea(child: body),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
