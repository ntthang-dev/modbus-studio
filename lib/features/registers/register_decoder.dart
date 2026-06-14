import 'dart:typed_data';

class RegisterDecoder {
  /// Decodes raw Modbus 16-bit register words starting at [startIndex] 
  /// into a formatted string representation based on the selected [dataType].
  static String format({
    required List<int> rawRegisters,
    required int startIndex,
    required String dataType, // 'Int16', 'Uint16', 'Int32', 'Uint32', 'Float32', 'Binary', 'Hex', 'Boolean'
    bool swapWords = false,
    double multiplier = 1.0,
    double offset = 0.0,
    String unit = '',
  }) {
    if (rawRegisters.isEmpty || startIndex < 0 || startIndex >= rawRegisters.length) {
      return '0';
    }

    final rawVal = rawRegisters[startIndex];

    // Boolean Type (mainly for FC01/FC02)
    if (dataType == 'Boolean') {
      return rawVal == 1 ? 'ON' : 'OFF';
    }

    // Binary Type
    if (dataType == 'Binary') {
      final binStr = rawVal.toRadixString(2).padLeft(16, '0');
      // Format as groups of 4 bits: 0000 0000 0000 0000
      return '${binStr.substring(0, 4)} ${binStr.substring(4, 8)} ${binStr.substring(8, 12)} ${binStr.substring(12, 16)}';
    }

    // Hex Type
    if (dataType == 'Hex') {
      return '0x${rawVal.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    }

    double value = 0.0;
    bool is32Bit = dataType == 'Int32' || dataType == 'Uint32' || dataType == 'Float32';

    if (is32Bit) {
      // 32-bit types require 2 registers
      if (startIndex + 1 >= rawRegisters.length) {
        return 'N/A'; // Out of bounds for 32-bit reading
      }

      final w1 = rawRegisters[startIndex];
      final w2 = rawRegisters[startIndex + 1];
      
      // Determine word order
      final word1 = swapWords ? w2 : w1;
      final word2 = swapWords ? w1 : w2;

      final byteData = ByteData(4);
      byteData.setUint16(0, word1, Endian.big);
      byteData.setUint16(2, word2, Endian.big);

      if (dataType == 'Float32') {
        value = byteData.getFloat32(0, Endian.big);
      } else if (dataType == 'Int32') {
        value = byteData.getInt32(0, Endian.big).toDouble();
      } else if (dataType == 'Uint32') {
        value = byteData.getUint32(0, Endian.big).toDouble();
      }
    } else {
      // 16-bit types
      if (dataType == 'Int16') {
        // Convert unsigned 16-bit to signed 16-bit
        final signedVal = rawVal > 32767 ? rawVal - 65536 : rawVal;
        value = signedVal.toDouble();
      } else {
        // Default to Uint16
        value = rawVal.toDouble();
      }
    }

    // Apply linear scaling formula: mx + c
    final scaledVal = value * multiplier + offset;

    // Format output: if it's a whole number, don't show trailing .0
    String formattedVal;
    if (scaledVal == scaledVal.roundToDouble()) {
      formattedVal = scaledVal.toInt().toString();
    } else {
      formattedVal = scaledVal.toStringAsFixed(2);
    }

    if (unit.trim().isNotEmpty) {
      return '$formattedVal $unit';
    }
    return formattedVal;
  }
}
