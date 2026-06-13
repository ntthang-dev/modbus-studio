import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/providers/connection_provider.dart';

class AutomationState {
  final List<ScheduledWrite> scheduledWrites;
  final List<String> logs;

  AutomationState({
    required this.scheduledWrites,
    this.logs = const [],
  });

  AutomationState copyWith({
    List<ScheduledWrite>? scheduledWrites,
    List<String>? logs,
  }) {
    return AutomationState(
      scheduledWrites: scheduledWrites ?? this.scheduledWrites,
      logs: logs ?? this.logs,
    );
  }
}

class AutomationNotifier extends Notifier<AutomationState> {
  Timer? _timer;
  final Map<int, int> _elapsedSeconds = {};
  static const String _dbPath = "historian.db";

  @override
  AutomationState build() {
    // Load scheduled writes from SQLite
    Future.microtask(() => loadScheduledWrites());

    // Listen to connection state to start/stop the scheduler timer
    ref.listen<ConnectionStatus>(connectionProvider, (prev, next) {
      if (next.isConnected) {
        _startTimer();
      } else {
        _stopTimer();
      }
    });

    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _elapsedSeconds.clear();
    });

    return AutomationState(scheduledWrites: []);
  }

  Future<void> loadScheduledWrites() async {
    try {
      final list = await dbGetScheduledWrites(dbPath: _dbPath);
      state = state.copyWith(scheduledWrites: list);
    } catch (e) {
      debugPrint("Error loading scheduled writes: $e");
    }
  }

  Future<void> saveScheduledWrite(ScheduledWrite write) async {
    try {
      await dbSaveScheduledWrite(dbPath: _dbPath, write: write);
      await loadScheduledWrites();
      _log("Saved scheduled write: ${write.isCoil ? 'Coil' : 'Register'} ${write.address} (interval: ${write.intervalSecs}s)");
    } catch (e) {
      debugPrint("Error saving scheduled write: $e");
    }
  }

  Future<void> deleteScheduledWrite(int id) async {
    try {
      await dbDeleteScheduledWrite(dbPath: _dbPath, id: id);
      _elapsedSeconds.remove(id);
      await loadScheduledWrites();
      _log("Deleted scheduled write ID: $id");
    } catch (e) {
      debugPrint("Error deleting scheduled write: $e");
    }
  }

  Future<void> toggleScheduledWrite(ScheduledWrite write) async {
    final updated = ScheduledWrite(
      id: write.id,
      address: write.address,
      value: write.value,
      intervalSecs: write.intervalSecs,
      isCoil: write.isCoil,
      isEnabled: !write.isEnabled,
    );
    await saveScheduledWrite(updated);
  }

  void _startTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });
    _log("Automation Scheduler started");
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _elapsedSeconds.clear();
    _log("Automation Scheduler stopped");
  }

  void _tick() {
    final connState = ref.read(connectionProvider);
    if (!connState.isConnected) {
      _stopTimer();
      return;
    }

    final activeWrites = state.scheduledWrites.where((w) => w.isEnabled).toList();
    if (activeWrites.isEmpty) return;

    for (final write in activeWrites) {
      final id = write.id;
      if (id == null) continue;

      final elapsed = (_elapsedSeconds[id] ?? 0) + 1;
      if (elapsed >= write.intervalSecs) {
        _elapsedSeconds[id] = 0;
        _executeWrite(write);
      } else {
        _elapsedSeconds[id] = elapsed;
      }
    }
  }

  Future<void> _executeWrite(ScheduledWrite write) async {
    final connNotifier = ref.read(connectionProvider.notifier);
    final timeStr = DateTime.now().toLocal().toString().split('.').first;
    
    try {
      if (write.isCoil) {
        final val = write.value != 0;
        await connNotifier.writeCoil(write.address, val);
        _log("[$timeStr] Autowrite Coil: ${write.address} -> $val");
      } else {
        await connNotifier.writeRegister(write.address, write.value);
        _log("[$timeStr] Autowrite Register: ${write.address} -> ${write.value}");
      }
    } catch (e) {
      _log("[$timeStr] Autowrite Error (${write.address}): $e");
    }
  }

  void _log(String message) {
    state = state.copyWith(
      logs: [message, ...state.logs].take(100).toList(),
    );
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }
}

final automationProvider = NotifierProvider<AutomationNotifier, AutomationState>(() {
  return AutomationNotifier();
});
