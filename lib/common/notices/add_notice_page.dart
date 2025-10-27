import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class AddNoticePage extends StatefulWidget {
  const AddNoticePage({super.key});

  @override
  _AddNoticePageState createState() => _AddNoticePageState();
}

class _AddNoticePageState extends State<AddNoticePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isImportant = false;
  List<String> _selectedPrefectures = [];

  final List<String> _prefectures = [
    '北海道',
    '青森県',
    '岩手県',
    '宮城県',
    '秋田県',
    '山形県',
    '福島県',
    '茨城県',
    '栃木県',
    '群馬県',
    '埼玉県',
    '千葉県',
    '東京都',
    '神奈川県',
    '新潟県',
    '富山県',
    '石川県',
    '福井県',
    '山梨県',
    '長野県',
    '岐阜県',
    '静岡県',
    '愛知県',
    '三重県',
    '滋賀県',
    '京都府',
    '大阪府',
    '兵庫県',
    '奈良県',
    '和歌山県',
    '鳥取県',
    '島根県',
    '岡山県',
    '広島県',
    '山口県',
    '徳島県',
    '香川県',
    '愛媛県',
    '高知県',
    '福岡県',
    '佐賀県',
    '長崎県',
    '熊本県',
    '大分県',
    '宮崎県',
    '鹿児島県',
    '沖縄県'
  ];

  /// **都道府県選択ダイアログ**
  void _showPrefecturePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  const Text('都道府県を選択',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView(
                      children: _prefectures.map((prefecture) {
                        return CheckboxListTile(
                          title: Text(prefecture),
                          value: _selectedPrefectures.contains(prefecture),
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                _selectedPrefectures.add(prefecture);
                              } else {
                                _selectedPrefectures.remove(prefecture);
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('確定'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// **Firestoreに保存**
  Future<void> _saveNotice() async {
    await FirebaseFirestore.instance.collection('announcements').add({
      'title': _titleController.text,
      'content': _contentController.text,
      'isImportant': _isImportant,
      'prefectures': _selectedPrefectures,
      'timestamp': FieldValue.serverTimestamp(),
    });
    Navigator.pop(context);
  }

  /// **URLをタップすると開く**
  Future<void> _onOpenLink(LinkableElement link) async {
    if (await canLaunchUrl(Uri.parse(link.url))) {
      await launchUrl(Uri.parse(link.url),
          mode: LaunchMode.externalApplication);
    } else {
      debugPrint("シミュレーターでは開けません: ${link.url}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('お知らせを追加')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'タイトル'),
              ),
              const SizedBox(height: 10),
              Container(
                height: 300, // 📌 内容エリアを大きくする
                child: TextField(
                  controller: _contentController,
                  maxLines: null, // 📌 自動で行を増やす
                  expands: true, // 📌 コンテナのサイズに合わせる
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: '内容（URLは自動リンク）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('重要'),
                value: _isImportant,
                onChanged: (val) => setState(() => _isImportant = val ?? false),
              ),
              const SizedBox(height: 10),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _showPrefecturePicker,
                  icon: const Icon(Icons.location_on),
                  label: const Text("都道府県を選択"),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                children: _selectedPrefectures
                    .map((pref) => Chip(label: Text(pref)))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _saveNotice,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
