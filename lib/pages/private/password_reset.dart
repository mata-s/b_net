import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PasswordResetPage extends StatelessWidget {
  const PasswordResetPage({super.key});

  Future<void> _sendPasswordResetEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null || user.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メールアドレスが登録されているアカウントのみ変更できます。'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: user.email!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'パスワード再設定用のメールを ${user.email} に送信しました。',
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to send password reset email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メールの送信に失敗しました。しばらくしてからお試しください。'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('パスワードを変更'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '登録されているメールアドレス宛に\n'
              'パスワード再設定用のメールを送信します。\n'
              'メールが届かない場合は、迷惑メールフォルダもご確認ください。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _sendPasswordResetEmail(context),
                child: const Text('再設定メールを送信'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
