import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _pwdConfirmController = TextEditingController();

  bool _isLoading = false;
  String _status = '';

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _pwdController.dispose();
    _pwdConfirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final pwd = _pwdController.text;
    final pwd2 = _pwdConfirmController.text;

    if (email.isEmpty || pwd.isEmpty || pwd2.isEmpty) {
      if (!mounted) return;
      setState(() => _status = '所有欄位都要填寫');
      return;
    }

    if (pwd != pwd2) {
      if (!mounted) return;
      setState(() => _status = '兩次輸入的密碼不一致');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _status = '註冊中...';
    });

    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: pwd,
      );

      final user = res.user;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _status = '註冊失敗：未取得使用者資料';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        Navigator.of(context).pop<String>(email);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '註冊失敗：${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '註冊發生錯誤：$e';
        _isLoading = false;
      });
    }
  }

  // 封裝與 LoginPage 一致的輸入框樣式
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
        keyboardType: keyboardType,
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
        iconTheme: const IconThemeData(color: Colors.white), // 返回箭頭改白色
        title: const Text('註冊帳號', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A2A4D), Color(0xFF121212)], // 統一深色漸層
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.person_add_alt_1_outlined, size: 80, color: Color(0xFF00FFA3)), // 螢光綠標籤
                const SizedBox(height: 16),
                const Text(
                  '建立新帳號',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email（登入帳號）',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildTextField(
                  controller: _pwdController,
                  label: '密碼',
                  obscureText: true,
                  icon: Icons.lock_outline,
                ),
                _buildTextField(
                  controller: _pwdConfirmController,
                  label: '再次輸入密碼',
                  obscureText: true,
                  icon: Icons.lock_clock_outlined,
                ),

                const SizedBox(height: 16),

                // 狀態顯示 (螢光綠字體)
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF00FFA3), fontSize: 13),
                ),

                const SizedBox(height: 32),

                // 註冊按鈕 (藍色漸層)
                GestureDetector(
                  onTap: _isLoading ? null : _register,
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
                        '註冊',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
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