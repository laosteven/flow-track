import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../services/ble_service.dart';
import '../services/stroke_analyzer.dart';
import '../models/sensor_data.dart';
import '../widgets/stroke_rate_card.dart';
import '../widgets/consistency_indicator.dart';
import '../widgets/motion_graph.dart';
import '../widgets/stats_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleService _bleService = BleService();
  final StrokeAnalyzer _strokeAnalyzer = StrokeAnalyzer();
  
  bool _isScanning = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  
  List<DiscoveredDevice> _discoveredDevices = [];
  
  double _strokeRate = 0.0;
  double _consistency = 100.0;
  int _totalStrokes = 0;
  double _averagePower = 0.0;
  
  List<AccelerometerData> _recentData = [];
  
  @override
  void initState() {
    super.initState();
    _initializeBle();
  }
  
  Future<void> _initializeBle() async {
    await _bleService.initialize();
    
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
        _isConnected = state.connectionState == DeviceConnectionState.connected;
        _connectionStatus = state.connectionState.toString().split('.').last;
      });
    });
    
    // Listen to accelerometer data
    _bleService.accelerometerData.listen((data) {
      _strokeAnalyzer.processAccelerometerData(data);
      
      setState(() {
        _strokeRate = _strokeAnalyzer.getStrokeRate();
        _consistency = _strokeAnalyzer.getConsistency();
        _totalStrokes = _strokeAnalyzer.getTotalStrokes();
        _averagePower = _strokeAnalyzer.getAveragePower();
        _recentData = _strokeAnalyzer.getRecentHistory(count: 100);
      });
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
      _connectionStatus = 'Disconnected';
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
    });
  }
  
  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dragon Paddle Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetStats,
              tooltip: 'Reset Statistics',
            ),
          IconButton(
            icon: Icon(_isConnected ? Icons.bluetooth_connected : Icons.bluetooth),
            onPressed: _isConnected ? _disconnect : _toggleScan,
            tooltip: _isConnected ? 'Disconnect' : 'Scan',
          ),
        ],
      ),
      body: _isConnected ? _buildConnectedView() : _buildScanView(),
    );
  }
  
  Widget _buildScanView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            _connectionStatus,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          if (_discoveredDevices.isEmpty && !_isScanning)
            ElevatedButton.icon(
              onPressed: _toggleScan,
              icon: const Icon(Icons.search),
              label: const Text('Scan for Devices'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          if (_isScanning) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Scanning for Dragon Paddle devices...'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _toggleScan,
              child: const Text('Stop Scan'),
            ),
          ],
          if (_discoveredDevices.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Discovered Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth, color: Colors.blue),
                      title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection status
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected, color: Colors.green),
                  const SizedBox(width: 10),
                  Text(
                    'Connected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Stroke rate - Big display
          StrokeRateCard(strokeRate: _strokeRate),
          const SizedBox(height: 16),
          
          // Consistency indicator with color
          ConsistencyIndicator(consistency: _consistency),
          const SizedBox(height: 16),
          
          // Statistics cards
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Total Strokes',
                  value: _totalStrokes.toString(),
                  icon: Icons.rowing,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatsCard(
                  title: 'Avg Power',
                  value: _averagePower.toStringAsFixed(1),
                  icon: Icons.speed,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Motion graph
          MotionGraph(data: _recentData),
        ],
      ),
    );
  }
}
