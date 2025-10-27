// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:b_net/common/chat_screen.dart';

// /// **チャットルームを開始する共通関数**
// Future<void> startChatRoom({
//   required BuildContext context,
//   required String recipientId,
//   required String recipientName,
//   required bool isTeamAccount,
//   required String userUid,
//   required String userName,
//   required String teamId,
//   required String teamName,
// }) async {
//   User? currentUser = FirebaseAuth.instance.currentUser;
//   if (currentUser == null) {
//     print('ログインしていないユーザーです');
//     return;
//   }

//   String roomId = '';

//   // チームアカウントか個人アカウントかに応じて送信者のIDを設定
//   String senderId = isTeamAccount ? teamId : userUid;
//   String senderName = isTeamAccount ? teamName : userName;
//   String senderProfileImageUrl = isTeamAccount ? '' : currentUser.photoURL ?? ''; // チームのプロフィール画像が必要なら適宜変更

//   // チャットルームが既に存在するか確認
//   QuerySnapshot chatRoomSnapshot = await FirebaseFirestore.instance
//       .collection('chatRooms')
//       .where('participants', arrayContains: senderId) // チームIDまたは個人IDで検索
//       .get();

//   QueryDocumentSnapshot? chatRoom;
//   for (var doc in chatRoomSnapshot.docs) {
//     if ((doc['participants'] as List).contains(recipientId)) {
//       chatRoom = doc;
//       break;
//     }
//   }

//   if (chatRoom != null) {
//     roomId = chatRoom.id;
//   } else {
//     // チャットルームを新規作成
//     DocumentReference newChatRoom = await FirebaseFirestore.instance.collection('chatRooms').add({
//       'participants': [senderId, recipientId], // チームIDまたは個人IDをparticipantsに保存
//       'createdAt': FieldValue.serverTimestamp(),
//       'recipientName': recipientName,  // 相手の名前を保存
//       'recipientProfileImageUrl': '',  // 相手のプロフィール画像を保存（必要に応じて更新）
//       'senderName': senderName,  // 自分の名前を保存
//       'senderProfileImageUrl': senderProfileImageUrl,  // 自分のプロフィール画像を保存
//     });
//     roomId = newChatRoom.id;
//   }

//   // チャット画面に遷移
//   if (roomId.isNotEmpty && recipientId.isNotEmpty) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => ChatScreen(
//           recipientId: recipientId,
//           recipientName: recipientName,
//           recipientProfileImageUrl: '', // 相手のプロフィール画像を渡す（必要なら）
//           roomId: roomId,
//           isTeamAccount: isTeamAccount,
//         ),
//       ),
//     );
//   } else {
//     print('roomId または recipientId が空です');
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:b_net/common/chat_screen.dart';

/// **チャットルームを開始する共通関数**
Future<void> startChatRoom({
  required BuildContext context,
  required String recipientId,
  required String recipientName,
  required String userUid,
  required String userName,
}) async {
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    print('⚠️ ログインしていないユーザーです');
    return;
  }

  String roomId = '';
  String senderId = userUid; // 🔹 送信者のID
  String senderName = userName; // 🔹 送信者の名前

  // **チャットルームが既に存在するか確認**
  QuerySnapshot chatRoomSnapshot = await FirebaseFirestore.instance
      .collection('chatRooms')
      .where('participants', arrayContains: senderId)
      .get();

  QueryDocumentSnapshot? chatRoom;
  for (var doc in chatRoomSnapshot.docs) {
    if ((doc['participants'] as List).contains(recipientId)) {
      chatRoom = doc;
      break;
    }
  }

  if (chatRoom != null) {
    roomId = chatRoom.id;
  } else {
    // **新しいチャットルームを作成**
    DocumentReference newChatRoom =
        await FirebaseFirestore.instance.collection('chatRooms').add({
      'participants': [senderId, recipientId], // 🔹 参加者リスト
      'createdAt': FieldValue.serverTimestamp(),
      'recipientName': recipientName,
      'senderName': senderName,
    });
    roomId = newChatRoom.id;
  }

  // **チャット画面に遷移（プロフィール画像は `ChatScreen` 内で取得）**
  if (roomId.isNotEmpty && recipientId.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientId: recipientId,
          recipientName: recipientName,
          roomId: roomId,
        ),
      ),
    );
  } else {
    print('⚠️ roomId または recipientId が空です');
  }
}
