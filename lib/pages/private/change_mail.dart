import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangeMailPage extends StatefulWidget {
  const ChangeMailPage({super.key});

  @override
  State<ChangeMailPage> createState() => _ChangeMailPageState();
}

class _ChangeMailPageState extends State<ChangeMailPage> {
  final _auth = FirebaseAuth.instance;
  // ignore: unused_field
  final _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSaving = false;

  User? get _currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _auth.userChanges().listen((user) {
      if (!mounted) return;
      _emailController.text = user?.email ?? '';
      setState(() {});
    });
    final email = _currentUser?.email ?? '';
    _emailController.text = email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _changeEmail() async {
    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインユーザーが見つかりません。')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'メールアドレス変更のリクエストを受け付けました。\n新しいメールアドレス宛に確認用リンクを送信しました。メール内のリンクをタップすると変更が完了します。\nメールが届かない場合は、迷惑メールフォルダもご確認ください。',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Failed to update email (auth): code=${e.code}, message=${e.message}');
      String message = 'メールアドレスの変更に失敗しました。';

      if (e.code == 'requires-recent-login') {
        message = 'セキュリティのため、再ログインが必要です。もう一度ログインしてからお試しください。';
      } else if (e.code == 'invalid-email') {
        message = 'メールアドレスの形式が正しくありません。';
      } else if (e.code == 'email-already-in-use') {
        message = 'このメールアドレスはすでに使用されています。';
      } else {
        message = 'メールアドレスの変更に失敗しました（${e.code}）。';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メールアドレスの変更に失敗しました。しばらくしてからお試しください。'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    // 簡易チェック（必要ならもっと厳密に）
    if (!text.contains('@') || !text.contains('.')) {
      return '正しいメールアドレスを入力してください';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('メールアドレスを変更'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentEmail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '現在のメールアドレス：$currentEmail',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            const Text(
              '新しいメールアドレスを入力してください。\n'
              '新しいメールアドレス宛に確認用リンクを送信します。メール内のリンクをタップすると変更が完了します。\n'
              'メールが届かない場合は、迷惑メールフォルダもご確認ください。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '新しいメールアドレス',
                  border: OutlineInputBorder(),
                ),
                validator: _validateEmail,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _changeEmail,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('メールアドレスを変更'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
