import 'package:b_net/pages/team/ranking/national_team_ranking.dart';
import 'package:b_net/pages/team/ranking/prefecture_team_ranking.dart';
import 'package:b_net/pages/team/team_analysis_page.dart';
import 'package:b_net/pages/team/team_calender_tab.dart';
import 'package:b_net/pages/team/team_performance_home.dart';
import 'package:b_net/pages/team/team_profile.dart';
import 'package:b_net/pages/team/team_register_member.dart';
import 'package:b_net/pages/team/team_schedule_calendar.dart';
import 'package:b_net/pages/team/team_mission_page.dart';
import 'package:b_net/pages/team/team_mvp_vote_page.dart';
import 'package:b_net/pages/team/team_annual_results.dart';
import 'package:b_net/services/team_subscription_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  bool _hasOngoingTeamGoal = false;

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
    // このページを開いたタイミングを記録（最近動きがあるチーム判定用）
    await _updateTeamLastLoginAt();

    await _fetchTeamData(); // チーム情報（都道府県など）
    await _checkTeamSubscriptionStatus(); // サブスク情報（gold / platina）
    await _checkOngoingTeamGoals();
    _initializePages(); // ← ここで初めてページを組み立てる
  } finally {
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }
}

  Future<void> _updateTeamLastLoginAt() async {
    final teamId = widget.team['teamId'] as String?;
    if (teamId == null || teamId.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .set({'lastLoginAt': Timestamp.now()}, SetOptions(merge: true));
    } catch (e) {
      // 失敗しても画面表示に影響させない
      print('❌ teams/{teamId}.lastLoginAt の更新に失敗: $e');
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

        if (
          productId.contains('teamPlatina') ||
          productId.contains('platina')
        ) {
          tier = TeamPlanTier.platina;
        } else if (
          productId.contains('teamGold') ||
          productId.contains('gold')
        ) {
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

  Future<void> _checkOngoingTeamGoals() async {
    final teamId = widget.team['teamId'] as String?;
    if (teamId == null || teamId.trim().isEmpty) return;

    try {
      final now = Timestamp.fromDate(DateTime.now());

      // チーム目標: /teams/{teamId}/goals を想定
      final snap = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('goals')
          .where('endDate', isGreaterThan: now)
          .limit(20)
          .get();

      bool hasOngoing = false;
      for (final doc in snap.docs) {
        final data = doc.data();

        // update=false（未達成/未終了）を優先。無い場合は endDate だけで判定。
        final update = data['update'];
        if (update is bool && update == true) {
          continue;
        }

        final end = data['endDate'];
        if (end is Timestamp) {
          final endDate = end.toDate();
          if (endDate.isAfter(DateTime.now())) {
            hasOngoing = true;
            break;
          }
        } else {
          // endDateが無い/型違いの場合でも、ここまで来たら「進行中あり」とみなす
          hasOngoing = true;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _hasOngoingTeamGoal = hasOngoing;
      });
    } catch (e) {
      // 取得失敗時は false のまま
      print('❌ チーム目標(進行中)の取得に失敗: $e');
      if (!mounted) return;
      setState(() {
        _hasOngoingTeamGoal = false;
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

  // Drawerメニューの生成（リッチ版）
  Widget _buildDrawer(BuildContext context) {
    // プラン表示用
    final String planLabel = _hasActiveTeamSubscription
        ? (_teamPlanTier == TeamPlanTier.platina
            ? 'プラチナ'
            : (_teamPlanTier == TeamPlanTier.gold ? 'ゴールド' : 'プレミアム'))
        : 'ベーシック';

    // チーム画像URL: profileImageのみ
    final String teamImageUrl =
        (widget.team['profileImage'] ?? '').toString();

    Widget buildAvatar() {
      if (teamImageUrl.isNotEmpty) {
        return CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white,
          backgroundImage: NetworkImage(teamImageUrl),
          onBackgroundImageError: (_, __) {},
        );
      }
      return const CircleAvatar(
        radius: 26,
        backgroundImage: AssetImage('assets/default_team_avatar.png'),
        backgroundColor: Colors.white,
      );
    }

    Widget buildPlanChip() {
      final bool isPremium = _hasActiveTeamSubscription;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPremium
              ? Colors.white.withOpacity(0.18)
              : Colors.black.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(isPremium ? 0.35 : 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPremium) ...[
              const Icon(
                Icons.workspace_premium,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              planLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget menuTile({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? iconColor,
      String? badgeText,
      Widget? trailing,
    }) {
      final Widget defaultTrailing = const Icon(Icons.chevron_right);

      return ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? Colors.blue,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badgeText != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.blue.withOpacity(0.25)),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        trailing: trailing ?? defaultTrailing,
        onTap: onTap,
      );
    }

    Widget sectionTitle(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
          // リッチなヘッダー
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade700,
                  Colors.blue.shade500,
                  Colors.blue.shade300,
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.team['teamName'] ?? 'チーム').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: buildPlanChip(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              teamPrefecture.isNotEmpty ? teamPrefecture : '未設定',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                sectionTitle('チーム'),
                menuTile(
                  icon: Icons.flag,
                  title: 'チーム目標',
                  iconColor: _hasOngoingTeamGoal ? Colors.orange : Colors.blue,
                  badgeText: _hasOngoingTeamGoal ? '進行中' : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TeamMissionPage(
                          teamId: widget.team['teamId'],
                          hasActiveTeamSubscription: _hasActiveTeamSubscription,
                        ),
                      ),
                    );
                  },
                ),
                menuTile(
                  icon: Icons.group,
                  title: 'チームプロフィール',
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
                        ),
                      ),
                    );
                  },
                ),
                menuTile(
                  icon: Icons.emoji_people_outlined,
                  title: 'チームメンバー一覧',
                  onTap: () {
                    // 先にドロワーを閉じてから遷移（遷移時の見た目を安定させる）
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TeamMembersPage(teamId: widget.team['teamId']),
                      ),
                    );
                  },
                ),
                menuTile(
                  icon: Icons.person_add_alt_1,
                  title: '選手を登録する',
                  onTap: () {
                    // 先にドロワーを閉じてから遷移（遷移時の見た目を安定させる）
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TeamRegisterMemberPage(
                          teamId: (widget.team['teamId'] ?? '').toString(),
                          teamPrefecture: teamPrefecture,
                        ),
                      ),
                    );
                  },
                ),
                menuTile(
                  icon: Icons.group_add,
                  title: 'チームに招待する',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => InviteMemberPage(team: widget.team),
                      ),
                    );
                  },
                ),

                const Divider(height: 28),
                sectionTitle('データ'),
                menuTile(
                  icon: Icons.bar_chart,
                  title: '成績',
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
                menuTile(
                  icon: Icons.analytics,
                  title: '分析',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TeamAnalysisPage(
                          teamId: widget.team['teamId'],
                        ),
                      ),
                    );
                  },
                ),

                if (maxWinStreak != null && maxWinStreak! >= 2)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withOpacity(0.18)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '最多連勝記録: $maxWinStreak連勝  (${widget.team['maxWinStreakYear'] ?? '不明'}年)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Divider(height: 28),
                sectionTitle('アカウント'),
                menuTile(
                  icon: Icons.swap_horiz,
                  title: 'チーム切り替え',
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
                menuTile(
                  icon: Icons.workspace_premium,
                  title: 'チームプラン',
                  iconColor: _hasActiveTeamSubscription ? Colors.amber : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            TeamSubscriptionScreen(teamId: widget.team['teamId']),
                      ),
                    );
                  },
                ),
                menuTile(
                  icon: Icons.person,
                  title: '個人ページに戻る',
                  iconColor: Colors.teal,
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => HomePage(
                          userUid: widget.userUid,
                          isTeamAccount: false,
                          accountId: widget.userUid,
                          accountName: widget.accountName,
                          userPrefecture: widget.userPrefecture,
                          userPosition: widget.userPosition,
                          userTeamId: widget.userTeamId,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
        ),
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