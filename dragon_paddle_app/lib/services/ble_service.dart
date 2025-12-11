import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models/sensor_data.dart';

class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  
  // BLE UUIDs from Arduino firmware
  static const String serviceUuid = "180A";
  static const String accelCharUuid = "2A37";
  static const String gyroCharUuid = "2A38";
  
  final _scanResultsController = StreamController<DiscoveredDevice>.broadcast();
  final _accelerometerController = StreamController<AccelerometerData>.broadcast();
  final _gyroscopeController = StreamController<GyroscopeData>.broadcast();
  final _connectionStateController = StreamController<DeviceConnectionState>.broadcast();
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;
  StreamSubscription? _connectionSubscription;
  
  String? _connectedDeviceId;
  
  Stream<DiscoveredDevice> get scanResults => _scanResultsController.stream;
  Stream<AccelerometerData> get accelerometerData => _accelerometerController.stream;
  Stream<GyroscopeData> get gyroscopeData => _gyroscopeController.stream;
  Stream<DeviceConnectionState> get connectionState => _connectionStateController.stream;
  
  bool get isConnected => _connectedDeviceId != null;
  
  /// Initialize BLE
  Future<void> initialize() async {
    // Check BLE status
    await for (final status in _ble.statusStream) {
      if (status == BleStatus.ready) {
        break;
      }
    }
  }
  
  /// Start scanning for devices
  Future<void> startScan() async {
    if (kIsWeb) {
      // flutter_reactive_ble is not supported on web; avoid calling platform APIs.
      print('startScan skipped: BLE not supported on web');
      return;
    }

    final granted = await _ensurePermissions();
    if (!granted) {
      print('startScan aborted: required permissions not granted');
      return;
    }

    _startBleScanInternal();
  }
  
  /// Stop scanning
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }
  
  /// Connect to a device
  Future<void> connect(String deviceId) async {
    stopScan();
    
    _connectionSubscription = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    ).listen(
      (state) {
        _connectionStateController.add(state.connectionState);
        if (state.connectionState == DeviceConnectionState.connected) {
          _connectedDeviceId = deviceId;
          _subscribeToCharacteristics(deviceId);
        } else if (state.connectionState == DeviceConnectionState.disconnected) {
          _connectedDeviceId = null;
          _unsubscribeFromCharacteristics();
        }
      },
      onError: (error) {
        print('Connection error: $error');
        _connectedDeviceId = null;
      },
    );
  }
  
  /// Subscribe to sensor data characteristics
  void _subscribeToCharacteristics(String deviceId) {
    final accelCharacteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(accelCharUuid),
      deviceId: deviceId,
    );
    
    final gyroCharacteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(gyroCharUuid),
      deviceId: deviceId,
    );
    
    _accelSubscription = _ble.subscribeToCharacteristic(accelCharacteristic).listen(
      (data) {
        if (data.length >= 12) {
          final accelData = AccelerometerData.fromBytes(Uint8List.fromList(data));
          if (kDebugMode) {
            print('BLE accel: ${accelData.magnitude.toStringAsFixed(2)}');
          }
          _accelerometerController.add(accelData);
        }
      },
      onError: (error) {
        print('Accelerometer subscription error: $error');
      },
    );
    
    _gyroSubscription = _ble.subscribeToCharacteristic(gyroCharacteristic).listen(
      (data) {
        if (data.length >= 12) {
          final gyroData = GyroscopeData.fromBytes(Uint8List.fromList(data));
          _gyroscopeController.add(gyroData);
        }
      },
      onError: (error) {
        print('Gyroscope subscription error: $error');
      },
    );
  }
  
  /// Unsubscribe from characteristics
  void _unsubscribeFromCharacteristics() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
  }
  
  /// Disconnect from device
  void disconnect() {
    _connectionSubscription?.cancel();
    _unsubscribeFromCharacteristics();
    _connectedDeviceId = null;
  }

  Future<bool> _ensurePermissions() async {
    // On Android 12+ additional BLUETOOTH_SCAN/CONNECT permissions may be required.
    // We request location (coarse) as a fallback for older Android versions.
    try {
      final statuses = await [
        Permission.locationWhenInUse,
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      // Consider permissions granted if any required permission is granted.
      bool granted = statuses.values.any((s) => s.isGranted);
      return granted;
    } catch (e) {
      print('Permission request failed: $e');
      return false;
    }
  }

  void _startBleScanInternal() {
    _scanSubscription?.cancel();
    try {
      _scanSubscription = _ble.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen(
        (device) {
          final name = device.name ?? '';
          final lname = name.toLowerCase();
          // Match FlowTrack, DragonPaddle (legacy), or any device advertising IMU
          if (lname.contains('flowtrack') || lname.contains('flowtrackimu') || lname.contains('dragonpaddle') || lname.contains('dragonpaddleimu') || lname.contains('imu')) {
            _scanResultsController.add(device);
          }
        },
        onError: (error) {
          print('Scan error: $error');
        },
      );
    } catch (e) {
      // Guard against platform / unsupported operation errors (e.g., Platform._operatingSystem)
      print('Failed to start BLE scan: $e');
    }
  }
}
