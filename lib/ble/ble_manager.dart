import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// UUIDs (MUST match ESP32)
final Guid serviceUUID =
    Guid("12345678-1234-1234-1234-1234567890ab");

final Guid charUUID =
    Guid("abcd1234-5678-1234-5678-abcdef123456");

class BleManager {

  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  /// Optional callback invoked with the X, Y, Z acceleration values every sensor frame.
  void Function(double ax, double ay, double az)? onDataCallback;

  // ===============================
  // STEP 1: SCAN + CONNECT
  // ===============================
  void startScan() {

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) async {

      for (var r in results) {

        if (r.device.platformName == "SmartGymSensor") {

          print("Device found!");

          await FlutterBluePlus.stopScan();

          device = r.device;

          await device!.connect();

          print("Connected!");

          discoverServices();
          break;
        }
      }
    });
  }

  // ===============================
  // STEP 2: DISCOVER + SUBSCRIBE
  // ===============================
  void discoverServices() async {

    List<BluetoothService> services =
        await device!.discoverServices();

    for (var service in services) {

      if (service.uuid == serviceUUID) {

        for (var char in service.characteristics) {

          if (char.uuid == charUUID) {

            characteristic = char;

            await characteristic!.setNotifyValue(true);

            characteristic!.lastValueStream.listen((value) {

              final data = String.fromCharCodes(value);
              onDataReceived(data);
            });

            print("Subscribed to data!");
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