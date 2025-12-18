import 'dart:async';

import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class HistoryPage extends StatefulWidget {
  final TcpClient client;
  final int userId;

  const HistoryPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.client.messages.listen((msg) {
      if (msg['action'] == 'get_history' && msg['status'] == 'ok') {
        final raw = msg['items'] as List<dynamic>? ?? [];
        setState(() {
          _items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      }
    });

    _requestHistory();
  }

  void _requestHistory() {
    setState(() {
      _loading = true;
    });

    widget.client.sendJson({
      'action': 'get_history',
      'userId': widget.userId,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _formatTime(String iso) {
    // 簡單切字串，不特別做時區處理
    // 例如 "2025-12-14T22:30:00.123456" -> "2025-12-14 22:30"
    if (iso.length >= 16) {
      return iso.substring(0, 16).replaceFirst('T', ' ');
    }
    return iso;
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final name = item['exerciseName'] ?? '';
    final part = item['bodyPart'] ?? '';
    final weight = item['weight'] ?? 0;
    final reps = item['reps'] ?? 0;
    final difficulty = item['difficulty'] ?? 0;
    final time = item['time'] ?? '';

    final volume = (weight is num && reps is num) ? weight * reps : 0;

    return Card(
      child: ListTile(
        title: Text('$name  x$reps @ ${weight}kg'),
        subtitle: Text(
          '$part｜主觀難度：$difficulty / 5\n時間：${_formatTime(time)}\n訓練量（重量×次數）：$volume',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      body = const Center(child: Text('目前沒有紀錄，先去做幾組吧！'));
    } else {
      body = ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildItem(_items[index]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('歷史訓練紀錄'),
        actions: [
          IconButton(
            onPressed: _requestHistory,
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: body,
      ),
    );
  }
}
