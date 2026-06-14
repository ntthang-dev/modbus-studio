import 'dart:typed_data';

class RegisterDecoder {
  /// Decodes raw Modbus 16-bit register words starting at [startIndex] 
  /// into a formatted string representation based on the selected [dataType].
  static String format({
    required List<int> rawRegisters,
    required int startIndex,
    required String dataType, // 'Int16', 'Uint16', 'Int32', 'Uint32', 'Float32', 'Binary', 'Hex', 'Boolean', 'String', 'Bitfield', 'Enum', 'DateTime32', 'DateTime64'
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
      return '${binStr.substring(0, 4)} ${binStr.substring(4, 8)} ${binStr.substring(8, 12)} ${binStr.substring(12, 16)}';
    }

    // Hex Type
    if (dataType == 'Hex') {
      return '0x${rawVal.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    }

    // String / ASCII Type
    if (dataType == 'String') {
      final chars = <int>[];
      for (int i = startIndex; i < rawRegisters.length; i++) {
        final reg = rawRegisters[i];
        final byte1 = (reg >> 8) & 0xFF;
        final byte2 = reg & 0xFF;
        
        if (byte1 == 0) break;
        chars.add(byte1);
        
        if (byte2 == 0) break;
        chars.add(byte2);
      }
      return String.fromCharCodes(chars).trim();
    }

    // Bitfield / BITMAP Type
    if (dataType == 'Bitfield') {
      final activeBits = <int>[];
      for (int i = 0; i < 16; i++) {
        if ((rawVal & (1 << i)) != 0) {
          activeBits.add(i);
        }
      }
      return activeBits.isEmpty ? 'None' : activeBits.join(',');
    }

    // Enum Type
    if (dataType == 'Enum') {
      if (unit.trim().isEmpty) {
        return rawVal.toString();
      }
      try {
        final parts = unit.split(',');
        for (final part in parts) {
          final kv = part.split(':');
          if (kv.length == 2) {
            final k = int.parse(kv[0].trim());
            final v = kv[1].trim();
            if (k == rawVal) {
              return v;
            }
          }
        }
      } catch (e) {
        // fallback
      }
      return rawVal.toString();
    }

    // DateTime Type (32-bit seconds or 64-bit milliseconds)
    if (dataType == 'DateTime32' || dataType == 'DateTime64') {
      final is64 = dataType == 'DateTime64';
      final requiredRegs = is64 ? 4 : 2;
      if (startIndex + requiredRegs > rawRegisters.length) {
        return 'N/A';
      }

      int timestampMs = 0;
      if (is64) {
        final w1 = rawRegisters[startIndex];
        final w2 = rawRegisters[startIndex + 1];
        final w3 = rawRegisters[startIndex + 2];
        final w4 = rawRegisters[startIndex + 3];

        final byteData = ByteData(8);
        byteData.setUint16(0, w1, Endian.big);
        byteData.setUint16(2, w2, Endian.big);
        byteData.setUint16(4, w3, Endian.big);
        byteData.setUint16(6, w4, Endian.big);
        timestampMs = byteData.getUint64(0, Endian.big);
      } else {
        final w1 = rawRegisters[startIndex];
        final w2 = rawRegisters[startIndex + 1];

        final byteData = ByteData(4);
        byteData.setUint16(0, w1, Endian.big);
        byteData.setUint16(2, w2, Endian.big);
        final timestampSec = byteData.getUint32(0, Endian.big);
        timestampMs = timestampSec * 1000;
      }

      try {
        final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'Invalid Date';
      }
    }

    double value = 0.0;
    bool is32Bit = dataType == 'Int32' || dataType == 'Uint32' || dataType == 'Float32';

    if (is32Bit) {
      if (startIndex + 1 >= rawRegisters.length) {
        return 'N/A';
      }

      final w1 = rawRegisters[startIndex];
      final w2 = rawRegisters[startIndex + 1];
      
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
      if (dataType == 'Int16') {
        final signedVal = rawVal > 32767 ? rawVal - 65536 : rawVal;
        value = signedVal.toDouble();
      } else {
        value = rawVal.toDouble();
      }
    }

    final scaledVal = value * multiplier + offset;

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

  /// Decodes raw Modbus 16-bit registers into a double value (if numeric/boolean).
  /// Returns null if the dataType cannot be represented as a double (e.g. String).
  static double? decodeToDouble({
    required List<int> rawRegisters,
    required int startIndex,
    required String dataType,
    bool swapWords = false,
    double multiplier = 1.0,
    double offset = 0.0,
  }) {
    if (rawRegisters.isEmpty || startIndex < 0 || startIndex >= rawRegisters.length) {
      return null;
    }
    final rawVal = rawRegisters[startIndex];

    if (dataType == 'Boolean') {
      return rawVal == 1 ? 1.0 : 0.0;
    }
    if (dataType == 'Binary' || dataType == 'Hex' || dataType == 'Bitfield' || dataType == 'Enum') {
      return rawVal.toDouble();
    }
    if (dataType == 'DateTime32' || dataType == 'DateTime64') {
      final is64 = dataType == 'DateTime64';
      final requiredRegs = is64 ? 4 : 2;
      if (startIndex + requiredRegs > rawRegisters.length) {
        return null;
      }
      if (is64) {
        final w1 = rawRegisters[startIndex];
        final w2 = rawRegisters[startIndex + 1];
        final w3 = rawRegisters[startIndex + 2];
        final w4 = rawRegisters[startIndex + 3];
        final byteData = ByteData(8);
        byteData.setUint16(0, w1, Endian.big);
        byteData.setUint16(2, w2, Endian.big);
        byteData.setUint16(4, w3, Endian.big);
        byteData.setUint16(6, w4, Endian.big);
        return byteData.getUint64(0, Endian.big).toDouble();
      } else {
        final w1 = rawRegisters[startIndex];
        final w2 = rawRegisters[startIndex + 1];
        final byteData = ByteData(4);
        byteData.setUint16(0, w1, Endian.big);
        byteData.setUint16(2, w2, Endian.big);
        return byteData.getUint32(0, Endian.big).toDouble();
      }
    }
    if (dataType == 'String') {
      return null;
    }

    double value = 0.0;
    bool is32Bit = dataType == 'Int32' || dataType == 'Uint32' || dataType == 'Float32';
    if (is32Bit) {
      if (startIndex + 1 >= rawRegisters.length) {
        return null;
      }
      final w1 = rawRegisters[startIndex];
      final w2 = rawRegisters[startIndex + 1];
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
      if (dataType == 'Int16') {
        final signedVal = rawVal > 32767 ? rawVal - 65536 : rawVal;
        value = signedVal.toDouble();
      } else {
        value = rawVal.toDouble();
      }
    }
    return value * multiplier + offset;
  }
}
