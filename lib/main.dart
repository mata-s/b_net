import 'package:b_net/common/chat_screen.dart';
import 'package:b_net/home_page.dart';
import 'package:b_net/login/registration_page.dart';
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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

  // タイムゾーン初期化（ローカル通知のスケジュール用）
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  // ローカル通知の初期化
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInitSettings =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // 月初＆3月のローカル通知をスケジュール
  await _scheduleMonthlyGoalNotification();
  await _scheduleMarchGoalNotification();

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

  runApp(const MyApp());
}

/// 毎月1日の朝9時に「今月の目標」を促すローカル通知をスケジュール
Future<void> _scheduleMonthlyGoalNotification() async {
  final now = tz.TZDateTime.now(tz.local);

  int year = now.year;
  int month = now.month;

  // すでに今月1日の9:00を過ぎていたら、来月1日をターゲットにする
  final thisMonthFirst9 = tz.TZDateTime(tz.local, year, month, 1, 9);
  if (now.isAfter(thisMonthFirst9)) {
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
  }

  final scheduledDate = tz.TZDateTime(tz.local, year, month, 1, 9);

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'goal_reminder_monthly',
    '月初の目標リマインダー',
    channelDescription: '毎月の始まりに目標を決めるリマインダー',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await flutterLocalNotificationsPlugin.zonedSchedule(
    100, // 通知ID（他と被らなければOK）
    '今月の目標を決めてみよう',
    'この1ヶ月で達成したいことを決めてみませんか？',
    scheduledDate,
    notificationDetails,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.wallClockTime,
    matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
  );
}

/// 毎年3月1日の朝9時に「今年の目標」を促すローカル通知をスケジュール
Future<void> _scheduleMarchGoalNotification() async {
  final now = tz.TZDateTime.now(tz.local);

  int year = now.year;

  // 今年の3月1日 9:00
  var marchDate = tz.TZDateTime(tz.local, year, 3, 1, 9);

  // すでに今年の3月1日 9:00 を過ぎている場合は来年3月にする
  if (now.isAfter(marchDate)) {
    year += 1;
    marchDate = tz.TZDateTime(tz.local, year, 3, 1, 9);
  }

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'goal_reminder_march',
    '3月の年間目標リマインダー',
    channelDescription: '3月に今年の目標を考えるためのリマインダー',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await flutterLocalNotificationsPlugin.zonedSchedule(
    101, // 通知ID（他の通知と被らないID）
    '今年の目標を決めてみよう',
    '今年の目標を考えてみませんか？',
    marchDate,
    notificationDetails,
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.wallClockTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );
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
      home: FutureBuilder<Widget>(
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

/// スケジュール通知から遷移してきたときに開く簡易ページ
/// スケジュール通知から遷移してきたときに開くページ
/// Firestore からイベントを取得して、その後 EventDetailPage に遷移する
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

  // iOSのみ：APNsトークンを待つ
  if (Platform.isIOS) {
    String? apnsToken = await messaging.getAPNSToken();
    int retry = 0;

    // APNs トークンが取れるまでリトライ
    while (apnsToken == null && retry < 5) {
      await Future.delayed(const Duration(seconds: 1));
      apnsToken = await messaging.getAPNSToken();
      retry++;
    }

    print("🍎 APNS Token: $apnsToken");
  }

  // 通知許可
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // FCMトークン
  final token = await messaging.getToken();
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

    // 🔐 RevenueCat に Firebase の UID でログインして、appUserID を固定する
    try {
      await Purchases.logIn(user.uid);
      print('✅ RevenueCat logIn succeeded for ${user.uid}');
    } catch (e) {
      print('⚠️ RevenueCat logIn failed: $e');
    }

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