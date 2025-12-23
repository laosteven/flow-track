import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/session_service.dart';
import '../widgets/app_drawer.dart';
import 'session_review_screen.dart';

class SessionListScreen extends StatefulWidget {
  final SessionService sessionService;

  const SessionListScreen({super.key, required this.sessionService});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<FileSystemEntity> _recordings = [];
  List<FileSystemEntity> _imported = [];
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  void _loadFiles() async {
    final recordings = await widget.sessionService.listRecordings();
    final imported = await widget.sessionService.listImported();
    setState(() {
      _recordings = recordings;
      _imported = imported;
    });
  }

  Future<void> _showRenameDialog(File file, String currentName) async {
    // Load session to get current paddler name
    final session = await widget.sessionService.loadSession(file);
    final currentPaddlerName = session['paddlerName'] as String? ?? '';

    // Remove extension from name
    String displayName = currentName
        .replaceAll('.json', '')
        .replaceAll('.flowtrack', '');

    final nameController = TextEditingController(text: displayName);
    final paddlerController = TextEditingController(text: currentPaddlerName);

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Session name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paddlerController,
              decoration: const InputDecoration(
                labelText: 'Paddler name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await widget.sessionService.renameSession(
          file,
          nameController.text.trim(),
          paddlerController.text.trim(),
        );
        _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session renamed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error renaming session: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Saved sessions'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.fiber_manual_record), text: 'My recordings'),
              Tab(icon: Icon(Icons.download), text: 'Imported'),
            ],
          ),
        ),
        drawer: AppDrawer(
          appVersion: _appVersion,
          isConnected: false,
          sessionService: widget.sessionService,
        ),
        body: TabBarView(
          children: [
            // My Recordings tab
            _buildSessionList(_recordings, 'No recordings found'),
            // Imported tab
            _buildSessionList(_imported, 'No imported sessions found'),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionList(List<FileSystemEntity> files, String emptyMessage) {
    if (files.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final f = files[index];
        final name = f.path.split(Platform.pathSeparator).last;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SessionReviewScreen(
                    file: File(f.path),
                    sessionService: widget.sessionService,
                  ),
                ),
              );
              // Refresh list when returning from review
              _loadFiles();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: widget.sessionService.loadSession(File(f.path)),
                      builder: (context, snapshot) {
                        final paddlerName =
                            snapshot.data?['paddlerName'] as String? ?? '';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 16)),
                            if (paddlerName.isNotEmpty)
                              Text(
                                paddlerName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          await _showRenameDialog(File(f.path), name);
                          break;
                        case 'export':
                          final messenger = ScaffoldMessenger.of(context);
                          final csv = await widget.sessionService
                              .exportSessionCsv(File(f.path));
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Exported: $csv')),
                            );
                          }
                          break;
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete session?'),
                              content: Text('Delete $name?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await widget.sessionService.deleteSession(
                              File(f.path),
                            );
                            _loadFiles();
                          }
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 12),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 12),
                            Text('Export CSV'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
