import 'package:flutter/material.dart';
import '../services/tcp_client.dart';
import 'checkin_page.dart';
import 'history_page.dart';
import 'summary_page.dart';

class HomePage extends StatelessWidget {
  final TcpClient client;
  final String username;
  final int userId;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.client,
    required this.username,
    required this.userId,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiftLog 主畫面'),
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            tooltip: '登出',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('歡迎，$username'),
            const SizedBox(height: 8),
            Text('你的 userId: $userId'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CheckinPage(
                      client: client,
                      userId: userId,
                    ),
                  ),
                );
              },
              child: const Text('開始今天的訓練（先做 Check-in）'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistoryPage(
                      client: client,
                      userId: userId,
                    ),
                  ),
                );
              },
              child: const Text('查看歷史紀錄'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SummaryPage(
                      client: client,
                      userId: userId,
                    ),
                  ),
                );
              },
              child: const Text('訓練統計 / 儀表板'),
            ),
          ],
        ),
      ),
    );
  }
}
