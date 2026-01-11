import 'package:b_net/common/post_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 日付フォーマット用
import 'package:b_net/common/profile_dialog.dart';
import 'package:b_net/common/chat_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PostListPage extends StatefulWidget {
  final String userUid;
  final String userName;
  final String? userTeamId;

  const PostListPage({
    super.key,
    required this.userUid,
    required this.userName,
    String? userTeamId,
    String? teamId,
  }) : userTeamId = teamId ?? userTeamId;

  @override
  _PostListPageState createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  String _selectedPrefecture = ''; // 検索用都道府県
  final TextEditingController _searchController = TextEditingController();

  String _normalizePrefecture(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\s\u3000]+'), '') // half/full width spaces
        .replaceAll('都', '')
        .replaceAll('道', '')
        .replaceAll('府', '')
        .replaceAll('県', '');
  }

  /// **投稿を削除**
  Future<void> _deletePost(String postId) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('投稿を削除'),
          content: const Text('本当にこの投稿を削除しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿を削除しました')),
      );
    }
  }

  /// **投稿を編集**
  void _editPost(String postId, Map<String, dynamic> postData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostPage(
          userUid: widget.userUid,
          userName: widget.userName,
          postId: postId, // 🔹 編集用に投稿IDを渡す
          existingData: postData, // 🔹 既存データを渡す
        ),
      ),
    );
  }

  /// **投稿されたチームの ID を取得**
  Future<String?> _fetchTeamId(String teamName) async {
    try {
      QuerySnapshot teamQuery = await FirebaseFirestore.instance
          .collection('teams')
          .where('teamName', isEqualTo: teamName)
          .get();

      if (teamQuery.docs.isNotEmpty) {
        if (teamQuery.docs.length == 1) {
          return teamQuery.docs.first.id;
        } else {
          return await _showTeamSelectionDialog(teamQuery.docs);
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error fetching team ID: $e');
      return null;
    }
  }

  Future<String?> _showTeamSelectionDialog(
      List<QueryDocumentSnapshot> teams) async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // 🔹 ダイアログ内で状態管理
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text("チームを選択してください"),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close), // 🔹 右上にバツボタン
                    onPressed: () {
                      Navigator.pop(context, null); // 🔹 ダイアログのみ閉じる
                    },
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: teams.map((team) {
                  Map<String, dynamic>? data =
                      team.data() as Map<String, dynamic>?;
                  String teamName = data?['teamName'] ?? '不明なチーム';
                  String teamId = team.id;
                  String? profileImage = data?['profileImage'];

                  return Column(
                    children: [
                      ListTile(
                        title: Text(teamName,
                            style: const TextStyle(fontSize: 16)),
                        leading: CircleAvatar(
                          backgroundImage:
                              profileImage != null && profileImage.isNotEmpty
                                  ? NetworkImage(profileImage)
                                  : const AssetImage(
                                          'assets/default_team_avatar.png')
                                      as ImageProvider,
                        ),
                        onTap: () {
                          if (teamId.isNotEmpty) {
                            showProfileDialog(context, teamId, true);
                          }
                        },
                      ),
                      const Divider(), // 🔹 各チームの下に枠線を追加
                    ],
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿一覧'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              keyboardType: TextInputType.text,
              onFieldSubmitted: (value) {
                setState(() {
                  _selectedPrefecture = _normalizePrefecture(value);
                });
              },
              decoration: InputDecoration(
                labelText: '都道府県で絞る',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _selectedPrefecture = _normalizePrefecture(_searchController.text);
                    });
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data!.docs.where((doc) {
                  var post = doc.data() as Map<String, dynamic>;
                  if (_selectedPrefecture.isEmpty) return true;
                  final postPref = _normalizePrefecture((post['prefecture'] ?? '').toString());
                  final queryPref = _selectedPrefecture;
                  return postPref.contains(queryPref);
                }).toList();

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    var post = posts[index].data() as Map<String, dynamic>;
                    String postedByName = post['postedByName'] ?? '匿名';
                    String timeRange = post['timeRange'] ?? '';
                    String? dateTime = post['dateTime'] as String?;
                    String? teamId = post['teamId'];
                    String? teamName = post['teamName'];
                    String postId = posts[index].id; // 🔹 投稿IDを取得
                    String postedBy = post['postedBy'] ?? '';
                    bool isMyPost = postedBy == widget.userUid; // 🔹 自分の投稿かどうか
                    Timestamp? createdAt = post['createdAt'] as Timestamp?;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(post['postedBy'])
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            leading: CircleAvatar(
                                child: CircularProgressIndicator()),
                            title: Text('読み込み中...'),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data == null) {
                          return const ListTile(
                            leading: CircleAvatar(child: Icon(Icons.error)),
                            title: Text('エラーが発生しました'),
                          );
                        }
                        var data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        String imageUrl = data['profileImage'] ?? '';
                        String displayName = data['name'] ?? postedByName;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    showProfileDialog(context, postedBy, false),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: imageUrl.isNotEmpty
                                          ? NetworkImage(imageUrl)
                                              as ImageProvider
                                          : AssetImage(
                                              'assets/default_avatar.png'),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    if (createdAt != null)
                                      Text(
                                        _formatTimestamp(createdAt),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (post['title'] != null &&
                                  post['title'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(post['title'],
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              if (teamName != null && teamName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (teamId != null && teamId.isNotEmpty) {
                                        showProfileDialog(
                                            context, teamId, true);
                                      } else {
                                        String? fetchedTeamId =
                                            await _fetchTeamId(teamName);
                                        if (fetchedTeamId != null) {
                                          showProfileDialog(
                                              context, fetchedTeamId, true);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'チームが登録されていない可能性があります')),
                                          );
                                        }
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(Icons.groups, size: 16.0),
                                        const SizedBox(width: 5),
                                        Text(
                                          teamName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              if ((dateTime != null && dateTime.isNotEmpty) ||
                                  timeRange.isNotEmpty)
                                const SizedBox(height: 5),

                              if (dateTime != null || timeRange.isNotEmpty)
                                Row(
                                  children: [
                                    if (dateTime != null &&
                                        dateTime.isNotEmpty) // 日付が存在すれば表示
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_month,
                                              size: 16.0),
                                          const SizedBox(width: 5),
                                          Text(
                                            dateTime, // 実際の日付の値
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    if (dateTime != null &&
                                        dateTime.isNotEmpty &&
                                        timeRange.isNotEmpty)
                                      const SizedBox(width: 16), // スペース追加
                                    if (timeRange.isNotEmpty) // 時間範囲が存在すれば表示
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule,
                                              size: 16.0),
                                          const SizedBox(width: 5),
                                          Text(
                                            timeRange,
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),

                              if (post['prefecture'] != null &&
                                  post['prefecture'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.near_me,
                                          size: 16.0), // 都道府県を表すアイコン
                                      const SizedBox(
                                          width: 5), // アイコンとテキストの間にスペース
                                      Text(
                                          '${post['prefecture']}'), // 都道府県のテキストを表示
                                    ],
                                  ),
                                ),

                              if (post['content'] != null &&
                                  post['content'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('${post['content']}'),
                                ),
                              SizedBox(height: 30),
                              // 🔹 自分の投稿なら編集・削除を横並びで表示
                              if (isMyPost)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    PopupMenuButton<String>(
                                      icon: FaIcon(FontAwesomeIcons.ellipsis,
                                          color: Colors.grey),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editPost(postId, post);
                                        } else if (value == 'delete') {
                                          _deletePost(postId);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit,
                                                  color: Colors.lightBlue),
                                              SizedBox(width: 8),
                                              Text('編集',
                                                  style: TextStyle(
                                                      color: Colors.black)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(), // 🔹 区切り線
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('削除',
                                                  style: TextStyle(
                                                      color: Colors.black)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                // 🔹 自分の投稿ではない場合のみ「連絡を取る」ボタンを表示
                                Align(
                                  alignment: Alignment.center,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      startChatRoom(
                                        context: context,
                                        recipientId: post['postedBy'],
                                        recipientName: displayName,
                                        userUid: widget.userUid,
                                        userName: widget.userName,
                                      );
                                    },
                                    child: const Text('連絡を取る'),
                                  ),
                                ),
                              const Divider(), // 下線

                              if (index == posts.length - 1)
                                const SizedBox(height: 70),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostPage(
                userUid: widget.userUid,
                userName: widget.userName,
                teamId: widget.userTeamId ?? '',
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // 日付をフォーマットする関数
  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy/MM/dd HH:mm').format(date); // 日付と時間をフォーマット
  }
}
