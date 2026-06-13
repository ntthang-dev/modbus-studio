import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/src/rust/api/client.dart';

class InspectorState {
  final bool isConnecting;
  final bool isConnected;
  final String? error;
  final List<int> registers;

  InspectorState({
    this.isConnecting = false,
    this.isConnected = false,
    this.error,
    this.registers = const [],
  });

  InspectorState copyWith({
    bool? isConnecting,
    bool? isConnected,
    String? error,
    List<int>? registers,
    bool clearError = false,
  }) {
    return InspectorState(
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      error: clearError ? null : (error ?? this.error),
      registers: registers ?? this.registers,
    );
  }
}

class DeviceInspectorScreen extends HookConsumerWidget {
  final String ipAddress;
  
  const DeviceInspectorScreen({super.key, required this.ipAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = useState<InspectorState>(InspectorState(isConnecting: true));

    useEffect(() {
      ModbusClient? client;
      Timer? pollingTimer;
      bool isMounted = true;

      void updateState(InspectorState s) {
        if (isMounted) state.value = s;
      }

      Future<void> connect() async {
        try {
          client = await ModbusClient.connect(ip: ipAddress, port: 502);
          updateState(state.value.copyWith(isConnecting: false, isConnected: true, clearError: true));
          
          pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
            if (client == null || !isMounted) return;
            try {
              final data = await client!.readHoldingRegisters(address: 0, quantity: 10);
              updateState(state.value.copyWith(registers: data.toList(), clearError: true));
            } catch (e) {
              updateState(state.value.copyWith(error: "Poll error: ${e.toString()}"));
            }
          });
        } catch (e) {
          updateState(state.value.copyWith(isConnecting: false, isConnected: false, error: e.toString()));
        }
      }

      connect();

      return () {
        isMounted = false;
        pollingTimer?.cancel();
        client?.disconnect();
      };
    }, [ipAddress]);

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF0A0A0C).withValues(alpha:0.6),
        middle: Text(ipAddress, style: const TextStyle(letterSpacing: 0.5)),
        previousPageTitle: 'Radar',
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Status Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E).withValues(alpha:0.7),
                      border: Border.all(color: const Color(0xFF2C2C2E).withValues(alpha:0.5)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: state.value.isConnecting 
                                ? CupertinoColors.systemYellow.withValues(alpha:0.2)
                                : state.value.isConnected 
                                    ? CupertinoColors.systemGreen.withValues(alpha:0.2)
                                    : CupertinoColors.systemRed.withValues(alpha:0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            state.value.isConnecting 
                                ? CupertinoIcons.arrow_2_circlepath 
                                : state.value.isConnected 
                                    ? CupertinoIcons.check_mark_circled_solid 
                                    : CupertinoIcons.exclamationmark_triangle,
                            color: state.value.isConnecting 
                                ? CupertinoColors.systemYellow 
                                : state.value.isConnected 
                                    ? CupertinoColors.systemGreen 
                                    : CupertinoColors.systemRed,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Connection Status', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                state.value.isConnecting ? 'Connecting...' : state.value.isConnected ? 'Connected & Polling' : 'Disconnected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (state.value.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(state.value.error!, style: const TextStyle(color: CupertinoColors.systemRed)),
              ),

            // Registers Grid
            Expanded(
              child: state.value.registers.isEmpty
                  ? Center(
                      child: state.value.isConnecting
                          ? const CupertinoActivityIndicator()
                          : const Text('No data yet', style: TextStyle(color: CupertinoColors.systemGrey)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: state.value.registers.length,
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E).withValues(alpha:0.5),
                            border: Border.all(color: CupertinoColors.systemTeal.withValues(alpha:0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Register 4000${index + 1}', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text(
                                '${state.value.registers[index]}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier',
                                  color: CupertinoColors.systemTeal,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.95, 0.95));
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
