import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/scanner.dart';
import 'package:modbus_studio/src/rust/api/client.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

class ScannedDevice {
  final String ip;
  final int port;
  final int slaveId;
  final int latencyMs;
  final String status;

  ScannedDevice({
    required this.ip,
    required this.port,
    required this.slaveId,
    required this.latencyMs,
    required this.status,
  });
}

class RadarState {
  final List<ScannedDevice> devices;
  final bool isScanning;

  RadarState({this.devices = const [], this.isScanning = false});

  RadarState copyWith({
    List<ScannedDevice>? devices,
    bool? isScanning,
  }) {
    return RadarState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class RadarNotifier extends Notifier<RadarState> {
  StreamSubscription<RadarDevice>? _subscription;

  @override
  RadarState build() {
    return RadarState();
  }

  void startScan({String target = "192.168.1", int port = 502}) {
    if (state.isScanning) return;

    state = RadarState(isScanning: true, devices: []);

    _subscription?.cancel();
    _subscription = null;

    final isFullIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(target);

    if (isFullIp) {
      _sweepSingleIp(target, port);
    } else {
      _subscription = startRadarScan(subnet: target).listen(
        (radarDevice) async {
          final activeIds = await _sweepSlaveIds(radarDevice.ip, port);
          final newDevices = activeIds.map((id) => ScannedDevice(
            ip: radarDevice.ip,
            port: port,
            slaveId: id,
            latencyMs: radarDevice.latencyMs,
            status: radarDevice.status,
          )).toList();

          if (newDevices.isEmpty) {
            newDevices.add(ScannedDevice(
              ip: radarDevice.ip,
              port: port,
              slaveId: 1,
              latencyMs: radarDevice.latencyMs,
              status: radarDevice.status,
            ));
          }
          state = state.copyWith(devices: [...state.devices, ...newDevices]);
        },
        onDone: () {
          state = state.copyWith(isScanning: false);
        },
        onError: (e) {
          state = state.copyWith(isScanning: false);
        },
      );
    }
  }

  Future<void> _sweepSingleIp(String ip, int port) async {
    final startTime = DateTime.now();
    final activeIds = await _sweepSlaveIds(ip, port);
    final latency = DateTime.now().difference(startTime).inMilliseconds;

    final newDevices = activeIds.map((id) => ScannedDevice(
      ip: ip,
      port: port,
      slaveId: id,
      latencyMs: latency,
      status: 'Online',
    )).toList();

    if (newDevices.isEmpty) {
      newDevices.add(ScannedDevice(
        ip: ip,
        port: port,
        slaveId: 1,
        latencyMs: latency,
        status: 'Offline',
      ));
    }

    state = state.copyWith(devices: newDevices, isScanning: false);
  }

  Future<List<int>> _sweepSlaveIds(String ip, int port) async {
    final activeIds = <int>[];
    const batchSize = 30;
    for (int i = 1; i <= 247; i += batchSize) {
      final batch = <Future<void>>[];
      for (int id = i; id < i + batchSize && id <= 247; id++) {
        final currentId = id;
        batch.add(() async {
          try {
            final client = await ModbusClient.connect(
              config: ConnectionConfig(
                protocolType: 'TCP',
                ip: ip,
                port: port,
              ),
              slaveId: currentId,
            );
            await client.readHoldingRegisters(address: 0, quantity: 1).timeout(const Duration(milliseconds: 100));
            activeIds.add(currentId);
            await client.disconnect();
          } catch (_) {
            try {
              final client = await ModbusClient.connect(
                config: ConnectionConfig(
                  protocolType: 'TCP',
                  ip: ip,
                  port: port,
                ),
                slaveId: currentId,
              );
              await client.readCoils(address: 0, quantity: 1).timeout(const Duration(milliseconds: 100));
              activeIds.add(currentId);
              await client.disconnect();
            } catch (_) {}
          }
        }());
      }
      await Future.wait(batch);
    }
    return activeIds..sort();
  }

  void stopScan() {
    _subscription?.cancel();
    state = state.copyWith(isScanning: false);
  }
}

final radarProvider = NotifierProvider<RadarNotifier, RadarState>(() {
  return RadarNotifier();
});
