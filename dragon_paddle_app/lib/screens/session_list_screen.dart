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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Sessions')),
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
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () async {
                              final csv = await widget.sessionService
                                  .exportSessionCsv(File(f.path));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Exported: $csv')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
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
                            },
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
