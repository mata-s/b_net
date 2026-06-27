import 'package:b_net/pages/team/edit_team_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../home_page.dart'; // 個人ページをインポート

class TeamProfilePage extends StatefulWidget {
  final String teamId;
  final String userUid;
  final String accountName;
  final String userPrefecture;
  final List<String> userPosition;
  final String? userTeamId;

  const TeamProfilePage({
    super.key,
    required this.teamId,
    required this.userUid,
    required this.accountName,
    required this.userPrefecture,
    required this.userPosition,
    this.userTeamId,
  });

  @override
  _TeamProfilePageState createState() => _TeamProfilePageState();
}

class _TeamProfilePageState extends State<TeamProfilePage> {
  DocumentSnapshot? _teamData;
  bool _isLoading = true;
  String? _errorMessage;
  String? _adminName;
  String? _adminId;
  String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isTeamSubscribed = false;
  String? _teamPlanName;

  @override
  void initState() {
    super.initState();
    _fetchTeamData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Theme.of(context) を安全に使える場所
    _loadTeamSubscriptionStatus();
  }

  Future<void> _fetchTeamData() async {
    try {
      print('Fetching team data for teamId: ${widget.teamId}');

      DocumentSnapshot teamSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();

      if (teamSnapshot.exists) {
        setState(() {
          _teamData = teamSnapshot;
          _isLoading = false;
          _adminId = teamSnapshot['createdBy'];
        });

        if (_adminId != null && _adminId!.isNotEmpty) {
          _fetchAdminName(_adminId!);
        }
      } else {
        setState(() {
          _teamData = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'チームデータの取得に失敗しました: $e';
      });
      // SnackBarをフレーム後にスケジュールして表示
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      });
    }
  }

  Future<void> _loadTeamSubscriptionStatus() async {
  final platform =
      Theme.of(context).platform == TargetPlatform.iOS ? 'iOS' : 'Android';

  final doc = await FirebaseFirestore.instance
      .collection('teams')
      .doc(widget.teamId)
      .collection('subscription')
      .doc(platform)
      .get();

  if (!doc.exists) {
    setState(() {});
    return;
  }

  final data = doc.data();
  final status = data?['status'];
  final productIdRaw = data?['productId'];

  if (status != 'active' || productIdRaw == null) {
    setState(() {});
    return;
  }

  _isTeamSubscribed = true;

  final productId = productIdRaw.toString().toLowerCase();

  final isGold = productId.contains('gold');
  final isPlatina = productId.contains('platina');
  final isYearly = productId.contains('yearly');

  if (isGold) {
    _teamPlanName = isYearly ? 'ゴールド（年額）' : 'ゴールド';
  } else if (isPlatina) {
    _teamPlanName = isYearly ? 'プラチナ（年額）' : 'プラチナ';
  } else {
    _teamPlanName = '不明なプラン';
  }

  setState(() {});
}

  /// 🔹 **管理者（createdBy）の名前を取得**
  Future<void> _fetchAdminName(String adminId) async {
    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();

      if (userSnapshot.exists) {
        setState(() {
          _adminName = userSnapshot['name'] ?? '管理者名不明';
        });
      } else {
        setState(() {
          _adminName = '管理者名不明';
        });
      }
    } catch (e) {
      setState(() {
        _adminName = '取得失敗';
      });
    }
  }

  Future<void> _leaveTeam() async {
    bool confirmLeave = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('チームを抜ける'),
          content: const Text('本当にチームから抜けますか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // ❌ キャンセル
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // ✅ 確認
              child: const Text('はい', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (!confirmLeave) return; // キャンセル時は処理を中断

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // 🔹 Firestore 更新（チームからユーザーを削除）
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({
        'members': FieldValue.arrayRemove([userId]),
      });

      // 🔹 Firestore 更新（ユーザーの参加チームからチームを削除）
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'teams': FieldValue.arrayRemove([widget.teamId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チームを抜けました')),
      );

      // 🔹 個人のページ（`HomePage`）へ戻る
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.of(context).pushAndRemoveUntil(
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
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  Future<void> _deleteTeam() async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('チームを削除'),
          content: const Text('本当に削除しますか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // ❌ キャンセル
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // ✅ 確認
              child: const Text('はい', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (!confirmDelete) return; // キャンセル時は処理を中断

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentReference teamRef =
          firestore.collection('teams').doc(widget.teamId);

      // 🔹 チームのメンバーを取得
      DocumentSnapshot teamSnapshot = await teamRef.get();
      if (!teamSnapshot.exists) {
        throw Exception('チームが存在しません');
      }

      List<dynamic> members = teamSnapshot['members'] ?? [];

      // 🔹 各メンバーの `teams` からこのチームを削除
      for (String memberId in members) {
        await firestore.collection('users').doc(memberId).update({
          'teams': FieldValue.arrayRemove([widget.teamId]),
        });
      }

      // 🔹 Firestore からチームを削除
      await teamRef.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チームが削除されました')),
      );

      // 🔹 個人ページ（HomePage）へ戻る
      String userId = FirebaseAuth.instance.currentUser!.uid;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => HomePage(
            userUid: userId,
            isTeamAccount: false,
            accountId: userId,
            accountName:
                FirebaseAuth.instance.currentUser!.displayName ?? '名前不明',
            userPrefecture: widget.userPrefecture,
            userPosition: widget.userPosition,
            userTeamId: widget.userTeamId,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('チーム削除に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チームプロフィール'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teamData == null
              ? const Center(child: Text('チームデータが見つかりません'))
              : SingleChildScrollView(
                  // 🔹 縦スクロール対応
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🔹 チームプロフィール画像（全幅表示, パディングなし）
                      Container(
                        width: double.infinity, // 画面横幅いっぱい
                        height: 300, // 高さを適度に設定
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: _teamData!['profileImage'] != null
                                ? NetworkImage(_teamData!['profileImage'])
                                : const AssetImage(
                                        'assets/default_team_avatar.png')
                                    as ImageProvider,
                            fit: BoxFit.cover, // 🔹 画像を横幅いっぱいにカバー
                          ),
                        ),
                      ),

                      // 🔹 ここから下はパディングを適用
                      Padding(
                        padding:
                            const EdgeInsets.all(16.0), // 🔹 画像以外の部分にパディングを適用
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // チーム名
                            Column(
                              children: [
                                Text(
                                  '${_teamData!['teamName']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_isTeamSubscribed) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _teamPlanName ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'ベーシック',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 都道府県
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 20, color: Colors.grey), // 📍 位置アイコン
                                const SizedBox(width: 5),
                                Text(
                                  '${_teamData!['prefecture']}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('平均年齢: ',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Text('${_teamData!['averageAge']}歳',
                                    style: const TextStyle(fontSize: 18)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 活動開始年
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('チーム結成: ',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Text('${_teamData!['startYear']}年',
                                    style: const TextStyle(fontSize: 18)),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 実績
                            const Text('実績',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            _teamData!['achievements'].isEmpty
                                ? const Text('実績はありません')
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: List.generate(
                                        _teamData!['achievements'].length,
                                        (index) {
                                      return Text(
                                          '- ${_teamData!['achievements'][index]}',
                                          style: const TextStyle(fontSize: 18));
                                    }),
                                  ),
                            const SizedBox(height: 16),

                            // チーム紹介文
                            const Text('チーム紹介文',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                              _teamData!['teamDescription'].isNotEmpty
                                  ? _teamData!['teamDescription']
                                  : '紹介文はありません',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 16),
                            // 「編集する」ボタン
                            TextButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (context) =>
                                            EditTeamProfilePage(
                                                teamId: widget.teamId)))
                                    .then((_) {
                                  _fetchTeamData(); // 🔹 編集後にデータを再取得
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10), // ボタンの余白
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(30), // 🔹 角丸で丸に近づける
                                  side: const BorderSide(
                                      color: Colors.blue, width: 1), // 🔹 青色の枠線
                                ),
                              ),
                              child: const Text(
                                '変更',
                                style: TextStyle(
                                  fontSize: 14, // 🔹 文字サイズを大きく
                                  color: Colors.blue, // 🔹 文字色
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // 「チームを抜ける」ボタン
                            if (_adminId != _currentUserId) ...[
                              ElevatedButton(
                                onPressed: _leaveTeam,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange),
                                child: const Text('チームを抜ける'),
                              ),
                            ],
                            const SizedBox(height: 8),

                            // 「チーム削除」ボタン
                            if (_adminId == _currentUserId) ...[
                              ElevatedButton(
                                onPressed: _deleteTeam,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                                child: const Text('チームを削除'),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('アカウント管理者'),
                                    Text(
                                      _adminName ?? '読み込み中...',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
