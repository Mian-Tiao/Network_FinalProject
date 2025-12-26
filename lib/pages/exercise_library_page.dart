import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class ExerciseLibraryPage extends StatefulWidget {
  final TcpClient client;
  final int userId;

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

  final List<String> _bodyParts = const [
    '全部', 'back', 'cardio', 'chest', 'lower arms', 'lower legs',
    'neck', 'shoulders', 'upper arms', 'upper legs', 'waist',
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
        setState(() {
          _loading = false;
          if (msg['status'] == 'ok') {
            _results = msg['results'] as List<dynamic>? ?? [];
          }
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
    final query = _nameController.text.trim().isEmpty ? null : _nameController.text.trim();
    final bodyPart = _selectedBodyPart == '全部' ? null : _selectedBodyPart;

    widget.client.sendJson({
      'action': 'search_exercises',
      'query': query,
      'bodyPart': bodyPart,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('動作圖鑑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          child: Column(
            children: [
              // 搜尋列 (修正：加入右側點擊搜尋功能)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF64B5F6), Color(0xFF42A5F5)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 15),
                      const Icon(Icons.search, color: Colors.white),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "關鍵字 (如 squat, press)",
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      // 新增：顯性的搜尋按鈕，讓不輸入文字也能點擊搜尋
                      IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Colors.white),
                        onPressed: _search,
                      ),
                      const SizedBox(width: 5),
                    ],
                  ),
                ),
              ),

              // 部位選擇
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DropdownButtonFormField<String>(
                  dropdownColor: const Color(0xFF1A2A4D),
                  value: _selectedBodyPart,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '選擇訓練部位',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  items: _bodyParts.map((bp) => DropdownMenuItem(value: bp, child: Text(bp))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedBodyPart = v);
                    // 選擇部位後自動觸發搜尋，這對使用者更方便
                    _search();
                  },
                ),
              ),

              if (_loading) const LinearProgressIndicator(color: Color(0xFF00FFA3)),

              Expanded(
                child: _results.isEmpty
                    ? Center(child: Text(_loading ? '搜尋中...' : '請輸入關鍵字或選擇部位', style: TextStyle(color: Colors.white.withOpacity(0.5))))
                    : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final ex = _results[index] as Map<String, dynamic>;
                    final gifUrl = ex['gifUrl'] as String? ?? '';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: gifUrl.isNotEmpty
                                    ? Image.network(gifUrl, fit: BoxFit.contain)
                                    : const Icon(Icons.image, color: Colors.grey, size: 50),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex['name'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                                    ),
                                    Text(
                                      ex['target'] ?? '',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                widget.client.sendJson({
                                  'action': 'add_exercise_from_api',
                                  'userId': widget.userId,
                                  'id': ex['id'],
                                  'name': ex['name'],
                                  'bodyPart': ex['bodyPart'],
                                  'target': ex['target'],
                                  'equipment': ex['equipment'],
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Color(0xFF00FFA3), shape: BoxShape.circle),
                                child: const Icon(Icons.add, size: 18, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}