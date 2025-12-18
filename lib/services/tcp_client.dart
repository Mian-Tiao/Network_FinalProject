import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TcpClient {
  final String host;
  final int port;

  Socket? _socket;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  /// 外部可以訂閱這個 stream 拿到伺服器傳回來的 JSON
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  TcpClient({required this.host, required this.port});

  Future<void> connect() async {
    if (_socket != null) return;

    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));

    // 伺服器那邊是 '\n' 分隔，所以這邊用 LineSplitter 切行
    _socket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.trim().isEmpty) return;
      try {
        final jsonData = jsonDecode(line) as Map<String, dynamic>;
        _controller.add(jsonData);
      } catch (e) {
        // JSON 解析失敗就先略過
        print('JSON parse error: $e, line = $line');
      }
    }, onError: (error) {
      print('Socket error: $error');
      disconnect();
    }, onDone: () {
      print('Socket done');
      disconnect();
    });
  }

  /// 發送 JSON 給伺服器
  void sendJson(Map<String, dynamic> data) {
    if (_socket == null) {
      print('Socket not connected');
      return;
    }
    final text = jsonEncode(data);
    _socket!.write('$text\n');
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
