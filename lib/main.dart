import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  // ✅ 新增這行
import 'services/tcp_client.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();  // ✅ 初始化 Flutter

  // ✅ 這裡先初始化 Supabase
  await Supabase.initialize(
    url: 'https://jjndkzdypnjplewubdzk.supabase.co',        // ← 換成你的 Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqbmRremR5cG5qcGxld3ViZHprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY2Nzk0MzUsImV4cCI6MjA4MjI1NTQzNX0.mIGWwd5cYYXrIoP-QjAdooc33vr1cDj4iOw8-MzKbz4',           // ← 換成你的 anon key
  );

  runApp(const LiftLogApp());
}

class LiftLogApp extends StatefulWidget {
  const LiftLogApp({super.key});

  @override
  State<LiftLogApp> createState() => _LiftLogAppState();
}

class _LiftLogAppState extends State<LiftLogApp> {
  late TcpClient _client;
  bool _connected = false;

  String? _username;
  String? _userId;   // ✅ 建議用 String (對應 Supabase user.id)

  @override
  void initState() {
    super.initState();
    _client = TcpClient(host: '10.0.2.2', port: 5000);
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    try {
      await _client.connect();
      setState(() {
        _connected = true;
      });
    } catch (e) {
      setState(() {
        _connected = false;
      });
      debugPrint('connect error: $e');
    }
  }

  void _handleLoginSuccess(String userId, String username) {
    setState(() {
      _userId = userId;
      _username = username;
    });
  }

  void _handleLogout() {
    setState(() {
      _userId = null;
      _username = null;
    });
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiftLog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: !_connected
          ? const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      )
          : (_username == null
          ? LoginPage(
        client: _client,
        onLoginSuccess: _handleLoginSuccess,
      )
          : HomePage(
        client: _client,
        username: _username!,
        userId: _userId!,    // ✅ HomePage 也記得改成接 String
        onLogout: _handleLogout,
      )),
    );
  }
}
