import 'package:b_net/common/post_page.dart';
import 'package:flutter/material.dart';
import 'package:b_net/widgets/b_net_floating_tab_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 日付フォーマット用
import 'package:b_net/common/profile_dialog.dart';
import 'package:b_net/common/chat_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  Set<String> _blockedUserIds = {};
  bool _blockedUsersLoaded = false;
  String _registeredPrefecture = '';
  bool _postFilterLoaded = false;
  bool _showCustomPrefectureInput = false;

  String get _postFilterPreferenceKey =>
      'post_list_prefecture_filter_${widget.userUid}';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _loadBlockedUsers();
    _loadPostFilter();
  }

  Future<void> _loadPostFilter() async {
    try {
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userUid)
            .get(),
      ]);
      final preferences = results[0] as SharedPreferences;
      final userDocument = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final registeredPrefecture =
          (userDocument.data()?['prefecture'] ?? '').toString();
      final savedFilter = preferences.containsKey(_postFilterPreferenceKey)
          ? preferences.getString(_postFilterPreferenceKey) ?? ''
          : registeredPrefecture;

      if (!mounted) return;
      setState(() {
        _registeredPrefecture = registeredPrefecture;
        _selectedPrefecture = _normalizePrefecture(savedFilter);
        _searchController.text = savedFilter;
        _showCustomPrefectureInput = savedFilter.isNotEmpty &&
            _normalizePrefecture(savedFilter) !=
                _normalizePrefecture(registeredPrefecture);
        _postFilterLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // 読み込みに失敗した場合は従来どおり全国表示にする。
        _postFilterLoaded = true;
      });
    }
  }

  Future<void> _setPrefectureFilter(
    String value, {
    bool closeCustomInput = false,
  }) async {
    final normalizedValue = _normalizePrefecture(value);
    setState(() {
      _selectedPrefecture = normalizedValue;
      _searchController.text = value;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
      if (closeCustomInput) {
        _showCustomPrefectureInput = false;
        _searchFocusNode.unfocus();
      }
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_postFilterPreferenceKey, value);
  }

  void _onSearchFocusChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _normalizePrefecture(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\s\u3000]+'), '') // half/full width spaces
        .replaceAll('都', '')
        .replaceAll('道', '')
        .replaceAll('府', '')
        .replaceAll('県', '');
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .collection('blockedUsers')
          .get();

      if (!mounted) return;
      setState(() {
        _blockedUserIds = snap.docs.map((d) => d.id).toSet();
        _blockedUsersLoaded = true;
      });
    } catch (e) {
      // 読み込みに失敗しても投稿一覧自体は表示できるようにする
      if (!mounted) return;
      setState(() {
        _blockedUsersLoaded = true;
      });
    }
  }

  Future<void> _reportPost({
    required String postId,
    required String reportedUserId,
    required String reason,
    required String? details,
  }) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'contentType': 'post',
      'contentId': postId,
      'reportedUserId': reportedUserId,
      'reporterUserId': widget.userUid,
      'reason': reason,
      'details': details,
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通報しました')),
    );
  }

  Future<void> _blockUserFromPost({
    required String targetUserId,
    required String postId,
    required String? targetUserName,
  }) async {
    // ブロック登録
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('blockedUsers')
        .doc(targetUserId)
        .set({'blockedAt': Timestamp.now()});

    // Apple ガイドライン要件: ブロック時に開発者へ通知（通報記録として残す）
    await FirebaseFirestore.instance.collection('reports').add({
      'contentType': 'user_block',
      'contentId': postId,
      'reportedUserId': targetUserId,
      'reporterUserId': widget.userUid,
      'reason': 'blocked_user',
      'details': targetUserName,
      'createdAt': Timestamp.now(),
    });

    if (!mounted) return;
    setState(() {
      _blockedUserIds.add(targetUserId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ユーザーをブロックしました')),
    );
  }

  Future<void> _showReportDialog({
    required String postId,
    required String reportedUserId,
  }) async {
    String selectedReason = 'inappropriate';
    final detailsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('通報する'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('スパム')),
                  DropdownMenuItem(value: 'abuse', child: Text('暴言・嫌がらせ')),
                  DropdownMenuItem(
                      value: 'inappropriate', child: Text('不適切な内容')),
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
    detailsController.dispose();

    if (result == true) {
      await _reportPost(
        postId: postId,
        reportedUserId: reportedUserId,
        reason: selectedReason,
        details: details.isEmpty ? null : details,
      );
    }
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
                            showProfileDialog(
                              context,
                              teamId,
                              true,
                              currentUserUid: widget.userUid,
                              currentUserName: widget.userName,
                            );
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

  Widget _buildAreaButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF60A5FA) : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFF2563EB) : Colors.black54,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: selected ? const Color(0xFF1D4ED8) : Colors.black87,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openPostPage() {
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
  }

  Widget _buildEmptyPosts() {
    final isAreaFiltered = _selectedPrefecture.isNotEmpty;
    final areaName = _searchController.text.trim().isNotEmpty
        ? _searchController.text.trim()
        : _selectedPrefecture;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        52,
        24,
        BNetFloatingTabBar.bodyClearance(context) + 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_outlined,
                  size: 42,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isAreaFiltered ? '$areaNameの投稿はまだありません' : 'まだ投稿がありません',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isAreaFiltered
                    ? '全国の投稿を見るか、この地域の募集や情報を投稿してみましょう。'
                    : 'メンバー募集や練習試合の相手探しなど、最初の投稿をしてみましょう。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openPostPage,
                  icon: const Icon(Icons.add),
                  label: const Text('投稿する'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (isAreaFiltered) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _setPrefectureFilter(
                      '',
                      closeCustomInput: true,
                    ),
                    icon: const Icon(Icons.public),
                    label: const Text('全国の投稿を見る'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
          if (_postFilterLoaded)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text(
                        '表示エリア',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_registeredPrefecture.isNotEmpty) ...[
                        Expanded(
                          child: _buildAreaButton(
                            label: _registeredPrefecture,
                            icon: Icons.near_me_outlined,
                            selected: _selectedPrefecture ==
                                _normalizePrefecture(_registeredPrefecture),
                            onTap: () => _setPrefectureFilter(
                              _registeredPrefecture,
                              closeCustomInput: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _buildAreaButton(
                          label: '全国',
                          icon: Icons.public,
                          selected: _selectedPrefecture.isEmpty,
                          onTap: () => _setPrefectureFilter(
                            '',
                            closeCustomInput: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showCustomPrefectureInput =
                              !_showCustomPrefectureInput;
                        });
                        if (_showCustomPrefectureInput) {
                          Future<void>.delayed(
                            const Duration(milliseconds: 100),
                            _searchFocusNode.requestFocus,
                          );
                        } else {
                          _searchFocusNode.unfocus();
                        }
                      },
                      icon: Icon(
                        _showCustomPrefectureInput
                            ? Icons.expand_less
                            : Icons.tune,
                        size: 18,
                      ),
                      label: Text(
                        _showCustomPrefectureInput ? '地域検索を閉じる' : '別の都道府県を選ぶ',
                      ),
                    ),
                  ),
                  if (_showCustomPrefectureInput) ...[
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.text,
                      onFieldSubmitted: (value) {
                        _setPrefectureFilter(value, closeCustomInput: true);
                      },
                      decoration: InputDecoration(
                        hintText: '例：兵庫県',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'この地域で表示',
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () {
                            _setPrefectureFilter(
                              _searchController.text,
                              closeCustomInput: true,
                            );
                          },
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: !_postFilterLoaded
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!_blockedUsersLoaded) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final posts = snapshot.data!.docs.where((doc) {
                        var post = doc.data() as Map<String, dynamic>;

                        // ブロックしているユーザーの投稿は即非表示
                        final postedBy = (post['postedBy'] ?? '').toString();
                        if (postedBy.isNotEmpty &&
                            _blockedUserIds.contains(postedBy)) {
                          return false;
                        }

                        if (_selectedPrefecture.isEmpty) return true;
                        final postPref = _normalizePrefecture(
                            (post['prefecture'] ?? '').toString());
                        final queryPref = _selectedPrefecture;
                        return postPref.contains(queryPref);
                      }).toList();

                      if (posts.isEmpty) {
                        return _buildEmptyPosts();
                      }

                      return ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          var post =
                              posts[index].data() as Map<String, dynamic>;
                          String postedByName = post['postedByName'] ?? '匿名';
                          String timeRange = post['timeRange'] ?? '';
                          String? dateTime = post['dateTime'] as String?;
                          String? teamId = post['teamId'];
                          String? teamName = post['teamName'];
                          String postId = posts[index].id; // 🔹 投稿IDを取得
                          String postedBy = post['postedBy'] ?? '';
                          bool isMyPost =
                              postedBy == widget.userUid; // 🔹 自分の投稿かどうか
                          Timestamp? createdAt =
                              post['createdAt'] as Timestamp?;

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
                                  leading:
                                      CircleAvatar(child: Icon(Icons.error)),
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
                                      onTap: () => showProfileDialog(
                                        context,
                                        postedBy,
                                        false,
                                        currentUserUid: widget.userUid,
                                        currentUserName: widget.userName,
                                      ),
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
                                                  fontSize: 12,
                                                  color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (post['title'] != null &&
                                        post['title'].toString().isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(post['title'],
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    if (teamName != null && teamName.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: GestureDetector(
                                          onTap: () async {
                                            if (teamId != null &&
                                                teamId.isNotEmpty) {
                                              showProfileDialog(
                                                context,
                                                teamId,
                                                true,
                                                currentUserUid: widget.userUid,
                                                currentUserName:
                                                    widget.userName,
                                              );
                                            } else {
                                              String? fetchedTeamId =
                                                  await _fetchTeamId(teamName);
                                              if (fetchedTeamId != null) {
                                                showProfileDialog(
                                                  context,
                                                  fetchedTeamId,
                                                  true,
                                                  currentUserUid:
                                                      widget.userUid,
                                                  currentUserName:
                                                      widget.userName,
                                                );
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
                                              const Icon(Icons.groups,
                                                  size: 16.0),
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

                                    if ((dateTime != null &&
                                            dateTime.isNotEmpty) ||
                                        timeRange.isNotEmpty)
                                      const SizedBox(height: 5),

                                    if (dateTime != null ||
                                        timeRange.isNotEmpty)
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
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          if (dateTime != null &&
                                              dateTime.isNotEmpty &&
                                              timeRange.isNotEmpty)
                                            const SizedBox(width: 16), // スペース追加
                                          if (timeRange
                                              .isNotEmpty) // 時間範囲が存在すれば表示
                                            Row(
                                              children: [
                                                const Icon(Icons.schedule,
                                                    size: 16.0),
                                                const SizedBox(width: 5),
                                                Text(
                                                  timeRange,
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),

                                    if (post['prefecture'] != null &&
                                        post['prefecture']
                                            .toString()
                                            .isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
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
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text('${post['content']}'),
                                      ),
                                    SizedBox(height: 30),
                                    // 🔹 自分の投稿なら編集・削除を横並びで表示
                                    if (isMyPost)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          PopupMenuButton<String>(
                                            icon: FaIcon(
                                                FontAwesomeIcons.ellipsis,
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
                                                        color:
                                                            Colors.lightBlue),
                                                    SizedBox(width: 8),
                                                    Text('編集',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.black)),
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
                                                            color:
                                                                Colors.black)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_horiz,
                                                  color: Colors.grey),
                                              onSelected: (value) async {
                                                if (value == 'report') {
                                                  await _showReportDialog(
                                                    postId: postId,
                                                    reportedUserId: postedBy,
                                                  );
                                                } else if (value == 'block') {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                            'ユーザーをブロック'),
                                                        content: const Text(
                                                            'このユーザーをブロックしますか？\nブロックすると投稿は即時非表示になります。'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    false),
                                                            child: const Text(
                                                                'キャンセル'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    true),
                                                            child: const Text(
                                                                'ブロック'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  if (confirm == true) {
                                                    await _blockUserFromPost(
                                                      targetUserId: postedBy,
                                                      postId: postId,
                                                      targetUserName:
                                                          displayName,
                                                    );
                                                  }
                                                }
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value: 'report',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.flag,
                                                          color: Colors.red),
                                                      SizedBox(width: 8),
                                                      Text('通報する'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'block',
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.block,
                                                          color:
                                                              Colors.black54),
                                                      SizedBox(width: 8),
                                                      Text('このユーザーをブロック'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
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
                                        ],
                                      ),
                                    const Divider(), // 下線
                                    if (index == posts.length - 1)
                                      SizedBox(
                                        height:
                                            BNetFloatingTabBar.bodyClearance(
                                          context,
                                        ),
                                      ),
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
      floatingActionButton: _searchFocusNode.hasFocus
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: BNetFloatingTabBar.bodyClearance(context),
              ),
              child: FloatingActionButton(
                onPressed: _openPostPage,
                child: const Icon(Icons.add),
              ),
            ),
    );
  }

  // 日付をフォーマットする関数
  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy/MM/dd HH:mm').format(date); // 日付と時間をフォーマット
  }
}
