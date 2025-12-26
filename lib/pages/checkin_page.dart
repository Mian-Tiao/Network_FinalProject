import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/tcp_client.dart';
import 'today_workout_page.dart';

class CheckinPage extends StatefulWidget {
  final TcpClient client;
  final int userId;

  const CheckinPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  int _sleep = 3;
  int _fatigue = 3;
  int _soreness = 3;
  int _stress = 3;

  String _result = '';
  bool _canGoWorkout = false;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.client.messages.listen((msg) {
      if (msg['action'] == 'checkin') {
        setState(() {
          final score = msg['fatigueScore'];
          final suggestion = msg['suggestion'];
          _result = '疲勞分數：$score\n建議：$suggestion';
          _canGoWorkout = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _sendCheckin() {
    widget.client.sendJson({
      'action': 'checkin',
      'userId': widget.userId,
      'sleep': _sleep,
      'fatigue': _fatigue,
      'soreness': _soreness,
      'stress': _stress,
    });
    setState(() => _result = '正在分析您的身體狀況...');
  }

  // 打造像截圖中的卡片
  Widget _buildCheckinCard(String title, int value, String desc, ValueChanged<double> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('$value / 5', style: const TextStyle(color: Color(0xFF00FFA3), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00FFA3),
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF00FFA3).withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: onChanged,
            ),
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
        title: const Text('Body Check-in', style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text("評估你今天的狀態，我們將調整你的訓練強度",
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      _buildCheckinCard('睡眠品質', _sleep, '1 為良好，5 為極差', (v) => setState(() => _sleep = v.toInt())),
                      _buildCheckinCard('身體疲勞', _fatigue, '1 為精神飽滿，5 為筋疲力竭', (v) => setState(() => _fatigue = v.toInt())),
                      _buildCheckinCard('肌肉酸痛', _soreness, '1 為無感，5 為嚴重酸痛', (v) => setState(() => _soreness = v.toInt())),
                      _buildCheckinCard('心理壓力', _stress, '1 為放鬆，5 為壓力極大', (v) => setState(() => _stress = v.toInt())),

                      if (_result.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Text(_result, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                    ],
                  ),
                ),

                // 底部按鈕區
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      if (!_canGoWorkout)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            ),
                            onPressed: _sendCheckin,
                            child: const Text('送出分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (_canGoWorkout)
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => TodayWorkoutPage(client: widget.client, userId: widget.userId),
                            ));
                          },
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF64B5F6), Color(0xFF1976D2)]),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Center(
                              child: Text('開始今日訓練', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}