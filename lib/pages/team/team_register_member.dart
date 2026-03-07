import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// チーム管理者（監督/マネージャー）が、
/// 「アプリ登録なしの選手（チームメンバー）」を users に作成するページ。
///
/// 保存先:
/// users/{newUid}
///   - name: String
///   - teams: List<String> (teamId を 1つ入れる)
///   - positions: List<String>
///   - prefecture: String (チームの都道府県)
///   - isTeamMemberOnly: true
class TeamRegisterMemberPage extends StatefulWidget {
  final String teamId;
  final String teamPrefecture;

  const TeamRegisterMemberPage({
    super.key,
    required this.teamId,
    required this.teamPrefecture,
  });

  @override
  State<TeamRegisterMemberPage> createState() => _TeamRegisterMemberPageState();
}

class _TeamRegisterMemberPageState extends State<TeamRegisterMemberPage> {
  final _nameController = TextEditingController();

  bool _saving = false;
  DateTime? _birthday;

  // この画面で登録したメンバー名を表示する
  final List<String> _registeredMemberNames = <String>[];

  // 必要なら増やしてOK
  static const List<String> _positionOptions = <String>[
    '投手',
    '捕手',
    '一塁手',
    '二塁手',
    '三塁手',
    '遊撃手',
    '左翼手',
    '中堅手',
    '右翼手',
  ];

  final Set<String> _selectedPositions = <String>{};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _birthday = picked;
      });
    }
  }

  Future<void> _registerMember() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前を入力してください')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // FirebaseAuth を使わずに「users のドキュメントID」を UID として採用
      final userRef = FirebaseFirestore.instance.collection('users').doc();
      final newUid = userRef.id;

      await userRef.set({
        'name': name,
        'teams': <String>[widget.teamId],
        'positions': _selectedPositions.toList(),
        'prefecture': widget.teamPrefecture,
        'isTeamMemberOnly': true,
        'birthday': _birthday != null ? Timestamp.fromDate(_birthday!) : null,
        // 便利なので付けておく（不要なら削除OK）
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // teams/{teamId} の members 配列にも追加
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .set({
        'members': FieldValue.arrayUnion([newUid])
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メンバーを登録しました')),
      );

      // この画面に留まり、登録済みリストに追加
      setState(() {
        _registeredMemberNames.insert(0, name);
        _nameController.clear();
        _selectedPositions.clear();
        _birthday = null;
      });

      // キーボードを閉じる
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー登録'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'アプリ未登録の選手をチームメンバーとして登録できます。\n（ログイン不要の選手用）',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '名前',
                hintText: '例）田中 太郎',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text(
                  'ポジション',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '（複数選択OK）',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _positionOptions.map((p) {
                final selected = _selectedPositions.contains(p);
                return FilterChip(
                  label: Text(p),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedPositions.add(p);
                      } else {
                        _selectedPositions.remove(p);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 誕生日（任意）
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '誕生日（任意）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'チーム平均年齢の計算に役立ちます（わかる場合のみでOK）',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickBirthday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cake_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _birthday == null
                                ? '誕生日を選択'
                                : '${_birthday!.year}年${_birthday!.month}月${_birthday!.day}日',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.location_on, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '都道府県: ${widget.teamPrefecture}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _registerMember,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登録する'),
              ),
            ),

            const SizedBox(height: 16),

            if (_registeredMemberNames.isNotEmpty) ...[
              const Text(
                'この画面で登録したメンバー',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._registeredMemberNames.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            n,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}