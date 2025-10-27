import 'package:flutter/material.dart';

class NoticeDetailPage extends StatelessWidget {
  final String title;
  final String content;
  final String date;
  final bool isImportant;
  final List<String> prefectures; // 🔹 選択した都道府県を追加

  const NoticeDetailPage({
    super.key,
    required this.title,
    required this.content,
    required this.date,
    this.isImportant = false,
    this.prefectures = const [], // 🔹 初期値は空のリスト
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("お知らせの詳細")), // 🔹 タイトルをAppBarから削除
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 日付（薄い文字で左上）
            Text(
              date,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),

            // 🔹 重要ラベルと都道府県を横並び
            Row(
              children: [
                if (isImportant)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "重要",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (isImportant && prefectures.isNotEmpty)
                  const SizedBox(width: 8), // 🔹 スペースを追加

                // 🔹 都道府県（薄い文字で表示）
                if (prefectures.isNotEmpty)
                  Expanded(
                    child: Text(
                      prefectures.join(" , "), // 🔹 都道府県を「/」区切りで表示
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 🔹 タイトル（中央寄せ）
            Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // 🔹 本文
            Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
