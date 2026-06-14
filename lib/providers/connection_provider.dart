import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/client.dart';
import 'package:modbus_studio/src/rust/api/historian.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';


class ConnectionStatus {
  final String? activeIp;
  final ConnectionConfig? activeConfig;
  final bool isConnecting;
  final bool isConnected;
  final String? error;
  final List<int> registers;
  final bool isWriting;
  final String? writeResult;

  ConnectionStatus({
    this.activeIp,
    this.activeConfig,
    this.isConnecting = false,
    this.isConnected = false,
    this.error,
    this.registers = const [],
    this.isWriting = false,
    this.writeResult,
  });

  ConnectionStatus copyWith({
    String? activeIp,
    ConnectionConfig? activeConfig,
    bool? isConnecting,
    bool? isConnected,
    String? error,
    List<int>? registers,
    bool? isWriting,
    String? writeResult,
    bool clearActiveIp = false,
    bool clearActiveConfig = false,
    bool clearError = false,
    bool clearWriteResult = false,
  }) {
    return ConnectionStatus(
      activeIp: clearActiveIp ? null : (activeIp ?? this.activeIp),
      activeConfig: clearActiveConfig ? null : (activeConfig ?? this.activeConfig),
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      error: clearError ? null : (error ?? this.error),
      registers: registers ?? this.registers,
      isWriting: isWriting ?? this.isWriting,
      writeResult: clearWriteResult ? null : (writeResult ?? this.writeResult),
    );
  }
}

class ConnectionNotifier extends Notifier<ConnectionStatus> {
  ModbusClient? _client;
  StreamSubscription<HistorianData>? _historianSubscription;

  @override
  ConnectionStatus build() {
    // Clean up when the provider is destroyed
    ref.onDispose(() {
      _cleanup();
    });
    return ConnectionStatus();
  }

  void _cleanup() {
    _historianSubscription?.cancel();
    _historianSubscription = null;
    try {
      _client?.disconnect();
    } catch (e) {
      debugPrint("Error disconnecting client during cleanup: $e");
    }
    _client = null;
  }

  Future<void> connect(ConnectionConfig config, {int slaveId = 1}) async {
    final deviceKey = (config.protocolType == 'TCP' || config.protocolType == 'RTU_TCP')
        ? config.ip ?? ''
        : config.portName ?? '';

    if (state.isConnected && state.activeIp == deviceKey) return;

    _cleanup();
    state = ConnectionStatus(activeIp: deviceKey, activeConfig: config, isConnecting: true);

    try {
      // 1. Connect the command client
      final client = await ModbusClient.connect(config: config, slaveId: slaveId);
      _client = client;

      state = state.copyWith(
        isConnecting: false,
        isConnected: true,
        clearError: true,
      );

      // 2. Start the historian stream loop
      final stream = startHistorianLoop(
        config: config,
        slaveId: slaveId,
        dbPath: "historian.db",
      );

      _historianSubscription = stream.listen(
        (HistorianData data) {
          if (data.error != null) {
            state = state.copyWith(error: "Historian: ${data.error}");
          } else {
            state = state.copyWith(
              registers: data.registers.toList(),
              clearError: true,
            );
            ref.read(alarmProvider.notifier).evaluateRegisters(data.registers);
          }
        },
        onError: (err) {
          state = state.copyWith(error: "Stream error: $err");
        },
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        error: e.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    _cleanup();
    state = ConnectionStatus();
  }

  Future<void> writeCoil(int address, bool value) async {
    if (_client == null || !state.isConnected) {
      throw Exception("Not connected");
    }

    state = state.copyWith(isWriting: true, clearWriteResult: true);
    try {
      await _client!.writeSingleCoil(address: address, value: value);
      state = state.copyWith(isWriting: false, writeResult: "Coil Write Success");
    } catch (e) {
      state = state.copyWith(isWriting: false, writeResult: "Write Error: $e");
      rethrow;
    }
  }

  Future<void> writeRegister(int address, int value) async {
    if (_client == null || !state.isConnected) {
      throw Exception("Not connected");
    }

    state = state.copyWith(isWriting: true, clearWriteResult: true);
    try {
      await _client!.writeSingleRegister(address: address, value: value);
      state = state.copyWith(isWriting: false, writeResult: "Register Write Success");
    } catch (e) {
      state = state.copyWith(isWriting: false, writeResult: "Write Error: $e");
      rethrow;
    }
  }

  // --- Profile database helpers ---
  Future<List<ConnectionProfile>> fetchProfiles() async {
    try {
      return await dbGetProfiles(dbPath: "historian.db");
    } catch (e) {
      debugPrint("Error fetching connection profiles: $e");
      return [];
    }
  }

  Future<void> saveProfile(ConnectionProfile profile) async {
    try {
      await dbSaveProfile(dbPath: "historian.db", profile: profile);
    } catch (e) {
      debugPrint("Error saving connection profile: $e");
      rethrow;
    }
  }

  Future<void> deleteProfile(int id) async {
    try {
      await dbDeleteProfile(dbPath: "historian.db", id: id);
    } catch (e) {
      debugPrint("Error deleting connection profile: $e");
      rethrow;
    }
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionStatus>(() {
  return ConnectionNotifier();
});
