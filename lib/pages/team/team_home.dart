import 'package:b_net/pages/team/ranking/national_team_ranking.dart';
import 'package:b_net/pages/team/ranking/prefecture_team_ranking.dart';
import 'package:b_net/pages/team/team_calender_tab.dart';
import 'package:b_net/pages/team/team_performance_home.dart';
import 'package:b_net/pages/team/team_profile.dart';
import 'package:b_net/pages/team/team_schedule_calendar.dart';
import 'package:b_net/pages/team/team_mission_page.dart';
import 'package:b_net/pages/team/team_mvp_vote_page.dart';
import 'package:b_net/pages/team/team_annual_results.dart';
import 'package:b_net/services/team_subscription_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuthを追加
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'member_parts/invite_member_page.dart'; // チームに招待するページ
import 'team_account.dart'; // チームアカウント切り替えページ
import 'member_parts/team_members_page.dart'; // チームメンバー一覧ページ
import '../../home_page.dart'; // 個人ページ

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum TeamPlanTier {
  none,
  gold,
  platina,
}

class TeamHomePage extends StatefulWidget {
  final Map<String, dynamic> team;
  final bool isTeamAccount; // 追加: チームアカウントかどうかのフラグ
  final String accountId; // 追加: アカウントID（チームIDまたは個人ID）
  final String accountName; // 追加: アカウント名（チーム名または個人名）
  final String userUid;
  final String userPrefecture;
  final List<String> userPosition;
  final String? userTeamId;

  const TeamHomePage({
    super.key,
    required this.team,
    required this.isTeamAccount, // 追加
    required this.accountId, // 追加
    required this.accountName, // 追加
    required this.userUid,
    required this.userPrefecture,
    required this.userPosition,
    this.userTeamId,
  });

  @override
  _TeamHomePageState createState() => _TeamHomePageState();
}

class _TeamHomePageState extends State<TeamHomePage> {
  int _selectedIndex = 0; // 初期選択インデックス
  late List<String> _memberIds = []; // メンバーのIDリスト
  late List<Widget> _pages = [];
  String teamPrefecture = ""; // チームの都道府県
  bool isLoading = true;
  int? maxWinStreak;
  bool _hasActiveTeamSubscription = false;
  TeamPlanTier _teamPlanTier = TeamPlanTier.none;

  // @override
  // void initState() {
  //   super.initState();
  //   _fetchTeamData();
  //   _checkTeamSubscriptionStatus();
  // }

  @override
void initState() {
  super.initState();
  _init();
}

Future<void> _init() async {
  try {
    final teamId = widget.team['teamId'] as String?;
    if (teamId != null && teamId.isNotEmpty) {
      try {
        await Purchases.logIn('team:$teamId');
        print('✅ RevenueCat: teamId でログイン (team:$teamId)');
      } catch (e) {
        print('⚠️ RevenueCat teamIdログイン失敗: $e');
      }
    }

    await _fetchTeamData();            // チーム情報（都道府県など）
    await _checkTeamSubscriptionStatus(); // サブスク情報（gold / platina）
    _initializePages();                // ← ここで初めてページを組み立てる
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

  Future<void> _fetchTeamData() async {
    try {
      DocumentSnapshot teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.team['teamId'])
          .get();

      if (teamDoc.exists && teamDoc.data() != null) {
        setState(() {
          final data = teamDoc.data() as Map<String, dynamic>;
          teamPrefecture = data['prefecture'] ?? "未設定";
          maxWinStreak = data['maxWinStreak'];
        });
      } else {
        print('❌ チームデータが見つかりません');
        setState(() {
          teamPrefecture = "未設定";
          maxWinStreak = null;
        });
      }
    } catch (e) {
      print('❌ Firestore からチームデータ取得中にエラー: $e');
      setState(() {
        teamPrefecture = "未設定";
        maxWinStreak = null;
      });
    }
  }

  Future<void> _checkTeamSubscriptionStatus() async {
    final teamId = widget.team['teamId'] as String?;
    if (teamId == null || teamId.isEmpty) return;
  
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('subscription')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
  
      if (!mounted) return;
  
      TeamPlanTier tier = TeamPlanTier.none;
  
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final productId = (data['productId'] ?? '') as String;
  
        if (productId.contains('teamPlatina')) {
          tier = TeamPlanTier.platina;
        } else if (productId.contains('teamGold')) {
          tier = TeamPlanTier.gold;
        }
      }
  
      setState(() {
        _hasActiveTeamSubscription = snapshot.docs.isNotEmpty;
        _teamPlanTier = tier;
      });
    } catch (e) {
      print('❌ チームのサブスク状態取得に失敗: $e');
      if (!mounted) return;
      setState(() {
        _hasActiveTeamSubscription = false;
        _teamPlanTier = TeamPlanTier.none;
      });
    }
  }

  void _initializePages() {
    // memberIdsをリストとして初期化
    _memberIds = List<String>.from(widget.team['members'] ?? []);

    _pages = [
      TeamPerformanceHome(
        teamId: widget.team['teamId'],
        memberIds: _memberIds,
        selectedPeriodFilter: '通算', // 初期値
        selectedGameTypeFilter: '全試合', // 初期値
        startDate: DateTime(2000, 1, 1), // 開始日
        endDate: DateTime.now(), // 終了日
        hasActiveTeamSubscription: _hasActiveTeamSubscription,
      ), 
      TeamCalenderTab(teamId: widget.team['teamId']),
      PrefectureTeamRanking(
        teamId: widget.team['teamId'],
        teamPrefecture: teamPrefecture,
        hasActiveTeamSubscription: _hasActiveTeamSubscription,
        teamPlanTier: _teamPlanTier,
      ),
      NationalTeamRanking(
        teamId: widget.team['teamId'],
        teamPrefecture: teamPrefecture,
        hasActiveTeamSubscription: _hasActiveTeamSubscription,
        teamPlanTier: _teamPlanTier,
      ),
      TeamMvpVotePage(teamId: widget.team['teamId'], hasActiveTeamSubscription: _hasActiveTeamSubscription, teamPlanTier: _teamPlanTier,),
      TeamScheduleCalendar(teamId: widget.team['teamId']),
    ];
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      // デフォルトのインデックス（例えば最初のページ）に戻す
      setState(() {
        _selectedIndex = 0; // または別の有効なインデックス
      });
    }
  }

  // Drawerメニューの生成
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              '${widget.team['teamName']} メニュー',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text('チーム目標'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      TeamMissionPage(teamId: widget.team['teamId'], hasActiveTeamSubscription: _hasActiveTeamSubscription),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('チームプロフィール'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => TeamProfilePage(
                          teamId: widget.team['teamId'],
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
            title: const Text('チームに招待する'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => InviteMemberPage(team: widget.team)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_people_outlined),
            title: const Text('チームメンバー一覧'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) =>
                        TeamMembersPage(teamId: widget.team['teamId'])),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('成績'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TeamAnnualResultsPage(
                    teamId: widget.team['teamId'],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('チームアカウント切り替え'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TeamAccountSwitchPage(
                    userUid: widget.userUid,
                    accountName: widget.accountName,
                    userPrefecture: widget.userPrefecture,
                    userPosition: widget.userPosition,
                    userTeamId: widget.userTeamId,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('個人ページに戻る'),
            onTap: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                // 🔄 ローディング表示（ぐるぐる＋白文字）
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.black87, // 背景を暗めにする
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          '個人アカウントに切り替え中…',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white, // 白文字
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                try {
                  await Purchases.logIn('user:${user.uid}');
                  print('✅ RevenueCat: Firebase UID にログイン (user:${user.uid})');

                  if (!context.mounted) return;

                  Navigator.of(context).pop(); // ローディング閉じる

                  // 個人ホームに遷移
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => HomePage(
                        userUid: user.uid,
                        isTeamAccount: false,
                        accountId: user.uid,
                        accountName: user.displayName ?? '名前不明',
                        userPrefecture: widget.userPrefecture,
                        userPosition: widget.userPosition,
                        userTeamId: widget.userTeamId,
                      ),
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop(); // ローディングを閉じる
                  print('⚠️ RevenueCat切り替え失敗: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('個人アカウントへの切り替えに失敗しました: $e')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ユーザーがログインしていません')),
                );
              }
            },
          ),
          if (maxWinStreak != null && maxWinStreak! >= 2)
            ListTile(
              leading:
                  const Icon(Icons.local_fire_department, color: Colors.red),
              title: Row(
                children: [
                  Text('最多連勝記録: ${maxWinStreak}連勝'),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.team['maxWinStreakYear'] ?? '不明'}年',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ListTile(
          leading: const Icon(Icons.workspace_premium),
            title: const Text('チームプラン'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                    TeamSubscriptionScreen(teamId: widget.team['teamId'])),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      return WillPopScope(
    // iOSの横スワイプやAndroidの戻るボタンで前のページに戻れないようにする
    onWillPop: () async {
      // false を返すと「戻る」操作をキャンセルする
      return false;
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text('${widget.team['teamName']}'),
      ),
      drawer: _buildDrawer(context), // ハンバーガーメニューを追加
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator()) // 🔥 Firestore のデータ取得中はローディング
          : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.blueGrey, // タブ全体の背景色
        selectedItemColor: Colors.blue, // 選択されているアイテムの色
        unselectedItemColor: Colors.black,
        onTap: _onItemTapped,
        currentIndex: _selectedIndex,
        // ラベルの色やスタイルを指定
        selectedLabelStyle:
            const TextStyle(color: Colors.red), // 選択されているラベルの色を赤に
        unselectedLabelStyle: const TextStyle(color: Colors.grey),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '成績',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: '記録する',
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
            icon: Icon(Icons.emoji_events),
            label: 'MVP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: '予定',
          ),
        ],
      ),
    ),
    );
  }
}
