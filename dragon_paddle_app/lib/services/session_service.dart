import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/sensor_data.dart';
import 'settings_service.dart';

class SessionService {
  final List<AccelerometerData> _buffer = [];
  final List<Map<String, dynamic>> _strokeEvents = [];
  bool _recording = false;
  DateTime? _startTime;
  StreamSubscription? _strokeSub;
  IOSink? _tempSink;
  File? _tempFile;
  Timer? _metricsTimer;
  final List<Map<String, dynamic>> _metrics = [];

  bool get isRecording => _recording;

  /// Get the FlowTrack base directory
  static Future<Directory> _getFlowTrackDirectory() async {
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
    return flowTrackDir;
  }

  /// Get the recordings directory
  static Future<Directory> _getRecordingsDirectory() async {
    final flowTrackDir = await _getFlowTrackDirectory();
    final recordingsDir = Directory('${flowTrackDir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Get the imported sessions directory
  static Future<Directory> _getImportedDirectory() async {
    final flowTrackDir = await _getFlowTrackDirectory();
    final importedDir = Directory('${flowTrackDir.path}/imported');
    if (!await importedDir.exists()) {
      await importedDir.create(recursive: true);
    }
    return importedDir;
  }

  Future<void> start() async {
    _buffer.clear();
    _strokeEvents.clear();
    _recording = true;
    _startTime = DateTime.now();
    // prepare temp file for streaming samples as NDJSON
    final dir = await getApplicationDocumentsDirectory();
    _tempFile = File(
      '${dir.path}/.recording_tmp_${_startTime!.millisecondsSinceEpoch}.ndjson',
    );
    _tempSink = _tempFile!.openWrite(
      mode: FileMode.writeOnlyAppend,
      encoding: utf8,
    );
  }

  /// Start recording and subscribe to a [StrokeAnalyzer] to capture stroke timestamps
  Future<void> startWithAnalyzer(dynamic analyzer) async {
    await start();
    try {
      // reset analyzer so stats start fresh for this recording
      try {
        analyzer.reset();
      } catch (_) {}
      _strokeSub = analyzer.onStroke.listen((event) {
        // event expected: { 'timestamp': ISOString, 'power': double }
        _strokeEvents.add(event);
      });
      // start metrics sampling every 1s
      _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        try {
          final now = DateTime.now().toIso8601String();
          final spm = analyzer.getStrokeRate();
          final consistency = analyzer.getConsistency();
          final avgPower = analyzer.getAveragePower();
          final distance = analyzer.getDistance();
          final speed = analyzer.getSpeed();
          final split500m = analyzer.getSplit500m();
          _metrics.add({
            't': now,
            'spm': spm,
            'consistency': consistency,
            'avgPower': avgPower,
            'distance': distance,
            'speed': speed,
            'split500m': split500m,
          });
        } catch (_) {}
      });
    } catch (_) {
      _strokeSub = null;
    }
  }

  void stop() {
    _recording = false;
    _strokeSub?.cancel();
    _strokeSub = null;
    // close temp sink
    _tempSink?.close();
    _tempSink = null;
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }

  void addSample(AccelerometerData sample) {
    if (!_recording) return;
    // write to in-memory buffer (for short sessions) and stream to temp file for long sessions
    _buffer.add(sample);
    try {
      final line = json.encode({
        't': sample.timestamp.toIso8601String(),
        'x': sample.x,
        'y': sample.y,
        'z': sample.z,
      });
      _tempSink?.writeln(line);
    } catch (_) {}
  }

  Future<String> saveSession({String? name, String? paddlerName}) async {
    final timestamp = _startTime ?? DateTime.now();
    final formatted =
        '${timestamp.year.toString().padLeft(4, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}-${timestamp.second.toString().padLeft(2, '0')}';
    final sessionName = name ?? formatted;

    // Get default paddler name from settings if not provided
    String finalPaddlerName = paddlerName ?? '';
    if (finalPaddlerName.isEmpty) {
      final settingsService = SettingsService();
      finalPaddlerName = await settingsService.getPaddlerName();
    }

    // If a temp file exists, prefer streaming source to build samples without holding everything in memory
    List<Map<String, dynamic>> jsonSamples = [];
    if (_tempFile != null && await _tempFile!.exists()) {
      // read NDJSON lines
      final lines = await _tempFile!.readAsLines();
      for (final l in lines) {
        if (l.trim().isEmpty) continue;
        try {
          final m = json.decode(l) as Map<String, dynamic>;
          jsonSamples.add(m);
        } catch (_) {}
      }
      // cleanup temp file
      try {
        await _tempFile!.delete();
      } catch (_) {}
      _tempFile = null;
    } else {
      jsonSamples = _buffer
          .map(
            (s) => {
              't': s.timestamp.toIso8601String(),
              'x': s.x,
              'y': s.y,
              'z': s.z,
            },
          )
          .toList();
    }

    final session = {
      'name': sessionName,
      'paddlerName': finalPaddlerName,
      'startedAt': timestamp.toIso8601String(),
      'samples': jsonSamples,
      'strokes': _strokeEvents,
      'metrics': _metrics,
    };

    // Save to FlowTrack/recordings/ folder
    final dir = await _getRecordingsDirectory();
    String filenameBase = sessionName.replaceAll(' ', '_');
    String filePath = '${dir.path}/$filenameBase.flowtrack';
    // avoid collisions by appending a counter
    int counter = 1;
    while (await File(filePath).exists()) {
      filePath = '${dir.path}/${filenameBase}_$counter.flowtrack';
      counter++;
    }
    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(session),
    );
    return file.path;
  }

  /// List user's own recordings
  Future<List<FileSystemEntity>> listRecordings() async {
    final dir = await _getRecordingsDirectory();
    
    final files = dir
        .listSync()
        .where((f) => f.path.endsWith('.json') || f.path.endsWith('.flowtrack'))
        .toList();
    
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  /// List imported sessions
  Future<List<FileSystemEntity>> listImported() async {
    final dir = await _getImportedDirectory();
    
    final files = dir
        .listSync()
        .where((f) => f.path.endsWith('.json') || f.path.endsWith('.flowtrack'))
        .toList();
    
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  /// List all sessions (recordings + imported) for backward compatibility
  Future<List<FileSystemEntity>> listSessions() async {
    final recordings = await listRecordings();
    final imported = await listImported();
    
    final allFiles = [...recordings, ...imported];
    
    // Also check old locations for backward compatibility
    try {
      Directory? oldDir;
      if (Platform.isAndroid) {
        oldDir = Directory('/storage/emulated/0/Download');
        if (!await oldDir.exists()) {
          oldDir = null;
        }
      }
      
      if (oldDir != null) {
        final oldFiles = oldDir
            .listSync()
            .where((f) => f.path.endsWith('.json') || f.path.endsWith('.flowtrack'))
            .toList();
        allFiles.addAll(oldFiles);
        
        // Check old sessions subdirectory
        final sessionsDir = Directory('${oldDir.path}/sessions');
        if (await sessionsDir.exists()) {
          final sessionFiles = sessionsDir
              .listSync()
              .where((f) => f.path.endsWith('.json') || f.path.endsWith('.flowtrack'))
              .toList();
          allFiles.addAll(sessionFiles);
        }
      }
    } catch (_) {}
    
    allFiles.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return allFiles;
  }

  Future<Map<String, dynamic>> loadSession(File file) async {
    final s = await file.readAsString();
    return json.decode(s) as Map<String, dynamic>;
  }

  Future<String> exportSessionCsv(File file) async {
    final map = await loadSession(file);
    final samples = map['samples'] as List<dynamic>;
    final buffer = StringBuffer();
    buffer.writeln('t,x,y,z');
    for (final s in samples) {
      buffer.writeln('${s['t']},${s['x']},${s['y']},${s['z']}');
    }

    // Save CSV to same directory as session file (already in Downloads on Android)
    String csvPath = file.path.replaceAll('.json', '.csv');
    csvPath = csvPath.replaceAll('.flowtrack', '.csv');
    final out = File(csvPath);
    await out.writeAsString(buffer.toString());
    return out.path;
  }

  Future<void> deleteSession(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> renameSession(
    File file,
    String newName,
    String paddlerName,
  ) async {
    // Load existing session
    final map = await loadSession(file);

    // Update name and paddler name
    map['name'] = newName;
    map['paddlerName'] = paddlerName;

    // Save to new file
    final dir = file.parent;
    // Determine the extension from the original file
    final extension = file.path.endsWith('.flowtrack') ? '.flowtrack' : '.json';
    final newFilename = '${newName.replaceAll(' ', '_')}$extension';
    final newPath = '${dir.path}/$newFilename';

    // Handle name collisions
    String finalPath = newPath;
    int counter = 1;
    while (await File(finalPath).exists() && finalPath != file.path) {
      finalPath = '${dir.path}/${newName.replaceAll(' ', '_')}_$counter$extension';
      counter++;
    }

    final newFile = File(finalPath);
    await newFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(map),
    );

    // Delete old file if name changed
    if (newFile.path != file.path) {
      await file.delete();
    }
  }

  Future<void> updatePaddlerName(File file, String paddlerName) async {
    // Load existing session
    final map = await loadSession(file);

    // Update paddler name only
    map['paddlerName'] = paddlerName;

    // Save back to the same file
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
  }
}
