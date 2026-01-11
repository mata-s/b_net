import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // クリップボード用
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart'; // 動画再生用
import 'package:image/image.dart' as img; // 画像圧縮用
import 'package:b_net/common/profile_dialog.dart';

class ChatScreen extends StatefulWidget {
  final String? recipientId;
  final String? recipientName;
  final String? recipientProfileImageUrl;
  final String? roomId;
  final Map<String, dynamic>? team; // チーム情報

  const ChatScreen({
    super.key,
    this.recipientId,
    this.recipientName,
    this.recipientProfileImageUrl,
    this.roomId,
    this.team, // 追加
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  User? _user;
  VideoPlayerController? _videoController;
  List<File> _imageFiles = [];
  late final Stream<QuerySnapshot> _messageStream;
  String? _userName; // Firestore 上のユーザー名
  String? _userProfileImageUrl; // Firestore 上のプロフィール画像URL
  bool _isIconVisible = false; // アイコンの表示/非表示を制御するフラグ
  bool _isUploading = false;
  bool _isSending = false;
  bool _isMarkingRead = false; // 未読リセット中かどうかのフラグ

  Future<void> _markCurrentRoomAsRead() async {
    if (_isMarkingRead) return;
    if (_user == null) return;
    if (widget.roomId == null || widget.roomId!.isEmpty) return;

    _isMarkingRead = true;
    try {
      await _firestore.collection('chatRooms').doc(widget.roomId).update({
        'unreadCounts.${_user!.uid}': 0,
      });
    } catch (e) {
      print('⚠️ _markCurrentRoomAsRead でエラー: $e');
    } finally {
      _isMarkingRead = false;
    }
  }


  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadCurrentUserProfile();

    // チャットメッセージのストリームは一度だけ作成して使い回す
    if (widget.roomId != null && widget.roomId!.isNotEmpty) {
      _messageStream = _firestore
          .collection('chatRooms')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // roomId がない場合でも型的に初期化しておく（使われない想定）
      _messageStream = const Stream.empty();
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final data = doc.data() ?? {};

      // Firestore の name / userName を優先して使う
      final nameFromFirestore = (data['name'] as String?)?.trim();
      final userNameFromFirestore = (data['userName'] as String?)?.trim();

      String resolvedName;
      if (nameFromFirestore != null && nameFromFirestore.isNotEmpty) {
        resolvedName = nameFromFirestore;
      } else if (userNameFromFirestore != null &&
          userNameFromFirestore.isNotEmpty) {
        resolvedName = userNameFromFirestore;
      } else if (currentUser.displayName != null &&
          currentUser.displayName!.trim().isNotEmpty) {
        resolvedName = currentUser.displayName!.trim();
      } else {
        resolvedName = '匿名';
      }

      final profileImageFromFirestore =
        (data['profileImageUrl'] as String?)?.trim()
        ?? (data['profileImage'] as String?)?.trim();

      setState(() {
        _userName = resolvedName;
        _userProfileImageUrl =
            (profileImageFromFirestore != null &&
                    profileImageFromFirestore.isNotEmpty)
                ? profileImageFromFirestore
                : (currentUser.photoURL ?? '');
      });
    } catch (e) {
      print('⚠️ _loadCurrentUserProfile でエラー: $e');
      setState(() {
        _userName = (currentUser.displayName != null &&
                currentUser.displayName!.isNotEmpty)
            ? currentUser.displayName!
            : '匿名';
        _userProfileImageUrl = currentUser.photoURL ?? '';
      });
    }
  }

  Future<Map<String, String>> _resolveSenderInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {
        'name': '匿名',
        'profileImageUrl': '',
      };
    }

    // すでに _loadCurrentUserProfile で取得済みならそれを使う
    if (_userName != null && _userName!.isNotEmpty) {
      return {
        'name': _userName!,
        'profileImageUrl': _userProfileImageUrl ?? (currentUser.photoURL ?? ''),
      };
    }

    try {
      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final data = doc.data() ?? {};

      final nameFromFirestore = (data['name'] as String?)?.trim();
      final userNameFromFirestore = (data['userName'] as String?)?.trim();
      final profileImageFromFirestore =
          (data['profileImageUrl'] as String?)?.trim();

      String resolvedName;
      if (nameFromFirestore != null && nameFromFirestore.isNotEmpty) {
        resolvedName = nameFromFirestore;
      } else if (userNameFromFirestore != null &&
          userNameFromFirestore.isNotEmpty) {
        resolvedName = userNameFromFirestore;
      } else if (currentUser.displayName != null &&
          currentUser.displayName!.trim().isNotEmpty) {
        resolvedName = currentUser.displayName!.trim();
      } else {
        resolvedName = '匿名';
      }

      final resolvedProfileImageUrl =
          (profileImageFromFirestore != null &&
                  profileImageFromFirestore.isNotEmpty)
              ? profileImageFromFirestore
              : (currentUser.photoURL ?? '');

      // 解決した結果を state にキャッシュしておく
      setState(() {
        _userName = resolvedName;
        _userProfileImageUrl = resolvedProfileImageUrl;
      });

      return {
        'name': resolvedName,
        'profileImageUrl': resolvedProfileImageUrl,
      };
    } catch (e) {
      print('⚠️ _resolveSenderInfo でエラーが発生: $e');
      final fallbackName =
          (currentUser.displayName != null && currentUser.displayName!.isNotEmpty)
              ? currentUser.displayName!
              : '匿名';
      return {
        'name': fallbackName,
        'profileImageUrl': currentUser.photoURL ?? '',
      };
    }
  }

  Future<void> _sendMessage(String messageText,
      {List<String>? imageUrls, String? videoUrl}) async {
    if (_isSending) return; // 🔹 すでに送信中なら処理をスキップ

    setState(() {
      _isSending = true; // 🔹 送信開始時に `true`
    });
    if ((messageText.isNotEmpty ||
            (imageUrls != null && imageUrls.isNotEmpty) ||
            videoUrl != null) &&
        _user != null) {
      String senderId = _user!.uid; // 送信者のユーザーID

      // 🔹 送信直前に必ず Firestore の name を含めて解決する
      final senderInfo = await _resolveSenderInfo();
      final String senderName = senderInfo['name'] ?? '匿名';
      final String senderProfileImageUrl = senderInfo['profileImageUrl'] ?? '';

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference chatRoomRef = FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.roomId);
        DocumentSnapshot chatRoomSnapshot = await transaction.get(chatRoomRef);

        List<dynamic> participants = chatRoomSnapshot.exists
            ? (chatRoomSnapshot['participants'] ?? [])
            : [senderId, widget.recipientId];

        // 🔹 recipientId を取得
        String? recipientId = participants.firstWhere(
          (id) => id != senderId,
          orElse: () => null,
        );

        // ❌ recipientId が null の場合は処理を中断
        if (recipientId == null || recipientId.isEmpty) {
          print("⚠️ recipientId is null or empty, cannot proceed.");
          return;
        }

        if (!chatRoomSnapshot.exists) {
          // 🔹 チャットルームが存在しない場合、新規作成
          transaction.set(chatRoomRef, {
            'participants': participants, // 参加者リスト
            'recipientId': recipientId, // 🔹 明示的に recipientId を保存
            'createdAt': FieldValue.serverTimestamp(),
            'lastMessage': messageText.isNotEmpty
                ? messageText
                : (imageUrls != null ? '画像が送信されました' : '動画が送信されました'),
            'lastMessageAt': FieldValue.serverTimestamp(),
            'unreadCounts': {recipientId: 1}, // 相手の未読カウントを1にセット
          });
        } else {
          Map<String, dynamic>? chatRoomData =
              chatRoomSnapshot.data() as Map<String, dynamic>?;

          if (chatRoomData != null) {
            Map<String, dynamic> unreadCounts =
                chatRoomData['unreadCounts'] ?? {};
            for (var participant in participants) {
              if (participant != senderId) {
                unreadCounts[participant] =
                    (unreadCounts[participant] ?? 0) + 1;
              }
            }

            // 🔹 既存のチャットルーム情報を更新
            transaction.update(chatRoomRef, {
              'lastMessage': messageText.isNotEmpty
                  ? messageText
                  : (imageUrls != null ? '画像が送信されました' : '動画が送信されました'),
              'lastMessageAt': FieldValue.serverTimestamp(),
              'recipientId': recipientId, // 🔹 recipientId を更新
              'unreadCounts': unreadCounts,
            });
          }
        }

        // 🔹 自分の未読カウントをリセット
        transaction.update(chatRoomRef, {
          'unreadCounts.$senderId': 0,
        });

        // 🔹 メッセージを Firestore に送信
        transaction.set(chatRoomRef.collection('messages').doc(), {
          'text': messageText,
          'createdAt': FieldValue.serverTimestamp(),
          'userId': senderId,
          'userName': senderName,
          'userProfileImageUrl': senderProfileImageUrl,
          'imageUrls': imageUrls ?? [],
          'videoUrl': videoUrl ?? '',
        });
      });

      // 入力フィールドをクリア
      _messageController.clear();
      _imageFiles.clear();
    }

    setState(() {
      _isSending = false; // 🔹 送信完了後に `false`
    });
  }

  Future<void> _pickImages() async {
    final List<XFile> selectedImages = await ImagePicker().pickMultiImage();
    if (selectedImages.isNotEmpty) {
      List<File> imageFiles =
          selectedImages.map((image) => File(image.path)).toList();
      setState(() {
        // ここでは送信せず、プレビュー用に保持しておく
        _imageFiles = imageFiles;
      });
    }
  }

  Future<void> _uploadImages(List<File> imageFiles, {String messageText = ''}) async {
    List<String> imageUrls = [];
    for (File imageFile in imageFiles) {
      File compressedImage = await _compressImage(imageFile);
      String fileName =
          'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = _storage.ref().child(fileName);
      await storageRef.putFile(compressedImage);
      String downloadUrl = await storageRef.getDownloadURL();
      imageUrls.add(downloadUrl);
    }
    // テキスト付きで送信可能にする
    await _sendMessage(messageText, imageUrls: imageUrls);
  }

  Future<File> _compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image != null) {
      final compressedImage = img.copyResize(image, width: 800); // 幅800pxにリサイズ
      final compressedBytes =
          img.encodeJpg(compressedImage, quality: 70); // 圧縮率70%
      final compressedFilePath =
          imageFile.path.replaceFirst('.jpg', '_compressed.jpg');
      final compressedFile = File(compressedFilePath);
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedFile;
    } else {
      return imageFile;
    }
  }

  Future<void> _pickVideo() async {
    final XFile? videoFile =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (videoFile != null) {
      setState(() {
        _isUploading = true; // 🔹 動画アップロード開始
      });
      File file = File(videoFile.path);
      await _validateAndUploadVideo(file);
      setState(() {
        _isUploading = false; // 🔹 動画アップロード完了
      });
    }
  }

  Future<void> _validateAndUploadVideo(File videoFile) async {
    _videoController = VideoPlayerController.file(videoFile);
    await _videoController!.initialize();

    final videoDuration = _videoController!.value.duration;
    if (videoDuration.inSeconds > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('30秒以内の動画のみアップロード可能です。')),
      );
      return;
    }

    String fileName =
        'chat_videos/${DateTime.now().millisecondsSinceEpoch}.mp4';
    Reference storageRef = _storage.ref().child(fileName);
    await storageRef.putFile(videoFile);
    String downloadUrl = await storageRef.getDownloadURL();
    await _sendMessage('', videoUrl: downloadUrl);
  }

  /// **Timestamp を `MM月dd日` 形式に変換**
  String _formatDateHeader(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return "${dateTime.month}月${dateTime.day}日";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomId == null || widget.roomId!.isEmpty) {
      return const Center(child: Text('チャットルームが存在しません'));
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            if (widget.recipientId != null && widget.recipientId!.isNotEmpty) {
              showProfileDialog(
                  context, widget.recipientId!, false); // 🔹 false = ユーザープロフィール
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("相手のプロフィールを開けません")),
              );
            }
          },
          child: Text(
            widget.recipientName ?? '相手不明',
            style: const TextStyle(),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // どこか他の箇所をタップしたらキーボードを閉じる
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
          Expanded(
            child: StreamBuilder(
              stream: _messageStream,
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                // 最初のデータがまだ来ていないときだけローディングを表示
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('メッセージがありません'));
                }

                final messages = snapshot.data!.docs;

                // 🔔 この画面を開いている間は自分の未読カウントを 0 にリセット
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markCurrentRoomAsRead();
                });

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message =
                        messages[index].data() as Map<String, dynamic>;
                    bool isMe = message['userId'] == _user!.uid;
                    List<String>? imageUrls =
                        List<String>.from(message['imageUrls'] ?? []);
                    String? videoUrl = message['videoUrl'] as String?;
                    Timestamp? createdAt = message['createdAt'] as Timestamp?;

                    // 📅 **日付ヘッダーを表示するかチェック**
                    bool showDateHeader = false;
                    if (index == messages.length - 1) {
                      // **リストの最初のメッセージには必ず日付を表示**
                      showDateHeader = true;
                    } else {
                      // **直前のメッセージの日付と比較**
                      Timestamp? prevCreatedAt =
                          messages[index + 1]['createdAt'] as Timestamp?;
                      if (prevCreatedAt != null && createdAt != null) {
                        showDateHeader = _formatDateHeader(prevCreatedAt) !=
                            _formatDateHeader(createdAt);
                      }
                    }

                    // 🔹 メッセージのリアクションを取得
                    String? reaction = message['reaction'] as String?;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 📅 **日付ヘッダーを表示**
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              _formatDateHeader(createdAt!),
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),

                        // 💬 **メッセージの吹き出し**
                        _buildMessageTile(
                          message['text'] ?? '',
                          createdAt,
                          imageUrls,
                          videoUrl,
                          isMe,
                          reaction,
                          messages[index].id,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_imageFiles.isNotEmpty)
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _imageFiles.length,
                itemBuilder: (context, index) {
                  final file = _imageFiles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imageFiles.removeAt(index);
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_isUploading) // 🔹 画像・動画アップロード中のみ表示
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: CircularProgressIndicator(), // 🔹 ローディングアイコン
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), // 四角で角を丸める
                border: Border.all(color: Colors.grey), // 枠線の色
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isIconVisible ? Icons.remove : Icons.add,),
                    onPressed: () {
                      setState(() {
                        _isIconVisible = !_isIconVisible; // アイコン表示/非表示の切り替え
                      });
                    },
                  ),
                  if (_isIconVisible) // _isIconVisibleがtrueの場合のみ表示
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: () => _pickImages(),
                    ),
                  // if (_isIconVisible) // _isIconVisibleがtrueの場合のみ表示
                  //   IconButton(
                  //     icon: const Icon(Icons.videocam),
                  //     onPressed: () => _pickVideo(),
                  //   ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'メッセージを入力',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0)),
                      ),
                      maxLines: null, // メッセージが長い場合折り返し
                    ),
                  ),
                  IconButton(
                    icon: _isSending
                        ? const CircularProgressIndicator() // 送信中はローディングアイコン
                        : const Icon(Icons.send),
                    onPressed: (_isSending || _isUploading)
                        ? null
                        : () async {
                            final text = _messageController.text.trim();
                            // 何も入力も選択もない場合は何もしない
                            if (text.isEmpty && _imageFiles.isEmpty) {
                              return;
                            }

                            // 画像が選択されている場合は、テキスト＋画像をまとめて送信
                            if (_imageFiles.isNotEmpty) {
                              setState(() {
                                _isUploading = true;
                              });
                              try {
                                final files = List<File>.from(_imageFiles);
                                await _uploadImages(files, messageText: text);
                              } finally {
                                setState(() {
                                  _isUploading = false;
                                });
                              }
                            } else {
                              // テキストのみ
                              await _sendMessage(text);
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
      ),
    );
  }

  Widget _buildMessageTile(
      String messageText,
      Timestamp? createdAt,
      List<String> imageUrls,
      String? videoUrl,
      bool isMe,
      String? reaction,
      String messageId) {
    return Padding(
        padding: EdgeInsets.fromLTRB(
    10,
    5,
    10,
    (reaction != null && reaction.isNotEmpty) ? 22 : 5,
  ),
      // padding: const EdgeInsets.symmetric(
      //     vertical: 5, horizontal: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end, // 🔹 吹き出しと時間の位置を揃える
        children: [
          // ✅ 自分のメッセージ: 時間 → 吹き出し の順番
          if (isMe && createdAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 5), // 吹き出しとの余白
              child: Text(
                _formatTimestamp(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

          // 🗣️ 相手のメッセージ: プロフィールアイコンを表示
          if (!isMe)
            GestureDetector(
              onTap: () {
                if (widget.recipientId != null) {
                  showProfileDialog(context, widget.recipientId!, false);
                } else {
                  print("⚠️ recipientId is null");
                }
              },
              child: CircleAvatar(
                backgroundImage: widget.recipientProfileImageUrl != null &&
                        widget.recipientProfileImageUrl!.isNotEmpty
                    ? NetworkImage(widget.recipientProfileImageUrl!)
                    : const AssetImage('assets/default_avatar.png')
                        as ImageProvider,
              ),
            ),
          const SizedBox(width: 8), // 吹き出しとアイコン/時間の間の余白

          // 💬 メッセージの吹き出し（リアクションは外に出す）
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.green[200] : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrls.isNotEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: imageUrls.map((url) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FullScreenImagePage(imageUrl: url),
                                  ),
                                );
                              },
                              child: Image.network(url,
                                  width: 150, height: 150, fit: BoxFit.cover),
                            );
                          }).toList(),
                        ),
                      if (videoUrl != null && videoUrl.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            // 動画再生処理
                          },
                          child: const Icon(Icons.play_circle_filled, size: 50),
                        ),
                      if (messageText.isNotEmpty)
                        GestureDetector(
                          onLongPress: () async {
                            // 長押しでメニューを表示（コピー / リアクション / キャンセル）
                            final result =
                                await showModalBottomSheet<String>(
                              context: context,
                              builder: (BuildContext context) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.copy),
                                        title: const Text('コピー'),
                                        onTap: () {
                                          Navigator.pop(context, 'copy');
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.emoji_emotions),
                                        title: const Text('リアクション'),
                                        onTap: () {
                                          Navigator.pop(context, 'reaction');
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.close),
                                        title: const Text('キャンセル'),
                                        onTap: () {
                                          Navigator.pop(context, 'cancel');
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );

                            if (result == 'copy') {
                              // コピー処理
                              await Clipboard.setData(
                                ClipboardData(text: messageText),
                              );
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('メッセージをコピーしました'),
                                ),
                              );
                            } else if (result == 'reaction') {
                              // リアクション選択用のボトムシート
                              final emoji =
                                  await showModalBottomSheet<String>(
                                context: context,
                                builder: (BuildContext context) {
                                  return SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12.0,
                                              horizontal: 16.0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildReactionEmojiButton(
                                                  context, '👍'),
                                              _buildReactionEmojiButton(
                                                  context, '❤️'),
                                              _buildReactionEmojiButton(
                                                  context, '😂'),
                                              _buildReactionEmojiButton(
                                                  context, '😮'),
                                              _buildReactionEmojiButton(
                                                  context, '👏'),
                                              _buildReactionEmojiButton(
                                                  context, '🙇'),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        ListTile(
                                          leading:
                                              const Icon(Icons.remove_circle),
                                          title: const Text('リアクションを削除'),
                                          onTap: () {
                                            Navigator.pop(context, '');
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.close),
                                          title: const Text('キャンセル'),
                                          onTap: () {
                                            Navigator.pop(context, null);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );

                              if (emoji != null) {
                                // Firestore に reaction フィールドを保存（空文字なら削除扱い）
                                final messageRef = _firestore
                                    .collection('chatRooms')
                                    .doc(widget.roomId)
                                    .collection('messages')
                                    .doc(messageId);

                                if (emoji.isEmpty) {
                                  await messageRef
                                      .update({'reaction': FieldValue.delete()});
                                } else {
                                  await messageRef.update({'reaction': emoji});
                                }
                              }
                            }
                          },
                          child: Text(
                            messageText,
                            style: const TextStyle(fontSize: 16),
                            softWrap: true,
                          ),
                        ),
                    ],
                  ),
                ),

                // ✅ リアクションは吹き出しの「外（下）」に表示（吹き出しの高さは増やさない）
                if (reaction != null && reaction.isNotEmpty)
                  Positioned(
                    right: isMe ? 6 : null,
                    left: isMe ? null : 6,
                    bottom: -18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        reaction,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ✅ 相手のメッセージ: 吹き出し → 時間 の順番
          if (!isMe && createdAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 5), // 吹き出しとの余白
              child: Text(
                _formatTimestamp(createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}

String _extensionFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final path = (uri?.path ?? url).toLowerCase(); // ← ?以降を無視できる
  if (path.endsWith('.png')) return 'png';
  if (path.endsWith('.webp')) return 'webp';
  if (path.endsWith('.heic')) return 'heic';
  if (path.endsWith('.jpeg')) return 'jpeg';
  if (path.endsWith('.jpg')) return 'jpg';
  return 'jpg';
}

// 画像全画面表示ページ
class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('画像'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () async {
              try {
                final uri = Uri.parse(imageUrl);
                final response = await http.get(uri);

                if (response.statusCode == 200) {
                  final Uint8List bytes = Uint8List.fromList(response.bodyBytes);

                   final ext = _extensionFromUrl(imageUrl);
                  
                  await Gal.putImageBytes(
                    bytes,
                    name: 'bnet_${DateTime.now().millisecondsSinceEpoch}.$ext',
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('画像を保存しました')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('画像のダウンロードに失敗しました'),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('画像の保存中にエラーが発生しました'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Image.network(imageUrl),
      ),
    );
  }
}

Widget _buildReactionEmojiButton(BuildContext context, String emoji) {
  return InkWell(
    onTap: () {
      Navigator.pop(context, emoji);
    },
    child: Text(
      emoji,
      style: const TextStyle(fontSize: 28),
    ),
  );
}