import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppScreen {
  hub,
  scanner,
  registers,
  analyzer,
  logger,
  charts,
  operations,
  simulator,
  tags,
  alarms,
  scripting,
  reports,
  settings,
  automation,
}

class UiState {
  final AppScreen currentScreen;
  final bool isInspectorOpen;
  final bool isSidebarCollapsed;
  final bool isFieldMode; // Outdoor high contrast mode
  final double densityScale; // 0.8 for compact, 1.0 for regular, 1.2 for large

  UiState({
    this.currentScreen = AppScreen.hub,
    this.isInspectorOpen = true,
    this.isSidebarCollapsed = false,
    this.isFieldMode = false,
    this.densityScale = 1.0,
  });

  UiState copyWith({
    AppScreen? currentScreen,
    bool? isInspectorOpen,
    bool? isSidebarCollapsed,
    bool? isFieldMode,
    double? densityScale,
  }) {
    return UiState(
      currentScreen: currentScreen ?? this.currentScreen,
      isInspectorOpen: isInspectorOpen ?? this.isInspectorOpen,
      isSidebarCollapsed: isSidebarCollapsed ?? this.isSidebarCollapsed,
      isFieldMode: isFieldMode ?? this.isFieldMode,
      densityScale: densityScale ?? this.densityScale,
    );
  }
}

class UiNotifier extends Notifier<UiState> {
  @override
  UiState build() {
    return UiState();
  }

  void setScreen(AppScreen screen) {
    state = state.copyWith(currentScreen: screen);
  }

  void toggleInspector() {
    state = state.copyWith(isInspectorOpen: !state.isInspectorOpen);
  }

  void setInspectorOpen(bool open) {
    state = state.copyWith(isInspectorOpen: open);
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarCollapsed: !state.isSidebarCollapsed);
  }

  void toggleFieldMode() {
    state = state.copyWith(isFieldMode: !state.isFieldMode);
  }

  void setDensityScale(double scale) {
    state = state.copyWith(densityScale: scale);
  }
}

final uiProvider = NotifierProvider<UiNotifier, UiState>(() {
  return UiNotifier();
});
