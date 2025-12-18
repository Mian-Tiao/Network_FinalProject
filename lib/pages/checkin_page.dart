import 'dart:async';

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

    setState(() {
      _result = '已送出，等待伺服器回應...';
    });
  }

  Widget _buildSlider(
      String title,
      int value,
      ValueChanged<double> onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title：$value', style: const TextStyle(fontSize: 14)),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$value',
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訓練前 Check-in'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSlider(
              '睡眠品質（1好 5很糟）',
              _sleep,
                  (v) => setState(() => _sleep = v.toInt()),
            ),
            _buildSlider(
              '身體疲勞（1不累 5爆累）',
              _fatigue,
                  (v) => setState(() => _fatigue = v.toInt()),
            ),
            _buildSlider(
              '酸痛程度（1不酸 5超酸）',
              _soreness,
                  (v) => setState(() => _soreness = v.toInt()),
            ),
            _buildSlider(
              '壓力 / 不舒服（1OK 5很不舒服）',
              _stress,
                  (v) => setState(() => _stress = v.toInt()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendCheckin,
              child: const Text('送出 Check-in'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _canGoWorkout
                  ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TodayWorkoutPage(
                      client: widget.client,
                      userId: widget.userId,
                    ),
                  ),
                );
              }
                  : null,
              child: const Text('前往今日課表'),
            ),
          ],
        ),
      ),
    );
  }
}
