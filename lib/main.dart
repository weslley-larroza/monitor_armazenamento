import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space_update/disk_space_update.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final data = await getStorageData();
    await sendData(data);
  });
}

Future<Map<String, dynamic>> getStorageData() async {
  final info = DeviceInfoPlugin();
  final androidInfo = await info.androidInfo;

  final total = await DiskSpace.getTotalDiskSpace;
  final free = await DiskSpace.getFreeDiskSpace;

  final deviceId = await getDeviceId();

  final usedMb = (total ?? 0) - (free ?? 0);
  final usedPercent = total != null && total > 0 ? (usedMb / total * 100) : 0;

  return {
    "deviceId": deviceId,
    "deviceName": androidInfo.model ?? 'Desconhecido',
    "totalMb": total,
    "freeMb": free,
    "usedMb": usedMb,
    "usedPercent": usedPercent,
    "timestamp": DateTime.now().toIso8601String(),
  };
}

Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('device_id');
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await prefs.setString('device_id', deviceId);
  }
  return deviceId;
}

Future<void> sendData(Map<String, dynamic> data) async {
  try {
    final response = await http.post(
      Uri.parse('http://192.168.110.198:5000/api/storage'),
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

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'monitor_storage_channel',
      initialNotificationTitle: 'Monitor de Armazenamento',
      initialNotificationContent: 'Rodando em segundo plano'
    ),
    iosConfiguration: IosConfiguration(),
  );

  await service.startService();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor de Armazenamento',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      debugShowCheckedModeBanner: false,
      home: const StorageMonitor(),
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

    periodicTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
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
        Uri.parse('http://192.168.110.198:5000/api/storage'),
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
    final usedPercent = totalMb != null && totalMb! > 0
        ? (usedMb / totalMb! * 100).toStringAsFixed(1)
        : '...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor de Armazenamento'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: () async {
              await loadStorageInfo();
              await sendDataToServer();
            },
          ),
        ],
      ),
      body: totalMb == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("Informações do Dispositivo",
                              style: Theme.of(context).textTheme.titleLarge),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.devices),
                            title: const Text("ID do Dispositivo"),
                            subtitle: Text(deviceId ?? '---'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.smartphone),
                            title: const Text("Modelo"),
                            subtitle: Text(deviceName),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("Armazenamento",
                              style: Theme.of(context).textTheme.titleLarge),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.storage),
                            title: const Text("Total"),
                            trailing: Text('${totalMb!.toStringAsFixed(2)} MB'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.folder_open),
                            title: const Text("Livre"),
                            trailing: Text('${freeMb!.toStringAsFixed(2)} MB'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.sd_storage),
                            title: const Text("Em uso"),
                            trailing: Text(
                                '${usedMb.toStringAsFixed(2)} MB  ($usedPercent%)'),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: double.tryParse(usedPercent.toString())! / 100,
                            color: Theme.of(context).colorScheme.primary,
                            backgroundColor: Colors.grey[300],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
