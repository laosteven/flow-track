import 'dart:io';
import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'session_review_screen.dart';

class SessionListScreen extends StatefulWidget {
  final SessionService sessionService;

  const SessionListScreen({super.key, required this.sessionService});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() async {
    final files = await widget.sessionService.listSessions();
    setState(() {
      _files = files;
    });
  }

  Future<void> _showRenameDialog(File file, String currentName) async {
    // Load session to get current paddler name
    final session = await widget.sessionService.loadSession(file);
    final currentPaddlerName = session['paddlerName'] as String? ?? '';

    final nameController = TextEditingController(
      text: currentName.replaceAll('.json', ''),
    );
    final paddlerController = TextEditingController(text: currentPaddlerName);

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
    return Scaffold(
      appBar: AppBar(title: const Text('Saved sessions')),
      body: _files.isEmpty
          ? const Center(child: Text('No sessions found'))
          : ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final f = _files[index];
                final name = f.path.split(Platform.pathSeparator).last;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SessionReviewScreen(
                            file: File(f.path),
                            sessionService: widget.sessionService,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: widget.sessionService.loadSession(
                                File(f.path),
                              ),
                              builder: (context, snapshot) {
                                final paddlerName =
                                    snapshot.data?['paddlerName'] as String? ??
                                    '';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontSize: 16),
                                    ),
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
                                  final csv = await widget.sessionService
                                      .exportSessionCsv(File(f.path));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
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
            ),
    );
  }
}
