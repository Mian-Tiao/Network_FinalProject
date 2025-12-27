import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_page.dart';
import '../services/tcp_client.dart';

class LoginPage extends StatefulWidget {
  final TcpClient client;
  final void Function(String userId, String username) onLoginSuccess;

  const LoginPage({
    super.key,
    required this.client,
    required this.onLoginSuccess,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();

  String _status = '請輸入帳號與密碼登入';
  bool _isLoading = false;

  // 如果你之後還要聽 TCP 的 login 回應再用，現在先不用
  StreamSubscription<Map<String, dynamic>>? _sub;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // 如果你之後還是要保留 TCP 的 login 回應，可以在這裡 listen
    // 目前我們改用 Supabase Auth 當真正登入，就先不綁定 action == 'login' 了
    /*
    _sub = widget.client.messages.listen((msg) {
      ...
    });
    */
  }

  @override
  void dispose() {
    _sub?.cancel();
    _emailController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _pwdController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _status = '帳號與密碼不能空白';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = '登入中...';
    });

    try {
      final authRes = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authRes.user;
      if (user == null) {
        setState(() {
          _status = '登入失敗：無法取得使用者資訊';
          _isLoading = false;
        });
        return;
      }

      final userId = user.id; // 這個就是之後給 TCP server 的 userId

      // （選擇性）通知 TCP server 一下：「這個 user 上線了」
      widget.client.sendJson({
        'action': 'login',
        'userId': userId,
        'username': email,
      });

      widget.onLoginSuccess(userId, email);
    } on AuthException catch (e) {
      setState(() {
        _status = '登入失敗：${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '登入發生錯誤：$e';
        _isLoading = false;
      });
    }
  }

  void _goRegister() async {
    // 跳到註冊頁
    final createdEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const RegisterPage(),
      ),
    );

    // 如果註冊成功回來，可以自動填入 email
    if (createdEmail != null && createdEmail.isNotEmpty) {
      _emailController.text = createdEmail;
      setState(() {
        _status = '註冊成功，請輸入密碼登入';
      });
    }
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
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '帳號（Email）',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwdController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密碼',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('登入'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _goRegister,
              child: const Text('還沒有帳號？前往註冊'),
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
