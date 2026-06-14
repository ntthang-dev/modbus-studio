import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

class DevicePreset {
  final String name;
  final String description;
  final ConnectionConfig config;
  final Map<int, String> registerTags;

  const DevicePreset({
    required this.name,
    required this.description,
    required this.config,
    required this.registerTags,
  });
}

class DeviceLibraryState {
  final String? selectedPresetName;
  final Map<int, String> activeTags;

  DeviceLibraryState({
    this.selectedPresetName,
    this.activeTags = const {},
  });

  DeviceLibraryState copyWith({
    String? selectedPresetName,
    Map<int, String>? activeTags,
    bool clearPreset = false,
  }) {
    return DeviceLibraryState(
      selectedPresetName: clearPreset ? null : (selectedPresetName ?? this.selectedPresetName),
      activeTags: activeTags ?? this.activeTags,
    );
  }
}

class DeviceLibraryNotifier extends Notifier<DeviceLibraryState> {
  @override
  DeviceLibraryState build() {
    return DeviceLibraryState();
  }

  // Built-in templates library
  final List<DevicePreset> presets = const [
    DevicePreset(
      name: 'Siemens S7-1200 PLC',
      description: 'Industrial PLC telemetry registers (Temp, Pressure, Flow)',
      config: ConnectionConfig(
        protocolType: 'TCP',
        ip: '192.168.1.100',
        port: 502,
      ),
      registerTags: {
        40001: 'Boiler Temperature',
        40002: 'Steam Pressure',
        40003: 'Water Flow Rate',
        40004: 'Feedwater Tank Level',
        40005: 'Exhaust Fan Speed',
      },
    ),
    DevicePreset(
      name: 'Schneider Electric Power Meter',
      description: 'Electricity analyzer mapping active power & voltage lines',
      config: ConnectionConfig(
        protocolType: 'TCP',
        ip: '192.168.1.101',
        port: 502,
      ),
      registerTags: {
        40001: 'Voltage Line 1 to N',
        40002: 'Voltage Line 2 to N',
        40003: 'Voltage Line 3 to N',
        40004: 'Active Power Sum',
        40005: 'Power Factor L1',
      },
    ),
    DevicePreset(
      name: 'Generic Modbus Weather Station',
      description: 'Outdoor environment transmitter registers',
      config: ConnectionConfig(
        protocolType: 'TCP',
        ip: '192.168.1.150',
        port: 502,
      ),
      registerTags: {
        40001: 'Ambient Temperature',
        40002: 'Relative Humidity',
        40003: 'Wind Speed',
        40004: 'Solar Irradiance',
      },
    ),
  ];

  void selectPreset(DevicePreset preset) {
    state = state.copyWith(
      selectedPresetName: preset.name,
      activeTags: preset.registerTags,
    );
  }

  void clearPreset() {
    state = state.copyWith(clearPreset: true, activeTags: {});
  }

  // Parses a JSON profile config and populates configuration
  Map<String, dynamic>? importJson(String jsonStr) {
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final name = data['name'] as String;
      final configMap = data['config'] as Map<String, dynamic>;
      
      final config = ConnectionConfig(
        protocolType: configMap['protocolType'] as String,
        ip: configMap['ip'] as String?,
        port: configMap['port'] as int?,
        portName: configMap['portName'] as String?,
        baudRate: configMap['baudRate'] as int?,
        parity: configMap['parity'] as String?,
        dataBits: configMap['dataBits'] as int?,
        stopBits: configMap['stopBits'] as int?,
      );

      final tagsMapRaw = data['tags'] as Map<String, dynamic>? ?? {};
      final tags = <int, String>{};
      tagsMapRaw.forEach((k, v) {
        final addr = int.tryParse(k);
        if (addr != null) {
          tags[addr] = v.toString();
        }
      });

      state = state.copyWith(
        selectedPresetName: name,
        activeTags: tags,
      );

      return {
        'name': name,
        'config': config,
      };
    } catch (e) {
      debugPrint("Error importing profile JSON: $e");
      return null;
    }
  }

  // Generates JSON profile payload for export
  String exportPreset({
    required String name,
    required ConnectionConfig config,
  }) {
    final Map<String, dynamic> configMap = {
      'protocolType': config.protocolType,
      'ip': config.ip,
      'port': config.port,
      'portName': config.portName,
      'baudRate': config.baudRate,
      'parity': config.parity,
      'dataBits': config.dataBits,
      'stopBits': config.stopBits,
    };

    final Map<String, String> tagsMap = {};
    state.activeTags.forEach((k, v) {
      tagsMap[k.toString()] = v;
    });

    final Map<String, dynamic> payload = {
      'name': name,
      'config': configMap,
      'tags': tagsMap,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}

final deviceLibraryProvider = NotifierProvider<DeviceLibraryNotifier, DeviceLibraryState>(() {
  return DeviceLibraryNotifier();
});
