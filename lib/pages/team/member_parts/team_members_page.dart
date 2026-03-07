import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeamMembersPage extends StatefulWidget {
  final String teamId;

  const TeamMembersPage({super.key, required this.teamId});

  @override
  _TeamMembersPageState createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String? _adminId;
  List<String> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchTeamData();
  }

  /// 🔹 **チームデータ（管理者ID & メンバー一覧）を取得**
  Future<void> _fetchTeamData() async {
    try {
      DocumentSnapshot teamSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();

      if (teamSnapshot.exists) {
        setState(() {
          _adminId = teamSnapshot['createdBy']; // ✅ 管理者ID
          _teamMembers = List<String>.from(teamSnapshot['members']); // ✅ メンバー一覧
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('チーム情報の取得に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チームメンバー一覧'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${_teamMembers.length}人のチームメンバー', // ✅ メンバー数を表示
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where(FieldPath.documentId,
                      whereIn: _teamMembers.isEmpty ? ['dummy'] : _teamMembers)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('メンバーがいません'));
                }

                List<DocumentSnapshot> members = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index].data() as Map<String, dynamic>;
                    final memberId = members[index].id;

                    // ✅ 現在の管理者かどうか
                    final bool isAdmin = memberId == _adminId;

                    // ✅ 「このページで登録した選手」は責任者に任命できない
                    //    登録時に users に `isTeamMemberOnly: true` を保存している前提
                    final bool isTeamMemberOnly = (member['isTeamMemberOnly'] == true);

                    return ListTile(
                      title: Text(member['name'] ?? '名前不明'),
                      subtitle: Text(
                        isAdmin
                            ? '管理者'
                            : (isTeamMemberOnly ? '登録選手（管理者に任命不可）' : ''),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_adminId == _currentUserId &&
                              memberId != _adminId &&
                              isTeamMemberOnly)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.black54),
                              onPressed: () {
                                final name = (member['name'] ?? '').toString();
                                final positions = (member['positions'] is List)
                                    ? List<String>.from(member['positions'] ?? const <String>[])
                                    : <String>[];

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeamEditRegisteredMemberPage(
                                      memberId: memberId,
                                      initialName: name,
                                      initialPositions: positions,
                                      onSaved: (newName, newPositions, birthday) async {
                                        await _updateRegisteredMember(memberId, newName, newPositions);

                                        if (birthday != null) {
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(memberId)
                                              .update({'birthday': Timestamp.fromDate(birthday)});
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (_adminId == _currentUserId &&
                              memberId != _adminId &&
                              !isTeamMemberOnly) // ✅ 登録選手（isTeamMemberOnly）は責任者に任命不可
                            IconButton(
                              icon: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                              onPressed: () {
                                _confirmChangeAdmin(memberId);
                              },
                            ),
                          if (_adminId == _currentUserId &&
                              memberId != _adminId) // ✅ 管理者かつ自分自身は削除不可
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _confirmRemoveMember(memberId);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 **管理者を変更する確認ダイアログ**
  void _confirmChangeAdmin(String newAdminId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認'),
          content: const Text('本当に管理者を変更しますか？'),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('はい', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.of(context).pop();
                _changeAdmin(newAdminId); // ✅ 管理者変更
              },
            ),
          ],
        );
      },
    );
  }

  /// 🔹 **管理者を変更**
  Future<void> _changeAdmin(String newAdminId) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // 🔹 Firestore 更新（新しい管理者を設定）
      await firestore.collection('teams').doc(widget.teamId).update({
        'createdBy': newAdminId,
      });

      setState(() {
        _adminId = newAdminId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('管理者が変更されました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('管理者変更中にエラーが発生しました: $e')),
      );
    }
  }

  /// 🔹 **メンバー削除の確認ダイアログ**
  void _confirmRemoveMember(String memberId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認'),
          content: const Text('このメンバーを削除しますか？'),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('削除', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _removeMember(memberId); // ✅ メンバー削除
              },
            ),
          ],
        );
      },
    );
  }

  /// 🔹 **メンバーを削除**
  Future<void> _removeMember(String userId) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // 🔹 Firestore 更新（チームのメンバー一覧から削除）
      await firestore.collection('teams').doc(widget.teamId).update({
        'members': FieldValue.arrayRemove([userId]),
      });

      // 🔹 Firestore 更新（ユーザーの `teams` からこのチームを削除）
      await firestore.collection('users').doc(userId).update({
        'teams': FieldValue.arrayRemove([widget.teamId]),
      });

      // 🔹 UI更新のため、ローカルのメンバーリストを更新
      setState(() {
        _teamMembers.remove(userId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メンバーが削除されました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メンバーの削除中にエラーが発生しました: $e')),
      );
    }
  }

  /// 🔹 **登録選手の情報を更新**
  Future<void> _updateRegisteredMember(
    String memberId,
    String newName,
    List<String> newPositions,
  ) async {
    try {
      final updateData = <String, dynamic>{
        'positions': newPositions,
      };

      // 名前が空なら上書きしない（事故防止）
      if (newName.isNotEmpty) {
        updateData['name'] = newName;
      }

      await FirebaseFirestore.instance.collection('users').doc(memberId).update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メンバー情報を更新しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    }
  }
}

class TeamEditRegisteredMemberPage extends StatefulWidget {
  final String memberId;
  final String initialName;
  final List<String> initialPositions;
  final Future<void> Function(String newName, List<String> newPositions, DateTime? birthday) onSaved;

  const TeamEditRegisteredMemberPage({
    super.key,
    required this.memberId,
    required this.initialName,
    required this.initialPositions,
    required this.onSaved,
  });

  @override
  State<TeamEditRegisteredMemberPage> createState() => _TeamEditRegisteredMemberPageState();
}

class _TeamEditRegisteredMemberPageState extends State<TeamEditRegisteredMemberPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _positionsController;
  bool _saving = false;
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _positionsController = TextEditingController(text: widget.initialPositions.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final newName = _nameController.text.trim();
    final newPositions = _positionsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      await widget.onSaved(newName, newPositions, _birthday);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メンバー情報を更新しました')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登録メンバーを編集'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名前',
              hintText: '例）山田 太郎',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _positionsController,
            decoration: const InputDecoration(
              labelText: 'ポジション（カンマ区切り）',
              hintText: '例）投手, 捕手, 一塁手',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('誕生日（任意）'),
            subtitle: Text(
              _birthday == null
                  ? '未設定'
                  : '${_birthday!.year}年${_birthday!.month}月${_birthday!.day}日',
            ),
            trailing: const Icon(Icons.cake_outlined),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(now.year - 20),
                firstDate: DateTime(1940),
                lastDate: now,
              );

              if (picked != null) {
                setState(() {
                  _birthday = picked;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          const Text(
            '※この編集は「登録選手」のみ可能です',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
