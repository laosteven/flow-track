import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models/sensor_data.dart';

class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  
  // Use short 16-bit UUIDs to match Arduino firmware exactly
  // These are standard Bluetooth SIG UUIDs that expand to the full 128-bit format
  static const String serviceUuid = "180A";
  static const String accelCharUuid = "2A37";
  static const String gyroCharUuid = "2A38";
  static const String magCharUuid = "2A39";
  static const String metricsCharUuid = "2A3A";
  static const String tempCharUuid = "2A3B";
  
  final _scanResultsController = StreamController<DiscoveredDevice>.broadcast();
  final _accelerometerController = StreamController<AccelerometerData>.broadcast();
  final _gyroscopeController = StreamController<GyroscopeData>.broadcast();
  final _magnetometerController = StreamController<MagnetometerData>.broadcast();
  final _metricsController = StreamController<AdvancedMetrics>.broadcast();
  final _temperatureController = StreamController<TemperatureData>.broadcast();
  final _connectionStateController = StreamController<DeviceConnectionState>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;
  StreamSubscription? _magSubscription;
  StreamSubscription? _metricsSubscription;
  StreamSubscription? _tempSubscription;
  StreamSubscription? _connectionSubscription;
  
  String? _connectedDeviceId;
  
  Stream<DiscoveredDevice> get scanResults => _scanResultsController.stream;
  Stream<AccelerometerData> get accelerometerData => _accelerometerController.stream;
  Stream<GyroscopeData> get gyroscopeData => _gyroscopeController.stream;
  Stream<MagnetometerData> get magnetometerData => _magnetometerController.stream;
  Stream<AdvancedMetrics> get advancedMetrics => _metricsController.stream;
  Stream<TemperatureData> get temperatureData => _temperatureController.stream;
  Stream<DeviceConnectionState> get connectionState => _connectionStateController.stream;
  Stream<String> get statusMessages => _statusController.stream;
  
  bool get isConnected => _connectedDeviceId != null;
  
  void _emitStatus(String message) {
    if (kDebugMode) {
      debugPrint('BLE Status: $message');
    }
    _statusController.add(message);
  }
  
  /// Initialize BLE
  Future<void> initialize() async {
    _emitStatus('Initializing BLE...');
    
    // Check BLE status
    await for (final status in _ble.statusStream) {
      _emitStatus('BLE status: ${status.toString()}');
      if (status == BleStatus.ready) {
        _emitStatus('BLE ready');
        break;
      } else if (status == BleStatus.unauthorized) {
        _emitStatus('ERROR: Bluetooth unauthorized - check app permissions in Settings');
        break;
      } else if (status == BleStatus.poweredOff) {
        _emitStatus('ERROR: Bluetooth is turned off - enable in Settings');
        break;
      } else if (status == BleStatus.unsupported) {
        _emitStatus('ERROR: Bluetooth not supported on this device');
        break;
      }
    }
  }
  
  /// Start scanning for devices
  Future<void> startScan() async {
    if (kIsWeb) {
      // flutter_reactive_ble is not supported on web; avoid calling platform APIs.
      if (kDebugMode) {
        debugPrint('startScan skipped: BLE not supported on web');
      }
      return;
    }

    final granted = await _ensurePermissions();
    if (!granted) {
      if (kDebugMode) {
        debugPrint('startScan aborted: required permissions not granted');
      }
      return;
    }

    _startBleScanInternal();
  }
  
  /// Stop scanning
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _unfilteredScanSubscription?.cancel();
    _unfilteredScanSubscription = null;
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
        if (kDebugMode) {
          debugPrint('Connection error: $error');
        }
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
    
    final magCharacteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(magCharUuid),
      deviceId: deviceId,
    );
    
    final metricsCharacteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(metricsCharUuid),
      deviceId: deviceId,
    );
    
    final tempCharacteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(tempCharUuid),
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
        if (kDebugMode) {
          debugPrint('Accelerometer subscription error: $error');
        }
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
        if (kDebugMode) {
          debugPrint('Gyroscope subscription error: $error');
        }
      },
    );
    
    _magSubscription = _ble.subscribeToCharacteristic(magCharacteristic).listen(
      (data) {
        if (data.length >= 12) {
          final magData = MagnetometerData.fromBytes(Uint8List.fromList(data));
          _magnetometerController.add(magData);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('Magnetometer subscription error: $error');
        }
      },
    );
    
    _metricsSubscription = _ble.subscribeToCharacteristic(metricsCharacteristic).listen(
      (data) {
        if (data.length >= 32) {
          final metrics = AdvancedMetrics.fromBytes(Uint8List.fromList(data));
          if (kDebugMode) {
            print('BLE metrics: ${metrics.toString()}');
          }
          _metricsController.add(metrics);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('Metrics subscription error: $error');
        }
      },
    );
    
    _tempSubscription = _ble.subscribeToCharacteristic(tempCharacteristic).listen(
      (data) {
        if (data.length >= 8) {
          final tempData = TemperatureData.fromBytes(Uint8List.fromList(data));
          _temperatureController.add(tempData);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('Temperature subscription error: $error');
        }
      },
    );
  }
  
  /// Unsubscribe from characteristics
  void _unsubscribeFromCharacteristics() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magSubscription?.cancel();
    _metricsSubscription?.cancel();
    _tempSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _magSubscription = null;
    _metricsSubscription = null;
    _tempSubscription = null;
  }
  
  /// Disconnect from device
  void disconnect() {
    _connectionSubscription?.cancel();
    _unsubscribeFromCharacteristics();
    _connectedDeviceId = null;
  }

  Future<bool> _ensurePermissions() async {
    _emitStatus('Checking permissions...');
    
    try {
      // On iOS, Bluetooth permission is handled automatically by the system
      // when we try to scan. The permission_handler package is unreliable for
      // Bluetooth on iOS. Just check BLE status instead.
      if (!kIsWeb && Platform.isIOS) {
        // On iOS, we rely on the BLE library to trigger the system permission dialog
        // Check if BLE is ready
        final status = await _ble.statusStream.first;
        if (status == BleStatus.ready) {
          _emitStatus('iOS: BLE ready');
          return true;
        } else if (status == BleStatus.unauthorized) {
          _emitStatus('ERROR: Bluetooth not authorized - check Settings > Privacy > Bluetooth');
          return false;
        } else if (status == BleStatus.poweredOff) {
          _emitStatus('ERROR: Bluetooth is off - enable in Control Center');
          return false;
        } else {
          _emitStatus('BLE status: $status - attempting scan anyway');
          return true; // Try anyway, iOS will prompt if needed
        }
      }
      
      // On Android 12+, we need BLUETOOTH_SCAN and BLUETOOTH_CONNECT
      if (!kIsWeb && Platform.isAndroid) {
        final permissions = <Permission>[
          Permission.locationWhenInUse,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ];
        
        final statuses = await permissions.request();
        
        // Log each permission status
        for (final entry in statuses.entries) {
          _emitStatus('Permission ${entry.key}: ${entry.value}');
        }

        // Check if any critical permission is denied
        final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
        final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
        
        if (!scanGranted || !connectGranted) {
          _emitStatus('ERROR: Bluetooth permissions denied');
          return false;
        }
      }
      
      _emitStatus('Permissions OK');
      return true;
    } catch (e) {
      _emitStatus('Permission check error: $e - trying anyway');
      return true; // Try scanning anyway
    }
  }

  void _startBleScanInternal() {
    _scanSubscription?.cancel();
    _unfilteredScanSubscription?.cancel();
    _emitStatus('Starting BLE scan...');
    
    try {
      // Show ALL BLE devices - no filtering
      // This helps debug iOS BLE issues and lets users manually select
      _scanSubscription = _ble.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen(
        (device) {
          // Only add devices that have a name (skip anonymous devices to reduce noise)
          // But include all named devices for debugging
          if (device.name.isNotEmpty) {
            if (kDebugMode) {
              debugPrint('Found BLE device: ${device.name} (${device.id}) RSSI: ${device.rssi}');
            }
            _emitStatus('Found: ${device.name} (${device.rssi} dBm)');
            _scanResultsController.add(device);
          }
        },
        onError: (error) {
          _emitStatus('Scan error: $error');
        },
      );
      
      _emitStatus('Scan started - looking for devices...');
    } catch (e) {
      _emitStatus('Failed to start scan: $e');
    }
  }
  
  StreamSubscription? _unfilteredScanSubscription;
  
  /// Dispose of all resources
  void dispose() {
    stopScan();
    disconnect();
    _scanResultsController.close();
    _accelerometerController.close();
    _gyroscopeController.close();
    _magnetometerController.close();
    _metricsController.close();
    _temperatureController.close();
    _connectionStateController.close();
    _statusController.close();
  }
}
