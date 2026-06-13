import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/providers/settings_provider.dart';


class AlarmState {
  final List<AlarmRule> rules;
  final List<AlarmLog> logs;
  final AlarmLog? activeBannerAlarm;

  AlarmState({
    required this.rules,
    required this.logs,
    this.activeBannerAlarm,
  });

  AlarmState copyWith({
    List<AlarmRule>? rules,
    List<AlarmLog>? logs,
    AlarmLog? activeBannerAlarm,
    bool clearBanner = false,
  }) {
    return AlarmState(
      rules: rules ?? this.rules,
      logs: logs ?? this.logs,
      activeBannerAlarm: clearBanner ? null : (activeBannerAlarm ?? this.activeBannerAlarm),
    );
  }
}

class AlarmNotifier extends Notifier<AlarmState> {
  @override
  AlarmState build() {
    // Trigger loading asynchronously
    Future.microtask(() {
      loadRules();
      loadLogs();
    });
    return AlarmState(rules: [], logs: []);
  }

  static const String _dbPath = "historian.db";
  
  // Track active breaches by rule ID to prevent repeat spam logging
  final Set<int> _activeBreaches = {};

  Future<void> loadRules() async {
    try {
      final list = await dbGetRules(dbPath: _dbPath);
      state = state.copyWith(rules: list);
    } catch (e) {
      debugPrint("Error loading alarm rules: $e");
    }
  }

  Future<void> loadLogs() async {
    try {
      final list = await dbGetAlarmLogs(dbPath: _dbPath);
      state = state.copyWith(logs: list);
    } catch (e) {
      debugPrint("Error loading alarm logs: $e");
    }
  }

  Future<void> addRule(AlarmRule rule) async {
    try {
      await dbSaveRule(dbPath: _dbPath, rule: rule);
      await loadRules();
    } catch (e) {
      debugPrint("Error adding alarm rule: $e");
    }
  }

  Future<void> deleteRule(int id) async {
    try {
      await dbDeleteRule(dbPath: _dbPath, id: id);
      // Clean from active breaches if deleted
      _activeBreaches.remove(id);
      await loadRules();
    } catch (e) {
      debugPrint("Error deleting alarm rule: $e");
    }
  }

  Future<void> clearLogs() async {
    try {
      await dbClearAlarmLogs(dbPath: _dbPath);
      await loadLogs();
    } catch (e) {
      debugPrint("Error clearing alarm logs: $e");
    }
  }

  void dismissBanner() {
    state = state.copyWith(clearBanner: true);
  }

  Future<void> evaluateRegisters(List<int> registers) async {
    // Perform database pruning on every tick to cap storage growth
    try {
      final settings = ref.read(settingsProvider);
      await dbPrunePollLogs(dbPath: _dbPath, maxRows: settings.maxLogRows);
      await dbPruneAlarmLogs(dbPath: _dbPath, maxRows: settings.maxLogRows);
    } catch (e) {
      debugPrint("Error pruning SQLite records: $e");
    }

    if (state.rules.isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    bool loggedNewAlarm = false;
    AlarmLog? triggeredBanner;

    for (final rule in state.rules) {
      if (!rule.isEnabled || rule.id == null) continue;

      final ruleIdInt = rule.id!;
      final index = rule.registerAddress - 40001;
      if (index < 0 || index >= registers.length) continue;

      final value = registers[index];
      bool isBreached = false;

      switch (rule.condition) {
        case '>':
          isBreached = value > rule.threshold;
          break;
        case '<':
          isBreached = value < rule.threshold;
          break;
        case '==':
          isBreached = value == rule.threshold;
          break;
        case '!=':
          isBreached = value != rule.threshold;
          break;
      }

      if (isBreached) {
        if (!_activeBreaches.contains(ruleIdInt)) {
          _activeBreaches.add(ruleIdInt);
          final message = "${rule.name}: Reg ${rule.registerAddress} value $value breached threshold ${rule.condition} ${rule.threshold}";
          
          final log = AlarmLog(
            id: null,
            ruleId: rule.id,
            registerAddress: rule.registerAddress,
            value: value,
            message: message,
            severity: rule.severity,
            timestamp: timestamp,
          );

          try {
            await dbLogAlarm(dbPath: _dbPath, log: log);
            loggedNewAlarm = true;
            triggeredBanner = log;
          } catch (e) {
            debugPrint("Error logging alarm: $e");
          }
        }
      } else {
        if (_activeBreaches.contains(ruleIdInt)) {
          _activeBreaches.remove(ruleIdInt);
          final message = "${rule.name} Cleared: Reg ${rule.registerAddress} value $value is nominal";
          
          final log = AlarmLog(
            id: null,
            ruleId: rule.id,
            registerAddress: rule.registerAddress,
            value: value,
            message: message,
            severity: "Nominal",
            timestamp: timestamp,
          );

          try {
            await dbLogAlarm(dbPath: _dbPath, log: log);
            loggedNewAlarm = true;
          } catch (e) {
            debugPrint("Error logging alarm recovery: $e");
          }
        }
      }
    }

    if (loggedNewAlarm) {
      await loadLogs();
    }

    if (triggeredBanner != null) {
      state = state.copyWith(activeBannerAlarm: triggeredBanner);
      
      // Auto dismiss banner after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (state.activeBannerAlarm == triggeredBanner) {
          dismissBanner();
        }
      });
    }
  }

  Future<void> logCustomAlarm(String message, String severity, {int registerAddress = 0, int value = 0}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final log = AlarmLog(
      id: null,
      ruleId: null,
      registerAddress: registerAddress,
      value: value,
      message: message,
      severity: severity,
      timestamp: timestamp,
    );
    try {
      await dbLogAlarm(dbPath: _dbPath, log: log);
      await loadLogs();
      state = state.copyWith(activeBannerAlarm: log);
      Future.delayed(const Duration(seconds: 5), () {
        if (state.activeBannerAlarm == log) {
          dismissBanner();
        }
      });
    } catch (e) {
      debugPrint("Error logging custom alarm: $e");
    }
  }
}

final alarmProvider = NotifierProvider<AlarmNotifier, AlarmState>(() {
  return AlarmNotifier();
});
