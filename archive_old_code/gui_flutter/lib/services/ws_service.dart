import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef CmdCallback = void Function(Map<String, dynamic> data);

class WSService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;

  final Map<String, List<CmdCallback>> _listeners = {};

  static final WSService _instance = WSService._internal();
  factory WSService() => _instance;
  WSService._internal();

  void connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8080/ws'));
      
      try {
        await _channel!.ready;
        isConnected = true;
        notifyListeners();
      } catch (e) {
        isConnected = false;
        notifyListeners();
        _reconnect();
        return;
      }

      _channel?.stream.listen(
        (message) {
          final data = jsonDecode(message) as Map<String, dynamic>;
          final cmd = data['cmd'] as String? ?? '';
          // Dispatch to registered command listeners
          if (_listeners.containsKey(cmd)) {
            for (final cb in _listeners[cmd]!) {
              cb(data);
            }
          }
        },
        onDone: () {
          isConnected = false;
          notifyListeners();
          _reconnect();
        },
        onError: (e) {
          isConnected = false;
          notifyListeners();
          _reconnect();
        },
      );
    } catch (e) {
      isConnected = false;
      notifyListeners();
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!isConnected) connect();
    });
  }

  void on(String cmd, CmdCallback callback) {
    _listeners.putIfAbsent(cmd, () => []);
    _listeners[cmd]!.add(callback);
  }

  void off(String cmd, CmdCallback callback) {
    _listeners[cmd]?.remove(callback);
  }

  void sendCommand(Map<String, dynamic> cmd) {
    if (isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(cmd));
    }
  }
}
