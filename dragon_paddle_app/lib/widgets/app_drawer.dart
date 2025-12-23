import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/session_list_screen.dart';
import '../screens/settings_screen.dart';
import '../services/session_service.dart';

class AppDrawer extends StatelessWidget {
  final String appVersion;
  final bool isConnected;
  final VoidCallback? onDisconnect;
  final VoidCallback? onScan;
  final VoidCallback? onResetStats;
  final SessionService? sessionService;

  const AppDrawer({
    super.key,
    required this.appVersion,
    required this.isConnected,
    this.onDisconnect,
    this.onScan,
    this.onResetStats,
    this.sessionService,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade700),
              accountName: const Text(
                "Flow Track",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: const Text("Dragon paddle tracker"),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Saved sessions'),
              onTap: () {
                Navigator.of(context).pop();
                // Check if we're already on the session list screen
                final currentRoute = ModalRoute.of(context);
                if (currentRoute?.settings.name != '/sessions') {
                  if (sessionService != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionListScreen(
                          sessionService: sessionService!,
                        ),
                        settings: const RouteSettings(name: '/sessions'),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              title: const Text("Generated reports"),
              leading: const Icon(Icons.insert_drive_file),
              enabled: false,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('GitHub'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () async {
                Navigator.of(context).pop();
                final uri = Uri.parse(
                  'https://github.com/laosteven/flow-track',
                );
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open browser: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            if (isConnected && onResetStats != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset statistics'),
                onTap: () {
                  Navigator.of(context).pop();
                  onResetStats?.call();
                },
              ),
            ListTile(
              leading: Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              ),
              title: Text(isConnected ? 'Disconnect' : 'Scan'),
              enabled: (isConnected && onDisconnect != null) || (!isConnected && onScan != null),
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                if (isConnected) {
                  onDisconnect?.call();
                } else {
                  onScan?.call();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                appVersion.isNotEmpty
                    ? 'App version: $appVersion'
                    : 'App version: loading...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
