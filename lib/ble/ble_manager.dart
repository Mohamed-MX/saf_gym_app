import 'package:flutter_blue_plus/flutter_blue_plus.dart';

BluetoothDevice? _connectedDevice;
BluetoothCharacteristic? _notifyCharacteristic;

// UUIDs (MUST match ESP32)
final Guid serviceUUID =
    Guid("12345678-1234-1234-1234-1234567890ab");

final Guid charUUID =
    Guid("abcd1234-5678-1234-5678-abcdef123456");

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  /// Optional callback invoked with the X, Y, Z acceleration values every sensor frame.
  void Function(double ax, double ay, double az)? onDataCallback;

  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        print("🔌 Disconnected from BLE");
        _connectedDevice = null;
        _notifyCharacteristic = null;
      }
    } catch (e) {
      print("Disconnect error: $e");
    }
  }

  // ===============================
  // STEP 1: SCAN + CONNECT
  // ===============================
  Future<void> startScan() async {
    if (_connectedDevice != null) {
      print("✅ Already connected, skipping scan");
      return;
    }

    // 🔥 VERY IMPORTANT: clean previous connection
    await disconnect();

    print("🔍 Scanning...");

    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {

        if (r.device.platformName.contains("SmartGymSensor")) {

          print("✅ Found device");

          await FlutterBluePlus.stopScan();

          _connectedDevice = r.device;

          try {
            await _connectedDevice!.connect(timeout: Duration(seconds: 5));
            print("✅ Connected");

            await discoverServices();

          } catch (e) {
            print("❌ Connection failed: $e");
          }

          break;
        }
      }
    });
  }

  // ===============================
  // STEP 2: DISCOVER + SUBSCRIBE
  // ===============================

  Future<void> discoverServices() async {
    if (_connectedDevice == null) return;

    var services = await _connectedDevice!.discoverServices();

    for (var service in services) {
      if (service.uuid.toString() == serviceUUID.toString()) {

        for (var c in service.characteristics) {
          if (c.uuid.toString() == charUUID.toString()) {

            _notifyCharacteristic = c;

            await c.setNotifyValue(true);

            c.lastValueStream.listen((value) {
              String data = String.fromCharCodes(value);

              // parse CSV: time,ax,ay,az
              List<String> parts = data.split(',');

              if (parts.length >= 4) {
                double ax = double.tryParse(parts[1]) ?? 0;
                double ay = double.tryParse(parts[2]) ?? 0;
                double az = double.tryParse(parts[3]) ?? 0;

                if (onDataCallback != null) {
                  onDataCallback!(ax, ay, az);
                }
              }
            });

            print("📡 Notifications enabled");
          }
        }
      }
    }
  }

  // ===============================
  // STEP 3: RECEIVE DATA
  // ===============================
  void onDataReceived(String data) {

    final parts = data.split(',');

    if (parts.length != 4) return;

    final t  = int.parse(parts[0]);
    final ax = double.parse(parts[1]);
    final ay = double.parse(parts[2]);
    final az = double.parse(parts[3]);

    print("t:$t ax:$ax ay:$ay az:$az");

    // Forward axes to any registered callback (e.g. RepGameScreen)
    onDataCallback?.call(ax, ay, az);
  }
}