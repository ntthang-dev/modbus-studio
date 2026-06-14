import 'package:flutter/cupertino.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:modbus_studio/providers/ui_provider.dart';
import 'package:modbus_studio/providers/connection_provider.dart';
import 'package:modbus_studio/features/scripting/scripting_provider.dart';

class ScriptingScreen extends HookConsumerWidget {
  const ScriptingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(uiProvider);
    final connState = ref.watch(connectionProvider);
    final scriptingState = ref.watch(scriptingProvider);
    final scriptingNotifier = ref.read(scriptingProvider.notifier);

    // Styling
    final bool isField = uiState.isFieldMode;
    final Color backgroundColor = isField ? CupertinoColors.lightBackgroundGray : const Color(0xFF0A0A0C);
    final Color cardColor = isField ? CupertinoColors.white : const Color(0xFF121216);
    final Color textColor = isField ? CupertinoColors.black : CupertinoColors.white;
    final Color subtextColor = isField ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey;
    final Color borderColor = isField ? CupertinoColors.systemGrey4 : const Color(0xFF1F1F24);

    final codeController = useTextEditingController(text: scriptingState.code);

    // Update state when editor content changes
    codeController.addListener(() {
      if (scriptingState.code != codeController.text) {
        scriptingNotifier.setCode(codeController.text);
      }
    });

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scripting Console',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sandboxed JavaScript automation runner',
                          style: TextStyle(fontSize: 13, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text('Live Run', style: TextStyle(fontSize: 12, color: textColor)),
                      const SizedBox(width: 8),
                      CupertinoSwitch(
                        value: scriptingState.isEnabled,
                        onChanged: (val) => scriptingNotifier.setEnabled(val),
                        activeTrackColor: CupertinoColors.systemTeal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Connection status warning
          if (!connState.isConnected)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemOrange.withValues(alpha:0.4), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: CupertinoColors.systemOrange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Manual run requires an active Modbus connection.',
                          style: TextStyle(color: isField ? CupertinoColors.systemOrange : CupertinoColors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Code Editor Area
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isField ? CupertinoColors.white : const Color(0xFF0F0F12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'EDITOR (JAVASCRIPT)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 1.0),
                          ),
                        ),
                        CupertinoButton(
                          color: CupertinoColors.systemTeal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          borderRadius: BorderRadius.circular(6),
                          onPressed: connState.isConnected ? () => scriptingNotifier.evaluateScriptManual() : null,
                          child: const Text('Execute Script', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: codeController,
                      maxLines: 12,
                      style: TextStyle(
                        fontFamily: 'SF Mono',
                        fontSize: 12,
                        color: textColor,
                      ),
                      decoration: BoxDecoration(
                        color: isField ? const Color(0xFFF0F0F2) : const Color(0xFF16161C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 0.5),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Error Alerts
          if (scriptingState.runtimeError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CupertinoColors.systemRed.withValues(alpha:0.4), width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SCRIPT EXECUTION ERROR',
                              style: TextStyle(color: CupertinoColors.systemRed, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scriptingState.runtimeError!,
                              style: TextStyle(color: textColor, fontSize: 12, fontFamily: 'SF Mono'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Execution Console Logs Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CONSOLE LOGS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: subtextColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (scriptingState.logs.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => scriptingNotifier.clearLogs(),
                      child: const Text('Clear Output', style: TextStyle(fontSize: 12, color: CupertinoColors.systemRed)),
                    ),
                ],
              ),
            ),
          ),

          // Console Logs Output
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: isField ? CupertinoColors.white : const Color(0xFF0F0F12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(12),
                child: scriptingState.logs.isEmpty
                    ? Center(
                        child: Text(
                          'Console output is empty.',
                          style: TextStyle(color: subtextColor.withValues(alpha:0.5), fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        itemCount: scriptingState.logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              scriptingState.logs[index],
                              style: TextStyle(
                                fontFamily: 'SF Mono',
                                fontSize: 11,
                                color: isField ? CupertinoColors.black : CupertinoColors.systemGrey2,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
