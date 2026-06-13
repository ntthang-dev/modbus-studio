import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/scanner.dart';

class RadarState {
  final List<RadarDevice> devices;
  final bool isScanning;

  RadarState({this.devices = const [], this.isScanning = false});

  RadarState copyWith({
    List<RadarDevice>? devices,
    bool? isScanning,
  }) {
    return RadarState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class RadarNotifier extends Notifier<RadarState> {
  StreamSubscription<RadarDevice>? _subscription;

  @override
  RadarState build() {
    return RadarState();
  }

  void startScan() {
    if (state.isScanning) return;

    state = RadarState(isScanning: true, devices: []);

    _subscription?.cancel();
    _subscription = startRadarScan(subnet: "192.168.1").listen(
      (device) {
        state = state.copyWith(devices: [...state.devices, device]);
      },
      onDone: () {
        state = state.copyWith(isScanning: false);
      },
      onError: (e) {
        state = state.copyWith(isScanning: false);
      },
    );
  }

  void stopScan() {
    _subscription?.cancel();
    state = state.copyWith(isScanning: false);
  }
}

final radarProvider = NotifierProvider<RadarNotifier, RadarState>(() {
  return RadarNotifier();
});
