import 'package:b_net/login/registration_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/team/member_parts/team_invite_link_landing_page.dart';

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

  Future<void> _setupFcmForLoggedInUser(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 通知権限リクエスト（iOS向け）
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
        print('✅ FCM token saved for user $uid: $token');
      } else {
        print('⚠️ FCM token is null or empty for user $uid');
      }
    } catch (e) {
      print('⚠️ Error setting up FCM for logged-in user $uid: $e');
    }
  }

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
          // ✅ Firebase UID を RevenueCat の appUserID として固定（user: プレフィックスを付ける）
          await Purchases.logIn('user:${user.uid}');
        } catch (e) {
          print('⚠️ RevenueCat logIn failed: $e');
        }

        // 🔔 ログインユーザーの FCM トークンを即時登録・更新
        await _setupFcmForLoggedInUser(user.uid);
      }

      // ✅ 画面遷移（スタックをすべてクリアして戻れないようにする）
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
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

                return FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, preferencesSnapshot) {
                    if (!preferencesSnapshot.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final pendingToken = preferencesSnapshot.data!
                        .getString(pendingTeamInviteTokenKey);
                    if (pendingToken != null && pendingToken.isNotEmpty) {
                      return TeamInviteLinkLandingPage(token: pendingToken);
                    }
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
                );
              },
            ),
          ),
          (route) => false,
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワード再設定メールを送るには、先にメールアドレスを入力してください。')),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('パスワード再設定用のメールを送信しました。迷惑メールフォルダもご確認ください。')),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'パスワード再設定メールの送信に失敗しました';
      if (e.code == 'invalid-email') {
        message = 'メールアドレスの形式が正しくありません。';
      } else if (e.code == 'user-not-found') {
        message = 'このメールアドレスは登録されていません。';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワード再設定メールの送信に失敗しました。時間をおいて再度お試しください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= 600;

    final double formWidth =
        isTablet ? (screenWidth * 0.55).clamp(360.0, 460.0) : 300;

    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: formWidth,
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
                  width: formWidth,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
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
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _resetPassword,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black),
                      children: [
                        const TextSpan(text: 'パスワードをお忘れの方は'),
                        TextSpan(
                          text: 'こちら',
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ],
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
