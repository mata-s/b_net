import 'package:b_net/common/chat_screen.dart';
import 'package:b_net/home_page.dart';
import 'package:b_net/login/registration_page.dart';
import 'package:b_net/pages/splash_page.dart';
import 'package:b_net/pages/team/event_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'pages/team/team_schedule_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:purchases_flutter/purchases_flutter.dart'; // ← RevenueCat をインポート！
import 'package:firebase_auth/firebase_auth.dart';
import 'login/login_page.dart';
import 'common/chat_room_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
RemoteMessage? initialPushMessage;

/// FCMのバックグラウンドメッセージを受け取るハンドラー（トップレベル関数必須）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // バックグラウンド用に Firebase 初期化
  await Firebase.initializeApp();
  print('🔔 [BG] 背景でメッセージ受信: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // アプリが完全に終了している状態から通知で起動されたとき
  initialPushMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialPushMessage != null) {
    print('🚀 [INITIAL] 通知からアプリが起動しました: ${initialPushMessage!.messageId}');
    print('🚀 [INITIAL] data: ${initialPushMessage!.data}');
  }

  // フォアグラウンドで通知を受け取ったとき
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('🔔 [FG] フォアグラウンドでメッセージ受信: ${message.messageId}');
    print('🔔 [FG] data: ${message.data}');
    if (message.notification != null) {
      print('🔔 [FG] notification: ${message.notification!.title} - ${message.notification!.body}');
    }
  });

  // バックグラウンドから通知タップで復帰したとき
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📲 [OPENED] 通知からアプリが開かれました: ${message.messageId}');
    print('📲 [OPENED] data: ${message.data}');
    _handleMessageNavigation(message);
  });

  final currentUser = FirebaseAuth.instance.currentUser;
  final initialRcAppUserId = currentUser != null ? 'user:${currentUser.uid}' : null;

  const rcIosApiKey = 'appl_fbWgJWNLbAYxpijcSkSdVjVGHtT';
  const rcAndroidApiKey = 'goog_blusfYbDUamqpKTBHVkzbKCfcNH';
  
  PurchasesConfiguration? configuration;

  if (Platform.isIOS) {
  configuration = PurchasesConfiguration(rcIosApiKey);
} else if (Platform.isAndroid) {
  configuration = PurchasesConfiguration(rcAndroidApiKey);
}

  if (configuration != null) {
    if (initialRcAppUserId != null) {
      configuration.appUserID = initialRcAppUserId;
    }

    // デバッグ時にログを見たい場合
    // await Purchases.setLogLevel(LogLevel.debug);

    await Purchases.configure(configuration);
    print('✅ RevenueCat configured. initial appUserID=${initialRcAppUserId ?? "(anonymous)"}');
  } else {
    print('⚠️ RevenueCat SDKキーが未設定です（Android など）。後で設定してください。');
  }

  // 日本語日付フォーマットの初期化
  initializeDateFormatting('ja_JP', null);

  runApp(const MyApp());
}


void enableFirestoreCache() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // アプリ起動直後（getInitialMessage で取得した通知）があれば、最初のフレーム描画後に遷移
    if (initialPushMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessageNavigation(initialPushMessage!);
        initialPushMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Firebase Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashPage (
        resolveNextPage: () async => const _InitialPageGate(),
        duration: const Duration(milliseconds: 3000),
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

class _InitialPageGate extends StatelessWidget {
  const _InitialPageGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getInitialPage(),
      builder: (context, snapshot) {
        // ローディング中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // エラー発生時
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('エラーが発生しました: ${snapshot.error}'),
            ),
          );
        }

        // データがある場合
        if (snapshot.hasData && snapshot.data != null) {
          return snapshot.data!;
        }

        // データが null の場合のフォールバック（念のため）
        return const Scaffold(
          body: Center(
            child: Text('初期画面を読み込めませんでした'),
          ),
        );
      },
    );
  }
}

Future<void> _handleMessageNavigation(RemoteMessage message) async {
  final nav = navigatorKey.currentState;
  if (nav == null) {
    print('⚠️ navigatorKey.currentState が null のため、画面遷移できませんでした。');
    return;
  }

  final data = message.data;

  final type = data['type'];

  // 🔔 チーム参加通知（joined_team）は HomePage へ遷移
  if (type == 'joined_team') {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final positions = List<String>.from(userData['positions'] ?? []);
      final teams = List<String>.from(userData['teams'] ?? []);
      final prefecture = userData['prefecture'] ?? '未設定';

      // 通知に含まれる teamId を優先して userTeamId にセット
      final pushedTeamId = data['teamId']?.toString();
      final userTeamId =
          pushedTeamId?.isNotEmpty == true ? pushedTeamId : (teams.isNotEmpty ? teams.first : null);

      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePage(
            userUid: user.uid,
            isTeamAccount: false,
            accountId: user.uid,
            accountName: userData['username'] ?? '未設定',
            userPrefecture: prefecture,
            userPosition: positions,
            userTeamId: userTeamId,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      print('⚠️ チーム参加通知からの HomePage 遷移に失敗: $e');
    }
    return;
  }

  // 🔔 MVP 月間・年間の通知は HomePage へ遷移
  if (type == 'mvp_vote' ||
      type == 'mvpVoteReminder' ||
      type == 'mvpTallyReminder' ||
      type == 'mvpResult' ||
      type == 'mvp_year_vote' ||
      type == 'mvpYearVoteReminder' ||
      type == 'mvpYearTallyNotice' ||
      type == 'mvpYearResult') {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final positions = List<String>.from(userData['positions'] ?? []);
      final teams = List<String>.from(userData['teams'] ?? []);
      final prefecture = userData['prefecture'] ?? '未設定';

      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePage(
            userUid: user.uid,
            isTeamAccount: false,
            accountId: user.uid,
            accountName: userData['username'] ?? '未設定',
            userPrefecture: prefecture,
            userPosition: positions,
            userTeamId: teams.isNotEmpty ? teams.first : null,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      print('⚠️ MVP通知からの HomePage 遷移に失敗: $e');
    }
    return;
  }

  // 🔔 チーム目標（月間・年間）の通知も HomePage へ遷移
  if (type == 'team_goal_month' || type == 'team_goal_year') {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final positions = List<String>.from(userData['positions'] ?? []);
      final teams = List<String>.from(userData['teams'] ?? []);
      final prefecture = userData['prefecture'] ?? '未設定';

      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePage(
            userUid: user.uid,
            isTeamAccount: false,
            accountId: user.uid,
            accountName: userData['username'] ?? '未設定',
            userPrefecture: prefecture,
            userPosition: positions,
            userTeamId: teams.isNotEmpty ? teams.first : null,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      print('⚠️ チーム目標通知からの HomePage 遷移に失敗: $e');
    }
    return;
  }

  // 🔔 重要なお知らせの通知（type == 'announcement'）は HomePage へ遷移
  if (type == 'announcement') {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final positions = List<String>.from(userData['positions'] ?? []);
      final teams = List<String>.from(userData['teams'] ?? []);
      final prefecture = userData['prefecture'] ?? '未設定';

      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePage(
            userUid: user.uid,
            isTeamAccount: false,
            accountId: user.uid,
            accountName: userData['username'] ?? '未設定',
            userPrefecture: prefecture,
            userPosition: positions,
            userTeamId: teams.isNotEmpty ? teams.first : null,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      print('⚠️ お知らせ通知からの HomePage 遷移に失敗: $e');
    }
    return;
  }

  // ① スケジュール通知（type == 'schedule'）
  if (data['type'] == 'schedule') {
    final teamId = data['teamId'];
    final scheduleId = data['scheduleId'];

    print('📅 スケジュール通知からの遷移: teamId=$teamId, scheduleId=$scheduleId');

    nav.push(
      MaterialPageRoute(
        builder: (_) => ScheduleNotificationPage(
          teamId: teamId?.toString() ?? '',
          scheduleId: scheduleId?.toString() ?? '',
        ),
      ),
    );
    return;
  }

  // ② チャット通知（従来どおり）
  final roomId = data['roomId'];
  final recipientId = data['recipientId'];
  final recipientName = data['recipientName'];
  final recipientProfileImageUrl = data['recipientProfileImageUrl'];

  // roomId がない場合は一覧画面だけ開く
  if (roomId == null || (roomId is String && roomId.isEmpty)) {
    nav.push(
      MaterialPageRoute(
        builder: (_) => ChatRoomListScreen(
          onUnreadCountChanged: () {},
        ),
      ),
    );
    return;
  }

  // roomId がある場合は、特定のチャットルーム画面を直接開く
  nav.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        roomId: roomId,
        recipientId: recipientId,
        recipientName: recipientName,
        recipientProfileImageUrl: recipientProfileImageUrl,
      ),
    ),
  );
}

class ScheduleNotificationPage extends StatefulWidget {
  final String teamId;
  final String scheduleId;

  const ScheduleNotificationPage({
    super.key,
    required this.teamId,
    required this.scheduleId,
  });

  @override
  State<ScheduleNotificationPage> createState() =>
      _ScheduleNotificationPageState();
}

class _ScheduleNotificationPageState extends State<ScheduleNotificationPage> {
  @override
  void initState() {
    super.initState();
    _loadAndOpenEvent();
  }

  Future<void> _loadAndOpenEvent() async {
    try {
      // 該当チーム・スケジュールIDのドキュメントを取得
      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('schedule')
          .doc(widget.scheduleId)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('イベントが見つかりませんでした')),
        );
        Navigator.of(context).pop();
        return;
      }

      final data = snap.data() as Map<String, dynamic>;

      // team_schedule_calendar.dart の Event と同じ構造で Event を生成
      final String title = data['title'] ?? 'タイトルなし';
      final String opponent = data['opponent'] ?? '不明';
      final String location = data['location'] ?? '不明';
      final String details = data['details'] ?? '';
      final String? time = data['time'];
      final String createdBy = data['createdBy'] ?? '不明';
      final String createdName = data['createdName'] ?? '不明';

      // stamps / comments は存在しなければ空リスト
      final List<Map<String, dynamic>> stamps = data.containsKey('stamps')
          ? List<Map<String, dynamic>>.from(data['stamps'])
          : <Map<String, dynamic>>[];

      final List<Map<String, dynamic>> comments = data.containsKey('comments')
          ? List<Map<String, dynamic>>.from(data['comments'])
          : <Map<String, dynamic>>[];

      final event = Event(
        snap.id,
        title,
        opponent,
        location,
        details,
        time,
        createdBy,
        createdName,
        stamps,
        comments,
      );

      if (!mounted) return;

      // 直接 EventDetailPage に遷移（このページは閉じる）
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EventDetailPage(
            event: event,
            teamId: widget.teamId,
            onUpdate: (updatedEvent) {
              // 通知経由なので、ここでの更新反映はとりあえず何もしない
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('イベントの読み込みに失敗しました: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 読み込み中はローディングだけ表示
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// ログイン中ユーザーの FCMトークンを Firestore に保存
Future<void> _setupMessagingForUser(String uid) async {
  final messaging = FirebaseMessaging.instance;

  // ✅ 先に通知許可（iOSはこれが先）
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // ✅ iOSのみ：APNsトークンが取れない場合（特にシミュレーター）は無理にFCM取得しない
  if (Platform.isIOS) {
    String? apnsToken = await messaging.getAPNSToken();
    int retry = 0;

    while (apnsToken == null && retry < 5) {
      await Future.delayed(const Duration(seconds: 1));
      apnsToken = await messaging.getAPNSToken();
      retry++;
    }

    print('🍎 APNS Token: $apnsToken');

    if (apnsToken == null) {
      // iOSシミュレーター等ではAPNSが取れず getToken() が例外になることがある
      print('⚠️ APNS token not available yet. Skip FCM token setup on this device.');
      return;
    }
  }

  String? token;
  try {
    token = await messaging.getToken();
  } catch (e) {
    print('⚠️ Failed to get FCM token for $uid: $e');
    return;
  }

  print('🔑 FCM token for $uid: $token');

  if (token != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(
      {'fcmTokens': FieldValue.arrayUnion([token])},
      SetOptions(merge: true),
    );
  }

  // トークン更新
  messaging.onTokenRefresh.listen((newToken) {
    FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'fcmTokens': FieldValue.arrayUnion([newToken])},
      SetOptions(merge: true),
    );
  });
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
    await _setupMessagingForUser(user.uid);

  // Update only the user's lastLoginAt field in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );


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