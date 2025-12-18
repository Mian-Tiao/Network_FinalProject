import 'dart:async';

import 'package:flutter/material.dart';
import '../services/tcp_client.dart';

class LoginPage extends StatefulWidget {
  final TcpClient client;
  final void Function(int userId, String username) onLoginSuccess;

  const LoginPage({
    super.key,
    required this.client,
    required this.onLoginSuccess,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _nameController = TextEditingController();
  String _status = '請輸入名稱後登入';
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    // 只關心 login 的回應
    _sub = widget.client.messages.listen((msg) {
      if (msg['action'] == 'login') {
        if (msg['status'] == 'ok') {
          final userId = msg['userId'] as int? ?? 0;
          final username = msg['username'] as String? ?? '';
          widget.onLoginSuccess(userId, username);
        } else {
          setState(() {
            _status = '登入失敗：${msg['message'] ?? '未知錯誤'}';
          });
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

  void _login() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _status = '名稱不能空白';
      });
      return;
    }

    widget.client.sendJson({
      'action': 'login',
      'username': name,
      'password': '1234', // 先寫死
    });

    setState(() {
      _status = '已送出登入請求，請稍候...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiftLog 登入'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '使用者名稱',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: const Text('登入'),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
