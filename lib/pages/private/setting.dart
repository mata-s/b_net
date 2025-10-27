import 'package:b_net/services/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('サブスク'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('通知'),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                  // 通知の有効・無効の切り替え処理をここに追加
                });
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('パスワードを変更する'),
            onTap: () {
              // パスワード変更処理を呼び出す
            },
          ),
          ListTile(
            title: const Text('サポート'),
            onTap: () {
              // サポートページに遷移
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('ログアウト'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
    );
  }
}
