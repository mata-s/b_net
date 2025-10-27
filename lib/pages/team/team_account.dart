import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'team_home.dart'; // チームのホームページを表示するクラスをインポート

class TeamAccountSwitchPage extends StatefulWidget {
  final String userUid;
  final String accountName;
  final String userPrefecture;
  final List<String> userPosition;
  final String? userTeamId;

  const TeamAccountSwitchPage({
    super.key,
    required this.userUid,
    required this.accountName,
    required this.userPrefecture,
    required this.userPosition,
    this.userTeamId,
  });

  @override
  _TeamAccountSwitchPageState createState() => _TeamAccountSwitchPageState();
}

class _TeamAccountSwitchPageState extends State<TeamAccountSwitchPage> {
  List<Map<String, dynamic>> teamAccounts = []; // teamIdを含むマップを使用
  bool isLoading = true;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserTeams();
  }

  // ユーザーの作成したチームと参加しているチームを取得する関数
  Future<void> _fetchUserTeams() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists &&
          userDoc.data() != null &&
          (userDoc.data() as Map<String, dynamic>).containsKey('teams')) {
        List<dynamic> userTeams = userDoc['teams'] ?? [];

        if (userTeams.isNotEmpty) {
          QuerySnapshot teamsSnapshot = await FirebaseFirestore.instance
              .collection('teams')
              .where(FieldPath.documentId, whereIn: userTeams)
              .get();

          setState(() {
            // ドキュメントID（teamId）を各ドキュメントデータに追加
            teamAccounts = teamsSnapshot.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              data['teamId'] = doc.id; // ドキュメントIDをteamIdとして追加
              return data;
            }).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('チームの取得中にエラーが発生しました: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チームアカウントに切り替える'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : teamAccounts.isEmpty
              ? const Center(child: Text('チームがありません'))
              : ListView.builder(
                  itemCount: teamAccounts.length,
                  itemBuilder: (context, index) {
                    var team = teamAccounts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: team['profileImage'] != null
                            ? NetworkImage(team['profileImage'])
                            : const AssetImage('assets/default_team_avatar.png')
                                as ImageProvider, // プロフィール画像がない場合はデフォルトの画像を使用
                      ),
                      title: Text(team['teamName'] ?? '不明なチーム'),
                      onTap: () {
                        _switchToTeamAccount(context, team);
                      },
                    );
                  },
                ),
    );
  }

  // チームアカウント切り替え処理
  void _switchToTeamAccount(
      BuildContext context, Map<String, dynamic> team) async {
    if (!team.containsKey('teamId')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チームIDが無効です')),
      );
      return;
    }

    // 👇 ローディングダイアログを表示（テキスト付き）
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'チームに切り替え中…',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      await Purchases.logOut();
      await Purchases.logIn(team['teamId']);
      print('✅ RevenueCat にチームIDでログイン: ${team['teamId']}');

      if (!mounted) return;
      Navigator.pop(context); // ローディング閉じる

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TeamHomePage(
            team: team,
            isTeamAccount: true,
            accountId: team['teamId'],
            accountName: team['teamName'],
            userUid: widget.userUid,
            userPrefecture: widget.userPrefecture,
            userPosition: widget.userPosition,
            userTeamId: widget.userTeamId,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // ローディング閉じる
      print('⚠️ RevenueCat ログイン失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('チーム切り替えに失敗しました: $e')),
      );
    }
  }
}
