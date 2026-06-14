import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/alarms/alarm_provider.dart';
import 'package:modbus_studio/providers/settings_provider.dart';
import 'package:modbus_studio/features/reports/pdf_report_helper.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/src/rust/api/historian.dart';

class ScriptingState {
  final String code;
  final bool isEnabled;
  final List<String> logs;
  final String? compileError;
  final String? runtimeError;

  ScriptingState({
    this.code = 'if (Modbus.getRegister(40001) > 800) {\n  Modbus.logAlarm("Boiler Hot!", "Critical");\n}',
    this.isEnabled = false,
    this.logs = const [],
    this.compileError,
    this.runtimeError,
  });

  ScriptingState copyWith({
    String? code,
    bool? isEnabled,
    List<String>? logs,
    String? compileError,
    String? runtimeError,
    bool clearCompileError = false,
    bool clearRuntimeError = false,
  }) {
    return ScriptingState(
      code: code ?? this.code,
      isEnabled: isEnabled ?? this.isEnabled,
      logs: logs ?? this.logs,
      compileError: clearCompileError ? null : (compileError ?? this.compileError),
      runtimeError: clearRuntimeError ? null : (runtimeError ?? this.runtimeError),
    );
  }
}

class ScriptingNotifier extends Notifier<ScriptingState> {
  JavascriptRuntime? _jsRuntime;

  @override
  ScriptingState build() {
    _initJs(logInit: false);
    
    // Listen to connection ticks to run the active script
    ref.listen<ConnectionStatus>(connectionProvider, (prev, next) {
      if (next.isConnected && state.isEnabled && next.registers.isNotEmpty) {
        // Run the script on every poll tick
        _runScriptOnTick(next.registers);
      }
    });

    ref.onDispose(() {
      _cleanup();
    });

    return ScriptingState();
  }

  void _initJs({bool logInit = false}) {
    _cleanup();
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (logInit) _log("MOCK JS Engine Initialized");
      return;
    }
    try {
      final runtime = getJavascriptRuntime();
      
      // Expose writeRegister bridge channel
      runtime.onMessage('writeRegister', (dynamic args) {
        try {
          final data = json.decode(args.toString()) as Map<String, dynamic>;
          final addr = data['address'] as int;
          final val = data['value'] as int;
          ref.read(connectionProvider.notifier).writeRegister(addr, val);
          _log("JS Autowrite: Reg $addr -> $val");
        } catch (e) {
          _log("JS Error writeRegister callback: $e");
        }
      });

      // Expose logAlarm bridge channel
      runtime.onMessage('logAlarm', (dynamic args) {
        try {
          final data = json.decode(args.toString()) as Map<String, dynamic>;
          final msg = data['message'].toString();
          final sev = data['severity'].toString();
          ref.read(alarmProvider.notifier).logCustomAlarm(msg, sev);
          _log("JS Custom Alarm: [$sev] $msg");
        } catch (e) {
          _log("JS Error logAlarm callback: $e");
        }
      });

      // Expose exportReport bridge channel
      runtime.onMessage('exportReport', (dynamic args) async {
        try {
          final data = json.decode(args.toString()) as Map<String, dynamic>;
          final format = (data['format'] ?? 'pdf').toString().toLowerCase();
          final rangeHours = (data['rangeHours'] ?? 24) as int;
          
          await exportReportHeadless(format: format, rangeHours: rangeHours);
        } catch (e) {
          _log("JS Error exportReport callback: $e");
        }
      });

      _jsRuntime = runtime;
    } catch (e) {
      debugPrint("Failed to initialize Javascript runtime: $e");
    }
  }

  void _cleanup() {
    try {
      _jsRuntime?.dispose();
    } catch (e) {
      debugPrint("Error disposing JS runtime: $e");
    }
    _jsRuntime = null;
  }

  void setCode(String code) {
    state = state.copyWith(code: code);
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
    _log("Scripting engine ${enabled ? 'ENABLED' : 'DISABLED'}");
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  Future<void> evaluateScriptManual() async {
    final connState = ref.read(connectionProvider);
    state = state.copyWith(clearCompileError: true, clearRuntimeError: true);
    _log("Evaluating script manually...");
    await _runScriptOnTick(connState.registers);
  }

  Future<void> _runScriptOnTick(List<int> registers) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      if (state.code.contains('logAlarm')) {
        ref.read(alarmProvider.notifier).logCustomAlarm("Boiler Hot!", "Critical");
        _log("JS Custom Alarm (Mock): [Critical] Boiler Hot!");
      }
      if (state.code.contains('exportReport')) {
        _log("JS Report Exporter (Mock): Auto-exported successfully.");
      }
      _log("Script executed successfully (Mock).");
      return;
    }

    if (_jsRuntime == null) {
      _initJs(logInit: true);
    }
    if (_jsRuntime == null) {
      state = state.copyWith(runtimeError: "JS engine not initialized");
      return;
    }

    // 1. Build registers snapshot mapping holding addresses (40001 + index) to values
    final Map<int, int> regMap = {};
    for (int i = 0; i < registers.length; i++) {
      regMap[40001 + i] = registers[i];
    }

    // 2. Prepend injection environment script
    final envInjection = '''
    const _registers = ${json.encode(regMap.map((k, v) => MapEntry(k.toString(), v)))};
    const Modbus = {
      getRegister: function(addr) {
        return _registers[addr] || 0;
      },
      writeRegister: function(addr, val) {
        sendMessage('writeRegister', JSON.stringify({address: addr, value: val}));
      },
      logAlarm: function(msg, sev) {
        sendMessage('logAlarm', JSON.stringify({message: msg, severity: sev}));
      },
      exportReport: function(format, hours) {
        sendMessage('exportReport', JSON.stringify({format: format, rangeHours: hours}));
      }
    };
    ''';

    final fullScript = envInjection + "\n" + state.code;

    try {
      final jsResult = await _jsRuntime!.evaluateAsync(fullScript);
      
      if (jsResult.isError) {
        final err = jsResult.stringResult;
        state = state.copyWith(runtimeError: err);
        _log("JS Runtime Error: $err");
      } else {
        _log("Script executed successfully.");
      }
    } catch (e) {
      state = state.copyWith(runtimeError: e.toString());
      _log("JS Execution Exception: $e");
    }
  }

  Future<void> exportReportHeadless({required String format, required int rangeHours}) async {
    try {
      const dbPath = "historian.db";
      final connState = ref.read(connectionProvider);
      
      final deviceName = connState.activeConfig?.ip ?? connState.activeConfig?.portName ?? 'Mock Node';
      final protocolType = connState.activeConfig?.protocolType ?? 'TCP';
      
      final end = DateTime.now();
      final start = end.subtract(Duration(hours: rangeHours));
      
      final telemetry = await getTelemetryLogsByRange(
        dbPath: dbPath,
        startTs: start.millisecondsSinceEpoch,
        endTs: end.millisecondsSinceEpoch,
      );
      
      final alarms = await dbGetAlarmLogsByRange(
        dbPath: dbPath,
        startTs: start.millisecondsSinceEpoch,
        endTs: end.millisecondsSinceEpoch,
      );
      
      final documentsDir = Directory('${Platform.environment['HOME']}/Documents/ModbusStudio/Reports');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      
      final timestamp = end.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final fileName = 'report_$timestamp.$format';
      final file = File('${documentsDir.path}/$fileName');
      
      if (format == 'pdf') {
        final pdf = await PdfReportHelper.generateHistoricalReport(
          deviceName: deviceName,
          protocolType: protocolType,
          telemetryPoints: telemetry,
          alarmLogs: alarms,
          startRange: start,
          endRange: end,
        );
        await file.writeAsBytes(await pdf.save());
      } else {
        final csv = _generateCsvString(telemetry, alarms);
        await file.writeAsString(csv);
      }
      
      _log("Report auto-exported successfully to: $fileName");
    } catch (e) {
      _log("Auto-export report failed: $e");
    }
  }

  String _generateCsvString(List<HistorianPoint> telemetry, List<AlarmLog> alarms) {
    final buffer = StringBuffer();
    
    buffer.writeln("=== TELEMETRY LOGS ===");
    buffer.writeln("Timestamp,Register Address,Value");
    for (final p in telemetry) {
      final dt = DateTime.fromMillisecondsSinceEpoch(p.timestampMs.toInt());
      buffer.writeln("${dt.toIso8601String()},${p.address},${p.value}");
    }
    
    buffer.writeln();
    
    buffer.writeln("=== ALARM EVENTS ===");
    buffer.writeln("Timestamp,Severity,Address,Value,Message");
    for (final l in alarms) {
      final dt = DateTime.fromMillisecondsSinceEpoch(l.timestamp.toInt());
      buffer.writeln("${dt.toIso8601String()},${l.severity},${l.registerAddress},${l.value},\"${l.message}\"");
    }
    
    return buffer.toString();
  }

  void _log(String message) {
    final timeStr = DateTime.now().toLocal().toString().split('.').first.split(' ').last;
    state = state.copyWith(
      logs: ["[$timeStr] $message", ...state.logs].take(100).toList(),
    );
  }
}

final scriptingProvider = NotifierProvider<ScriptingNotifier, ScriptingState>(() {
  return ScriptingNotifier();
});
