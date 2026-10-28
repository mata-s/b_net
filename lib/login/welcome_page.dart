import 'package:b_net/login/login_page.dart';
import 'package:b_net/login/registration_page.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              children: [
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.sports_baseball,
                      size: 48, color: Color(0xFF2563EB)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'B-Net',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  '草野球の成績が、\nランキングと分析に変わる。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    height: 1.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                const _WelcomeFeature(
                  icon: Icons.edit_note,
                  title: '試合後にかんたん記録',
                  description: '分かる成績だけで始められます',
                ),
                const _WelcomeFeature(
                  icon: Icons.emoji_events_outlined,
                  title: '地域・同年代ランキング',
                  description: '自分の現在地を楽しく確認できます',
                ),
                const _WelcomeFeature(
                  icon: Icons.insights_outlined,
                  title: 'プレースタイルを分析',
                  description: '入力を重ねるほど自分の特徴が見えてきます',
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => _open(context, const SignUpPage()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('無料で始める'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _open(context, const LoginPage()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('ログイン'),
                ),
                const SizedBox(height: 12),
                const Text(
                  '基本機能は無料で利用できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(description,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
