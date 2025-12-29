import 'dart:async';

import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class HistoryPage extends StatefulWidget {
  final TcpClient client;
  final String userId;

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
      if (!mounted) return;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${weight}kg × $reps',
                style: const TextStyle(color: Color(0xFF00FFA3), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(part, style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Text('難度：$difficulty / 5', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('訓練時間', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  Text(_formatTime(time), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('總訓練量', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  Text('${volume}kg', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('訓練紀錄', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _requestHistory,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '重新整理',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2A4D), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3)))
              : _items.isEmpty
              ? Center(child: Text('目前沒有紀錄，先去做幾組吧！', style: TextStyle(color: Colors.white.withOpacity(0.5))))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _items.length,
            itemBuilder: (context, index) => _buildItem(_items[index]),
          ),
        ),
      ),
    );
  }
}
