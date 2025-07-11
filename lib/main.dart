import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space_update/disk_space_update.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: StorageMonitor(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class StorageMonitor extends StatefulWidget {
  const StorageMonitor({super.key});
  @override
  State<StorageMonitor> createState() => _StorageMonitorState();
}

class _StorageMonitorState extends State<StorageMonitor> {
  double? totalMb;
  double? freeMb;
  String deviceName = "";
  String? deviceId;

  Timer? periodicTimer;

  @override
  void initState() {
    super.initState();
    initDeviceData();
  }

  Future<void> initDeviceData() async {
    await loadOrCreateDeviceId();
    await loadStorageInfo();

    periodicTimer = Timer.periodic(const Duration(hours: 2), (_) async {
      await loadStorageInfo();
      await sendDataToServer();
    });
  }

  Future<void> loadOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId!);
    }

    print('ID do aparelho: $deviceId');
  }

  Future<void> loadStorageInfo() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;

    final total = await DiskSpace.getTotalDiskSpace;
    final free = await DiskSpace.getFreeDiskSpace;

    setState(() {
      deviceName = androidInfo.model ?? 'Desconhecido';
      totalMb = total ?? 0;
      freeMb = free ?? 0;
    });
  }

  Future<void> sendDataToServer() async {
    if (totalMb == null || freeMb == null || deviceId == null) return;

    final usedMb = totalMb! - freeMb!;
    final usedPercent = totalMb! > 0 ? (usedMb / totalMb! * 100) : 0;

    final data = {
      "deviceId": deviceId,
      "deviceName": deviceName,
      "totalMb": totalMb,
      "freeMb": freeMb,
      "usedMb": usedMb,
      "usedPercent": usedPercent,
      "timestamp": DateTime.now().toIso8601String(),
    };

    try {
      final response = await http.post(
        Uri.parse('http://ip.server:5000/api/storage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        print('Dados enviados com sucesso!');
      } else {
        print('Falha ao enviar dados. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao enviar dados: $e');
    }
  }

  @override
  void dispose() {
    periodicTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usedMb = (totalMb ?? 0) - (freeMb ?? 0);
    final usedPercent = totalMb! > 0
        ? (usedMb / totalMb! * 100).toStringAsFixed(1)
        : '...';

    return Scaffold(
      appBar: AppBar(title: const Text('Monitor de Armazenamento')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: totalMb == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ID do Dispositivo: $deviceId"),
                  const SizedBox(height: 10),
                  Text("Modelo: $deviceName"),
                  const SizedBox(height: 20),
                  Text("Total: ${totalMb!.toStringAsFixed(2)} MB"),
                  Text("Livre: ${freeMb!.toStringAsFixed(2)} MB"),
                  Text("Usado: ${usedMb.toStringAsFixed(2)} MB ($usedPercent%)"),
                ],
              ),
      ),
    );
  }
}
