import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  final box = GetStorage();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeChar;

  bool isConnecting = false;
  bool isReconnecting = false;

  String statusText = "Idle";

  static const String SERVICE_UUID = "12345678-1234-1234-1234-123456789abc";
  static const String CHAR_UUID = "abcdefab-1234-5678-1234-abcdefabcdef";
  static const String SAVED_DEVICE_ID = "saved_device_id";

  @override
  void onInit() {
    super.onInit();
    Future.delayed(const Duration(milliseconds: 300), () {
      autoConnectSavedDevice();
    });
  }

  /// SCAN
  Future<void> scanDevices() async {
    statusText = "Scanning...";
    update();

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    await FlutterBluePlus.turnOn();
    await FlutterBluePlus.stopScan();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) {
      autoConnectSavedDeviceFromResults(results);
    });
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  /// AUTO CONNECT SAVED DEVICE ON STARTUP
  void autoConnectSavedDevice() async {
    final savedId = box.read(SAVED_DEVICE_ID);
    if (savedId != null && connectedDevice == null) {
      await FlutterBluePlus.stopScan();
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          if (r.device.remoteId.toString() == savedId) {
            connectToDevice(r.device);
            break;
          }
        }
      });
    }
  }

  void autoConnectSavedDeviceFromResults(List<ScanResult> results) {
    final savedId = box.read(SAVED_DEVICE_ID);
    if (savedId != null && connectedDevice == null) {
      for (var r in results) {
        if (r.device.remoteId.toString() == savedId) {
          connectToDevice(r.device);
          break;
        }
      }
    }
  }

  /// CONNECT
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnecting) return;

    try {
      isConnecting = true;
      statusText = "Connecting...";
      update();

      await FlutterBluePlus.stopScan();

      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      final services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (var char in service.characteristics) {
            if (char.uuid.toString() == CHAR_UUID) {
              writeChar = char;
            }
          }
        }
      }

      connectedDevice = device;
      box.write(SAVED_DEVICE_ID, device.remoteId.toString());
      statusText = "Connected";
      update();

      // DISCONNECT LISTENER
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          writeChar = null;
          statusText = "Disconnected";
          update();

          if (!isReconnecting) {
            isReconnecting = true;
            Future.delayed(const Duration(seconds: 2), () {
              isReconnecting = false;
              scanDevices();
            });
          }
        }
      });
    } catch (_) {
      statusText = "Connection Failed";
      update();
    } finally {
      isConnecting = false;
      update();
    }
  }

  /// SEND DATA
  Future<void> sendData(String data) async {
    if (writeChar == null) return;
    await writeChar!.write(utf8.encode(data));
  }

  /// CLEAR SAVED DEVICE
  void clearSavedDevice() {
    box.remove(SAVED_DEVICE_ID);
    connectedDevice = null;
    statusText = "Idle";
    update();
  }
}
