import 'package:b_net/common/chat_room_list_screen.dart';
import 'package:b_net/common/notices/notices_page.dart';
import 'package:b_net/common/post_list_page.dart';
import 'package:b_net/common/search_page.dart';
import 'package:b_net/pages/private/annual_results.dart';
import 'package:b_net/pages/private/director_and_manager.dart';
import 'package:b_net/pages/private/director/director_calendar.dart';
import 'package:b_net/pages/private/manager/manager_geme_page.dart';
import 'package:b_net/pages/private/mission_page.dart';
import 'package:b_net/pages/private/national/national_page.dart';
import 'package:b_net/pages/private/private_calendar_tab.dart';
import 'package:b_net/pages/private/ranking/ranking_page.dart';
import 'package:b_net/pages/private/setting.dart';
import 'package:b_net/pages/team/create_team.dart';
import 'package:b_net/pages/team/team_account.dart';
import 'package:b_net/services/subscription_screen.dart';
import 'package:flutter/material.dart';
import 'pages/private/individual_home.dart';
import 'pages/private/profile_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  final String userUid;
  final bool isTeamAccount;
  final String accountId;
  final String accountName;
  final String userPrefecture;
  final List<String> userPosition;
  final String? userTeamId;

  // HomePage({required this.userUid});
  const HomePage({
    super.key,
    required this.userUid,
    required this.isTeamAccount,
    required this.accountId,
    required this.accountName,
    required this.userPrefecture,
    required this.userPosition,
    this.userTeamId,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<Widget> _pages = [];
  bool hasUnreadNotices = false;
  int unreadChatCount = 0;
  bool _hasActiveSubscription = false;

  StreamSubscription<QuerySnapshot>? _chatRoomsSubscription;
  StreamSubscription<QuerySnapshot>? _announcementsSubscription;

  @override
  void initState() {
  super.initState();
  _checkUnreadNotices();
  _fetchUnreadMessageCount();
  _checkSubscriptionStatus().then((_) {
    _initializePages();
  });
  }

    /// 個人サブスクが「active」かどうかチェック
  Future<void> _checkSubscriptionStatus() async {
    final uid = widget.userUid;
    if (uid.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (!mounted) return;

    setState(() {
      _hasActiveSubscription = snapshot.docs.isNotEmpty;
    });
  }

  /// **未読チャット数を取得**
  Future<void> _fetchUnreadMessageCount() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    // 以前の購読があれば一度キャンセル
    await _chatRoomsSubscription?.cancel();

    _chatRoomsSubscription = FirebaseFirestore.instance
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen(
      (chatSnapshot) {
        int totalUnread = 0;

        for (var doc in chatSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          int unreadCount = data['unreadCounts']?[userId] ?? 0;
          totalUnread += unreadCount;
        }

        if (mounted) {
          setState(() {
            unreadChatCount = totalUnread; // 🔴 未読数を更新
          });
        }
      },
      onError: (error) {
        // 権限エラーなどはログに出すだけにしてクラッシュさせない
        debugPrint('chatRooms snapshots error: $error');
      },
    );
  }

  void _updateUnreadChatCount() {
    setState(() {
      _fetchUnreadMessageCount(); // 🔹 未読数を再取得
    });
  }

  /// **未読のお知らせがあるかチェック**
  Future<void> _checkUnreadNotices() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    // 以前の購読があれば一度キャンセル
    await _announcementsSubscription?.cancel();

    _announcementsSubscription = FirebaseFirestore.instance
        .collection('announcements')
        .snapshots()
        .listen(
      (announcementSnapshot) async {
        bool hasUnread = false;

        for (var doc in announcementSnapshot.docs) {
          bool isRead = await _isRead(userId, doc.id);
          if (!isRead) {
            hasUnread = true;
            break;
          }
        }

        if (mounted) {
          setState(() {
            hasUnreadNotices = hasUnread;
          });
        }
      },
      onError: (error) {
        debugPrint('announcements snapshots error: $error');
      },
    );
  }

  /// **ユーザーがお知らせを読んだか確認**
  Future<bool> _isRead(String userId, String noticeId) async {
    DocumentSnapshot readDoc = await FirebaseFirestore.instance
        .collection('users_read')
        .doc(userId)
        .collection('read_announcements')
        .doc(noticeId)
        .get();
    return readDoc.exists;
  }

  void _initializePages() {
    _pages = [
      (widget.userPosition.contains('監督') ||
              widget.userPosition.contains('マネージャー'))
          ? DirectorAndManagerPage(
              userUid: widget.userUid,
              userPosition: widget.userPosition,
            )
          : IndividualHome(
              userUid: widget.userUid,
              userPosition: widget.userPosition,
              hasActiveSubscription: _hasActiveSubscription
            ),
      widget.userPosition.contains('マネージャー')
          ? ManagerGemePage(
              userUid: widget.userUid, teamId: widget.userTeamId ?? '')
          : widget.userPosition.contains('監督')
              ? DirectoCalendar(
                  userUid: widget.userUid, teamId: widget.userTeamId ?? '')
              : PrivateCalendarTab(userUid: widget.userUid, positions: widget.userPosition, hasActiveSubscription: _hasActiveSubscription,),
      PostListPage(userUid: widget.userUid, userName: widget.accountName),
      RankingPage(
        uid: widget.userUid,
        prefecture: widget.userPrefecture,
        hasActiveSubscription: _hasActiveSubscription,
      ),
      NationalPage(
        uid: widget.userUid,
        prefecture: widget.userPrefecture,
        hasActiveSubscription: _hasActiveSubscription,
      ),
      ChatRoomListScreen(onUnreadCountChanged: _updateUnreadChatCount),
    ];
  }

  void _onTabTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
    } else {
      // デフォルトのインデックス（例えば最初のページ）に戻す
      setState(() {
        _currentIndex = 0; // または別の有効なインデックス
      });
    }
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
    _announcementsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/logo.png',
          height: 40, // 画像の高さを調整
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SearchPage()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'メニュー',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text('目標'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MissionPage(userUid: widget.userUid, hasActiveSubscription: _hasActiveSubscription),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('プロフィール'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(userUid: widget.userUid),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('チームアカウントに切り替える'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => TeamAccountSwitchPage(
                            userUid: widget.userUid,
                            accountName: widget.accountName,
                            userPrefecture: widget.userPrefecture,
                            userPosition: widget.userPosition,
                            userTeamId: widget.userTeamId,
                          )),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('チームアカウントを作る'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CreateTeamAccountPage(
                            userUid: widget.userUid,
                            accountName: widget.accountName,
                            userPrefecture: widget.userPrefecture,
                            userPosition: widget.userPosition,
                            userTeamId: widget.userTeamId,
                          )),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('成績'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnnualResultsPage(userPosition: widget.userPosition,),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('お知らせ'),
                  if (hasUnreadNotices)
                    const Icon(Icons.circle,
                        color: Colors.red, size: 10), // 🔴 未読マーク
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NoticesPage()),
                ).then((_) => _checkUnreadNotices()); // 🔄 お知らせページを閉じたら未読チェック
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('設定'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text('プレミアムプラン'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubscriptionScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: _pages.isNotEmpty
          ? _pages[_currentIndex]
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.blueGrey,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black,
        onTap: _onTabTapped,
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              (widget.userPosition.contains('監督') ||
                      widget.userPosition.contains('マネージャー'))
                  ? Icons.note
                  : Icons.bar_chart,
            ),
            label: (widget.userPosition.contains('監督') ||
                    widget.userPosition.contains('マネージャー'))
                ? 'メモ'
                : '成績',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mode),
            label: widget.userPosition.contains('監督') ? 'オーダー' : '記録する',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '投稿一覧',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.rankingStar),
            label: 'ランキング',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.baseballBatBall),
            label: '全国',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none, // 🔹 バッジがアイコンの枠外にも配置できるようにする
              children: [
                const Icon(Icons.chat), // チャットアイコンのサイズはそのまま
                if (unreadChatCount > 0) // 🔴 未読数があるときのみバッジを表示
                  Positioned(
                    right: -2, // 🔹 右上に寄せる
                    top: -2, // 🔹 上に寄せる
                    child: Container(
                      padding: const EdgeInsets.all(2), // 🔹 バッジの余白を小さく
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(7), // 🔹 丸みを小さく調整
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12, // 🔹 バッジの幅を小さく
                        minHeight: 12, // 🔹 バッジの高さを小さく
                      ),
                      child: Text(
                        '$unreadChatCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8, // 🔹 数字を小さく
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'チャット',
          ),
        ],
      ),
    );
  }
}
