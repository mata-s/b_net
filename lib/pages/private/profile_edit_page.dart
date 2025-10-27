import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ProfileEditPage extends StatefulWidget {
  final String userUid;
  final String userName;
  final String profileImageUrl;
  final List<String> positions;
  final String? prefecture; // 既存の都道府県を受け取るためのフィールド
  final String? bio;

  const ProfileEditPage({
    super.key,
    required this.userUid,
    required this.userName,
    required this.profileImageUrl,
    required this.positions,
    this.prefecture, // 既存の都道府県を受け取る
    this.bio,
  });

  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _profileImageFile;
  String? _profileImageUrl;
  List<String> _selectedPositions = [];
  final List<String> _availablePositions = [
    '監督',
    'マネージャー',
    '投手',
    '捕手',
    '一塁手',
    '二塁手',
    '三塁手',
    '遊撃手',
    '左翼手',
    '中堅手',
    '右翼手'
  ];
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
  String? _selectedPrefecture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userName;
    _profileImageUrl = widget.profileImageUrl;
    _selectedPositions = List<String>.from(widget.positions);
    _selectedPrefecture = widget.prefecture; // 既存の都道府県を初期値にセット
    _bioController.text = widget.bio ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File originalFile = File(pickedFile.path);

      // 画像を読み込み
      img.Image? image = img.decodeImage(originalFile.readAsBytesSync());

      if (image != null) {
        // 画像を圧縮（例えば幅を600pxにリサイズ）
        img.Image resizedImage = img.copyResize(image, width: 600);

        // 圧縮された画像をファイルとして保存
        File compressedFile = File(pickedFile.path)
          ..writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));

        setState(() {
          _profileImageFile = compressedFile;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true; // 🔹 ローディング開始
    });

    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final FirebaseStorage storage = FirebaseStorage.instance;

    final user = auth.currentUser;
    if (user != null) {
      String? imageUrl;

      try {
        // プロフィール画像が選択されていればアップロード
        if (_profileImageFile != null) {
          final storageRef =
              storage.ref().child('profile_images/${user.uid}.jpg');
          await storageRef.putFile(_profileImageFile!);
          imageUrl = await storageRef.getDownloadURL();
        }

        // Firestoreに名前と画像URLとポジション、都道府県を保存
        await firestore.collection('users').doc(user.uid).set({
          'name': _nameController.text,
          'profileImage': imageUrl ?? _profileImageUrl, // 新しい画像がなければ既存の画像URLを使用
          'positions': _selectedPositions,
          'prefecture': _selectedPrefecture,
          'include': _bioController.text,
        }, SetOptions(merge: true));

        // 保存が成功したら、プロフィールページに戻る
        Navigator.pop(context, true); // true を渡してプロフィールページに戻る
      } catch (e) {
        print('Upload error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プロフィールの更新中にエラーが発生しました: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false; // 🔹 ローディング終了
        });
      }
    }
  }

  void _showCupertinoPrefecturePicker(BuildContext context) {
    int initialIndex = _selectedPrefecture != null
        ? _prefectures.indexOf(_selectedPrefecture!)
        : 0;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          height: 300,
          child: CupertinoPicker(
            backgroundColor: Colors.white,
            itemExtent: 40.0,
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex,
            ),
            onSelectedItemChanged: (int index) {},
            children: _prefectures.map((prefecture) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPrefecture = prefecture;
                  });
                  Navigator.pop(context);
                },
                child: Center(
                  child: Text(
                    prefecture,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImageFile != null
                    ? FileImage(_profileImageFile!)
                    : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                        ? NetworkImage(_profileImageUrl!)
                        : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                child: _profileImageFile == null
                    ? const Icon(Icons.camera_alt, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名前'),
            ),
            const SizedBox(height: 20),
            // 都道府県選択
            GestureDetector(
              onTap: () {
                _showCupertinoPrefecturePicker(context);
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: '都道府県',
                    border: UnderlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down), // 🔽 右側に下矢印アイコン追加
                  ),
                  controller: TextEditingController(
                    text: _selectedPrefecture ?? '選択してください',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 🔹 自己紹介フィールド追加
            TextField(
              controller: _bioController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '自己紹介',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ポジションを選択(複数選択可)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5.0,
              runSpacing: 5.0,
              children: _availablePositions.map((String position) {
                return ChoiceChip(
                  label: Text(position),
                  selected: _selectedPositions.contains(position),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPositions.add(position);
                      } else {
                        _selectedPositions.remove(position);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile, // 🔹 ローディング中は押せない
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white, // 🔹 ボタン内のインジケーターを白に
                        strokeWidth: 3,
                      ),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
