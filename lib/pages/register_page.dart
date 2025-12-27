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
      setState(() {
        _status = '所有欄位都要填寫';
      });
      return;
    }

    if (pwd != pwd2) {
      if (!mounted) return;
      setState(() {
        _status = '兩次輸入的密碼不一致';
      });
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

      // ✅ 註冊成功：把 email 帶回登入頁，自動幫你填帳號
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('註冊帳號'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email（登入帳號）',
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
            const SizedBox(height: 12),
            TextField(
              controller: _pwdConfirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '再次輸入密碼',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('註冊'),
              ),
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
