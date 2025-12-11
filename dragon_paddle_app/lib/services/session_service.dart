import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/sensor_data.dart';

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

  Future<void> start() async {
    _buffer.clear();
    _strokeEvents.clear();
    _recording = true;
    _startTime = DateTime.now();
    // prepare temp file for streaming samples as NDJSON
    final dir = await getApplicationDocumentsDirectory();
    _tempFile = File('${dir.path}/.recording_tmp_${_startTime!.millisecondsSinceEpoch}.ndjson');
    _tempSink = _tempFile!.openWrite(mode: FileMode.writeOnlyAppend, encoding: utf8);
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
          _metrics.add({'t': now, 'spm': spm, 'consistency': consistency, 'avgPower': avgPower});
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
      final line = json.encode({'t': sample.timestamp.toIso8601String(), 'x': sample.x, 'y': sample.y, 'z': sample.z});
      _tempSink?.writeln(line);
    } catch (_) {}
  }

  Future<String> saveSession({String? name}) async {
    final timestamp = _startTime ?? DateTime.now();
    final formatted = '${timestamp.year.toString().padLeft(4, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}-${timestamp.second.toString().padLeft(2, '0')}';
    final sessionName = name ?? formatted;

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
      jsonSamples = _buffer.map((s) => {
            't': s.timestamp.toIso8601String(),
            'x': s.x,
            'y': s.y,
            'z': s.z,
          }).toList();
    }

    final session = {
      'name': sessionName,
      'startedAt': timestamp.toIso8601String(),
      'samples': jsonSamples,
      'strokes': _strokeEvents,
      'metrics': _metrics,
    };

    final dir = await getApplicationDocumentsDirectory();
    String filenameBase = sessionName.replaceAll(' ', '_');
    String filePath = '${dir.path}/$filenameBase.json';
    // avoid collisions by appending a counter
    int counter = 1;
    while (await File(filePath).exists()) {
      filePath = '${dir.path}/${filenameBase}_$counter.json';
      counter++;
    }
    final file = File(filePath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(session));
    return file.path;
  }

  Future<List<FileSystemEntity>> listSessions() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) => f.path.endsWith('.json')).toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
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

    final out = File(file.path.replaceAll('.json', '.csv'));
    await out.writeAsString(buffer.toString());
    return out.path;
  }

  Future<void> deleteSession(File file) async {
    if (await file.exists()) await file.delete();
  }
}
