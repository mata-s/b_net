import 'package:b_net/common/chat_room_list_screen.dart';
import 'package:b_net/common/notices/notices_page.dart';
import 'package:b_net/common/post_list_page.dart';
import 'package:b_net/common/search_page.dart';
import 'package:b_net/pages/private/annual_results.dart';
import 'package:b_net/pages/private/predict_analysis_page.dart';
import 'package:b_net/pages/private/director_and_manager.dart';
import 'package:b_net/pages/private/director/director_calendar.dart';
import 'package:b_net/pages/private/manager/manager_geme_page.dart';
import 'package:b_net/pages/private/mission_page.dart';
import 'package:b_net/pages/private/national/national_page.dart';
import 'package:b_net/pages/private/private_calendar_tab.dart';
import 'package:b_net/pages/private/ranking/ranking_page.dart';
import 'package:b_net/pages/private/setting.dart';
import 'package:b_net/pages/team/create_team.dart';
import 'package:b_net/pages/team/member_parts/team_invite_identify_member_page.dart';
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
  bool _hasOngoingGoal = false;

  StreamSubscription<QuerySnapshot>? _chatRoomsSubscription;
  StreamSubscription<QuerySnapshot>? _announcementsSubscription;
  StreamSubscription<QuerySnapshot>? _goalsSubscription;
  // --- team invites
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _teamInvitesSubscription;
  QueryDocumentSnapshot<Map<String, dynamic>>? _pendingInviteDoc;

  @override
  void initState() {
    super.initState();
    _checkUnreadNotices();
    _fetchUnreadMessageCount();
    _listenOngoingGoals();
    _listenPendingTeamInvites();
    _checkSubscriptionStatus().then((_) {
      _initializePages();
    });
  }
  /// 目標（month / year）が「進行中」かどうかをリアルタイムで監視
  void _listenOngoingGoals() {
    final uid = widget.userUid;
    if (uid.isEmpty) return;

    // 以前の購読があれば一度キャンセル
    _goalsSubscription?.cancel();

    _goalsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals')
        .snapshots()
        .listen(
      (snapshot) {
        final now = DateTime.now();
        final monthKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
        final yearKey = now.year;

        bool hasOngoing = false;

        for (final doc in snapshot.docs) {
          final data = doc.data();

          // month は "YYYY-MM" / "YYYY-M" の両方を許容して "YYYY-MM" に正規化
          String? month;
          final dynamic monthRaw = data['month'];
          if (monthRaw is String) {
            final raw = monthRaw.trim();
            if (raw.isNotEmpty) {
              final parts = raw.split('-');
              if (parts.length == 2) {
                final y = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                if (y != null && m != null && m >= 1 && m <= 12) {
                  month = '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
                } else {
                  // 想定外フォーマットはそのまま（比較には使わない）
                  month = raw;
                }
              } else {
                month = raw;
              }
            }
          }

          // year は int / String の両方を許容
          final dynamic yearRaw = data['year'];
          final int? year = (yearRaw is int)
              ? yearRaw
              : (yearRaw is String ? int.tryParse(yearRaw.trim()) : null);

          final bool isThisMonth = (month != null && month == monthKey);
          final bool isThisYear = (year != null && year == yearKey);
          if (!isThisMonth && !isThisYear) continue;

          // endDate が未来なら「進行中」
          final dynamic endDateRaw = data['endDate'];
          if (endDateRaw is Timestamp) {
            final endDate = endDateRaw.toDate();
            if (endDate.isAfter(now)) {
              hasOngoing = true;
              break;
            }
          }
        }

        if (!mounted) return;
        if (_hasOngoingGoal != hasOngoing) {
          setState(() {
            _hasOngoingGoal = hasOngoing;
          });
        }
      },
      onError: (error) {
        debugPrint('goals snapshots error: $error');
      },
    );
  }

  /// teamInvites の pending を監視（チーム所属中でも表示）
  void _listenPendingTeamInvites() {
    final uid = widget.userUid;
    if (uid.isEmpty) return;

    _teamInvitesSubscription?.cancel();

    _teamInvitesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('teamInvites')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;

        if (snapshot.docs.isEmpty) {
          // 0件になっても一瞬で消えるのが気になる場合は、ここを即nullにせずに
          // 例えば数秒ディレイで消すなども可能。まずは素直に反映。
          setState(() {
            _pendingInviteDoc = null;
          });
          return;
        }

        // createdAt があれば最新を選ぶ（無い場合は先頭）
        QueryDocumentSnapshot<Map<String, dynamic>> latest = snapshot.docs.first;
        for (final d in snapshot.docs) {
          final a = latest.data()['createdAt'];
          final b = d.data()['createdAt'];
          if (a is Timestamp && b is Timestamp) {
            if (b.compareTo(a) > 0) latest = d;
          } else if (a is! Timestamp && b is Timestamp) {
            // latest に createdAt が無くて d にあるなら d を優先
            latest = d;
          }
        }

        setState(() {
          _pendingInviteDoc = latest;
        });
      },
      onError: (error) {
        // エラー時に一瞬で消えるのを防ぐため、直前の表示は維持してログだけ出す
        debugPrint('teamInvites snapshots error: $error');
      },
    );
  }

  Future<void> _respondToTeamInvite({
    required QueryDocumentSnapshot<Map<String, dynamic>> inviteDoc,
    required bool accept,
  }) async {
    final uid = widget.userUid;
    if (uid.isEmpty) return;

    final data = inviteDoc.data();
    final String teamId = (data['teamId'] as String?)?.trim() ?? '';
    if (teamId.isEmpty) return;

    // ✅ 参加する場合は「あなたはいますか？」画面へ進める（ここではまだ teams/members は更新しない）
    if (accept) {
      final String teamName = (data['teamName'] as String?)?.trim() ?? '';

      if (!mounted) return;
      final selectedMemberUid = await Navigator.of(context).push<String?>(
        MaterialPageRoute(
          builder: (_) => TeamInviteIdentifyMemberPage(
            currentUserUid: uid,
            teamId: teamId,
            inviteDocId: inviteDoc.id,
            teamName: teamName,
          ),
        ),
      );

      // ここでは「③ 選択」まで。選択結果を招待ドキュメントへ保存（次のステップで統合処理に使う）
      if (selectedMemberUid != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('teamInvites')
              .doc(inviteDoc.id)
              .set(
            {
              'selectedMemberUid': selectedMemberUid,
              'step': 'member_selected',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('選択しました。次の手順へ進めます')),
          );
        } catch (e) {
          debugPrint('save selected member error: $e');
        }
      }

      return;
    }

    // ✅ 参加しない（辞退）は従来どおり status 更新
    try {
      final inviteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('teamInvites')
          .doc(inviteDoc.id);

      await inviteRef.set(
        {
          'status': 'declined',
          'respondedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('招待を辞退しました')),
      );
    } catch (e) {
      debugPrint('team invite decline error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('処理に失敗しました: $e')),
      );
    }
  }

  Future<void> _showTeamInviteDialog({
    required String teamName,
    required QueryDocumentSnapshot<Map<String, dynamic>> inviteDoc,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'チーム招待',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: '閉じる',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: Text('$teamName から招待が届いています。\n参加しますか？'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _respondToTeamInvite(inviteDoc: inviteDoc, accept: false);
              },
              child: const Text('参加しない'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _respondToTeamInvite(inviteDoc: inviteDoc, accept: true);
              },
              child: const Text('参加する'),
            ),
          ],
        );
      },
    );
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
          Map<String, dynamic> data = doc.data();
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
      PostListPage(userUid: widget.userUid, userName: widget.accountName, teamId: widget.userTeamId ?? ''),
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
    _goalsSubscription?.cancel();
    _teamInvitesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTeam = (widget.userTeamId != null && widget.userTeamId!.trim().isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SearchPage(
                    userPosition: widget.userPosition,
                    userTeamId: widget.userTeamId,
                    userPrefecture: widget.userPrefecture,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // ===== Header =====
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userUid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();

                  final name = (data?['name'] as String?)?.trim().isNotEmpty == true
                      ? (data!['name'] as String)
                      : widget.accountName;

                  final prefecture = (data?['prefecture'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true
                      ? (data!['prefecture'] as String)
                      : widget.userPrefecture;

                  final positionsRaw = data?['position'];
                  final List<String> positions = (positionsRaw is List)
                      ? positionsRaw
                          .whereType<String>()
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                      : widget.userPosition;

                  // Firestore の実フィールドは profileImage を使う（photoUrl ではない）
                  final photoUrl = (data?['profileImage'] as String?)?.trim();

                  // ignore: unused_local_variable
                  final initial = (name.isNotEmpty ? name.substring(0, 1) : 'B')
                      .toUpperCase();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: (photoUrl != null && photoUrl.isNotEmpty)
                                ? Image.network(
                                    photoUrl,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/default_avatar.png',
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : Image.asset(
                                    'assets/default_avatar.png',
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _hasActiveSubscription
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.black.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.35),
                                      ),
                                    ),
                                    child: Text(
                                      _hasActiveSubscription ? 'プレミアム' : 'ベーシック',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                prefecture,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: positions
                                    .take(3)
                                    .map(
                                      (p) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          p,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ===== Menu =====
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // 監督・マネージャー専用：相手チーム探し（SearchPageへ）
                    if (widget.userPosition.contains('監督') ||
                        widget.userPosition.contains('マネージャー')) ...[
                      _DrawerSectionTitle(title: 'チーム'),
                      _RichDrawerTile(
                        icon: Icons.search,
                        title: '相手チームを探す',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchPage(
                                userPosition: widget.userPosition,
                                userTeamId: widget.userTeamId,
                                userPrefecture: widget.userPrefecture,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                    ],
                    _DrawerSectionTitle(title: '成績・振り返り'),
                    _RichDrawerTile(
                      icon: Icons.flag,
                      title: '目標',
                      leadingIconColor:
                          _hasOngoingGoal ? Colors.orange : null,
                      badgeText: _hasOngoingGoal ? '進行中' : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MissionPage(
                              userUid: widget.userUid,
                              hasActiveSubscription: _hasActiveSubscription,
                            ),
                          ),
                        );
                      },
                    ),
                    _RichDrawerTile(
                      icon: Icons.star,
                      title: '成績',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnnualResultsPage(
                              userPosition: widget.userPosition,
                            ),
                          ),
                        );
                      },
                    ),
                   if (!(widget.userPosition.contains('監督') ||
                         widget.userPosition.contains('マネージャー')))
                     _RichDrawerTile(
                       icon: Icons.insights,
                       title: '予測・分析',
                       onTap: () {
                         Navigator.pop(context);
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (context) => PredictAnalysisPage(
                               userUid: widget.userUid,
                               userPosition: widget.userPosition,
                             ),
                           ),
                         );
                       },
                     ),

                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 6),

                    _DrawerSectionTitle(title: 'アカウント'),
                    _RichDrawerTile(
                      icon: Icons.person,
                      title: 'プロフィール',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfilePage(userUid: widget.userUid),
                          ),
                        );
                      },
                    ),
                    _RichDrawerTile(
                      icon: Icons.swap_horiz,
                      title: 'チームに切り替える',
                      leadingIconColor: hasTeam ? const Color(0xFF2E7D32) : null,
                      onTap: () {
                        if (!hasTeam) return;
                        Navigator.pop(context);
                        Navigator.push(
                          context,
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
                    _RichDrawerTile(
                      icon: Icons.group_add,
                      title: 'チームを作る',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateTeamAccountPage(
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

                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 6),

                    _DrawerSectionTitle(title: '情報・設定'),
                    _RichDrawerTile(
                      icon: Icons.workspace_premium,
                      title: 'プレミアムプラン',
                      leadingIconColor: _hasActiveSubscription ? const Color(0xFFFFB300) : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SubscriptionScreen()),
                        );
                      },
                    ),
                    _RichDrawerTile(
                      icon: Icons.campaign,
                      title: 'お知らせ',
                      leadingIconColor: hasUnreadNotices ? Colors.red : null,
                      titleSuffix: hasUnreadNotices ? const _UnreadDot() : null,
                      trailingWidget: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => NoticesPage()),
                        ).then((_) => _checkUnreadNotices());
                      },
                    ),
                    _RichDrawerTile(
                      icon: Icons.settings,
                      title: '設定',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingsPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if ((widget.userPosition.contains('監督') ||
                  widget.userPosition.contains('マネージャー')) &&
              !(widget.userTeamId != null &&
                  widget.userTeamId!.trim().isNotEmpty))
            GestureDetector(
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
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.groups, color: Color(0xFF1565C0)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'まずはチームを作成しましょう',
                            style: TextStyle(
                              color: Color(0xFF0D47A1),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Color(0xFF1565C0)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '🏟 チームを作成すると出来ること',
                      style: TextStyle(
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '・試合スコア管理\n・チーム成績\n・個人成績',
                      style: TextStyle(
                        color: const Color(0xFF0D47A1).withOpacity(0.9),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 招待が届いていれば案内を表示（全ユーザー対象・チーム所属中でも表示）
          if (_pendingInviteDoc != null)
            Builder(
              builder: (context) {
                final invite = _pendingInviteDoc!.data();
                final String teamId = (invite['teamId'] as String?)?.trim() ?? '';
                final String teamNameFromInvite =
                    (invite['teamName'] as String?)?.trim() ?? '';

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: teamId.isNotEmpty
                      ? FirebaseFirestore.instance.collection('teams').doc(teamId).snapshots()
                      : const Stream.empty(),
                  builder: (context, teamSnap) {
                    final teamNameFromTeamDoc =
                        (teamSnap.data?.data()?['teamName'] as String?)?.trim() ??
                        (teamSnap.data?.data()?['name'] as String?)?.trim() ??
                        '';

                    final String teamName = teamNameFromInvite.isNotEmpty
                        ? teamNameFromInvite
                        : (teamNameFromTeamDoc.isNotEmpty ? teamNameFromTeamDoc : 'チーム');

                    return GestureDetector(
                      onTap: () {
                        _showTeamInviteDialog(
                          teamName: teamName,
                          inviteDoc: _pendingInviteDoc!,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mail, color: Color(0xFFF57F17)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$teamName から招待が届いています',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF5D4037),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFFF57F17)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          Expanded(
            child: _pages.isNotEmpty
                ? _pages[_currentIndex]
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
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

class _DrawerSectionTitle extends StatelessWidget {
  final String title;
  const _DrawerSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RichDrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badgeText;
  final Widget? trailingWidget;
  final Color? leadingIconColor;
  final Widget? titleSuffix;

  const _RichDrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeText,
    this.trailingWidget,
    this.leadingIconColor,
    this.titleSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: leadingIconColor ?? Colors.blue,
        size: 26,
      ),
      title: Row(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (titleSuffix != null) ...[
            const SizedBox(width: 6),
            titleSuffix!,
          ],
          if (badgeText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF1565C0).withOpacity(0.18),
                ),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: trailingWidget ?? const Icon(Icons.chevron_right),
      onTap: onTap,
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}