import 'package:flutter/material.dart';
import 'services/tcp_client.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() {
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
  int? _userId;

  @override
  void initState() {
    super.initState();
    // 先固定連到模擬器用的 10.0.2.2:5000
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

  void _handleLoginSuccess(int userId, String username) {
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
        userId: _userId ?? 0,
        onLogout: _handleLogout,
      )),
    );
  }
}
