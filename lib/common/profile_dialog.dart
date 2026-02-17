import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_net/common/chat_utils.dart';
import 'package:b_net/main.dart';

void showProfileDialog(
    BuildContext context, String accountId, bool isTeamAccount,
    {String? currentUserUid,
    String? currentUserName,
    bool isFromSearch = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ProfileDialog(
      accountId: accountId,
      isTeamAccount: isTeamAccount,
      currentUserUid: currentUserUid,
      currentUserName: currentUserName,
      isFromSearch: isFromSearch, // 🔹 検索ページから開いたかどうかのフラグ
    ),
  );
}

class ProfileDialog extends StatefulWidget {
  final String accountId;
  final bool isTeamAccount;
  final String? currentUserUid;
  final String? currentUserName;
  final bool isFromSearch; // 🔹 検索ページから開いたかどうか

  const ProfileDialog({
    Key? key,
    required this.accountId,
    required this.isTeamAccount,
    this.currentUserUid,
    this.currentUserName,
    this.isFromSearch = false, // 🔹 デフォルトは false（検索から開いた時だけ true）
  }) : super(key: key);

  @override
  _ProfileDialogState createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  late Future<Map<String, dynamic>?> _profileData;
  String? currentUserName; // 🔹 Firestoreから取得した送信者名
  String? teamAdminUid; // 🔹 チームの管理者ID
  String? teamAdminName; // 🔹 チーム管理者の名前
  List<Map<String, String>> _teamNames = [];

  @override
  void initState() {
    super.initState();
    _profileData = _fetchProfileData();
    if (widget.currentUserName == null) {
      _fetchCurrentUserName(); // 🔹 送信者名を取得
    } else {
      currentUserName = widget.currentUserName;
    }
  }

  /// 🔹 Firestore からユーザーの名前を取得
  Future<void> _fetchCurrentUserName() async {
    if (widget.currentUserUid == null) return;

    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserUid)
        .get();

    if (snapshot.exists) {
      setState(() {
        currentUserName = snapshot['name'] ?? '不明';
      });
    }
  }

  /// 🔹 Firestore からプロフィールデータを取得
  Future<Map<String, dynamic>?> _fetchProfileData() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection(widget.isTeamAccount ? 'teams' : 'users')
        .doc(widget.accountId)
        .get();

    if (!snapshot.exists) return null;
    var data = snapshot.data() as Map<String, dynamic>?;

    if (!widget.isTeamAccount && data != null && data['teams'] != null) {
      _fetchTeamNames(List<String>.from(data['teams']));
    }

    if (widget.isTeamAccount && data != null) {
      setState(() {
        teamAdminUid = data['createdBy']; // 🔹 チームの管理者IDを取得
      });

      if (teamAdminUid != null) {
        DocumentSnapshot adminSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(teamAdminUid)
            .get();

        if (adminSnapshot.exists) {
          setState(() {
            teamAdminName = adminSnapshot['name'] ?? '不明';
          });
        }
      }
    }
    return data;
  }

  Future<void> _fetchTeamNames(List<dynamic> teamIds) async {
    if (teamIds.isEmpty) return;

    List<Map<String, String>> fetchedTeams = [];

    for (String teamId in teamIds) {
      DocumentSnapshot teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .get();
      if (teamDoc.exists) {
        fetchedTeams.add({
          'teamId': teamId, // 🔹 teamId も String に統一
          'teamName': teamDoc['teamName'] ?? '不明なチーム',
        });
      }
    }

    setState(() {
      _teamNames = fetchedTeams;
    });
  }

  String _formatBirthday(Timestamp birthday) {
    DateTime date = birthday.toDate();
    return "${date.year}年${date.month}月${date.day}日";
  }

  int _calculateAge(Timestamp birthday) {
    final b = birthday.toDate();
    final now = DateTime.now();

    int age = now.year - b.year;
    final hasHadBirthdayThisYear =
        (now.month > b.month) || (now.month == b.month && now.day >= b.day);
    if (!hasHadBirthdayThisYear) age -= 1;
    return age;
  }

  Future<void> _reportUser({
    required String reportedUserId,
    required String reason,
    required String? details,
  }) async {
    if (widget.currentUserUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通報するにはログインが必要です')),
        );
      }
      return;
    }

    await FirebaseFirestore.instance.collection('reports').add({
      'contentType': widget.isTeamAccount ? 'team_profile' : 'user_profile',
      'contentId': reportedUserId,
      'reportedUserId': reportedUserId,
      'reporterUserId': widget.currentUserUid,
      'reason': reason,
      'details': details,
      'status': 'open',
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isTeamAccount ? 'チームを通報しました' : 'ユーザーを通報しました'),
      ),
    );
  }

  Future<void> _blockUser({
    required String targetUserId,
    required String? targetUserName,
  }) async {
    if (widget.currentUserUid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ブロックするにはログインが必要です')),
        );
      }
      return;
    }

    // ブロック登録
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserUid)
        .collection('blockedUsers')
        .doc(targetUserId)
        .set({'blockedAt': Timestamp.now()});

    // Apple ガイドライン要件: ブロック時に開発者へ通知（通報記録として残す）
    await FirebaseFirestore.instance.collection('reports').add({
      'contentType': 'user_block',
      'contentId': targetUserId,
      'reportedUserId': targetUserId,
      'reporterUserId': widget.currentUserUid,
      'reason': 'blocked_user',
      'details': targetUserName,
      'status': 'open',
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;

    // 先にダイアログを閉じる（context破棄によるassert回避）
    Navigator.of(context).pop();

    // root ScaffoldMessenger に対して SnackBar を表示
    Future.microtask(() {
      final messenger = ScaffoldMessenger.maybeOf(
          navigatorKey.currentContext ?? context);
      messenger?.showSnackBar(
        const SnackBar(content: Text('ユーザーをブロックしました')),
      );
    });
  }

  Future<void> _showUserReportDialog(String reportedUserId) async {
    String selectedReason = 'inappropriate';
    final detailsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.isTeamAccount ? 'チームを通報する' : 'ユーザーを通報する'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('スパム')),
                  DropdownMenuItem(value: 'abuse', child: Text('暴言・嫌がらせ')),
                  DropdownMenuItem(value: 'inappropriate', child: Text('不適切な内容')),
                ],
                onChanged: (v) {
                  if (v != null) selectedReason = v;
                },
                decoration: const InputDecoration(labelText: '理由'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '詳細（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('送信'),
            ),
          ],
        );
      },
    );

    final details = detailsController.text.trim();

    if (result == true) {
      await _reportUser(
        reportedUserId: reportedUserId,
        reason: selectedReason,
        details: details.isEmpty ? null : details,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.4,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _profileData,
            builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('データが見つかりません'));
          }

          var data = snapshot.data!;
          String name = widget.isTeamAccount
              ? data['teamName'] ?? 'チーム名不明'
              : data['name'] ?? '名前不明';
          String recipientId =
              widget.isTeamAccount ? teamAdminUid ?? '' : widget.accountId;
          String recipientName =
              widget.isTeamAccount ? teamAdminName ?? '不明' : name;

          // **デフォルト画像処理**
          String profileImageUrl = data['profileImage'] ?? '';
          profileImageUrl = profileImageUrl.isNotEmpty
              ? profileImageUrl
              : (widget.isTeamAccount
                  ? 'assets/default_team_avatar.png'
                  : 'assets/default_avatar.png');

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                    // ===== Header =====
                    if (widget.isTeamAccount)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: Stack(
                          children: [
                            // 背景画像（チームは写真を大きく見せる）
                            SizedBox(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.height * 0.28,
                              child: Image(
                                image: profileImageUrl.startsWith('http')
                                    ? NetworkImage(profileImageUrl)
                                        as ImageProvider
                                    : AssetImage(profileImageUrl)
                                        as ImageProvider,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/default_team_avatar.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                            // 画像の上に薄いグラデーション
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.10),
                                      Colors.black.withOpacity(0.60),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 閉じるボタン
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Material(
                                color: Colors.black.withOpacity(0.25),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  tooltip: '閉じる',
                                ),
                              ),
                            ),
                            // チーム名 + 都道府県 + 平均年齢（下に寄せる）
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (data['prefecture'] != null &&
                                      data['prefecture']
                                          .toString()
                                          .isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 6.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              data['prefecture'].toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (data['averageAge'] != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        '平均年齢: ${data['averageAge']}歳',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // ユーザーは「カードっぽい」グラデーション + 中央アバターに
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFB3B3),
                                Color(0xFFFF8FA3),
                                Color(0xFFFFB07A),
                              ],
                            ),
                          ),
                          child: Stack(
                            children: [
                              // 閉じるボタン（右上）
                              Align(
                                alignment: Alignment.topRight,
                                child: Material(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                    tooltip: '閉じる',
                                  ),
                                ),
                              ),

                              // 中央コンテンツ
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 18),

                                    // アバター（ユーザーだけ）
                                    CircleAvatar(
                                      radius: 44,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.75),
                                      child: CircleAvatar(
                                        radius: 40,
                                        backgroundImage:
                                            profileImageUrl.startsWith('http')
                                                ? NetworkImage(profileImageUrl)
                                                    as ImageProvider
                                                : AssetImage(profileImageUrl)
                                                    as ImageProvider,
                                        backgroundColor: Colors.grey.shade200,
                                        onBackgroundImageError: (_, __) {},
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    Text(
                                      name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1.1,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        if (data['prefecture'] != null &&
                                            data['prefecture']
                                                .toString()
                                                .isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: Colors.white
                                                    .withOpacity(0.90),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                data['prefecture']
                                                    .toString(),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.90),
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (data['prefecture'] != null &&
                                            data['prefecture']
                                                .toString()
                                                .isNotEmpty &&
                                            data['positions'] != null &&
                                            data['positions'].isNotEmpty)
                                          const SizedBox(height: 4),
                                        if (data['positions'] != null &&
                                            data['positions'].isNotEmpty)
                                          Text(
                                            (data['positions'] as List)
                                                .join(', '),
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withOpacity(0.85),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        if (data['birthday'] != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.cake,
                                                  size: 14,
                                                  color: Colors.white
                                                      .withOpacity(0.90),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_formatBirthday(data['birthday'])}（${_calculateAge(data['birthday'])}歳）',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.85),
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ],
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
                      ),

                    // ===== Actions =====
                    const SizedBox(height: 14),

                    if (widget.isTeamAccount)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data['startYear'] != null &&
                                    data['startYear'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: const [
                                      Icon(Icons.flag, size: 18, color: Colors.grey),
                                      SizedBox(width: 6),
                                      Text(
                                        'チーム結成',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${data['startYear']}年',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],

                                if (data['achievements'] != null &&
                                    data['achievements'].isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    '実績',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: List.generate(
                                      data['achievements'].length,
                                      (index) => Text(
                                        '・${data['achievements'][index]}',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ),
                                ],

                                if (data['teamDescription'] != null &&
                                    data['teamDescription'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'チーム紹介文',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['teamDescription'],
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!widget.isTeamAccount) ...[
                      Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.6,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // ✅ 所属チーム（データがある場合のみ表示）
                                if (_teamNames.isNotEmpty) ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.groups,
                                          size: 18, color: Colors.grey),
                                      SizedBox(width: 6),
                                      Text(
                                        '所属チーム',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _teamNames.map((team) {
                                      final String teamId =
                                          team['teamId'] ?? '';
                                      final String teamName =
                                          team['teamName'] ?? '不明なチーム';

                                      return ActionChip(
                                        label: Text(teamName),
                                        onPressed: teamId.isEmpty
                                            ? null
                                            : () {
                                                showProfileDialog(
                                                  context,
                                                  teamId,
                                                  true,
                                                  currentUserUid:
                                                      widget.currentUserUid,
                                                  currentUserName:
                                                      widget.currentUserName ??
                                                          currentUserName,
                                                );
                                              },
                                      );
                                    }).toList(),
                                  ),
                                ],

                                // ✅ 自己紹介（データがある場合のみ表示）
                                if (data['include'] != null &&
                                    data['include']
                                        .toString()
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  const SizedBox(height: 3),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        data['include'].toString(),
                                        style: const TextStyle(fontSize: 16),
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // 🔹 **チーム / ユーザー共通の「メッセージを送る」ボタン**
                    if (recipientId.isNotEmpty &&
                        widget.currentUserUid != null &&
                        widget.currentUserUid != recipientId)
                      Center(
                        child: ConstrainedBox(
                          // 少しコンパクトな横幅に制限（中央寄せボタン）
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  print("✅ メッセージを送るボタンが押されました");
                                  print("👤 送信者 UID: ${widget.currentUserUid}");
                                  print("📛 送信者名: $currentUserName");
                                  print("👤 受信者 UID: $recipientId");
                                  print("📛 受信者名: $recipientName");

                                  if (widget.currentUserUid == null ||
                                      currentUserName == null) {
                                    print("⚠️ 送信者情報が不足しています");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text("エラー: 送信者情報が不足しています"),
                                      ),
                                    );
                                    return;
                                  }

                                  if (recipientId.isEmpty ||
                                      recipientName.isEmpty) {
                                    print("⚠️ 受信者情報が不足しています");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text("エラー: 受信者情報が不足しています"),
                                      ),
                                    );
                                    return;
                                  }

                                  startChatRoom(
                                    context: context,
                                    recipientId: recipientId,
                                    recipientName: recipientName,
                                    userUid: widget.currentUserUid!,
                                    userName: currentUserName!,
                                  );
                                },
                                icon: const Icon(Icons.send_rounded),
                                label: const Text("メッセージを送る"),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 20),
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                  elevation: 2,
                                ),
                              ),
                              if (widget.isTeamAccount)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    '※メッセージはチームの代表者に届きます。',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                    // 🔹 通報・ブロック（ユーザーのみ / スクロール末尾・右寄せ）
                    if (!widget.isTeamAccount &&
                        widget.currentUserUid != null &&
                        widget.currentUserUid != widget.accountId)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  _showUserReportDialog(widget.accountId);
                                },
                                icon: const Icon(Icons.flag,
                                    size: 18, color: Colors.red),
                                label: const Text(
                                  '通報',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(0, 0),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('ユーザーをブロック'),
                                        content: const Text(
                                          'このユーザーをブロックしますか？\nブロックすると投稿やメッセージは表示されなくなります。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('キャンセル'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('ブロック'),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    await _blockUser(
                                      targetUserId: widget.accountId,
                                      targetUserName: name,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.block,
                                    size: 18, color: Colors.grey),
                                label: const Text(
                                  'ブロック',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: const Size(0, 0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 🔹 チームプロフィール用 通報（スクロール末尾・右寄せ）
                    if (widget.isTeamAccount &&
                        widget.currentUserUid != null &&
                        teamAdminUid != null &&
                        widget.currentUserUid != teamAdminUid)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              _showUserReportDialog(widget.accountId);
                            },
                            icon: const Icon(Icons.flag, color: Colors.red),
                            label: const Text(
                              '通報',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              minimumSize: const Size(0, 0),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
          );
        },
      ),
      ),
      ),
    );
  }
}
