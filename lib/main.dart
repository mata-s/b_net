import 'package:b_net/home_page.dart';
import 'package:b_net/login/registration_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:purchases_flutter/purchases_flutter.dart'; // ← RevenueCat をインポート！

import 'package:firebase_auth/firebase_auth.dart';
import 'login/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化
  await Firebase.initializeApp();

  // RevenueCat 初期化（←ここにあなたの公開 SDK キーを貼る！）
  // final configuration = Platform.isAndroid
  //   ? PurchasesConfiguration('your_android_revenuecat_sdk_key') // ← Android用
  //   : PurchasesConfiguration('appl_fbWgJWNLbAYxpijcSkSdVjVGHtT');    // ← iOS用

  // await Purchases.configure(configuration);

  final configuration = Platform.isIOS
      ? PurchasesConfiguration(
          'appl_fbWgJWNLbAYxpijcSkSdVjVGHtT') // ← あなたのiOS SDKキー
      : null;

  if (configuration != null) {
    await Purchases.configure(configuration);
  } else {
    print('⚠️ AndroidのRevenueCat SDKキーが未設定です。後で設定してください。');
  }

  // 日本語日付フォーマットの初期化
  initializeDateFormatting('ja_JP', null);

  runApp(MyApp());
}

void enableFirestoreCache() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else {
            return snapshot.data!;
          }
        },
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ja', ''),
      ],
      locale: const Locale('ja', ''),
    );
  }
}

Future<Widget> _getInitialPage() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  if (isFirstLaunch) {
    await prefs.setBool('isFirstLaunch', false);
    return const SignUpPage();
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final positions = List<String>.from(data['positions'] ?? []);
        final teams = List<String>.from(data['teams'] ?? []);
        final prefecture = data['prefecture'] ?? "未設定";

        return HomePage(
          userUid: user.uid,
          isTeamAccount: false,
          accountId: user.uid,
          accountName: data['username'] ?? '未設定',
          userPrefecture: prefecture,
          userPosition: positions,
          userTeamId: teams.isNotEmpty ? teams.first : null,
        );
      }
    } catch (e) {
      print('⚠️ ユーザーデータ取得失敗: $e');
    }
    return HomePage(
      userUid: user.uid,
      isTeamAccount: false,
      accountId: user.uid,
      accountName: '未設定',
      userPrefecture: '未設定',
      userPosition: const [],
      userTeamId: null,
    );
  } else {
    return const LoginPage();
  }
}
