import 'dart:async';

import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class SummaryPage extends StatefulWidget {
  final TcpClient client;
  final int userId;

  const SummaryPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  bool _loading = true;
  int _totalSets = 0;
  double _totalVolume = 0;
  double _recent7DaysVolume = 0;
  List<Map<String, dynamic>> _exerciseStats = [];
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.client.messages.listen((msg) {
      if (msg['action'] == 'get_summary' && msg['status'] == 'ok') {
        final exStats = (msg['exerciseStats'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          _totalSets = msg['totalSets'] as int? ?? 0;
          _totalVolume =
              (msg['totalVolume'] as num? ?? 0).toDouble();
          _recent7DaysVolume =
              (msg['recent7DaysVolume'] as num? ?? 0).toDouble();
          _exerciseStats = exStats;
          _loading = false;
        });
      }
    });

    _requestSummary();
  }

  void _requestSummary() {
    setState(() {
      _loading = true;
    });

    widget.client.sendJson({
      'action': 'get_summary',
      'userId': widget.userId,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Widget _buildTopCards() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('總組數',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$_totalSets 組',
                      style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text('總訓練量',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${_totalVolume.toStringAsFixed(1)} kg×reps',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('最近 7 天訓練量',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${_recent7DaysVolume.toStringAsFixed(1)} kg×reps'),
            const SizedBox(height: 4),
            const Text(
              '（用重量 × 次數，把最近七天的組數加總）',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseStatCard(Map<String, dynamic> ex) {
    final name = ex['name'] ?? '';
    final part = ex['bodyPart'] ?? '';
    final sets = ex['sets'] ?? 0;
    final bestWeight = (ex['bestWeight'] as num? ?? 0).toDouble();
    final totalVolume = (ex['totalVolume'] as num? ?? 0).toDouble();

    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          '$part\n總組數：$sets｜最佳重量：${bestWeight.toStringAsFixed(1)} kg\n累積訓練量：${totalVolume.toStringAsFixed(1)} kg×reps',
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
    } else if (_totalSets == 0) {
      body = const Center(child: Text('還沒有訓練紀錄，先去做幾組吧！'));
    } else {
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopCards(),
            _buildRecentCard(),
            const SizedBox(height: 8),
            const Text(
              '各動作統計',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ..._exerciseStats
                .map((ex) => _buildExerciseStatCard(ex))
                .toList(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('訓練統計總覽'),
        actions: [
          IconButton(
            onPressed: _requestSummary,
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
