import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_dialog.dart'; // 🔹 プロフィール表示用

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _searchType = 'チーム名'; // 🔹 初期状態はチーム検索
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged); // 🔹 入力ごとに検索
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// 🔹 テキスト変更時の処理
  void _onSearchTextChanged() {
    String searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
    } else {
      _searchData();
    }
  }

  /// 🔹 Firestore からリアルタイム検索
  Future<void> _searchData() async {
    String searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    QuerySnapshot querySnapshot;
    if (_searchType == 'チーム名') {
      querySnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('teamName', isGreaterThanOrEqualTo: searchQuery)
          .where('teamName', isLessThan: searchQuery + '\uf8ff')
          .get();
    } else if (_searchType == '県') {
      // 🔹 県の検索（あいまい検索）
      querySnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('prefecture', isGreaterThanOrEqualTo: searchQuery)
          .where('prefecture', isLessThan: searchQuery + '\uf8ff')
          .get();
    } else {
      // 🔹 ユーザー検索
      querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThan: searchQuery + '\uf8ff')
          .get();
    }

    setState(() {
      _searchResults = querySnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;

        if (_searchType == 'ユーザー名') {
          return {
            'id': doc.id,
            'name': data['name'] ?? '不明',
            'sub': Column(
              // 🔹 都道府県 & 守備位置を表示
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['prefecture'] != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(data['prefecture']),
                    ],
                  ),
                if (data['positions'] != null &&
                    (data['positions'] as List).isNotEmpty)
                  Row(
                    children: [
                      const Text('ポジション:'),
                      const SizedBox(width: 4),
                      Text(
                          (data['positions'] as List).join(', ')), // 🔹 守備位置を表示
                    ],
                  ),
              ],
            ),
            'isTeam': false,
          };
        } else {
          return {
            'id': doc.id,
            'name': data['teamName'] ?? '不明',
            'sub': Row(
              // 🔹 チームの所在地をアイコンで表示
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(data['prefecture'] ?? '不明'),
              ],
            ),
            'isTeam': true,
          };
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("検索")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 ラジオボタン（検索タイプ選択）
            Row(
              children: [
                _buildRadioButton("チーム名", "チーム名"),
                _buildRadioButton("県", "県"),
                _buildRadioButton("ユーザー名", "ユーザー名"),
              ],
            ),
            const SizedBox(height: 10),

            // 🔹 検索バー（検索ボタン付き）
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _searchType == '県'
                          ? "都道府県を入力"
                          : _searchType == 'ユーザー名'
                              ? "ユーザー名を入力"
                              : "チーム名を入力",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12.0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchData, // 🔹 検索ボタンタップで検索
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 🔹 検索結果リスト
            Expanded(
              child: _searchResults.isEmpty
                  ? const Center(child: Text("該当する結果がありません"))
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(result['name']),
                          subtitle: result['sub'],
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // 🔹 プロフィールを開く（チーム or ユーザー）
                            showProfileDialog(
                              context,
                              result['id'],
                              result['isTeam'],
                              currentUserUid:
                                  FirebaseAuth.instance.currentUser!.uid,
                              currentUserName: FirebaseAuth
                                  .instance.currentUser!.displayName,
                              isFromSearch: true, // 🔹 検索結果から開く時だけ true にする
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 **ラジオボタンウィジェット**
  Widget _buildRadioButton(String title, String value) {
    return Row(
      children: [
        Radio(
          value: value,
          groupValue: _searchType,
          onChanged: (newValue) {
            setState(() {
              _searchType = newValue.toString();
              _searchController.clear(); // 🔹 入力欄をリセット
              _searchResults = []; // 🔹 検索結果をクリア
            });
          },
        ),
        Text(title),
        const SizedBox(width: 10),
      ],
    );
  }
}
