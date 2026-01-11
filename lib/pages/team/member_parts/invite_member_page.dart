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
  List<DocumentSnapshot> _searchResults = [];
  DocumentSnapshot? _selectedUser; // 選択されたユーザー
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
        final data = doc.data() as Map<String, dynamic>;
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

  // 選択されたユーザーをチームに追加
  Future<void> _addUserToTeam() async {
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
      String userId = _selectedUser!.id;

      // チームにユーザーを追加
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.team['teamId'])
          .update({
        'members': FieldValue.arrayUnion([userId]),
      });

      // ユーザーの `teams` フィールドにチームIDを追加
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'teams': FieldValue.arrayUnion([widget.team['teamId']]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザーがチームに追加されました')),
      );
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

  Widget _buildUserListTile(DocumentSnapshot userDoc) {
    var user = userDoc.data() as Map<String, dynamic>;
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
            onPressed: _addUserToTeam,
            child: const Text('チームに追加'),
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
