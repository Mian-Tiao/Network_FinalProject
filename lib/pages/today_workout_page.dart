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
  String _selectedBodyPart = 'all';

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
              backgroundColor: Colors.orangeAccent,
            ),
          );
        } else {
          if(!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 已紀錄這一組'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
    _requestPlan();
  }

  void _requestPlan() {
    setState(() => _loading = true);
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
    final weightController = TextEditingController(text: '${exercise['suggestedWeight']}');
    final repsController = TextEditingController(text: '${exercise['minReps']}');
    final exId = exercise['id'] as int;
    final currentSet = (_sessionSetCounts[exId] ?? 0) + 1;
    int difficulty = 3;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Theme(
              data: ThemeData.dark(),
              child: AlertDialog(
                backgroundColor: const Color(0xFF1A2A4D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('紀錄第 $currentSet 組', style: const TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(exercise['name'], style: const TextStyle(color: Color(0xFF00FFA3), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: weightController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: '重量 (kg)', labelStyle: TextStyle(color: Colors.white70)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    TextField(
                      controller: repsController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: '次數 (reps)', labelStyle: TextStyle(color: Colors.white70)),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('難度：', style: TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            value: difficulty.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            activeColor: const Color(0xFF00FFA3),
                            onChanged: (v) => setStateDialog(() => difficulty = v.toInt()),
                          ),
                        ),
                        Text('$difficulty', style: const TextStyle(color: Color(0xFF00FFA3))),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.white54))),
                  TextButton(
                    onPressed: () {
                      widget.client.sendJson({
                        'action': 'log_set',
                        'userId': widget.userId,
                        'exerciseId': exId,
                        'weight': double.tryParse(weightController.text) ?? 0,
                        'reps': int.tryParse(repsController.text) ?? 0,
                        'difficulty': difficulty,
                      });
                      setState(() => _sessionSetCounts[exId] = currentSet);
                      Navigator.pop(context);
                    },
                    child: const Text('送出', style: TextStyle(color: Color(0xFF64B5F6))),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBodyPartFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('all', '全部'),
          const SizedBox(width: 8),
          _buildFilterChip('back', '練背'),
          const SizedBox(width: 8),
          _buildFilterChip('chest', '練胸'),
          const SizedBox(width: 8),
          _buildFilterChip('legs', '練腿'),
          const SizedBox(width: 8),
          _buildFilterChip('shoulders', '肩'),
          const SizedBox(width: 8),
          _buildFilterChip('arms', '手臂'),
          const SizedBox(width: 8),
          _buildFilterChip('core', '核心'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _selectedBodyPart == value;
    return ChoiceChip(
      // 這裡改為 Colors.black 確保字體清晰
      label: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      selected: selected,
      selectedColor: const Color(0xFF00FFA3), // 選中時為螢光綠
      backgroundColor: Colors.white70, // 未選中時為淺灰色/白，搭配黑色字體
      onSelected: (_) => setState(() => _selectedBodyPart = value),
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

    String extraLine = (lastWeight != null)
        ? '上一組：${lastWeight.toStringAsFixed(1)} kg × $lastReps (難度 $lastDifficulty/5)'
        : '（尚未有紀錄，建議從輕量開始）';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$part | 建議：${weight.toStringAsFixed(1)}kg ($minReps-$maxReps reps)',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(extraLine, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _openLogSetDialog(ex),
            child: const Text('紀錄'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _plan.where((ex) {
      if (_selectedBodyPart == 'all') return true;
      final bp = (ex['bodyPart'] ?? '').toString().toLowerCase();
      if (_selectedBodyPart == 'legs') return bp.contains('leg');
      if (_selectedBodyPart == 'core') return bp.contains('waist') || bp.contains('abs') || bp.contains('core');
      return bp == _selectedBodyPart;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('今日訓練課表', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _requestPlan, icon: const Icon(Icons.refresh, color: Colors.white))],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A2A4D), Color(0xFF121212)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_fatigueScore != null)
                  Text('今日疲勞分數：$_fatigueScore', style: const TextStyle(color: Color(0xFF00FFA3), fontWeight: FontWeight.bold)),
                if (_note.isNotEmpty)
                  Text(_note, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 12),
                if (!_loading && _plan.isNotEmpty) _buildBodyPartFilter(),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3)))
                      : filtered.isEmpty
                      ? const Center(child: Text('目前沒有安排動作', style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildExerciseCard(filtered[index]),
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