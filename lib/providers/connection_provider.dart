import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/client.dart';
import 'package:modbus_studio/src/rust/api/historian.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';
import 'package:modbus_studio/features/registers/register_decoder.dart';


class ConnectionStatus {
  final String? activeIp;
  final ConnectionConfig? activeConfig;
  final bool isConnecting;
  final bool isConnected;
  final String? error;
  final List<int> registers;
  final bool isWriting;
  final String? writeResult;
  final int functionCode;
  final int startAddress;
  final int quantity;

  ConnectionStatus({
    this.activeIp,
    this.activeConfig,
    this.isConnecting = false,
    this.isConnected = false,
    this.error,
    this.registers = const [],
    this.isWriting = false,
    this.writeResult,
    this.functionCode = 3,
    this.startAddress = 0,
    this.quantity = 100,
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
    int? functionCode,
    int? startAddress,
    int? quantity,
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
      functionCode: functionCode ?? this.functionCode,
      startAddress: startAddress ?? this.startAddress,
      quantity: quantity ?? this.quantity,
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
    ref.read(sparklineProvider.notifier).clear();
  }

  Future<void> connect(ConnectionConfig config, {int slaveId = 1}) async {
    final deviceKey = (config.protocolType == 'TCP' || config.protocolType == 'RTU_TCP')
        ? config.ip ?? ''
        : config.portName ?? '';

    if (state.isConnected && state.activeIp == deviceKey) return;

    _cleanup();
    state = ConnectionStatus(
      activeIp: deviceKey,
      activeConfig: config,
      isConnecting: true,
      quantity: 100,
    );

    try {
      // 1. Connect the command client
      final client = await ModbusClient.connect(config: config, slaveId: slaveId);
      _client = client;

      state = state.copyWith(
        isConnecting: false,
        isConnected: true,
        clearError: true,
      );

      // Load register configs for this device key
      await ref.read(registerConfigProvider.notifier).loadConfigs(deviceKey);

      // 2. Start the historian stream loop
      final stream = startHistorianLoop(
        config: config,
        slaveId: slaveId,
        dbPath: "historian.db",
        functionCode: state.functionCode,
        startAddress: state.startAddress,
        quantity: state.quantity,
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
            final configs = ref.read(registerConfigProvider);
            final defaultType = (state.functionCode == 1 || state.functionCode == 2) ? 'Boolean' : 'Uint16';
            final addressPrefix = switch (state.functionCode) {
              1 => 1,
              2 => 10001,
              3 => 40001,
              4 => 30001,
              _ => 40001,
            };
            final newValues = <int, double>{};
            for (int i = 0; i < data.registers.length; i++) {
              final address = addressPrefix + state.startAddress + i;
              final config = configs[address];
              final doubleVal = RegisterDecoder.decodeToDouble(
                rawRegisters: data.registers.toList(),
                startIndex: i,
                dataType: config?.dataType ?? defaultType,
                multiplier: config?.multiplier ?? 1.0,
                offset: config?.offset ?? 0.0,
              );
              if (doubleVal != null) {
                newValues[address] = doubleVal;
              }
            }
            if (newValues.isNotEmpty) {
              ref.read(sparklineProvider.notifier).addValues(newValues);
            }
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

  void updatePollConfig(int functionCode, int startAddress, int quantity) {
    if (!state.isConnected) return;
    
    state = state.copyWith(
      functionCode: functionCode,
      startAddress: startAddress,
      quantity: quantity,
      registers: const [],
    );

    _historianSubscription?.cancel();
    _historianSubscription = null;

    final config = state.activeConfig!;
    final slaveId = 1;

    final stream = startHistorianLoop(
      config: config,
      slaveId: slaveId,
      dbPath: "historian.db",
      functionCode: functionCode,
      startAddress: startAddress,
      quantity: quantity,
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
          final configs = ref.read(registerConfigProvider);
          final defaultType = (state.functionCode == 1 || state.functionCode == 2) ? 'Boolean' : 'Uint16';
          final addressPrefix = switch (state.functionCode) {
            1 => 1,
            2 => 10001,
            3 => 40001,
            4 => 30001,
            _ => 40001,
          };
          final newValues = <int, double>{};
          for (int i = 0; i < data.registers.length; i++) {
            final address = addressPrefix + state.startAddress + i;
            final config = configs[address];
            final doubleVal = RegisterDecoder.decodeToDouble(
              rawRegisters: data.registers.toList(),
              startIndex: i,
              dataType: config?.dataType ?? defaultType,
              multiplier: config?.multiplier ?? 1.0,
              offset: config?.offset ?? 0.0,
            );
            if (doubleVal != null) {
              newValues[address] = doubleVal;
            }
          }
          if (newValues.isNotEmpty) {
            ref.read(sparklineProvider.notifier).addValues(newValues);
          }
        }
      },
      onError: (err) {
        state = state.copyWith(error: "Stream error: $err");
      },
    );
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, ConnectionStatus>(() {
  return ConnectionNotifier();
});

class RegisterConfigNotifier extends Notifier<Map<int, RegisterConfig>> {
  @override
  Map<int, RegisterConfig> build() {
    return const {};
  }

  Future<void> loadConfigs(String deviceKey) async {
    try {
      final list = await dbGetRegisterConfigs(dbPath: "historian.db", deviceKey: deviceKey);
      final map = <int, RegisterConfig>{};
      for (final cfg in list) {
        map[cfg.address] = cfg;
      }
      state = map;
    } catch (e) {
      debugPrint("Error loading register configs: $e");
    }
  }

  Future<void> saveConfig(RegisterConfig config) async {
    try {
      await dbSaveRegisterConfig(dbPath: "historian.db", config: config);
      final map = Map<int, RegisterConfig>.from(state);
      map[config.address] = config;
      state = map;
    } catch (e) {
      debugPrint("Error saving register config: $e");
    }
  }
}

final registerConfigProvider =
    NotifierProvider<RegisterConfigNotifier, Map<int, RegisterConfig>>(() {
  return RegisterConfigNotifier();
});

class SparklineNotifier extends Notifier<Map<int, List<double>>> {
  @override
  Map<int, List<double>> build() {
    return const {};
  }

  void addValues(Map<int, double> newValues) {
    final next = Map<int, List<double>>.from(state);
    newValues.forEach((address, value) {
      final list = List<double>.from(next[address] ?? []);
      list.add(value);
      if (list.length > 25) {
        list.removeAt(0);
      }
      next[address] = list;
    });
    state = next;
  }

  void clear() {
    state = const {};
  }
}

final sparklineProvider =
    NotifierProvider<SparklineNotifier, Map<int, List<double>>>(() {
  return SparklineNotifier();
});
