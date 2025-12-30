import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tcp_client.dart';
import 'chat_room_page.dart';
import 'create_room_page.dart';

class ChatRoomsPage extends StatefulWidget {
  final TcpClient client;
  final String userId;     // Supabase uid
  final String username;

  const ChatRoomsPage({
    super.key,
    required this.client,
    required this.userId,
    required this.username,
  });

  @override
  State<ChatRoomsPage> createState() => _ChatRoomsPageState();
}

class _ChatRoomsPageState extends State<ChatRoomsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];

  String? _selectedPrRoomId; // 存在手機端

  StreamSubscription<Map<String, dynamic>>? _sub;

  String get _prKey => 'prRoom_${widget.userId}';

  @override
  void initState() {
    super.initState();

    _sub = widget.client.messages.listen((msg) {
      if (!mounted) return;

      final action = msg['action'];

      if (action == 'chat_list_rooms' && msg['status'] == 'ok') {
        final raw = msg['rooms'] as List<dynamic>? ?? [];
        setState(() {
          _rooms = raw.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      }

      if (action == 'chat_create_room' && msg['status'] == 'ok') {
        final roomId = msg['roomId']?.toString() ?? '';
        final roomName = (msg['roomName'] ?? msg['title'] ?? '聊天室').toString();

        if (roomId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('建立成功但 roomId 空的，無法跳轉')),
          );
          return;
        }

        // 先刷新清單（可有可無）
        _requestRooms();

        // ✅ 直接跳轉進聊天室
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              client: widget.client,
              userId: widget.userId,      // uid
              username: widget.username,  // 顯示用
              roomId: roomId,
              roomTitle: roomName,
            ),
          ),
        );
      }
    });

    _loadPrRoomFromLocal();
    _requestRooms();
  }

  Future<void> _loadPrRoomFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPrRoomId = prefs.getString(_prKey);
    });
  }

  Future<void> _savePrRoomToLocal(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prKey, roomId);
    setState(() => _selectedPrRoomId = roomId);
  }

  void _requestRooms() {
    setState(() => _loading = true);
    widget.client.sendJson({
      'action': 'chat_list_rooms',
      'uid': widget.userId,
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openPrRoomSelector() async {
    if (_rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('你目前沒有聊天室，先建立一個吧')),
      );
      return;
    }

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        String? temp = _selectedPrRoomId;

        return AlertDialog(
          backgroundColor: const Color(0xFF1A2A4D),
          title: const Text(
            '選擇 PR 發送群組',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _rooms.map((r) {
                final id = r['id']?.toString() ?? '';
                final title = r['name']?.toString().trim().isNotEmpty == true ? r['name'].toString() : '聊天室';

                return RadioListTile<String>(
                  value: id,
                  groupValue: temp,
                  activeColor: const Color(0xFF00FFA3),
                  title: Text(title, style: const TextStyle(color: Colors.white)),
                  onChanged: (v) {
                    temp = v;
                    (context as Element).markNeedsBuild();
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('取消', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFA3),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(context, temp),
              child: const Text('設定'),
            ),
          ],
        );
      },
    );

    if (chosen == null || chosen.isEmpty) return;

    await _savePrRoomToLocal(chosen);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更新 PR 發送群組 ✅')),
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final title = (room['name']?.toString().trim().isNotEmpty == true) ? room['name'].toString() : '聊天室';
    final roomId = room['id']?.toString() ?? '';
    final isPrRoom = roomId.isNotEmpty && roomId == _selectedPrRoomId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatRoomPage(
                client: widget.client,
                userId: widget.userId,
                username: widget.username,
                roomId: roomId,
                roomTitle: title,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFA3).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPrRoom ? Icons.emoji_events : Icons.forum,
                  color: const Color(0xFF00FFA3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPrRoom ? '✅ 目前 PR 會發到這裡' : '點擊進入聊天室',
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 16),
            ],
          ),
        ),
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
        title: const Text('聊天室', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: '選擇 PR 發送群',
            onPressed: _openPrRoomSelector,
            icon: const Icon(Icons.emoji_events, color: Color(0xFF00FFA3)),
          ),
          IconButton(
            tooltip: '重新整理',
            onPressed: _requestRooms,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            tooltip: '新增聊天室',
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => CreateRoomPage(
                    client: widget.client,
                    userId: widget.userId,
                  ),
                ),
              );
              if (ok == true) _requestRooms();
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3)))
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _rooms.isEmpty
                ? Center(
              child: Text(
                '目前沒有聊天室\n右上角「+」建立一個吧！',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            )
                : ListView.builder(
              itemCount: _rooms.length,
              itemBuilder: (_, i) => _roomCard(_rooms[i]),
            ),
          ),
        ),
      ),
    );
  }
}
