import 'package:b_net/login/login_page.dart';
import 'package:b_net/pages/private/change_mail.dart';
import 'package:b_net/pages/private/delete_account_page.dart';
import 'package:b_net/pages/private/password_reset.dart';
import 'package:b_net/pages/private/blocked_users_page.dart';
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
  static const String _webBaseUrl = 'https://baseball-net.vercel.app';

  bool _notificationsEnabled = true;
  bool _showTeamNameInRanking = false;
  bool _isUpdatingRankingPrivacy = false;
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
    _loadRankingPrivacySetting();
  }

  Future<void> _loadRankingPrivacySetting() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        // 未設定のユーザーはプライバシーを優先して非公開にする。
        _showTeamNameInRanking = data['showTeamNameInRanking'] == true;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load ranking privacy setting: $e');
    }
  }

  Future<void> _updateRankingPrivacySetting(bool value) async {
    final user = _currentUser;
    if (user == null || _isUpdatingRankingPrivacy) return;

    final previousValue = _showTeamNameInRanking;
    setState(() {
      _showTeamNameInRanking = value;
      _isUpdatingRankingPrivacy = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'showTeamNameInRanking': value,
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? '次回のランキング更新からチーム名を公開します' : '次回のランキング更新からチーム名を非公開にします',
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to update ranking privacy setting: $e');
      if (!mounted) return;
      setState(() {
        _showTeamNameInRanking = previousValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存できませんでした。もう一度お試しください。')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingRankingPrivacy = false;
        });
      }
    }
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
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

  bool _isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _cardGroup({required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = _isTablet(context);
          final double horizontalPadding = 16.0 + (isTablet ? 60.0 : 0.0);
          final double maxContentWidth = isTablet ? 720.0 : double.infinity;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  24,
                ),
                children: [
                  // ===== 通知 =====
                  _sectionTitle('通知'),
                  _cardGroup(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('通知を受け取る'),
                        subtitle: const Text(
                          '試合やチームのお知らせを受け取ります',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            _updateNotificationSetting(value);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ===== プライバシー =====
                  _sectionTitle('プライバシー'),
                  _cardGroup(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: const Text('ランキングでチーム名を公開する'),
                        subtitle: const Text(
                          '全国・都道府県の個人ランキングに反映されます。変更は次回のランキング更新時に反映されます',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: _isUpdatingRankingPrivacy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: _showTeamNameInRanking,
                                onChanged: _updateRankingPrivacySetting,
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ===== アカウント =====
                  _sectionTitle('アカウント'),
                  _cardGroup(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.mail_outline),
                        title: const Text('メールアドレス'),
                        subtitle: Text(
                          FirebaseAuth.instance.currentUser?.email
                                      ?.isNotEmpty ==
                                  true
                              ? FirebaseAuth.instance.currentUser!.email!
                              : '未登録',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
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
                      _divider(),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('パスワードを変更する'),
                        subtitle: const Text(
                          'パスワード再設定メールを送信します',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PasswordResetPage(),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      ListTile(
                        leading: const Icon(Icons.block),
                        title: const Text('ブロックしたユーザー'),
                        subtitle: const Text(
                          'ブロックしたユーザーの一覧と解除',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlockedUsersPage(
                                userUid: _currentUser?.uid,
                              ),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      ListTile(
                        leading:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text(
                          'アカウントを削除する',
                          style: TextStyle(color: Colors.red),
                        ),
                        subtitle: const Text(
                          '登録情報とデータを削除します',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DeleteAccountPage(),
                            ),
                          );
                        },
                      ),
                      _divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'ログアウト',
                          style: TextStyle(color: Colors.red),
                        ),
                        subtitle: const Text(
                          'この端末からログアウトします',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        onTap: () async {
                          // 👻 RevenueCatの現在のUserIDを取得して、匿名かチェック
                          try {
                            final purchaserInfo =
                                await Purchases.getCustomerInfo();
                            final currentAppUserID =
                                purchaserInfo.originalAppUserId;

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
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                            (route) => false,
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ===== サポート =====
                  _sectionTitle('サポート'),
                  _cardGroup(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.rule_folder_outlined),
                        title: const Text('ランキングルール・計算方法について'),
                        subtitle: const Text(
                          'Webサイトで詳しいルール・成績の計算方法を確認できます',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 20),
                        onTap: () {
                          _openExternalUrl('$_webBaseUrl/ranking-rules');
                        },
                      ),
                      _divider(),
                      ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: const Text('お問い合わせ'),
                        subtitle: const Text(
                          'ご不明点・ご要望はこちらから',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 20),
                        onTap: () {
                          _openExternalUrl('$_webBaseUrl/contact');
                        },
                      ),
                      _divider(),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('利用規約'),
                        trailing: const Icon(Icons.open_in_new, size: 20),
                        onTap: () {
                          _openExternalUrl('$_webBaseUrl/terms');
                        },
                      ),
                      _divider(),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('プライバシーポリシー'),
                        trailing: const Icon(Icons.open_in_new, size: 20),
                        onTap: () {
                          _openExternalUrl('$_webBaseUrl/privacy');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      'Baseball Net',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
