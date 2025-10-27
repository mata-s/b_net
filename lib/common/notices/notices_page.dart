import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notice_detail_page.dart';
import 'add_notice_page.dart';

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key});

  @override
  _NoticesPageState createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  bool _isAdmin = false;
  String? _userId;
  Map<String, bool> _readStatus = {}; // 🔹 既読データのキャッシュ
  bool _isLoadingReadStatus = true; // 🔄 読み込み中フラグ

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadReadStatus(); // 🔹 既読データを取得
  }

  /// **管理者チェック**
  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final adminDoc = await FirebaseFirestore.instance
        .collection('admin_users')
        .doc(user.uid)
        .get();

    setState(() {
      _isAdmin = adminDoc.exists;
    });
  }

  /// **日付フォーマット関数**
  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return DateFormat('yyyy年MM月dd日').format(date);
  }

  /// **ユーザーが読んだお知らせを Firestore から一括取得**
  Future<void> _loadReadStatus() async {
    if (_userId == null) return;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users_read')
        .doc(_userId)
        .collection('read_announcements')
        .get();

    setState(() {
      for (var doc in querySnapshot.docs) {
        _readStatus[doc.id] = true;
      }
      _isLoadingReadStatus = false; // 🔄 ローディング完了
    });
  }

  /// **お知らせを既読として Firestore に保存**
  Future<void> _markAsRead(String noticeId) async {
    if (_userId == null || _readStatus[noticeId] == true) return;

    await FirebaseFirestore.instance
        .collection('users_read')
        .doc(_userId)
        .collection('read_announcements')
        .doc(noticeId)
        .set({'read': true, 'timestamp': FieldValue.serverTimestamp()});

    setState(() {
      _readStatus[noticeId] = true; // 🔹 即時更新
    });
  }

  /// **すべてのお知らせを既読にする**
  Future<void> _markAllAsRead() async {
    if (_userId == null) return;

    final querySnapshot =
        await FirebaseFirestore.instance.collection('announcements').get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var doc in querySnapshot.docs) {
      String noticeId = doc.id;
      batch.set(
        FirebaseFirestore.instance
            .collection('users_read')
            .doc(_userId)
            .collection('read_announcements')
            .doc(noticeId),
        {'read': true, 'timestamp': FieldValue.serverTimestamp()},
      );

      _readStatus[noticeId] = true; // 🔹 UI を即時更新
    }

    await batch.commit(); // 🔥 Firestore にまとめて書き込み

    setState(() {}); // 🔹 UI を更新
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft, // 🔹 タイトルを左寄せ
          child: const Text('お知らせ'),
        ),
        actions: [
          TextButton(
            onPressed: _markAllAsRead, // 🔹 すべて既読にする
            child: const Text(
              "すべて既読にする",
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    _isLoadingReadStatus) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('お知らせはありません'));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String noticeId = doc.id;
                    bool isImportant = data['isImportant'] ?? false;
                    String title = data['title'] ?? 'タイトルなし';
                    String formattedDate = data['timestamp'] != null
                        ? _formatDate(data['timestamp'] as Timestamp)
                        : '日付不明';

                    bool isUnread = _readStatus[noticeId] == false ||
                        !_readStatus.containsKey(noticeId);

                    return ListTile(
                      onTap: () {
                        // 🔹 画面を開いた時点で既読処理
                        _markAsRead(noticeId);

                        // 🔹 詳細画面へ遷移
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NoticeDetailPage(
                              title: data['title'] ?? 'タイトルなし',
                              content: data['content'] ?? '内容なし',
                              date: formattedDate,
                              isImportant: isImportant,
                              prefectures:
                                  List<String>.from(data['prefectures'] ?? []),
                            ),
                          ),
                        );
                      },
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (isImportant)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "重要",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: isUnread
                          ? const Icon(Icons.circle,
                              color: Colors.red, size: 10) // 🔴 未読マーク
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddNoticePage()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
