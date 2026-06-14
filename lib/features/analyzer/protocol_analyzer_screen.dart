import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/connection_provider.dart';

class ModbusFrame {
  final DateTime timestamp;
  final bool isRequest;
  final int transactionId;
  final int unitId;
  final int functionCode;
  final String details;
  final String rawBytes;

  ModbusFrame({
    required this.timestamp,
    required this.isRequest,
    required this.transactionId,
    required this.unitId,
    required this.functionCode,
    required this.details,
    required this.rawBytes,
  });
}

class ProtocolAnalyzerScreen extends HookConsumerWidget {
  const ProtocolAnalyzerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connState = ref.watch(connectionProvider);
    final frames = useState<List<ModbusFrame>>([]);
    final selectedFrame = useState<ModbusFrame?>(null);
    final isPaused = useState<bool>(false);
    final nextTxId = useRef<int>(1);

    // Stream simulator of packets when connected
    useEffect(() {
      if (!connState.isConnected || isPaused.value) return null;

      final timer = Timer.periodic(const Duration(seconds: 1), (t) {
        final txId = nextTxId.value++;
        
        // 1. Generate Request
        final reqFrame = ModbusFrame(
          timestamp: DateTime.now(),
          isRequest: true,
          transactionId: txId,
          unitId: 1,
          functionCode: 3,
          details: 'Read Holding Registers, Address: 40001, Quantity: 10',
          rawBytes: '00 ${_toHex(txId, 2)} 00 00 00 06 01 03 00 00 00 0A',
        );
        
        // 2. Generate Response
        final dataBytes = connState.registers.map((v) => _toHex(v, 4)).join(' ');
        final respFrame = ModbusFrame(
          timestamp: DateTime.now().add(const Duration(milliseconds: 15)),
          isRequest: false,
          transactionId: txId,
          unitId: 1,
          functionCode: 3,
          details: 'Response Successful - 10 registers read',
          rawBytes: '00 ${_toHex(txId, 2)} 00 00 00 ${_toHex(3 + 20, 2)} 01 03 14 $dataBytes',
        );

        frames.value = [respFrame, reqFrame, ...frames.value].take(100).toList();
      });

      return () {
        timer.cancel();
      };
    }, [connState.isConnected, connState.registers, isPaused.value]);

    if (!connState.isConnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.waveform_path_ecg,
                size: 64,
                color: CupertinoColors.systemGrey.withValues(alpha:0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Protocol Analyzer Offline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CupertinoColors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect to a Modbus TCP device to capture and analyze frames in real-time.',
                style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Controls Row
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CupertinoButton(
                    color: isPaused.value ? CupertinoColors.systemGreen : CupertinoColors.systemOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => isPaused.value = !isPaused.value,
                    child: Text(isPaused.value ? 'Resume Capture' : 'Pause Capture', style: const TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.white, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton(
                    color: CupertinoColors.destructiveRed.withValues(alpha:0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () {
                      frames.value = [];
                      selectedFrame.value = null;
                    },
                    child: const Text('Clear Log', style: TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.systemRed, fontSize: 13)),
                  ),
                ],
              ),
              Text(
                '${frames.value.length} frames captured',
                style: const TextStyle(color: CupertinoColors.systemGrey2, fontSize: 12, fontFamily: 'SF Mono'),
              ),
            ],
          ),
        ),

        // Split Layout: Frame list & Decoder Details
        Expanded(
          child: Row(
            children: [
              // Left: Frame List
              Expanded(
                flex: 3,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: frames.value.length,
                  itemBuilder: (context, index) {
                    final frame = frames.value[index];
                    final isSelected = selectedFrame.value == frame;
                    
                    return _buildFrameRow(frame, isSelected, () {
                      selectedFrame.value = frame;
                    });
                  },
                ),
              ),

              // Right: Frame Details Inspector (Industrial Frame Decoder layout)
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.only(right: 16, bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141419),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF23232C)),
                  ),
                  child: selectedFrame.value == null
                      ? Center(
                          child: Text(
                            'Select a frame to decode',
                            style: TextStyle(color: CupertinoColors.systemGrey.withValues(alpha:0.6), fontSize: 13),
                          ),
                        )
                      : _buildFrameDecoder(selectedFrame.value!),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFrameRow(ModbusFrame frame, bool isSelected, VoidCallback onTap) {
    final typeColor = frame.isRequest ? CupertinoColors.systemBlue : CupertinoColors.systemGreen;
    final timeStr = '${frame.timestamp.hour.toString().padLeft(2, '0')}:${frame.timestamp.minute.toString().padLeft(2, '0')}:${frame.timestamp.second.toString().padLeft(2, '0')}.${frame.timestamp.millisecond.toString().padLeft(3, '0')}';
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? CupertinoColors.systemTeal.withValues(alpha:0.12)
              : const Color(0xFF0D0D10),
          border: Border.all(
            color: isSelected 
                ? CupertinoColors.systemTeal 
                : const Color(0xFF1F1F24),
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Tx/Rx Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                frame.isRequest ? 'TX' : 'RX',
                style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            
            // Timestamp
            Text(
              timeStr,
              style: const TextStyle(fontFamily: 'SF Mono', fontSize: 11, color: CupertinoColors.systemGrey),
            ),
            const SizedBox(width: 16),
            
            // Short detail
            Expanded(
              child: Text(
                frame.details,
                style: const TextStyle(fontSize: 13, color: CupertinoColors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameDecoder(ModbusFrame frame) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.circle_grid_hex, color: CupertinoColors.systemTeal, size: 18),
            const SizedBox(width: 8),
            const Text(
              'FRAME DECODER',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: CupertinoColors.white),
            ),
            const Spacer(),
            Text(
              frame.isRequest ? 'REQUEST' : 'RESPONSE',
              style: TextStyle(
                color: frame.isRequest ? CupertinoColors.systemBlue : CupertinoColors.systemGreen,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Decoded PDU elements
        _buildDecodeRow('Transaction ID', '0x${frame.transactionId.toRadixString(16).padLeft(4, '0').toUpperCase()} (${frame.transactionId})'),
        _buildDecodeRow('Protocol ID', '0x0000 (Modbus TCP)'),
        _buildDecodeRow('Length', '0x${(frame.rawBytes.replaceAll(' ', '').length ~/ 2 - 6).toRadixString(16).padLeft(4, '0').toUpperCase()} bytes'),
        _buildDecodeRow('Unit ID / Slave', '0x${frame.unitId.toRadixString(16).padLeft(2, '0').toUpperCase()} (${frame.unitId})'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Container(height: 1, color: const Color(0xFF2C2C35)),
        ),
        _buildDecodeRow('Function Code', '0x${frame.functionCode.toRadixString(16).padLeft(2, '0').toUpperCase()} (FC03 Read Holding Registers)'),
        
        const SizedBox(height: 16),
        const Text(
          'RAW HEX STREAM',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CupertinoColors.systemGrey2),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1F1F24)),
          ),
          child: Text(
            frame.rawBytes,
            style: const TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 12,
              color: CupertinoColors.systemTeal,
              height: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDecodeRow(String field, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(field, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
          Text(val, style: const TextStyle(color: CupertinoColors.white, fontSize: 12, fontFamily: 'SF Mono', fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _toHex(int val, int pad) {
    return val.toRadixString(16).toUpperCase().padLeft(pad, '0');
  }
}
