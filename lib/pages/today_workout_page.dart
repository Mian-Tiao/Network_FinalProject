import 'dart:async';

import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class TodayWorkoutPage extends StatefulWidget {
  final TcpClient client;
  final int userId;

  const TodayWorkoutPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<TodayWorkoutPage> createState() => _TodayWorkoutPageState();
}

class _TodayWorkoutPageState extends State<TodayWorkoutPage> {
  bool _loading = true;
  String _note = '';
  int? _fatigueScore;
  List<Map<String, dynamic>> _plan = [];
  StreamSubscription<Map<String, dynamic>>? _sub;

  final Map<int, int> _sessionSetCounts = {};

  @override
  void initState() {
    super.initState();
    _sub = widget.client.messages.listen((msg) {
      if (msg['action'] == 'get_today_plan' && msg['status'] == 'ok') {
        final List<dynamic> rawPlan = msg['plan'] ?? [];
        setState(() {
          _fatigueScore = msg['fatigueScore'] as int?;
          _note = msg['note'] as String? ?? '';
          _plan = rawPlan.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      } else if (msg['action'] == 'log_set' && msg['status'] == 'ok') {
        final isPr = msg['isPr'] as bool? ?? false;
        final prevBest = (msg['prevBest'] as num? ?? 0).toDouble();

        if (isPr) {
          if(!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                prevBest > 0
                    ? '🔥 恭喜打破個人紀錄！原本最佳是 ${prevBest.toStringAsFixed(1)} kg'
                    : '🔥 恭喜完成這個動作的第一組紀錄！',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          if(!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已紀錄這一組'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    _requestPlan();
  }

  void _requestPlan() {
    setState(() {
      _loading = true;
    });

    widget.client.sendJson({
      'action': 'get_today_plan',
      'userId': widget.userId,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openLogSetDialog(Map<String, dynamic> exercise) {
    final weightController =
    TextEditingController(text: '${exercise['suggestedWeight']}');
    final repsController =
    TextEditingController(text: '${exercise['minReps']}');

    final exId = exercise['id'] as int;
    // 目前是第幾組？（還沒做過就是第 1 組）
    final currentSet = (_sessionSetCounts[exId] ?? 0) + 1;

    int difficulty = 3; // 初始主觀難度

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('紀錄第 $currentSet 組 - ${exercise['name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '建議每個動作做約 4–5 組\n（每一組可以依照感覺微調重量與次數）',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: weightController,
                    decoration: const InputDecoration(
                      labelText: '重量 (kg)',
                    ),
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: repsController,
                    decoration: const InputDecoration(
                      labelText: '次數 (reps)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('主觀難度：'),
                      Expanded(
                        child: Slider(
                          value: difficulty.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '$difficulty',
                          onChanged: (v) {
                            // 注意：更新 dialog 自己的 state
                            setStateDialog(() {
                              difficulty = v.toInt();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    final weight =
                        double.tryParse(weightController.text) ?? 0;
                    final reps =
                        int.tryParse(repsController.text) ?? 0;

                    widget.client.sendJson({
                      'action': 'log_set',
                      'userId': widget.userId,
                      'exerciseId': exId,
                      'weight': weight,
                      'reps': reps,
                      'difficulty': difficulty,
                    });

                    // 這一組送出後，把這個動作的組數 +1
                    setState(() {
                      _sessionSetCounts[exId] = currentSet;
                    });

                    Navigator.of(context).pop();
                  },
                  child: const Text('送出'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildExerciseCard(Map<String, dynamic> ex) {
    final name = ex['name'] ?? '';
    final part = ex['bodyPart'] ?? '';
    final minReps = ex['minReps'] ?? 0;
    final maxReps = ex['maxReps'] ?? 0;
    final weight = (ex['suggestedWeight'] as num? ?? 0).toDouble();

    final lastWeight = (ex['lastWeight'] as num?)?.toDouble();
    final lastReps = ex['lastReps'] as int?;
    final lastDifficulty = ex['lastDifficulty'] as int?;

    String extraLine = '';
    if (lastWeight != null && lastReps != null && lastDifficulty != null) {
      extraLine =
      '\n上一組：${lastWeight.toStringAsFixed(1)} kg × $lastReps（難度 $lastDifficulty / 5）';
    } else {
      extraLine = '\n（尚未有這個動作的紀錄，建議從較輕重量開始）';
    }

    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          '$part\n建議重量：${weight.toStringAsFixed(1)} kg｜目標 reps：$minReps–$maxReps$extraLine',
          style: const TextStyle(fontSize: 13),
        ),
        isThreeLine: true,
        trailing: ElevatedButton(
          onPressed: () => _openLogSetDialog(ex),
          child: const Text('紀錄一組'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    if (_fatigueScore != null) {
      widgets.add(
        Text('今日疲勞分數：$_fatigueScore'),
      );
    }
    if (_note.isNotEmpty) {
      widgets.add(const SizedBox(height: 4));
      widgets.add(Text(
        _note,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ));
    }
    widgets.add(const SizedBox(height: 12));

    if (_loading) {
      widgets.add(const Center(child: CircularProgressIndicator()));
    } else {
      if (_plan.isEmpty) {
        widgets.add(const Text('今天沒有安排課表。'));
      } else {
        widgets.add(
          Expanded(
            child: ListView.builder(
              itemCount: _plan.length,
              itemBuilder: (context, index) {
                return _buildExerciseCard(_plan[index]);
              },
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日訓練課表'),
        actions: [
          IconButton(
            onPressed: _requestPlan,
            icon: const Icon(Icons.refresh),
            tooltip: '重新取得課表',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        ),
      ),
    );
  }
}
