import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Service for exporting and importing session data
/// Uses base64 encoded compressed JSON for sharing via deep links
class SessionShareService {
  /// Get the imported sessions directory
  static Future<Directory> _getImportedDirectory() async {
    Directory baseDir;
    if (Platform.isAndroid) {
      // Try to use Documents folder on Android
      baseDir = Directory('/storage/emulated/0/Documents');
      if (!await baseDir.exists()) {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }
    
    final flowTrackDir = Directory('${baseDir.path}/FlowTrack');
    if (!await flowTrackDir.exists()) {
      await flowTrackDir.create(recursive: true);
    }
    
    final importedDir = Directory('${flowTrackDir.path}/imported');
    if (!await importedDir.exists()) {
      await importedDir.create(recursive: true);
    }
    return importedDir;
  }

  /// Export a session data map to a shareable deep link format
  /// Returns a tuple of (deepLink, jsonFile) for flexibility
  static Future<({String deepLink, File jsonFile})> exportSession(
    Map<String, dynamic> sessionData,
  ) async {
    // Convert session data to JSON string
    final jsonString = json.encode(sessionData);

    // Save as .flowtrack file for direct file sharing option
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final jsonFile = File('${dir.path}/session_export_$timestamp.flowtrack');
    await jsonFile.writeAsString(jsonString);

    // For deep link: compress and encode
    // Using gzip compression to reduce size
    final jsonBytes = utf8.encode(jsonString);
    final compressed = gzip.encode(jsonBytes);
    final base64Data = base64Url.encode(compressed);

    // Create deep link with the compressed data
    // Format: flowtrack://session?data=<base64_compressed_json>
    final deepLink = 'flowtrack://session?data=$base64Data';

    if (kDebugMode) {
      print(
        'Session exported: ${jsonString.length} bytes → ${compressed.length} bytes compressed',
      );
      print('Deep link length: ${deepLink.length} characters');
    }

    return (deepLink: deepLink, jsonFile: jsonFile);
  }

  /// Import session data from a deep link
  /// Returns the decoded session data map
  static Map<String, dynamic>? importFromDeepLink(String deepLink) {
    try {
      // Parse the deep link
      final uri = Uri.parse(deepLink);

      // Check if it's a valid flowtrack session link
      if (uri.scheme != 'flowtrack' || uri.host != 'session') {
        if (kDebugMode) {
          print('Invalid deep link format: $deepLink');
        }
        return null;
      }

      // Extract the data parameter
      final base64Data = uri.queryParameters['data'];
      if (base64Data == null || base64Data.isEmpty) {
        if (kDebugMode) {
          print('No data parameter found in deep link');
        }
        return null;
      }

      // Decode and decompress
      final compressed = base64Url.decode(base64Data);
      final jsonBytes = gzip.decode(compressed);
      final jsonString = utf8.decode(jsonBytes);

      // Parse JSON
      final sessionData = json.decode(jsonString) as Map<String, dynamic>;

      if (kDebugMode) {
        print('Session imported successfully: ${sessionData['name']}');
      }

      return sessionData;
    } catch (e) {
      if (kDebugMode) {
        print('Error importing session from deep link: $e');
      }
      return null;
    }
  }

  /// Import session data from a JSON file
  static Future<Map<String, dynamic>?> importFromFile(File file) async {
    try {
      final jsonString = await file.readAsString();
      return importFromJsonString(jsonString);
    } catch (e) {
      if (kDebugMode) {
        print('Error importing session from file: $e');
      }
      return null;
    }
  }

  /// Import session data from a JSON string
  static Future<Map<String, dynamic>?> importFromJsonString(String jsonString) async {
    try {
      final sessionData = json.decode(jsonString) as Map<String, dynamic>;

      if (kDebugMode) {
        print('Session imported: ${sessionData['name']}');
      }

      return sessionData;
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing session JSON: $e');
      }
      return null;
    }
  }

  /// Share session using the platform share sheet
  /// Includes both the deep link and the JSON file attachment
  static Future<void> shareSession({
    required String deepLink,
    required File jsonFile,
    String? sessionName,
  }) async {
    final name = sessionName ?? 'Session';
    final message =
        'Check out my $name! Open this link in Flow Track app:\n\n$deepLink\n\n'
        'Or download the attached JSON file and import it manually.';

    try {
      // Share with both text (deep link) and file attachment
      await Share.shareXFiles(
        [XFile(jsonFile.path)],
        text: message,
        subject: 'Flow Track session: $name',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing session: $e');
      }
      // Fallback to text-only sharing
      await Share.share(message, subject: 'Flow Track session: $name');
    }
  }

  /// Save imported session to a file in the app's imported sessions directory
  static Future<File> saveImportedSession(
    Map<String, dynamic> sessionData,
  ) async {
    // Save to FlowTrack/imported/ folder
    final dir = await _getImportedDirectory();

    // Generate filename from session data
    final sessionName = sessionData['name'] ?? 'imported_session';
    // Sanitize filename
    final safeName = sessionName.replaceAll(RegExp(r'[^\w\s-]'), '_');

    final filename = '$safeName.flowtrack';

    final file = File('${dir.path}/$filename');
    await file.writeAsString(json.encode(sessionData));

    if (kDebugMode) {
      print('Imported session saved to: ${file.path}');
    }

    return file;
  }
}
