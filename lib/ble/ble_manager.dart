import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── Expected UUIDs (must match ESP32 firmware) ────────────────────────────────
final Guid serviceUUID = Guid("12345678-1234-1234-1234-1234567890ab");
final Guid charUUID    = Guid("abcd1234-5678-1234-5678-abcdef123456");

// ── Diagnostic snapshot of a single discovered service ────────────────────────
class BleServiceInfo {
  final String serviceUuid;
  final List<BleCharInfo> characteristics;
  BleServiceInfo(this.serviceUuid, this.characteristics);
}

class BleCharInfo {
  final String charUuid;
  final bool canNotify;
  final bool canRead;
  final bool isTarget; // matches our expected charUUID
  BleCharInfo({
    required this.charUuid,
    required this.canNotify,
    required this.canRead,
    required this.isTarget,
  });
}

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  // ── Internal state ────────────────────────────────────────────
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  // ── Public state ──────────────────────────────────────────────
  bool get isConnected => _device != null && _characteristic != null;

  /// Name of the connected device (for diagnostics).
  String get connectedDeviceName => _device?.platformName ?? '—';

  /// Latest IMU readings (updated every sensor frame).
  double lastAx = 0, lastAy = 0, lastAz = 0;

  // ── Diagnostic state ──────────────────────────────────────────
  /// All services/characteristics discovered on the last connect attempt.
  List<BleServiceInfo> discoveredServices = [];

  /// Whether the target service UUID was found.
  bool serviceFound = false;

  /// Whether the target characteristic UUID was found (and notified).
  bool charFound = false;

  /// Last raw string received from the characteristic (for debugging).
  String lastRawPacket = '';

  /// Timestamp of the last raw packet.
  DateTime? lastPacketTime;

  /// Total packets received since last connect.
  int packetCount = 0;

  // ── Callbacks ─────────────────────────────────────────────────
  /// Called every time a new IMU frame arrives.
  void Function(double ax, double ay, double az)? onDataCallback;

  /// Called when the BLE device disconnects unexpectedly.
  void Function()? onDisconnectedCallback;

  // ── Connection state stream ───────────────────────────────────
  final StreamController<bool> _connectedController =
      StreamController<bool>.broadcast();

  /// Emits `true` on connect/service-found, `false` on disconnect/service-not-found.
  Stream<bool> get connectionStream => _connectedController.stream;

  // ── Diagnostic stream (fires on every raw packet) ─────────────
  final StreamController<String> _rawDataController =
      StreamController<String>.broadcast();

  /// Emits every raw BLE packet as a string.
  Stream<String> get rawDataStream => _rawDataController.stream;

  // ── Public API ────────────────────────────────────────────────

  /// Auto-scan and auto-connect to the first "SmartGymSensor" found.
  Future<void> startScan() async {
    if (isConnected) return;
    await _cleanUp();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        if (r.device.platformName.contains("SmartGymSensor")) {
          _scanSubscription?.cancel();
          await FlutterBluePlus.stopScan();
          await connectToDevice(r.device);
          break;
        }
      }
    });
  }

  /// Connect to a specific [device] chosen by the user.
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_device?.remoteId == device.remoteId && isConnected) return;

    await _cleanUp();
    _device = device;

    // Watch for unexpected disconnections
    _connectionSubscription = _device!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _characteristic = null;
        _device = null;
        _connectedController.add(false);
        onDisconnectedCallback?.call();
      }
    });

    await _device!.connect(
      timeout: const Duration(seconds: 8),
      autoConnect: false,
    );
    await _discoverServices();
  }

  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (_) {}
    await _cleanUp();
    _connectedController.add(false);
  }

  /// Manually read the characteristic to test if the PCB can send data at all
  /// (helps debug if notifications are broken on the ESP32 side).
  Future<void> triggerManualRead() async {
    if (_characteristic == null) return;
    try {
      final value = await _characteristic!.read();
      if (value.isNotEmpty) {
        final raw = String.fromCharCodes(value);
        lastRawPacket = "READ: $raw";
        lastPacketTime = DateTime.now();
        packetCount++;
        _rawDataController.add(lastRawPacket);
      } else {
        lastRawPacket = "READ: (empty bytes)";
        _rawDataController.add(lastRawPacket);
      }
    } catch (e) {
      lastRawPacket = "READ ERROR: $e";
      _rawDataController.add(lastRawPacket);
    }
  }

  // ── Private helpers ───────────────────────────────────────────

  Future<void> _cleanUp() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _characteristic = null;
    _device = null;
    lastAx = lastAy = lastAz = 0;
    discoveredServices = [];
    serviceFound = false;
    charFound = false;
    lastRawPacket = '';
    lastPacketTime = null;
    packetCount = 0;
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;

    final services = await _device!.discoverServices();

    // ── Build diagnostic snapshot of ALL services ─────────────
    discoveredServices = services.map((s) {
      final chars = s.characteristics.map((c) {
        final props = c.properties;
        return BleCharInfo(
          charUuid: c.uuid.toString(),
          canNotify: props.notify || props.indicate,
          canRead: props.read,
          isTarget: c.uuid.toString().toLowerCase() ==
              charUUID.toString().toLowerCase(),
        );
      }).toList();
      return BleServiceInfo(s.uuid.toString(), chars);
    }).toList();

    // ── Try to find our target service + char ────────────────
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          serviceUUID.toString().toLowerCase()) {
        serviceFound = true;

        for (final c in service.characteristics) {
          if (c.uuid.toString().toLowerCase() ==
              charUUID.toString().toLowerCase()) {
            charFound = true;
            _characteristic = c;

            await c.setNotifyValue(true);

            c.lastValueStream.listen((value) {
              if (value.isEmpty) return;

              final raw = String.fromCharCodes(value);
              lastRawPacket = raw;
              lastPacketTime = DateTime.now();
              packetCount++;
              _rawDataController.add(raw);

              final parts = raw.split(',');

              // Expected format: time,ax,ay,az
              if (parts.length >= 4) {
                final ax = double.tryParse(parts[1].trim()) ?? 0;
                final ay = double.tryParse(parts[2].trim()) ?? 0;
                final az = double.tryParse(parts[3].trim()) ?? 0;

                lastAx = ax;
                lastAy = ay;
                lastAz = az;

                onDataCallback?.call(ax, ay, az);
              }
            });

            _connectedController.add(true);
            return;
          }
        }
      }
    }

    // ── Target service or char not found ─────────────────────
    // Keep the physical connection alive so diagnostics can show
    // what UUIDs the device actually has.
    // Emit true on connectionStream so the UI shows "connected"
    // (physical link is up), but isConnected stays false because
    // _characteristic is still null.
    _connectedController.add(true);
  }
}