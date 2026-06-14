import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final int maxLogRows;
  final bool writeProtection;
  final int responseTimeoutMs;

  SettingsState({
    this.maxLogRows = 1000,
    this.writeProtection = true,
    this.responseTimeoutMs = 3000,
  });

  SettingsState copyWith({
    int? maxLogRows,
    bool? writeProtection,
    int? responseTimeoutMs,
  }) {
    return SettingsState(
      maxLogRows: maxLogRows ?? this.maxLogRows,
      writeProtection: writeProtection ?? this.writeProtection,
      responseTimeoutMs: responseTimeoutMs ?? this.responseTimeoutMs,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    return SettingsState();
  }

  void setMaxLogRows(int limit) {
    state = state.copyWith(maxLogRows: limit);
  }

  void setWriteProtection(bool enabled) {
    state = state.copyWith(writeProtection: enabled);
  }

  void setResponseTimeoutMs(int timeout) {
    state = state.copyWith(responseTimeoutMs: timeout);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
