import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _boatController = TextEditingController();
  
  bool _autoSaveSessions = true;
  bool _keepScreenAwake = false;
  bool _showAdvancedMetrics = true;
  bool _vibrateFeedback = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final name = await _settingsService.getPaddlerName();
    final boat = await _settingsService.getBoatName();
    final autoSave = await _settingsService.getAutoSaveSessions();
    final keepAwake = await _settingsService.getKeepScreenAwake();
    final advanced = await _settingsService.getShowAdvancedMetrics();
    final vibrate = await _settingsService.getVibrateFeedback();

    setState(() {
      _nameController.text = name;
      _boatController.text = boat;
      _autoSaveSessions = autoSave;
      _keepScreenAwake = keepAwake;
      _showAdvancedMetrics = advanced;
      _vibrateFeedback = vibrate;
    });
  }

  Future<void> _saveSettings() async {
    await _settingsService.setPaddlerName(_nameController.text.trim());
    await _settingsService.setBoatName(_boatController.text.trim());
    await _settingsService.setAutoSaveSessions(_autoSaveSessions);
    await _settingsService.setKeepScreenAwake(_keepScreenAwake);
    await _settingsService.setShowAdvancedMetrics(_showAdvancedMetrics);
    await _settingsService.setVibrateFeedback(_vibrateFeedback);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _boatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Paddler name',
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      helperText: 'This will be used for all your recordings',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _boatController,
                    decoration: const InputDecoration(
                      labelText: 'Boat/Team name',
                      hintText: 'Enter boat or team name',
                      prefixIcon: Icon(Icons.rowing),
                      border: OutlineInputBorder(),
                      helperText: 'Optional team or boat identifier',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recording Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recording',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Auto-save sessions'),
                    subtitle: const Text(
                      'Automatically save recordings when stopped',
                    ),
                    value: _autoSaveSessions,
                    onChanged: (value) {
                      setState(() {
                        _autoSaveSessions = value;
                      });
                    },
                    secondary: const Icon(Icons.save),
                  ),
                  SwitchListTile(
                    title: const Text('Haptic feedback'),
                    subtitle: const Text('Vibrate on stroke detection'),
                    value: _vibrateFeedback,
                    onChanged: (value) {
                      setState(() {
                        _vibrateFeedback = value;
                      });
                    },
                    secondary: const Icon(Icons.vibration),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Display Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Display',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Keep screen awake during use'),
                    subtitle: const Text(
                      'Prevent screen from turning off while connected',
                    ),
                    value: _keepScreenAwake,
                    onChanged: (value) {
                      setState(() {
                        _keepScreenAwake = value;
                      });
                    },
                    secondary: const Icon(Icons.brightness_high),
                  ),
                  SwitchListTile(
                    title: const Text('Show advanced metrics'),
                    subtitle: const Text(
                      'Display temperature, trajectory, and other advanced data',
                    ),
                    value: _showAdvancedMetrics,
                    onChanged: (value) {
                      setState(() {
                        _showAdvancedMetrics = value;
                      });
                    },
                    secondary: const Icon(Icons.analytics),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
