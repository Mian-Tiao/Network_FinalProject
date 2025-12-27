import 'package:flutter/material.dart';
import '../services/tcp_client.dart';
import 'checkin_page.dart';
import 'history_page.dart';
import 'summary_page.dart';
import 'exercise_library_page.dart';

class HomePage extends StatelessWidget {
  final TcpClient client;
  final String username;
  final String userId;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.client,
    required this.username,
    required this.userId,
    required this.onLogout,
  });

  // 封裝功能卡片樣式
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
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
        title: const Text('LiftLog', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: '登出',
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // 歡迎語區塊
                Text('歡迎回來，$username 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('今天想挑戰什麼運動？',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
                const SizedBox(height: 32),

                // 功能列表
                Expanded(
                  child: ListView(
                    children: [
                      _buildMenuCard(
                        icon: Icons.history,
                        title: '訓練歷史紀錄',
                        subtitle: '回顧過去的汗水與進步',
                        iconColor: const Color(0xFF64B5F6),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HistoryPage(client: client, userId: userId))),
                      ),
                      _buildMenuCard(
                        icon: Icons.bar_chart,
                        title: '訓練統計分析',
                        subtitle: '數據化的成長圖表',
                        iconColor: const Color(0xFF00FFA3),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SummaryPage(client: client, userId: userId))),
                      ),
                      _buildMenuCard(
                        icon: Icons.menu_book,
                        title: '動作圖鑑',
                        subtitle: '學習標準的健身動作',
                        iconColor: Colors.orangeAccent,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ExerciseLibraryPage(client: client, userId: userId))),
                      ),
                    ],
                  ),
                ),

                // 底部主按鈕 (與截圖一致的藍色漸層)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CheckinPage(client: client, userId: userId)));
                    },
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '開始今日訓練 (Check-in)',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
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
