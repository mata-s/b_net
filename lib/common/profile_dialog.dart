import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_net/common/chat_utils.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
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
                Image(
                  image: profileImageUrl
                          .startsWith('http') // ネットワーク画像なら `NetworkImage`
                      ? NetworkImage(profileImageUrl) as ImageProvider
                      : AssetImage(profileImageUrl)
                          as ImageProvider, // ローカル画像なら `AssetImage`
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height * 0.3,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      widget.isTeamAccount
                          ? 'assets/default_team_avatar.png'
                          : 'assets/default_avatar.png',
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.3,
                      fit: BoxFit.cover,
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (widget.isTeamAccount) ...[
                  if (data['prefecture'] != null &&
                      data['prefecture'].toString().isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on,
                            size: 20, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          data['prefecture'],
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  if (data['averageAge'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '平均年齢: ${data['averageAge']}歳',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  if (data['startYear'] != null &&
                      data['startYear'].toString().isNotEmpty)
                    const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('チーム結成: ',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${data['startYear']}年',
                          style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  if (data['achievements'] != null &&
                      data['achievements'].isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('実績',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          List.generate(data['achievements'].length, (index) {
                        return Text('- ${data['achievements'][index]}',
                            style: const TextStyle(fontSize: 18));
                      }),
                    ),
                  ],
                  if (data['teamDescription'] != null &&
                      data['teamDescription'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('チーム紹介文',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        data['teamDescription'],
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ],
                if (!widget.isTeamAccount) ...[
                  Center(
                    // 🔹 全体を中央揃え
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height *
                            0.6, // 60%の高さ制限
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.center, // 🔹 テキストを中央揃え
                          children: [
                            // ✅ 都道府県（データがある場合のみ表示）
                            if (data['prefecture'] != null &&
                                data['prefecture'].toString().isNotEmpty)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center, // 🔹 中央揃え
                                children: [
                                  const Icon(Icons.location_on,
                                      size: 20, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(
                                    data['prefecture'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),

                            // ✅ 誕生日（データがある場合のみ表示）
                            if (data['birthday'] != null)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center, // 🔹 中央揃え
                                children: [
                                  const Icon(Icons.cake,
                                      size: 20, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(_formatBirthday(data['birthday'])),
                                ],
                              ),

                            // ✅ ポジション（データがある場合のみ表示）
                            if (data['positions'] != null &&
                                data['positions'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${data['positions'].join(', ')}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center, // 🔹 中央揃え
                                ),
                              ),

                            // ✅ 所属チーム（データがある場合のみ表示）
                            if (_teamNames.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text('所属チーム',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center, // 🔹 中央揃え
                                children: _teamNames
                                    .map((team) => GestureDetector(
                                          onTap: () {
                                            String teamId = team[
                                                'teamId']!; // 🔹 明示的に String として扱う
                                            if (teamId.isNotEmpty) {
                                              showProfileDialog(
                                                  context, teamId, true);
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "チーム情報が取得できませんでした")),
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4.0),
                                            child: Text(
                                              team[
                                                  'teamName']!, // 🔹 teamName も String 扱い
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.blue),
                                              textAlign:
                                                  TextAlign.center, // 🔹 中央揃え
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],

                            // ✅ 自己紹介（データがある場合のみ表示）
                            if (data['include'] != null &&
                                data['include'].toString().isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Text(
                                '自己紹介',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Text(
                                  data['include'],
                                  style: const TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center, // 🔹 中央揃え
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                // 🔹 **チーム or ユーザー両方に「連絡を取る」ボタンを追加**
                if (widget.isFromSearch && recipientId.isNotEmpty)
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        print("✅ 連絡を取るボタンが押されました");
                        print("👤 送信者 UID: ${widget.currentUserUid}");
                        print("📛 送信者名: $currentUserName");
                        print("👤 受信者 UID: $recipientId");
                        print("📛 受信者名: $recipientName");

                        if (widget.currentUserUid == null ||
                            currentUserName == null) {
                          print("⚠️ 送信者情報が不足しています");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("エラー: 送信者情報が不足しています")),
                          );
                          return;
                        }

                        if (recipientId.isEmpty || recipientName.isEmpty) {
                          print("⚠️ 受信者情報が不足しています");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("エラー: 受信者情報が不足しています")),
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
                      child: const Text("連絡を取る"),
                    ),
                  ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる',
                      style: TextStyle(color: Colors.red, fontSize: 18)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
