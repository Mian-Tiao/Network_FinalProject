import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class ChatRoomPage extends StatefulWidget {
  final TcpClient client;
  final String userId;     // 放 uid 字串
  final String username;   // 顯示用
  final String roomId;     // room id
  final String roomTitle;  // room name
  const ChatRoomPage({
    super.key,
    required this.client,
    required this.userId,
    required this.username,
    required this.roomId,
    required this.roomTitle,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();

    _sub = widget.client.messages.listen((msg) {
      if (!mounted) return;

      // ✅ 歷史訊息
      if (msg['action'] == 'get_room_history' && msg['status'] == 'ok') {
        if ((msg['roomId']?.toString() ?? '') != widget.roomId) return;

        final raw = msg['items'] as List<dynamic>? ?? [];
        setState(() {
          _items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
        _scrollToBottom();
      }

      // ✅ 即時推播
      if (msg['action'] == 'room_message') {
        if ((msg['roomId']?.toString() ?? '') != widget.roomId) return;

        final item = <String, dynamic>{
          'senderId': msg['senderId'],
          'senderName': msg['senderName'],
          'text': msg['text'],
          'meta': msg['meta'],
          'time': msg['time'],
        };

        setState(() => _items.add(item));
        _scrollToBottom();
      }
    });


    widget.client.sendJson({
      'action': 'send_room_message',
      'uid': widget.userId,                 // ✅ demo 固定
      'roomId': widget.roomId,
      'senderName': widget.username, // ✅ 這裡放 email
    });

    // ✅ 拉歷史
    _requestMessages();
  }

  void _requestMessages() {
    setState(() => _loading = true);
    widget.client.sendJson({
      'action': 'get_room_history',
      'uid': widget.userId,
      'roomId': widget.roomId,
      'limit': 80,
    });
  }

  void _send() {
    final text = _textController.text.trim(); // ✅ 先宣告
    if (text.isEmpty) return;

    widget.client.sendJson({
      'action': 'send_room_message',
      'uid': widget.userId, // demo 固定
      'roomId': widget.roomId,
      'text': text, // ✅ 這裡才用得到
      'senderName': widget.username,
    });

    _textController.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _messageBubble(Map<String, dynamic> item) {
    // ✅ TCP 欄位版本
    final senderId = item['senderId']?.toString() ?? '';
    final senderName = item['senderName']?.toString() ?? '';
    final text = item['text']?.toString() ?? '';
    final meta = item['meta'];

    final isMe = (item['senderName']?.toString() ?? '') == widget.username;
    final isSystem = senderId == 'system';

    // PR / 系統卡片
    if (isSystem || (meta is Map && meta['type'] == 'pr')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFA3).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00FFA3).withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFF00FFA3)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF00FFA3) : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                senderName.isEmpty ? '對方' : senderName,
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '輸入訊息...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF00FFA3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.black),
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
        title: Text(widget.roomTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _requestMessages,
            icon: const Icon(Icons.refresh, color: Colors.white),
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
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FFA3)))
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _messageBubble(_items[i]),
                ),
              ),
              _inputBar(),
            ],
          ),
        ),
      ),
    );
  }
}
