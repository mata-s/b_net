import 'package:b_net/login/registration_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _obscureText = true; // パスワード表示非表示のフラグ

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        try {
          // 👻 現在の RevenueCat ユーザーを確認
          final purchaserInfo = await Purchases.getCustomerInfo();
          final currentAppUserID = purchaserInfo.originalAppUserId;

          if (currentAppUserID.contains('anonymous')) {
            print('👻 現在は匿名ユーザーなので logOut スキップ');
          } else {
            await Purchases.logOut();
            print('✅ RevenueCat: logOut 完了');
          }
        } catch (e) {
          print('⚠️ RevenueCat logOut エラー（無視してOK）: $e');
        }

        // ✅ Firebase UID で RevenueCat にログイン
        await Purchases.logIn(user.uid);
        print('✅ RevenueCat: logIn 完了 (${user.uid})');
      }

      // ✅ 画面遷移
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Scaffold(
                    body: Center(child: Text('ユーザーデータが見つかりません')),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final positions = List<String>.from(data['positions'] ?? []);
                final teams = List<String>.from(data['teams'] ?? []);
                final prefecture = data['prefecture'] ?? '未設定';

                return HomePage(
                  userUid: user.uid,
                  isTeamAccount: false,
                  accountId: user.uid,
                  accountName: user.displayName ?? '匿名',
                  userPrefecture: prefecture,
                  userPosition: positions,
                  userTeamId: teams.isNotEmpty ? teams.first : null,
                );
              },
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'ログインに失敗しました';

      if (e.code == 'wrong-password') {
        errorMessage = 'パスワードが違います';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'メールアドレスの形式が違います';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'このメールアドレスは登録されていません';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'このアカウントは無効になっています';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      print('❌ 予期せぬログインエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインに失敗しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    labelText: 'パスワードw',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off
                            : Icons.visibility, // 修正箇所
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText; // 表示非表示の切り替え
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: const Text('ログイン'),
              ),
              const SizedBox(height: 15),
              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black),
                  children: [
                    const TextSpan(text: 'アカウントを作成していない方は'),
                    TextSpan(
                      text: 'こちら',
                      style: const TextStyle(color: Colors.blue),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignUpPage(),
                            ),
                          );
                        },
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
