import 'package:b_net/login/login_page.dart';
import 'package:b_net/pages/private/change_mail.dart';
import 'package:b_net/pages/private/delete_account_page.dart';
import 'package:b_net/pages/private/password_reset.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Webサイト（b-net-web）のベースURL
  // ※デプロイ先に合わせて必要なら変更してください
  static const String _webBaseUrl = 'https://baseball-net.vercel.app';

  bool _notificationsEnabled = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.userChanges().listen((user) {
      if (!mounted) return;
      setState(() {});
    });
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final enabled = data['notificationsEnabled'];
      if (enabled is bool) {
        setState(() {
          _notificationsEnabled = enabled;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load notification setting: $e');
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    final user = _currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'notificationsEnabled': value,
        },
        SetOptions(merge: true),
      );
      debugPrint('✅ notificationsEnabled updated to $value');
    } catch (e) {
      debugPrint('⚠️ Failed to update notification setting: $e');
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ページを開けませんでした。通信状況をご確認ください。'),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to launch url: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ページを開けませんでした。通信状況をご確認ください。'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ===== 通知セクション =====
          const Text(
            '通知',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('通知を受け取る'),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                _updateNotificationSetting(value);
              },
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // ===== アカウントセクション =====
          const SizedBox(height: 8),
          const Text(
            'アカウント',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('メールアドレス'),
            subtitle: Text(
              FirebaseAuth.instance.currentUser?.email?.isNotEmpty == true
                  ? FirebaseAuth.instance.currentUser!.email!
                  : '未登録',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangeMailPage(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('パスワードを変更する'),
             trailing: const Icon(Icons.chevron_right),
            onTap: () {
            Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PasswordResetPage(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text(
              'アカウントを削除する',
              style: TextStyle(color: Colors.red),
            ),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeleteAccountPage(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('ログアウト'),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () async {
              // 👻 RevenueCatの現在のUserIDを取得して、匿名かチェック
              try {
                final purchaserInfo = await Purchases.getCustomerInfo();
                final currentAppUserID = purchaserInfo.originalAppUserId;

                if (currentAppUserID.contains('anonymous')) {
                  debugPrint('👻 匿名ユーザーなので RevenueCat logOut スキップ');
                } else {
                  await Purchases.logOut();
                  debugPrint('✅ RevenueCat: logOut 完了');
                }
              } catch (e) {
                debugPrint('⚠️ RevenueCat logOut エラー: $e');
              }

              // Firebase ログアウト
              await _auth.signOut();

              // ログイン画面へ遷移（スタックをすべてクリア）
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),

          const SizedBox(height: 16),
          const Divider(),

          // ===== サポートセクション =====
          const SizedBox(height: 8),
          const Text(
            'サポート',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('ランキングルール・計算方法について'),
            subtitle: const Text(
              'Webサイトで詳しいランキングのルール・成績の計算方法を確認できます',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () {
              _openExternalUrl('$_webBaseUrl/ranking-rules');
            },
          ),
          ListTile(
            title: const Text('お問い合わせ'),
            onTap: () {
              _openExternalUrl('$_webBaseUrl/contact');
            },
          ),
          ListTile(
            title: const Text('利用規約'),
            onTap: () {
              _openExternalUrl('$_webBaseUrl/terms');
            },
          ),
          ListTile(
            title: const Text('プライバシーポリシー'),
            onTap: () {
              _openExternalUrl('$_webBaseUrl/privacy');
            },
          ),
        ],
      ),
    );
  }
}
