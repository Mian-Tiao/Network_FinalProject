import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class ExerciseLibraryPage extends StatefulWidget {
  final TcpClient client;
  final int userId; // 👈 新增這行

  const ExerciseLibraryPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final TextEditingController _nameController = TextEditingController();

  // bodyPart 下拉選單（ExerciseDB 的分類）
  final List<String> _bodyParts = const [
    '全部',
    'back',
    'cardio',
    'chest',
    'lower arms',
    'lower legs',
    'neck',
    'shoulders',
    'upper arms',
    'upper legs',
    'waist',
  ];

  String _selectedBodyPart = '全部';
  bool _loading = false;
  List<dynamic> _results = [];

  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();

    _sub = widget.client.messages.listen((msg) {
      if (!mounted) return;

      if (msg['action'] == 'search_exercises') {
        setState(() => _loading = false);

        if (msg['status'] == 'ok') {
          setState(() {
            _results = msg['results'] as List<dynamic>? ?? [];
          });
        } else if (msg['action'] == 'add_exercise_from_api') {
          if (msg['status'] == 'ok') {
            final name = msg['name'] ?? '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('成功把「$name」加入今日課表')),
            );
          } else {
            final err = msg['message'] ?? '加入課表失敗';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err.toString())),
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _loading = true;
      _results = [];
    });

    final query = _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim();
    final bodyPart =
    _selectedBodyPart == '全部' ? null : _selectedBodyPart;

    widget.client.sendJson({
      'action': 'search_exercises',
      'query': query,
      'bodyPart': bodyPart,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('動作圖鑑（ExerciseDB API）'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 搜尋區
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '關鍵字（如 squat, press）',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBodyPart,
                    decoration: const InputDecoration(labelText: '部位'),
                    items: _bodyParts
                        .map(
                          (bp) => DropdownMenuItem(
                        value: bp,
                        child: Text(bp),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedBodyPart = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('搜尋動作'),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                child: Text(
                  '輸入關鍵字或選部位後按「搜尋動作」\n會從線上資料庫抓動作與 GIF 回來',
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final ex = _results[index] as Map<String, dynamic>;
                  final name = ex['name'] ?? '';
                  final bodyPart = ex['bodyPart'] ?? '';
                  final target = ex['target'] ?? '';
                  final equipment = ex['equipment'] ?? '';
                  final gifUrl = ex['gifUrl'] as String? ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '部位: $bodyPart ／ 目標肌群: $target\n器材: $equipment',
                            style: const TextStyle(fontSize: 12),
                          ),
                          // 👇 從這裡開始加圖片
                          if (gifUrl.isNotEmpty) const SizedBox(height: 8),
                          if (gifUrl.isNotEmpty)
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  gifUrl,
                                  fit: BoxFit.cover,
                                  // 方便除錯：有錯時在 console 印出來
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint('❌ 讀圖失敗 $gifUrl: $error');
                                    return const Center(
                                      child: Text('圖片載入失敗'),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                widget.client.sendJson({
                                  'action': 'add_exercise_from_api',
                                  'userId': widget.userId,
                                  'id': ex['id'],
                                  'name': name,
                                  'bodyPart': bodyPart,
                                  'target': target,
                                  'equipment': equipment,
                                });

                                // 先樂觀提示，等 server 回覆也可以再顯示一次
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已送出，將「$name」加入課表')),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('加入課表'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
