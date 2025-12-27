import 'dart:async';

import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class SummaryPage extends StatefulWidget {
  final TcpClient client;
  final String userId;

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
      if (!mounted) return;
      if (msg['action'] == 'get_summary' && msg['status'] == 'ok') {
        final exStats = (msg['exerciseStats'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          _totalSets = msg['totalSets'] as int? ?? 0;
          _totalVolume = (msg['totalVolume'] as num? ?? 0).toDouble();
          _recent7DaysVolume = (msg['recent7DaysVolume'] as num? ?? 0).toDouble();
          _exerciseStats = exStats;
          _loading = false;
        });
      }
    });

    _requestSummary();
  }

  void _requestSummary() {
    setState(() => _loading = true);
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

  // 頂部摘要卡片
  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // 最近 7 天訓練量
  Widget _buildRecentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF64B5F6).withOpacity(0.2), const Color(0xFF1976D2).withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF64B5F6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today, color: Color(0xFF64B5F6), size: 18),
              SizedBox(width: 8),
              Text('最近 7 天訓練量', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_recent7DaysVolume.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text('kg×reps', style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('（用重量 × 次數，把最近七天的組數加總）', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
        ],
      ),
    );
  }

  // 動作統計列表項
  Widget _buildExerciseStatCard(Map<String, dynamic> ex) {
    final name = ex['name'] ?? '';
    final part = ex['bodyPart'] ?? '';
    final sets = ex['sets'] ?? 0;
    final bestWeight = (ex['bestWeight'] as num? ?? 0).toDouble();
    final totalVol = (ex['totalVolume'] as num? ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('$part', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSmallInfo('總組數', '$sets 組'),
              _buildSmallInfo('最佳重量', '${bestWeight.toStringAsFixed(1)} kg', highlight: true),
              _buildSmallInfo('累積訓練量', '${totalVol.toStringAsFixed(1)} kg×reps'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(
            color: highlight ? const Color(0xFF00FFA3) : Colors.white70,
            fontSize: 12,
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal
        )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 確保背景透明不露白
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('訓練統計', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _requestSummary,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              : _totalSets == 0
              ? Center(child: Text('還沒有訓練紀錄，先去做幾組吧！', style: TextStyle(color: Colors.white.withOpacity(0.4))))
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatTile('總累積組數', '$_totalSets 組', Icons.fitness_center, const Color(0xFF00FFA3)),
                    const SizedBox(width: 16),
                    _buildStatTile('總訓練量', '${_totalVolume.toStringAsFixed(1)} kg×reps', Icons.equalizer, Colors.orangeAccent),
                  ],
                ),
                _buildRecentCard(),
                const Text('各動作統計', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._exerciseStats.map((ex) => _buildExerciseStatCard(ex)).toList(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}