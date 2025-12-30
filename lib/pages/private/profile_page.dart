import 'dart:io';

import 'package:b_net/common/post_page.dart';
import 'package:b_net/common/profile_dialog.dart';
import 'package:b_net/login/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'profile_edit_page.dart';
import 'package:intl/intl.dart'; // 日付フォーマット用
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfilePage extends StatefulWidget {
  final String userUid;
  const ProfilePage({super.key, required this.userUid});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _profileImageUrl;
  String? _userName;
  String? _prefecture;
  String? _birthday;
  String? _bio;
  int? _age;
  List<String> _positions = [];
  List<String> _teams = [];
  bool _isLoading = true;
  String? _personalPlanName;
  bool _isPersonalSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadSubscriptionStatus();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      setState(() {
        _userName = userDoc.data()?['name'] ?? '不明な名前';
        _profileImageUrl = userDoc.data()?['profileImage'];
        _prefecture = userDoc.data()?['prefecture'] ?? '未設定';
        _positions = List<String>.from(userDoc.data()?['positions'] ?? []);
        _teams = List<String>.from(userDoc.data()?['teams'] ?? []);
        _bio = userDoc.data()?['include'] ?? '';
        _nameController.text = _userName ?? '';

        _birthday = userDoc.data()?['birthday'] != null
            ? (userDoc.data()?['birthday'] as Timestamp).toDate().toString()
            : null;

        if (_birthday != null) {
          final birthdayDate = DateTime.parse(_birthday!);
          final now = DateTime.now();
          _age = now.year - birthdayDate.year;
          if (now.month < birthdayDate.month ||
              (now.month == birthdayDate.month && now.day < birthdayDate.day)) {
            _age = _age! - 1;
          }
        } else {
          _age = null;
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final platform = Platform.isIOS ? 'iOS' : 'Android';
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('subscription')
        .doc(platform)
        .get();

    if (doc.exists) {
      final data = doc.data();
      final status = data?['status'];
      final productId = data?['productId'];

      if (status == 'active' && productId != null) {
        _isPersonalSubscribed = true;
        if (productId.contains('12month')) {
          _personalPlanName = 'プレミアム(年額)';
        } else if (productId.contains('1month')) {
          _personalPlanName = 'プレミアム';
        } else {
          _personalPlanName = '不明なプラン';
        }
      }
    }
  }

  Future<String?> _getTeamName(String teamId) async {
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    if (teamDoc.exists) {
      return teamDoc.data()?['teamName'] ?? 'チーム名不明';
    } else {
      return null; // チームが存在しない場合
    }
  }

  // 🔹 _birthday を "YYYY年MM月DD日" 形式で変換する関数
  String _formatBirthday(String birthday) {
    final DateTime date = DateTime.parse(birthday);
    return DateFormat('yyyy年MM月dd日').format(date);
  }

  /// **Timestamp を yyyy/MM/dd HH:mm 形式の文字列に変換**
  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy/MM/dd HH:mm').format(date);
  }

  Future<String?> _fetchTeamId(String teamName) async {
    try {
      QuerySnapshot teamQuery = await FirebaseFirestore.instance
          .collection('teams')
          .where('teamName', isEqualTo: teamName)
          .get();

      if (teamQuery.docs.isNotEmpty) {
        return teamQuery.docs.first.id;
      }
      return null;
    } catch (e) {
      print('⚠️ Error fetching team ID: $e');
      return null;
    }
  }

  void _editPost(String postId, Map<String, dynamic> postData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostPage(
          userUid: widget.userUid,
          userName: _userName ?? '',
          postId: postId,
          existingData: postData,
        ),
      ),
    );
  }

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
      setState(() {});
    }
  }

// 🔹 投稿リストを取得して表示する
  Widget _buildUserPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('postedBy', isEqualTo: widget.userUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            '投稿がありません',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          );
        }

        final posts = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: posts.map((doc) {
            final post = doc.data() as Map<String, dynamic>;
            String postId = doc.id;
            String postedBy = post['postedBy'] ?? '';
            String title = post['title'] ?? '';
            String teamName = post['teamName'] ?? '';
            String? teamId = post['teamId'];
            String dateTime = post['dateTime'] ?? '';
            String timeRange = post['timeRange'] ?? '';
            String prefecture = post['prefecture'] ?? '';
            String content = post['content'] ?? '';
            Timestamp? createdAt = post['createdAt'] is Timestamp
                ? post['createdAt'] as Timestamp
                : null;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => showProfileDialog(context, postedBy, false),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: (_profileImageUrl != null &&
                                  _profileImageUrl!.isNotEmpty)
                              ? NetworkImage(_profileImageUrl!)
                              : const AssetImage('assets/default_avatar.png')
                                  as ImageProvider,
                        ),
                        const SizedBox(width: 10),
                        Text(_userName ?? 'ユーザー',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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

                  // 🔹 投稿のタイトル
                  if (title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),

                  // 🔹 チーム情報
                  if (teamName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: () async {
                          if (teamId != null && teamId.isNotEmpty) {
                            showProfileDialog(context, teamId, true);
                          } else {
                            String? fetchedTeamId =
                                await _fetchTeamId(teamName);
                            if (fetchedTeamId != null) {
                              showProfileDialog(context, fetchedTeamId, true);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('チームが登録されていない可能性があります')),
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

                  // 🔹 日付と時間
                  if ((dateTime.isNotEmpty) || timeRange.isNotEmpty)
                    const SizedBox(height: 5),

                  if (dateTime.isNotEmpty || timeRange.isNotEmpty)
                    Row(
                      children: [
                        if (dateTime.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 16.0),
                              const SizedBox(width: 5),
                              Text(
                                dateTime,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        if (dateTime.isNotEmpty && timeRange.isNotEmpty)
                          const SizedBox(width: 16),
                        if (timeRange.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 16.0),
                              const SizedBox(width: 5),
                              Text(
                                timeRange,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                      ],
                    ),

                  // 🔹 都道府県
                  if (prefecture.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.near_me, size: 16.0),
                          const SizedBox(width: 5),
                          Text(prefecture),
                        ],
                      ),
                    ),

                  // 🔹 投稿内容
                  if (content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(content),
                    ),

                  const SizedBox(height: 5),

                  // 🔹 編集・削除メニュー（三点メニュー）
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
                                Icon(Icons.edit, color: Colors.lightBlue),
                                SizedBox(width: 8),
                                Text('編集',
                                    style: TextStyle(color: Colors.black)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('削除',
                                    style: TextStyle(color: Colors.black)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(), // 🔹 投稿ごとの区切り線
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          TextButton(
            child: const Text('ログアウト'),
            onPressed: () async {
              // 👻 RevenueCatの現在のUserIDを取得して、匿名かチェック
              try {
                final purchaserInfo = await Purchases.getCustomerInfo();
                final currentAppUserID = purchaserInfo.originalAppUserId;

                if (currentAppUserID.contains('anonymous')) {
                  print('👻 匿名ユーザーなので RevenueCat logOut スキップ');
                } else {
                  await Purchases.logOut();
                  print('✅ RevenueCat: logOut 完了');
                }
              } catch (e) {
                print('⚠️ RevenueCat logOut エラー: $e');
              }

              // Firebase ログアウト
              await _auth.signOut();

              // ログイン画面へ遷移（スタックをすべてクリア）
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 16.0),
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage: (_profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty)
                                  ? NetworkImage(_profileImageUrl!)
                                  : const AssetImage(
                                          'assets/default_avatar.png')
                                      as ImageProvider,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileEditPage(
                                    userUid: widget.userUid,
                                    userName: _userName ?? '',
                                    profileImageUrl: _profileImageUrl ?? '',
                                    positions: _positions,
                                    prefecture: _prefecture,
                                    bio: _bio,
                                  ),
                                ),
                              );
                              if (result == true) {
                                _loadUserProfile();
                              }
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '$_userName',
                            style: const TextStyle(
                                fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (_isPersonalSubscribed) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified,
                                      size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    _personalPlanName ?? '',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                      const SizedBox(height: 10),
                      Text(
                        '${_positions.join(', ')}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.groups,
                            size: 30,
                          ),
                          const SizedBox(width: 8), // アイコンとテキストの間に余白
                          Expanded(
                            // チーム名が長い場合に折り返し表示を許可
                            child: FutureBuilder(
                              future: Future.wait(
                                  _teams.map((teamId) => _getTeamName(teamId))),
                              builder: (context,
                                  AsyncSnapshot<List<String?>> snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                } else if (snapshot.hasError) {
                                  return const Text('エラーが発生しました');
                                } else {
                                  final teamNames = snapshot.data
                                          ?.where(
                                              (teamName) => teamName != null)
                                          .toList() ??
                                      [];

                                  if (teamNames.isEmpty) {
                                    return const Text('チームに所属していません',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600));
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: teamNames
                                        .map((teamName) => Text(teamName!,
                                            style:
                                                const TextStyle(fontSize: 16)))
                                        .toList(),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_bio != null && _bio!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '自己紹介',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _bio!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // 🔹 テキストとアイコンを中央に配置
                            children: [
                              const Icon(Icons.location_on,
                                  size: 20,
                                  color: Colors.grey), // 📍 位置アイコン（都道府県）
                              const SizedBox(width: 5), // 🔹 アイコンとテキストの間に余白を追加
                              Text(
                                '$_prefecture',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // 🔹 テキストとアイコンを中央に配置
                            children: [
                              const Icon(Icons.cake,
                                  size: 20,
                                  color: Colors.grey), // 📍 位置アイコン（都道府県）
                              const SizedBox(width: 5), // 🔹 アイコンとテキストの間に余白を追加
                              if (_age != null)
                                Text('${_formatBirthday(_birthday!)} $_age歳',
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      // 🔹 投稿リストを取得して表示する
                      _buildUserPosts(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
