import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PostPage extends StatefulWidget {
  final String userUid;
  final String userName;
  final String? postId; // 🔹 編集時は投稿IDを受け取る
  final Map<String, dynamic>? existingData; // 🔹 既存の投稿データを受け取る

  const PostPage({
    super.key,
    required this.userUid,
    required this.userName,
    this.postId,
    this.existingData,
  });

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeRangeController = TextEditingController();
  final TextEditingController _prefectureController = TextEditingController();
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  bool _isLoading = false;

  Map<String, String> _teamMap = {};
  String? _selectedTeamName;
  String? _selectedTeamId;

  @override
  void initState() {
    super.initState();
    _fetchUserTeams();

    // 🔹 既存のデータがある場合はフィールドにセット（編集モード）
    if (widget.existingData != null) {
      _titleController.text = widget.existingData!['title'] ?? '';
      _dateController.text = widget.existingData!['dateTime'] ?? '';
      _timeRangeController.text = widget.existingData!['timeRange'] ?? '';
      _prefectureController.text = widget.existingData!['prefecture'] ?? '';
      _teamNameController.text = widget.existingData!['teamName'] ?? '';
      _postController.text = widget.existingData!['content'] ?? '';
      _selectedTeamId = widget.existingData!['teamId'];
    }
  }

  /// **ユーザーが所属するチームを取得**
  Future<void> _fetchUserTeams() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userUid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;

        if (userData == null || !userData.containsKey('teams')) return;

        List<dynamic> teamIds = userData['teams'] ?? [];
        Map<String, String> teamMap = {};

        for (String teamId in teamIds) {
          DocumentSnapshot teamDoc = await FirebaseFirestore.instance
              .collection('teams')
              .doc(teamId)
              .get();
          if (teamDoc.exists) {
            String teamName = teamDoc['teamName'] ?? 'チーム名不明';
            teamMap[teamName] = teamId;
          }
        }

        setState(() {
          _teamMap = teamMap;
          if (_teamMap.isNotEmpty && _selectedTeamId == null) {
            _selectedTeamName = _teamMap.keys.first;
            _teamNameController.text = _selectedTeamName!;
            _selectedTeamId = _teamMap[_selectedTeamName];
          }
        });
      }
    } catch (e) {
      print('⚠️ Error fetching team names: $e');
    }
  }

  /// **投稿を作成または更新**
  Future<void> _submitPost() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.postId != null) {
        // 🔹 既存の投稿を更新
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update({
          'title': _titleController.text,
          'dateTime': _dateController.text,
          'timeRange': _timeRangeController.text,
          'prefecture': _prefectureController.text,
          'teamName': _teamNameController.text,
          'teamId': _selectedTeamId,
          'content': _postController.text,
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿を更新しました！')));
      } else {
        // 🔹 新規投稿
        await FirebaseFirestore.instance.collection('posts').add({
          'title': _titleController.text,
          'dateTime': _dateController.text,
          'timeRange': _timeRangeController.text,
          'prefecture': _prefectureController.text,
          'teamName': _teamNameController.text,
          'teamId': _selectedTeamId,
          'content': _postController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'postedBy': widget.userUid,
          'postedByName': widget.userName,
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('投稿が完了しました！')));
      }

      Navigator.of(context).pop();
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

  /// **UIを構築**
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.postId != null ? '投稿を編集' : '新規投稿'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'タイトル',
                hintText: '例: 練習試合相手の募集、助っ人募集',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _buildTeamSelectionField(),
            const SizedBox(height: 20),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '日付を選択',
                hintText: '例: 2024/10/01',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _timeRangeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '時間範囲を選択',
                hintText: '例: 14:00 - 16:00',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () => _selectTimeRange(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _prefectureController,
              decoration: const InputDecoration(
                labelText: '募集都道府県',
                hintText: '例: 大阪、兵庫',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _postController,
              decoration: const InputDecoration(
                labelText: '詳細',
                hintText: '例: 助っ人募集していませんか？\n球場抑えてる方試合しませんか？',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitPost,
                    child: Text(widget.postId != null ? '更新する' : '投稿する'),
                  ),
          ],
        ),
      ),
    );
  }

  /// **日付選択**
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy/MM/dd').format(picked);
      });
    }
  }

  Future<void> _selectTimeRange(BuildContext context) async {
    // 🔹 現在の時刻を取得
    final TimeOfDay now = TimeOfDay.now();

    // 🔹 1回目（開始時間）の選択
    final TimeOfDay? startPicked = await showTimePicker(
      context: context,
      initialTime: now, // ← 現在の時間をデフォルトに設定
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (startPicked != null) {
      // 🔹 2回目（終了時間）の選択
      final TimeOfDay? endPicked = await showTimePicker(
        context: context,
        initialTime: startPicked.replacing(
            hour: (startPicked.hour + 1) % 24), // 1時間後をデフォルトに
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );

      if (endPicked != null) {
        setState(() {
          _timeRangeController.text =
              '${startPicked.format(context)} - ${endPicked.format(context)}'; // 🔹 時間範囲をセット
        });
      }
    }
  }

  /// **チーム選択フィールド（自由入力 + ドロップダウン）**
  Widget _buildTeamSelectionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('チーム名（選択 または 入力）',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _teamNameController,
                decoration: const InputDecoration(
                  hintText: 'チーム名を入力 または 選択',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedTeamName = value; // 手入力の場合、チーム名を直接セット
                    _selectedTeamId = null; // IDをリセット
                  });
                },
              ),
            ),
            if (_teamMap.isNotEmpty) // 🔹 チームがある場合のみドロップダウンを表示
              PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (String selectedTeamName) {
                  setState(() {
                    _selectedTeamName = selectedTeamName;
                    _selectedTeamId =
                        _teamMap[selectedTeamName]; // 🔹 選択したチームの `teamId` をセット
                    _teamNameController.text =
                        selectedTeamName; // 🔹 選択したチーム名を表示
                  });
                },
                itemBuilder: (BuildContext context) {
                  return _teamMap.keys.map((String teamName) {
                    return PopupMenuItem<String>(
                      value: teamName,
                      child: Text(teamName), // 🔹 チーム名を表示
                    );
                  }).toList();
                },
              ),
          ],
        ),
      ],
    );
  }
}
