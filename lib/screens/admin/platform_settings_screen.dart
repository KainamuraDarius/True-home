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

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final cfg = await _service.getConfig();
    setState(() {
      _forCustomers = cfg.requireEmailVerificationForCustomers;
      _forAgents = cfg.requireEmailVerificationForAgents;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final ok = await _service.updateConfig(
      requireEmailVerificationForCustomers: _forCustomers,
      requireEmailVerificationForAgents: _forAgents,
    );
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Settings saved' : 'Failed to save settings'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading) ...[
            SwitchListTile(
              title: const Text('Require email verification for Customers'),
              value: _forCustomers,
              onChanged: (v) => setState(() => _forCustomers = v),
            ),
            SwitchListTile(
              title: const Text('Require email verification for Agents'),
              value: _forAgents,
              onChanged: (v) => setState(() => _forAgents = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) return SingleChildScrollView(child: content);
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: content)));
  }
}
