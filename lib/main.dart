// ignore_for_file: dead_code

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'ble_controller.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // <-- import required

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init(); // initialize persistent storage
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  Color statusColor(String status) {
    if (status == "Connected") return Colors.green;
    if (status == "Connecting...") return Colors.blue;
    if (status == "Disconnected") return Colors.red;
    if (status == "Scanning...") return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(title: const Text("BLE LED Control")),
      body: SafeArea(
        child: GetBuilder<BleController>(
          init: BleController(),
          builder: (controller) {
            return Column(
              children: [
                // STATUS BAR
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: statusColor(controller.statusText),
                  child: Text(
                    controller.statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // CONNECTED DEVICE UI
                if (controller.connectedDevice != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Connected to: ${controller.connectedDevice!.name.isNotEmpty ? controller.connectedDevice!.name : controller.connectedDevice!.id}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => controller.sendData("ON"),
                    child: const Text("LED ON"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => controller.sendData("OFF"),
                    child: const Text("LED OFF"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: controller.clearSavedDevice,
                    child: const Text("CLEAR SAVED DEVICE"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                  const Divider(),
                ],

                // DEVICE LIST (always visible)
                Expanded(
                  child: StreamBuilder<List<ScanResult>>(
                    stream: controller.scanResults,
                    builder: (context, snapshot) {
                      final results = snapshot.data ?? [];
                      final devices = results
                          .where(
                            (r) => (r.device.name)
                                .toLowerCase()
                                .startsWith("airtek"),
                          )
                          .toList();

                      if (devices.isEmpty) {
                        return const Center(
                          child: Text("Searching devices..."),
                        );
                      }

                      return ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final r = devices[index];
                          final device = r.device;
                          return ListTile(
                            title: Text(
                              device.name.isNotEmpty
                                  ? device.name
                                  : device.id.toString(),
                            ),
                            subtitle: Text(device.id.toString()),
                            trailing:
                                controller.connectedDevice != null &&
                                    device.id == controller.connectedDevice!.id
                                ? const Icon(Icons.check, color: Colors.green)
                                : null,
                            onTap: () => controller.connectToDevice(device),
                          );
                        },
                      );
                    },
                  ),
                ),

                // SCAN BUTTON
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.scanDevices,
                      child: const Text("SCAN"),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
