import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:b_net/login/login_page.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isDeleting = false;
  bool _agreed = false;

  String? _userName;
  List<String> _userPositions = [];
  String? _userPrefecture;

  User? get _currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return;

     final data = doc.data();

      if (!mounted) return;
      setState(() {
        _userName = data?['name'] as String?;
        _userPositions = List<String>.from(data?['positions'] ?? []);
        _userPrefecture = data?['prefecture'] as String?;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load user profile for delete page: $e');
    }
  }

  Future<void> _deleteAccount() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注意事項に同意するにチェックを入れてください。')),
      );
      return;
    }

    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインユーザーが見つかりませんでした。')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('本当に削除しますか？'),
        content: const Text(
          'アカウントと関連するデータが削除されます。この操作は元に戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final uid = user.uid;

      // Firestore 上のユーザーデータを削除
      // TODO: 必要であれば Cloud Functions などでサブコレクションも含めて一括削除する
      await _firestore.collection('users').doc(uid).delete();

      // Firebase Authentication のアカウント削除
      await user.delete();

      // 念のためサインアウト
      await _auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アカウントを削除しました。')), 
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Failed to delete account (auth): $e');
      String message = 'アカウントの削除に失敗しました。';
      if (e.code == 'requires-recent-login') {
        message = 'セキュリティのため、再ログインが必要です。もう一度ログインしてからお試しください。';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete account: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('アカウントの削除に失敗しました。しばらくしてからお試しください。'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('アカウントを削除'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ① 大きめの警告ブロック
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'アカウントと関連するデータを完全に削除します。\n'
                      '一度削除すると元に戻すことはできません。',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // ② アカウントサマリー
            if (email.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '削除対象のアカウント',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // メールアドレス（Auth）
                      Row(
                        children: [
                          const Icon(Icons.email, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 名前
                      if (_userName != null && _userName!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.person, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userName!,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (_userName != null && _userName!.isNotEmpty)
                        const SizedBox(height: 4),
                      // ポジション（配列）
                      if (_userPositions.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sports_baseball,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userPositions.join(' / '),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      if (_userPositions.isNotEmpty)
                        const SizedBox(height: 4),
                      // 都道府県
                      if (_userPrefecture != null &&
                          _userPrefecture!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.place, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userPrefecture!,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            // ③ 削除されるデータリスト
            const Text(
              '削除されるデータ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const _BulletText('ログイン用アカウント情報（メールアドレスなど）'),
            const _BulletText('プロフィール情報（名前、ポジション、都道府県など）'),
            const _BulletText('あなたに紐づくチーム・個人成績データ'),
            const SizedBox(height: 16),

            // 注意事項チェック
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: _isDeleting
                      ? null
                      : (v) {
                          setState(() {
                            _agreed = v ?? false;
                          });
                        },
                ),
                const Expanded(
                  child: Text(
                    '注意事項を理解し、アカウントと関連データを削除することに同意します。',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: _isDeleting ? null : _deleteAccount,
                child: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('アカウントを削除する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('・', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
