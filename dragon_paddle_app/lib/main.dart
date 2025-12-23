import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'screens/home_screen.dart';
import 'screens/session_review_screen.dart';
import 'services/session_share_service.dart';
import 'services/session_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastHandledUri; // Track the last handled URI to prevent duplicates

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links when app is already open
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );

    // Handle initial link when app is opened from terminated state
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        // Handle the deep link, then clear it
        await _handleDeepLink(uri);
      }
    } catch (err) {
      debugPrint('Failed to get initial link: $err');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Handling deep link: $uri');

    // Prevent handling the same URI multiple times
    if (_lastHandledUri == uri.toString()) {
      debugPrint('URI already handled, skipping: $uri');
      return;
    }
    _lastHandledUri = uri.toString();

    // Check if it's a .flowtrack file being opened (content:// or file://)
    if ((uri.scheme == 'file' || uri.scheme == 'content') && 
        uri.path.toLowerCase().endsWith('.flowtrack')) {
      try {
        Map<String, dynamic>? sessionData;
        
        if (uri.scheme == 'content') {
          // Handle content:// URIs (from file providers like Messenger)
          // We need to use platform channel to read the content
          try {
            const platform = MethodChannel('com.flowtrack.app/files');
            final String? jsonString = await platform.invokeMethod('readContentUri', uri.toString());
            
            if (jsonString != null && jsonString.isNotEmpty) {
              sessionData = await SessionShareService.importFromJsonString(jsonString);
            }
          } catch (e) {
            debugPrint('Platform channel error: $e');
            // Fallback: try to read as file path
            throw Exception('Cannot read content URI. Please save the file to Downloads and try again.');
          }
        } else {
          // Handle file:// URIs
          final file = File(uri.path);
          sessionData = await SessionShareService.importFromFile(file);
        }

        if (sessionData == null) {
          _showErrorDialog('Invalid session file');
          return;
        }

        // Save the imported session to a file in app directory
        final savedFile = await SessionShareService.saveImportedSession(sessionData);

        // Show success message
        _showSuccessDialog('Session imported successfully!', () {
          // Navigate to session review screen
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => SessionReviewScreen(
                file: savedFile,
                sessionService: SessionService(),
              ),
            ),
          );
        });
      } catch (e) {
        debugPrint('Error handling JSON file import: $e');
        _showErrorDialog('Failed to import session file: $e');
      }
      return;
    }

    // Check if it's a session import link
    if (uri.scheme == 'flowtrack' && uri.host == 'session') {
      try {
        // Import session data from the deep link
        final sessionData = SessionShareService.importFromDeepLink(
          uri.toString(),
        );

        if (sessionData == null) {
          _showErrorDialog('Invalid session link');
          return;
        }

        // Save the imported session to a file
        final file = await SessionShareService.saveImportedSession(sessionData);

        // Show success message
        _showSuccessDialog('Session imported successfully!', () {
          // Navigate to session review screen
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => SessionReviewScreen(
                file: file,
                sessionService: SessionService(),
              ),
            ),
          );
        });
      } catch (e) {
        debugPrint('Error handling session import: $e');
        _showErrorDialog('Failed to import session: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessDialog(String message, VoidCallback onView) {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onView();
              },
              child: const Text('View Session'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Flow Track',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
