import 'package:flutter_test/flutter_test.dart';
import 'package:modbus_studio/features/inspector/device_inspector_screen.dart';

void main() {
  group('InspectorState', () {
    test('initializes with default values', () {
      final state = InspectorState();
      
      expect(state.isConnecting, false);
      expect(state.isConnected, false);
      expect(state.error, isNull);
      expect(state.registers, isEmpty);
    });

    test('copyWith updates specific fields while keeping others', () {
      final state = InspectorState(isConnecting: true);
      
      final updated = state.copyWith(isConnected: true, isConnecting: false);
      
      expect(updated.isConnecting, false);
      expect(updated.isConnected, true);
      expect(updated.error, isNull);
      expect(updated.registers, isEmpty);
    });

    test('copyWith clearError flag clears the error', () {
      final state = InspectorState(error: 'Connection timeout');
      
      final updated = state.copyWith(clearError: true);
      
      expect(updated.error, isNull);
    });
  });
}
