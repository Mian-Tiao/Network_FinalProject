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

  StreamSubscription<Map<String, dynamic>>? _sub;

  SupabaseClient get _supabase => Supabase.instance.client;

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
      setState(() => _status = '帳號與密碼不能空白');
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

      final userId = user.id;
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
    final createdEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );

    if (createdEmail != null && createdEmail.isNotEmpty) {
      _emailController.text = createdEmail;
      setState(() => _status = '註冊成功，請輸入密碼登入');
    }
  }

  // 封裝輸入框樣式
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 防止露白
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('LiftLog 登入', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2A4D), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo 或 標題區
                const Icon(Icons.fitness_center, size: 80, color: Color(0xFF00FFA3)),
                const SizedBox(height: 16),
                const Text(
                  '歡迎回來',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                _buildTextField(
                  controller: _emailController,
                  label: '帳號（Email）',
                  icon: Icons.email_outlined,
                ),
                _buildTextField(
                  controller: _pwdController,
                  label: '密碼',
                  obscureText: true,
                  icon: Icons.lock_outline,
                ),

                const SizedBox(height: 16),

                // 狀態顯示
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF00FFA3), fontSize: 13),
                ),

                const SizedBox(height: 32),

                // 登入按鈕 (漸層風格)
                GestureDetector(
                  onTap: _isLoading ? null : _login,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        '登入',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: _goRegister,
                  child: const Text(
                    '還沒有帳號？前往註冊',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
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