import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class CreateRoomPage extends StatefulWidget {
  final TcpClient client;
  final String userId;

  const CreateRoomPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _titleController = TextEditingController();
  final _emailsController = TextEditingController();

  bool _loading = false;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.client.messages.listen((msg) {
      if (!mounted) return;
      if (msg['action'] == 'create_room') {
        setState(() => _loading = false);

        if (msg['status'] == 'ok') {
          final notFound = (msg['notFound'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          if (notFound.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('以下 email 找不到：${notFound.join(", ")}')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('聊天室建立成功 ✅')),
            );
          }
          Navigator.pop(context, true);
        } else {
          final err = msg['message'] ?? '建立聊天室失敗';
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
    _titleController.dispose();
    _emailsController.dispose();
    super.dispose();
  }

  void _create() {
    final title = _titleController.text.trim().isEmpty ? '新聊天室' : _titleController.text.trim();
    final raw = _emailsController.text.trim();

    // 支援：逗號/換行 分隔
    final emails = raw
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() => _loading = true);

    widget.client.sendJson({
      "action": "chat_create_room",
      "uid": widget.userId,                 // ✅ 這裡改成 uid
      "roomName": "xxx",
      "memberEmails": ["a@gmail.com","b@gmail.com"],
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
        title: const Text('建立聊天室', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('聊天室名稱', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '例如：健身夥伴群',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('加入成員 Email（可多個）', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailsController,
                        style: const TextStyle(color: Colors.white),
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: '用逗號或換行分隔\n例如：a@gmail.com, b@gmail.com',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFA3))),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFA3),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    onPressed: _loading ? null : _create,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('建立聊天室', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
