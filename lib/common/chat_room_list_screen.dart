import 'package:b_net/common/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatRoomListScreen extends StatefulWidget {
  final VoidCallback? onUnreadCountChanged;

  const ChatRoomListScreen({super.key, required this.onUnreadCountChanged});

  @override
  _ChatRoomListScreenState createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
  }

  void _openChatRoom(String roomId, List<dynamic> participants) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // 自分以外のユーザーIDを取得
    String? recipientId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => null, // 👈 null の場合の対応
    );

    if (recipientId != null) {
      try {
        // 🔹 Firestore から相手の情報を取得
        DocumentSnapshot recipientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(recipientId)
            .get();

        if (recipientDoc.exists) {
          Map<String, dynamic>? recipientData =
              recipientDoc.data() as Map<String, dynamic>?;
          String recipientName = recipientData?['name'] ?? '未設定';
          String recipientProfileImageUrl =
              recipientData?['profileImage'] ?? '';

          // 🔹 `ChatScreen` に遷移
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                recipientId: recipientId,
                recipientName: recipientName,
                recipientProfileImageUrl: recipientProfileImageUrl,
                roomId: roomId,
              ),
            ),
          );
        } else {
          print("⚠️ recipientDoc does not exist");
        }
      } catch (e) {
        print("⚠️ Error fetching recipient data: $e");
      }
    } else {
      print("⚠️ recipientId is null");
    }
  }

  /// **相手のユーザーデータを取得**
  Future<Map<String, dynamic>?> _getOtherUserData(
      List<dynamic> participants) async {
    String otherUserId =
        participants.firstWhere((id) => id != _user!.uid, orElse: () => '');

    if (otherUserId.isEmpty) return null;

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(otherUserId).get();

    if (userDoc.exists) {
      return userDoc.data() as Map<String, dynamic>;
    }

    return null;
  }

  /// **未読カウントをリセット**
  Future<void> _resetUnreadCount(String roomId) async {
    String userId = _user!.uid;
    await _firestore.collection('chatRooms').doc(roomId).update({
      'unreadCounts.$userId': 0,
    });

    // 🔹 コールバックが `null` でない場合のみ呼び出し
    if (widget.onUnreadCountChanged != null) {
      widget.onUnreadCountChanged!();
    }
  }

  /// **チャットルームとそのメッセージを削除**
  Future<void> _deleteChatRoom(String roomId) async {
    try {
      WriteBatch batch = _firestore.batch();

      // 🔹 まず `messages` コレクション内のすべてのメッセージを取得
      QuerySnapshot messagesSnapshot = await _firestore
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .get();

      // 🔹 取得したメッセージをバッチ処理で削除
      for (QueryDocumentSnapshot doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 🔹 その後、チャットルーム自体を削除
      batch.delete(_firestore.collection('chatRooms').doc(roomId));

      // 🔹 一括削除を実行
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除しました')),
      );
    } catch (e) {
      print("⚠️ チャットルーム削除エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チャットルームの削除に失敗しました')),
      );
    }
  }

  /// **メッセージを短縮（20文字以上の場合に省略）**
  String _shortenMessage(String message) {
    return message.length > 20 ? '${message.substring(0, 20)}...' : message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('チャットルーム一覧'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chatRooms')
            .where('participants', arrayContains: _user?.uid)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('チャットルームがありません'));
          }

          List<QueryDocumentSnapshot> chatRooms = snapshot.data!.docs;

          // 🔥 `lastMessageAt` がないデータにも対応
          chatRooms.sort((a, b) {
            Map<String, dynamic> aData = a.data() as Map<String, dynamic>;
            Map<String, dynamic> bData = b.data() as Map<String, dynamic>;

            Timestamp lastMessageA = aData.containsKey('lastMessageAt')
                ? aData['lastMessageAt']
                : Timestamp(0, 0);
            Timestamp lastMessageB = bData.containsKey('lastMessageAt')
                ? bData['lastMessageAt']
                : Timestamp(0, 0);

            return lastMessageB.compareTo(lastMessageA);
          });

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              var room = chatRooms[index].data() as Map<String, dynamic>;
              String roomId = chatRooms[index].id;
              List<dynamic> participants = room['participants'];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getOtherUserData(participants),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      title: Text('ロード中...'),
                    );
                  }

                  var otherUserData = userSnapshot.data!;
                  String displayName = otherUserData['name'] ?? '匿名ユーザー';
                  String displayProfileImageUrl =
                      otherUserData['profileImage'] ?? '';

                  // 自分の未読メッセージ数を取得
                  String userId = _user!.uid;
                  int unreadCount = room['unreadCounts']?[userId] ?? 0;

                  return Dismissible(
                    key: Key(roomId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      bool confirmDelete = await showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('チャットルームを削除'),
                            content: const Text('本当に削除しますか？この操作は元に戻せません。'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false), // ❌ キャンセル
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true), // ✅ 削除
                                child: const Text('削除',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          );
                        },
                      );

                      return confirmDelete; // `true` のときだけ削除
                    },
                    onDismissed: (direction) async {
                      await _deleteChatRoom(roomId);
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: displayProfileImageUrl.isNotEmpty
                            ? NetworkImage(displayProfileImageUrl)
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                      ),
                      title: Text(displayName),
                      subtitle: Text(_shortenMessage(
                          room['lastMessage'] ?? 'メッセージがありません')),
                      trailing: unreadCount > 0
                          ? CircleAvatar(
                              backgroundColor: Colors.red,
                              radius: 12,
                              child: Text('$unreadCount',
                                  style: const TextStyle(color: Colors.white)),
                            )
                          : null,
                      onTap: () async {
                        await _resetUnreadCount(roomId);
                        _openChatRoom(roomId, participants);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
