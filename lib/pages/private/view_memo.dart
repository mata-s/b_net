import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewMemoPage extends StatelessWidget {
  final String userUid;
  final List<String> userPosition;
  final Map<String, dynamic> memoData;

  const ViewMemoPage({
    required this.userUid,
    required this.userPosition,
    required this.memoData,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('メモ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '日付: ${memoData['date'] != null ? (memoData['date'] as Timestamp).toDate().toString().split(' ')[0] : '未設定'}',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('場所: ${memoData['location'] ?? '未設定'}',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('対戦相手: ${memoData['opponent'] ?? '未設定'}',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('点数: ${memoData['score'] ?? '未設定'}',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('勝敗: ${memoData['result'] ?? '未設定'}',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('メモ:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(memoData['memo'] ?? 'メモなし', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
