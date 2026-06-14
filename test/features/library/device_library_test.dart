import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/library/device_library_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

void main() {
  group('DeviceLibraryNotifier Unit Tests', () {
    test('Initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(deviceLibraryProvider);
      expect(state.selectedPresetName, isNull);
      expect(state.activeTags, isEmpty);
    });

    test('selectPreset updates active tags and selected name', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceLibraryProvider.notifier);
      final preset = notifier.presets.first;

      notifier.selectPreset(preset);

      final state = container.read(deviceLibraryProvider);
      expect(state.selectedPresetName, preset.name);
      expect(state.activeTags, preset.registerTags);
    });

    test('clearPreset resets selected preset and tags', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceLibraryProvider.notifier);
      final preset = notifier.presets.first;

      notifier.selectPreset(preset);
      notifier.clearPreset();

      final state = container.read(deviceLibraryProvider);
      expect(state.selectedPresetName, isNull);
      expect(state.activeTags, isEmpty);
    });

    test('importJson parses valid JSON correctly and updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceLibraryProvider.notifier);
      
      const jsonPayload = '''
      {
        "name": "Test PLC Device",
        "config": {
          "protocolType": "TCP",
          "ip": "10.0.0.5",
          "port": 502
        },
        "tags": {
          "40001": "Temperature Log",
          "40002": "Pressure Log"
        }
      }
      ''';

      final result = notifier.importJson(jsonPayload);
      expect(result, isNotNull);
      expect(result!['name'], 'Test PLC Device');
      
      final config = result['config'] as ConnectionConfig;
      expect(config.protocolType, 'TCP');
      expect(config.ip, '10.0.0.5');
      expect(config.port, 502);

      final state = container.read(deviceLibraryProvider);
      expect(state.selectedPresetName, 'Test PLC Device');
      expect(state.activeTags[40001], 'Temperature Log');
      expect(state.activeTags[40002], 'Pressure Log');
    });

    test('importJson throws ProfileImportException for invalid JSON structure', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceLibraryProvider.notifier);
      
      // Missing required name and config fields
      const jsonPayload = '{"tags": {}}';

      expect(
        () => notifier.importJson(jsonPayload),
        throwsA(isA<ProfileImportException>()),
      );
    });

    test('exportPreset serializes preset to expected JSON format', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(deviceLibraryProvider.notifier);
      final preset = notifier.presets.first;
      notifier.selectPreset(preset);

      final jsonStr = notifier.exportPreset(
        name: preset.name,
        config: preset.config,
      );

      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      expect(decoded['name'], preset.name);
      expect(decoded['config']['protocolType'], preset.config.protocolType);
      expect(decoded['config']['ip'], preset.config.ip);
      expect(decoded['config']['port'], preset.config.port);
      expect(decoded['tags']['40001'], preset.registerTags[40001]);
    });
  });
}
