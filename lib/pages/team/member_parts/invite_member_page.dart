import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InviteMemberPage extends StatefulWidget {
  final Map<String, dynamic> team;

  const InviteMemberPage({super.key, required this.team});

  @override
  _InviteMemberPageState createState() => _InviteMemberPageState();
}

class _InviteMemberPageState extends State<InviteMemberPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _searchResults = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedUser; // 選択されたユーザー
  bool _hasSearched = false; // 検索が実行されたかどうかを判断するフラグ

  String _normalizeName(String input) {
    // 半角/全角スペースを除去して比較しやすくする
    return input.replaceAll(RegExp(r'[ \u3000]'), '');
  }

  bool _hasAnySpace(String input) {
    return RegExp(r'[ \u3000]').hasMatch(input);
  }

  String _prefixForFirestore(String rawQuery) {
    final q = rawQuery.trim();
    if (q.isEmpty) return q;

    // スペースが含まれているなら、そのまま前方一致検索に使う
    if (_hasAnySpace(q)) return q;

    // スペースなし検索は「姓+名」を繋げて入力されがちなので、
    // そのままだと Firestore の前方一致で拾えない（例: 又吉真春 vs 又吉 真春）。
    // 候補を取りにいくために先頭2文字だけで絞り、あとは端末側で厳密にフィルタする。
    final int take = q.length >= 2 ? 2 : 1;
    return q.substring(0, take);
  }

  // 名前でユーザーを検索（スペース有無も吸収して候補を拾い、端末側で厳密フィルタ）
  Future<void> _searchUsersByName() async {
    final rawQuery = _nameController.text.trim();
    if (rawQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前を入力してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults.clear();
      _hasSearched = true; // 検索が実行されたことを設定
      _selectedUser = null; // 検索し直したら選択は解除
    });

    try {
      final normalizedQuery = _normalizeName(rawQuery);
      final prefix = _prefixForFirestore(rawQuery);

      // Firestore 側は前方一致で候補を取る（取りすぎ防止で limit）
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: prefix)
          .where('name', isLessThanOrEqualTo: '$prefix\uf8ff')
          .limit(50)
          .get();

      // 端末側で「スペース除去後の名前」が入力を含むかでフィルタ
      final filtered = userSnapshot.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        final normalizedName = _normalizeName(name);
        return normalizedName.contains(normalizedQuery);
      }).toList();

      setState(() {
        _searchResults = filtered;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 選択されたユーザーに「招待」を送る（承認されるまで members/teams は更新しない）
  Future<void> _inviteUserToTeam() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザーを選択してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String teamId = (widget.team['teamId'] ?? '').toString();
      if (teamId.isEmpty) {
        throw Exception('teamId が取得できませんでした');
      }

      final String inviteeUid = _selectedUser!.id;

      // チーム責任者など「入れてはいけない」ケースがあるならここで弾く
      // （例）招待対象がすでに members に入っている場合はスキップ
      final List<dynamic> currentMembers = (widget.team['members'] ?? []) as List<dynamic>;
      if (currentMembers.map((e) => e.toString()).contains(inviteeUid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すでにチームメンバーです')),
        );
        return;
      }

      final now = FieldValue.serverTimestamp();

      // ① チーム側: 招待一覧（teams/{teamId}/invites/{inviteeUid}）
      final teamInviteRef = FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('invites')
          .doc(inviteeUid);

      await teamInviteRef.set({
        'teamId': teamId,
        'inviteeUid': inviteeUid,
        'status': 'pending', // pending / accepted / rejected
        'createdAt': now,
        // 送り主など必要なら追加（例: invitedByUid）
      }, SetOptions(merge: true));

      // ② ユーザー側: 受信招待（users/{uid}/teamInvites/{teamId}）
      final userInviteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(inviteeUid)
          .collection('teamInvites')
          .doc(teamId);

      await userInviteRef.set({
        'teamId': teamId,
        'inviteeUid': inviteeUid,
        'status': 'pending',
        'createdAt': now,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('招待を送信しました（相手の承認待ち）')),
      );

      // 招待を送ったら選択解除（連続招待しやすく）
      setState(() {
        _selectedUser = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildUserListTile(QueryDocumentSnapshot<Map<String, dynamic>> userDoc) {
    final user = userDoc.data();
    String name = user['name'] ?? '名前不明';
    String? profileImageUrl = user['profileImage']; // プロフィール画像のURLはnullの可能性あり
    String? prefecture = user['prefecture']; // 都道府県もnullの可能性あり
    List<dynamic>? positions = user['positions'];
    Timestamp? birthdayTimestamp = user['birthday'];
    int? age;

    // 年齢を計算
    if (birthdayTimestamp != null) {
      age = _calculateAge(birthdayTimestamp);
    }

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage:
                profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : const AssetImage('assets/default_avatar.png')
                        as ImageProvider, // デフォルト画像とネットワーク画像の切り替え
          ),
          title: Text(name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prefecture != null && prefecture.isNotEmpty) // 都道府県がある場合のみ表示
                Text('都道府県: $prefecture'),
              if (age != null) Text('年齢: $age 歳'), // 年齢がある場合のみ表示
              if (positions != null && positions.isNotEmpty)
                Text('ポジション: ${positions.join(', ')}'), // ポジションがある場合のみ表示
            ],
          ),
          onTap: () {
            setState(() {
              if (_selectedUser == userDoc) {
                _selectedUser = null; // 再度タップで選択を解除
              } else {
                _selectedUser = userDoc; // 選択されたユーザーを設定
              }
            });
          },
          selected: _selectedUser == userDoc,
          selectedTileColor: Colors.grey[300], // 選択されたタイルの色
        ),
        if (_selectedUser == userDoc) // 選択されたユーザーのタイルの下にボタンを表示
          ElevatedButton(
            onPressed: _inviteUserToTeam,
            child: const Text('招待を送る'),
          ),
      ],
    );
  }

  int _calculateAge(Timestamp birthdayTimestamp) {
    DateTime birthday = birthdayTimestamp.toDate();
    DateTime today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバーを招待する'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // 中央揃えに変更
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) {
                FocusScope.of(context).unfocus();
                _searchUsersByName();
              },
              decoration: const InputDecoration(labelText: '名前'),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    // ボタンを中央に配置
                    child: ElevatedButton(
                      onPressed: _searchUsersByName,
                      child: const Text('ユーザーを検索'),
                    ),
                  ),
            const SizedBox(height: 16),
            _hasSearched && _searchResults.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Text('該当するユーザーが見つかりません'),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return _buildUserListTile(_searchResults[index]);
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
