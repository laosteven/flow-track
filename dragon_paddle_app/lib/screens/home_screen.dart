import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/ble_service.dart';
import '../services/stroke_analyzer.dart';
import '../services/session_service.dart';
import '../screens/session_list_screen.dart';
import '../models/sensor_data.dart';
import '../widgets/stroke_rate_card.dart';
import '../widgets/consistency_indicator.dart';
import '../widgets/motion_graph.dart';
import '../widgets/stats_card.dart';
import '../widgets/advanced_metrics_card.dart';
import '../widgets/temperature_card.dart';
import '../widgets/ml_quality_card.dart';
import '../widgets/trajectory_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _bleService = BleService();
  final StrokeAnalyzer _strokeAnalyzer = StrokeAnalyzer();
  final SessionService _sessionService = SessionService();

  bool _isScanning = false;
  bool _isConnected = false;
  bool _keepAwake = false;
  bool _showConnectionBanner = false;

  List<DiscoveredDevice> _discoveredDevices = [];

  double _strokeRate = 0.0;
  double _consistency = 100.0;
  int _totalStrokes = 0;
  double _averagePower = 0.0;

  List<AccelerometerData> _recentData = [];
  
  // Advanced metrics
  AdvancedMetrics _advancedMetrics = AdvancedMetrics.empty();
  TemperatureData _temperatureData = TemperatureData.empty();
  MLClassifications _mlClassifications = MLClassifications.empty();
  MagnetometerData? _lastMagData;
  
  // Trajectory tracking
  List<TrajectoryPoint> _trajectoryPoints = [];
  final int _maxTrajectoryPoints = 100;

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  Future<void> _initializeBle() async {
    await _bleService.initialize();
    // Initialize wakelock toggle to current state
    try {
      final wakelockEnabled = await WakelockPlus.enabled;
      setState(() {
        _keepAwake = wakelockEnabled;
      });
    } catch (e) {
      // ignore: avoid_print
      print('WakelockPlus not available: $e');
    }

    // Listen to scan results
    _bleService.scanResults.listen((device) {
      setState(() {
        if (!_discoveredDevices.any((d) => d.id == device.id)) {
          _discoveredDevices.add(device);
        }
      });
    });

    // Listen to connection state
    _bleService.connectionState.listen((state) {
      setState(() {
        _isConnected = state == DeviceConnectionState.connected;
        // show transient banner on connect/disconnect
        _showConnectionBanner = true;
      });

      // auto-hide banner after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showConnectionBanner = false;
          });
        }
      });
    });

    // Listen to accelerometer data
    _bleService.accelerometerData.listen((data) {
      _strokeAnalyzer.processAccelerometerData(data);
      // record sample when recording
      _sessionService.addSample(data);

      setState(() {
        _strokeRate = _strokeAnalyzer.getStrokeRate();
        _consistency = _strokeAnalyzer.getConsistency();
        _totalStrokes = _strokeAnalyzer.getTotalStrokes();
        _averagePower = _strokeAnalyzer.getAveragePower();
        _recentData = _strokeAnalyzer.getRecentHistory(count: 100);
      });
      
      // Update trajectory with accelerometer position (integrate acceleration)
      if (_lastMagData != null) {
        _updateTrajectory(data, _lastMagData!);
      }
    });
    
    // Listen to magnetometer data
    _bleService.magnetometerData.listen((data) {
      setState(() {
        _lastMagData = data;
      });
    });
    
    // Listen to advanced metrics
    _bleService.advancedMetrics.listen((metrics) {
      setState(() {
        _advancedMetrics = metrics;
      });
    });
    
    // Listen to temperature data
    _bleService.temperatureData.listen((tempData) {
      setState(() {
        _temperatureData = tempData;
      });
    });
    
    // Listen to ML classifications
    _bleService.mlClassifications.listen((mlData) {
      setState(() {
        _mlClassifications = mlData;
      });
    });
  }
  
  void _updateTrajectory(AccelerometerData accel, MagnetometerData mag) {
    // Simplified trajectory visualization using raw sensor data
    // Note: This uses acceleration values directly as position coordinates
    // for relative motion visualization. For true position tracking, would need:
    // 1. Double integration (accel -> velocity -> position)
    // 2. Drift correction using magnetometer/position reset
    // Current approach provides useful relative motion patterns for technique analysis
    final point = TrajectoryPoint(
      x: accel.x,
      y: accel.y,
      z: accel.z,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _trajectoryPoints.add(point);
      // Keep only recent points
      if (_trajectoryPoints.length > _maxTrajectoryPoints) {
        _trajectoryPoints.removeAt(0);
      }
    });
  }

  void _toggleScan() {
    if (_isScanning) {
      _bleService.stopScan();
    } else {
      setState(() {
        _discoveredDevices.clear();
      });
      _bleService.startScan();
    }
    setState(() {
      _isScanning = !_isScanning;
    });
  }

  Future<void> _connectToDevice(String deviceId) async {
    await _bleService.connect(deviceId);
  }

  void _disconnect() {
    _bleService.disconnect();
    setState(() {
      _isConnected = false;
    });
  }

  void _resetStats() {
    _strokeAnalyzer.reset();
    setState(() {
      _strokeRate = 0.0;
      _consistency = 100.0;
      _totalStrokes = 0;
      _averagePower = 0.0;
      _recentData = [];
      _trajectoryPoints = [];
      _advancedMetrics = AdvancedMetrics.empty();
      _mlClassifications = MLClassifications.empty();
    });
  }

  Future<void> _toggleRecording() async {
    if (_sessionService.isRecording) {
      _sessionService.stop();
      // auto-save session
      final path = await _sessionService.saveSession();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Session saved: $path')));
    } else {
      await _sessionService.startWithAnalyzer(_strokeAnalyzer);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recording started')));
    }
    setState(() {});
  }

  void _openSessions() async {
    // simple navigation to a new screen listing saved sessions
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionListScreen(sessionService: _sessionService),
      ),
    );
  }

  @override
  void dispose() {
    _bleService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flow Track'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Keep-awake compact button
          IconButton(
            icon: Icon(_keepAwake ? Icons.bedtime : Icons.bedtime_outlined),
            onPressed: () async {
              final newVal = !_keepAwake;
              setState(() {
                _keepAwake = newVal;
              });
              try {
                await WakelockPlus.toggle(enable: newVal);
              } catch (e) {
                // ignore: avoid_print
                print('WakelockPlus toggle failed: $e');
              }
            },
            tooltip: _keepAwake
                ? 'Disable keep screen awake'
                : 'Keep screen awake',
          ),
          IconButton(
            icon: Icon(
              _sessionService.isRecording
                  ? Icons.mode_standby
                  : Icons.rowing,
              color: _sessionService.isRecording ? Colors.red : null,
            ),
            onPressed: _toggleRecording,
            tooltip: _sessionService.isRecording
                ? 'Stop Recording'
                : 'Start Recording',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DrawerHeader(
                child: Text(
                  'Flow Track',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Saved Sessions'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openSessions();
                },
              ),
              const Spacer(),
              if (_isConnected)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reset Statistics'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _resetStats();
                  },
                ),
              ListTile(
                leading: Icon(
                  _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                ),
                title: Text(_isConnected ? 'Disconnect' : 'Scan'),
                onTap: () {
                  Navigator.of(context).pop();
                  if (_isConnected) {
                    _disconnect();
                  } else {
                    _toggleScan();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'App Version: 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          _isConnected ? _buildConnectedView() : _buildScanView(),
          // Transient connection banner (top)
          if (_showConnectionBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? Colors.green.shade600
                            : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isConnected ? Icons.check_circle : Icons.info,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isConnected ? 'Connected' : 'Disconnected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_searching, size: 80, color: Colors.blue),
          const SizedBox(height: 20),
          Text(
            _isConnected ? 'Connected' : 'Disconnected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          if (_discoveredDevices.isEmpty && !_isScanning)
            ElevatedButton.icon(
              onPressed: _toggleScan,
              icon: const Icon(Icons.search),
              label: const Text('Scan for Devices'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
            ),
          if (_isScanning) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Scanning for Flow Track devices...'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _toggleScan,
              child: const Text('Stop Scan'),
            ),
          ],
          if (_discoveredDevices.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Discovered Devices:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 5,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth, color: Colors.blue),
                      title: Text(
                        device.name.isNotEmpty ? device.name : 'Unknown Device',
                      ),
                      subtitle: Text(device.id),
                      trailing: ElevatedButton(
                        onPressed: () => _connectToDevice(device.id),
                        child: const Text('Connect'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectedView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 700; // tune threshold
        final graphHeight = compact ? 160.0 : 240.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              StrokeRateCard(
                strokeRate: _strokeRate,
                compact: compact,
                onInfo: () => _showInfo(
                  'Stroke Rate',
                  'Strokes per minute based on detected stroke timestamps.',
                ),
              ),
              const SizedBox(height: 12),

              ConsistencyIndicator(
                consistency: _consistency,
                compact: compact,
                onInfo: () => _showInfo(
                  'Consistency',
                  'Coefficient of variation of recent stroke powers (0-100%).',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: StatsCard(
                      title: 'Total Strokes',
                      value: _totalStrokes.toString(),
                      icon: Icons.rowing,
                      color: Colors.blue,
                      compact: compact,
                      onInfo: () => _showInfo(
                        'Total Strokes',
                        'Running count of detected strokes for this session.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatsCard(
                      title: 'Avg Power',
                      value: _averagePower.toStringAsFixed(1),
                      icon: Icons.speed,
                      color: Colors.orange,
                      compact: compact,
                      onInfo: () => _showInfo(
                        'Average Power',
                        'Average acceleration magnitude of recent strokes.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              MotionGraph(
                data: _recentData,
                compact: compact,
                height: graphHeight,
                onInfo: () => _showInfo(
                  'Motion Pattern',
                  'Live 3-axis accelerometer data for the last samples.',
                ),
              ),
              const SizedBox(height: 12),
              
              // Advanced metrics
              AdvancedMetricsCard(metrics: _advancedMetrics),
              const SizedBox(height: 12),
              
              // Temperature monitoring
              TemperatureCard(temperature: _temperatureData),
              const SizedBox(height: 12),
              
              // ML Quality analysis
              MLQualityCard(ml: _mlClassifications),
              const SizedBox(height: 12),
              
              // 3D Trajectory visualization
              TrajectoryWidget(trajectoryPoints: _trajectoryPoints),
            ],
          ),
        );
      },
    );
  }

  void _showInfo(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
