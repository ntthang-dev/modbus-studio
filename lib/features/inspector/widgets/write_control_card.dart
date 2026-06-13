import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class WriteControlCard extends HookWidget {
  final Future<void> Function(int address, bool value)? onWriteCoil;
  final Future<void> Function(int address, int value)? onWriteRegister;

  const WriteControlCard({
    super.key,
    this.onWriteCoil,
    this.onWriteRegister,
  });

  @override
  Widget build(BuildContext context) {
    // 0 = Coil, 1 = Register
    final selectedTab = useState(0);
    final addressCtrl = useTextEditingController(text: '0');
    final registerValueCtrl = useTextEditingController(text: '0');
    final coilValue = useState(false);
    final isWriting = useState(false);
    final writeResult = useState<String?>(null);

    Future<void> handleWrite() async {
      isWriting.value = true;
      writeResult.value = null;
      try {
        final address = int.parse(addressCtrl.text);
        if (selectedTab.value == 0) {
          if (onWriteCoil != null) await onWriteCoil!(address, coilValue.value);
        } else {
          final val = int.parse(registerValueCtrl.text);
          if (onWriteRegister != null) await onWriteRegister!(address, val);
        }
        writeResult.value = "Success!";
      } catch (e) {
        writeResult.value = "Error: ${e.toString()}";
      } finally {
        isWriting.value = false;
        // Clear success message after 3 seconds
        if (writeResult.value == "Success!") {
          Future.delayed(const Duration(seconds: 3), () {
            if (writeResult.value == "Success!") writeResult.value = null;
          });
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha:0.7),
              border: Border.all(color: CupertinoColors.systemTeal.withValues(alpha:0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Write Command',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: selectedTab.value,
                  children: const {
                    0: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Coil (FC 5)')),
                    1: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Register (FC 6)')),
                  },
                  onValueChanged: (val) {
                    if (val != null) selectedTab.value = val;
                    writeResult.value = null; // Clear error/success on tab switch
                  },
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Address', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
                          const SizedBox(height: 4),
                          CupertinoTextField(
                            controller: addressCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: CupertinoColors.white),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Value', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
                          const SizedBox(height: 4),
                          selectedTab.value == 0
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: CupertinoSwitch(
                                    value: coilValue.value,
                                    onChanged: (val) => coilValue.value = val,
                                    activeTrackColor: CupertinoColors.systemTeal,
                                  ),
                                )
                              : CupertinoTextField(
                                  controller: registerValueCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: CupertinoColors.white),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2C2C2E),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (writeResult.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      writeResult.value!,
                      style: TextStyle(
                        color: writeResult.value == "Success!" ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                CupertinoButton(
                  color: CupertinoColors.systemTeal,
                  onPressed: isWriting.value || (onWriteCoil == null && onWriteRegister == null) ? null : handleWrite,
                  child: isWriting.value 
                      ? const CupertinoActivityIndicator() 
                      : const Text('Send Command', style: TextStyle(fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
