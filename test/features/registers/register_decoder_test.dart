import 'package:flutter_test/flutter_test.dart';
import 'package:modbus_studio/features/registers/register_decoder.dart';

void main() {
  group('RegisterDecoder Tests', () {
    test('Decodes Boolean type (FC01/FC02)', () {
      expect(RegisterDecoder.format(rawRegisters: [1], startIndex: 0, dataType: 'Boolean'), 'ON');
      expect(RegisterDecoder.format(rawRegisters: [0], startIndex: 0, dataType: 'Boolean'), 'OFF');
    });

    test('Decodes 16-bit Unsigned (Uint16)', () {
      expect(RegisterDecoder.format(rawRegisters: [123], startIndex: 0, dataType: 'Uint16'), '123');
    });

    test('Decodes 16-bit Signed (Int16)', () {
      expect(RegisterDecoder.format(rawRegisters: [65535], startIndex: 0, dataType: 'Int16'), '-1');
      expect(RegisterDecoder.format(rawRegisters: [32767], startIndex: 0, dataType: 'Int16'), '32767');
      expect(RegisterDecoder.format(rawRegisters: [32768], startIndex: 0, dataType: 'Int16'), '-32768');
    });

    test('Decodes Hex and Binary types', () {
      expect(RegisterDecoder.format(rawRegisters: [255], startIndex: 0, dataType: 'Hex'), '0x00FF');
      expect(RegisterDecoder.format(rawRegisters: [5], startIndex: 0, dataType: 'Binary'), '0000 0000 0000 0101');
    });

    test('Decodes 32-bit Float (Float32)', () {
      // 1.0 representation: 0x3F800000 -> w1 = 0x3F80 (16256), w2 = 0x0000 (0)
      expect(RegisterDecoder.format(rawRegisters: [16256, 0], startIndex: 0, dataType: 'Float32'), '1');
      // Swapped words: w1 = 0, w2 = 16256
      expect(RegisterDecoder.format(rawRegisters: [0, 16256], startIndex: 0, dataType: 'Float32', swapWords: true), '1');
    });

    test('Applies multiplier, offset, and unit', () {
      // 100 * 0.1 - 40 = -30
      expect(
        RegisterDecoder.format(
          rawRegisters: [100],
          startIndex: 0,
          dataType: 'Uint16',
          multiplier: 0.1,
          offset: -40.0,
          unit: 'C',
        ),
        '-30 C',
      );
    });
  });
}
