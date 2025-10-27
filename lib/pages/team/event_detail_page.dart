import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:b_net/pages/team/team_schedule_calendar.dart'; // 🔹 Event クラスをインポート

class EventDetailPage extends StatefulWidget {
  final Event event;
  final String teamId;
  final Function(Event) onUpdate; // 🔹 親画面の更新用コールバック

  const EventDetailPage({
    super.key,
    required this.event,
    required this.teamId,
    required this.onUpdate,
  });

  @override
  _EventDetailPageState createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Event _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event; // 初期データ
  }

  Future<void> _stampEvent(String stampType) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String userName = userDoc['name'] ?? '未設定';

    List<Map<String, dynamic>> updatedStamps =
        List<Map<String, dynamic>>.from(_event.stamps);
    updatedStamps.removeWhere((stamp) => stamp['userId'] == userId);
    updatedStamps
        .add({'userId': userId, 'userName': userName, 'stampType': stampType});

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .doc(_event.id)
        .update({'stamps': updatedStamps});

    setState(() {
      _event = _event.copyWith(newStamps: updatedStamps);
    });

    widget.onUpdate(_event); // 🔹 親画面も更新
  }

  Future<void> _addComment(String commentText) async {
    if (commentText.isEmpty) return;

    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String userName = userDoc['name'] ?? '未設定';

    Map<String, dynamic> newComment = {
      'userId': userId,
      'userName': userName,
      'comment': commentText
    };

    await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('schedule')
        .doc(_event.id)
        .update({
      'comments': FieldValue.arrayUnion([newComment])
    });

    setState(() {
      _event = _event.copyWith(newComments: [..._event.comments, newComment]);
    });

    widget.onUpdate(_event); // 🔹 親画面も更新
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 タイトル (中央揃え)
              Center(
                child: Text(
                  _event.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 詳細情報
              if (_event.time != null && _event.time!.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6.0), // 適切な余白を追加
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time,
                          size: 22, color: Color(0xFF444444)), // 📍 アイコン
                      const SizedBox(width: 8), // アイコンとテキストの間隔
                      Expanded(
                        // 🔹 追加：テキストを折り返すために Expanded を使用
                        child: Text(
                          _event.time!,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          softWrap: true, // 🔹 折り返しを許可
                          overflow: TextOverflow.visible, // 🔹 全て表示（切り捨てを防ぐ）
                        ),
                      ),
                    ],
                  ),
                ),

              if (_event.location.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6.0), // 適切な余白を追加
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on,
                          size: 22, color: Color(0xFF444444)), // 📍 アイコン
                      const SizedBox(width: 8), // アイコンとテキストの間隔
                      Expanded(
                        // 🔹 追加：テキストを折り返すために Expanded を使用
                        child: Text(
                          _event.location, // 🔹 場所の情報
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          softWrap: true, // 🔹 折り返しを許可
                          overflow: TextOverflow.visible, // 🔹 全て表示（切り捨てを防ぐ）
                        ),
                      ),
                    ],
                  ),
                ),

              if (_event.opponent.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6.0), // 適切な余白を追加
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.people,
                          size: 22, color: Color(0xFF444444)), // 📍 アイコン
                      const SizedBox(width: 8), // アイコンとテキストの間隔
                      Expanded(
                        // 🔹 追加：テキストを折り返すために Expanded を使用
                        child: Text(
                          _event.opponent, // 🔹 場所の情報
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500),
                          softWrap: true, // 🔹 折り返しを許可
                          overflow: TextOverflow.visible, // 🔹 全て表示（切り捨てを防ぐ）
                        ),
                      ),
                    ],
                  ),
                ),

              if (_event.details.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6.0), // 適切な余白を追加
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // 🔹 左寄せ
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.description,
                              size: 22, color: Color(0xFF444444)), // 📄 アイコン
                          const SizedBox(width: 8),
                          Text(
                            "詳細", // 🔹 ラベル部分
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF444444)), // 濃いグレー
                          ),
                        ],
                      ),
                      const SizedBox(height: 4), // 🔹 ラベルと本文の間に少し間隔を空ける
                      Text(
                        _event.details, // 🔹 本文
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                        softWrap: true, // 🔹 折り返しを許可
                        overflow: TextOverflow.visible, // 🔹 切り捨てを防ぐ
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0), // 適切な余白を追加
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.person,
                        size: 18, color: Color(0xFF444444)), // 📍 アイコン
                    const SizedBox(width: 8),
                    Text(
                      "作成者: ", // 🔹 ラベル部分
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF444444)), // 濃いグレー
                    ),
                    const SizedBox(width: 6), // ラベルと値の間隔
                    Text(_event.createdName)
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  // 🔹 スタンプ（タップ可能: ダイアログを開く）
                  GestureDetector(
                    onTap: () => _showStampSelectionDialog(),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_emotions, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          "スタンプ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4), // スタンプと数の間隔
                        Text(
                          "${_event.stamps.length}件", // 🔹 スタンプの数を表示
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ],
                    ),
                  ),

                  // 🔹 スタンプの内訳
                  Row(
                    children:
                        _getStampSummary(_event.stamps).entries.map((entry) {
                      return GestureDetector(
                        onTap: () => _showStampDetailDialog(
                            entry.key, _event.stamps), // 🔹 タップでスタンプ詳細ダイアログを開く
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: Row(
                            children: [
                              Text(
                                "${entry.key}", // スタンプアイコン
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${entry.value}", // スタンプの数
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              if (_event.stamps.isNotEmpty) ...[
                const Text("スタンプ",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                // 🔹 スタンプを押したユーザー一覧
                Column(
                  children: _event.stamps.map((stamp) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_emotions, size: 18),
                          const SizedBox(width: 8),
                          Text("${stamp['userName']}: ",
                              style: const TextStyle(fontSize: 16)),
                          Text("${stamp['stampType']}",
                              style: const TextStyle(fontSize: 18)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showCommentInputDialog(),
                child: Row(
                  children: [
                    const Icon(Icons.comment, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      "コメント",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 4), // コメントと数の間隔
                    Text(
                      "${_event.comments.length}件", // 🔹 コメントの数を表示
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_event.comments.isNotEmpty) ...[
                const Text("コメント",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _event.comments.length,
                  itemBuilder: (context, index) {
                    final comment = _event.comments[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start, // 上揃えにする
                        children: [
                          // 🔹 ユーザー名（折り返しを防ぐ）
                          Text(
                            "${comment['userName']}: ",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),

                          // 🔹 コメント部分（折り返す際にインデント）
                          Expanded(
                            child: Text(
                              comment['comment'],
                              style: const TextStyle(fontSize: 16),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  void _showStampSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // 🔹 角丸デザイン
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6, // 🔹 画面の60%の高さ
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'スタンプを選択',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // 🔹 中央揃え
                    children: [
                      _buildStampOption('🙆‍♂️'),
                      _buildStampOption('🙅'),
                      _buildStampOption('🤔'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context), // 🔹 キャンセルボタンでダイアログを閉じる
                  child: const Text(
                    "キャンセル",
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// 🔹 スタンプの選択肢を作るウィジェット（大きな絵文字）
  Widget _buildStampOption(String emoji) {
    return GestureDetector(
      onTap: () {
        _stampEvent(emoji);
        Navigator.pop(context); // 🔹 スタンプ選択後にダイアログを閉じる
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0), // 余白をつける
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 48), // 🔹 絵文字を大きくする
        ),
      ),
    );
  }

  Map<String, int> _getStampSummary(List<Map<String, dynamic>> stamps) {
    Map<String, int> summary = {};
    for (var stamp in stamps) {
      String type = stamp['stampType'];
      summary[type] = (summary[type] ?? 0) + 1;
    }
    return summary;
  }

  void _showStampDetailDialog(
      String stampType, List<Map<String, dynamic>> stamps) {
    List<String> users = stamps
        .where((stamp) => stamp['stampType'] == stampType)
        .map((stamp) =>
            stamp['userName'].toString()) // 🔹 toString() で確実に String にする
        .toList(); // 🔹 明示的に List<String> に変換

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$stampType を押した人"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: users.map((user) => ListTile(title: Text(user))).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("閉じる"),
          ),
        ],
      ),
    );
  }

  void _showCommentInputDialog() {
    TextEditingController commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("コメントを入力"),
        content: TextField(controller: commentController),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 🔹 キャンセルボタンでダイアログを閉じる
            },
            child: const Text("キャンセル"),
          ),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.isNotEmpty) {
                _addComment(commentController.text);
                Navigator.pop(context); // 🔹 コメント送信後にダイアログを閉じる
              }
            },
            child: const Text("送信"),
          ),
        ],
      ),
    );
  }
}
