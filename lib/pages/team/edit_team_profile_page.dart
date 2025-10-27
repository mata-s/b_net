import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class EditTeamProfilePage extends StatefulWidget {
  final String teamId;

  const EditTeamProfilePage({super.key, required this.teamId});

  @override
  _EditTeamProfilePageState createState() => _EditTeamProfilePageState();
}

class _EditTeamProfilePageState extends State<EditTeamProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _teamDescriptionController =
      TextEditingController();
  final TextEditingController _achievementController = TextEditingController();

  List<String> _achievements = [];
  String? _selectedPrefecture;
  File? _profileImage;
  String? _profileImageUrl;
  bool _isLoading = false;

  // 日本の都道府県リスト
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

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    try {
      DocumentSnapshot teamSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();

      if (teamSnapshot.exists) {
        Map<String, dynamic> teamData =
            teamSnapshot.data() as Map<String, dynamic>;

        setState(() {
          _teamNameController.text = teamData['teamName'];
          _teamDescriptionController.text = teamData['teamDescription'];
          _selectedPrefecture = teamData['prefecture'];
          _achievements = List<String>.from(teamData['achievements']);
          _profileImageUrl = teamData['profileImage'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File originalImage = File(pickedFile.path);
      img.Image? image = img.decodeImage(originalImage.readAsBytesSync());

      if (image != null) {
        img.Image resizedImage =
            img.copyResize(image, width: 600); // 幅を600pxにリサイズ
        File compressedImage = File(pickedFile.path)
          ..writeAsBytesSync(
              img.encodeJpg(resizedImage, quality: 85)); // 圧縮して保存

        setState(() {
          _profileImage = compressedImage;
        });
      }
    }
  }

  Future<void> _updateTeamProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? imageUrl;
        if (_profileImage != null) {
          String fileName =
              '${FirebaseAuth.instance.currentUser!.uid}_team_profile.jpg';
          UploadTask uploadTask = FirebaseStorage.instance
              .ref()
              .child('team_images/$fileName')
              .putFile(_profileImage!);

          TaskSnapshot snapshot = await uploadTask;
          imageUrl = await snapshot.ref.getDownloadURL();
        }

        await FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.teamId)
            .update({
          'teamName': _teamNameController.text,
          'teamDescription': _teamDescriptionController.text,
          'prefecture': _selectedPrefecture,
          'achievements': _achievements,
          if (imageUrl != null) 'profileImage': imageUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チームプロフィールが更新されました')),
        );

        Navigator.of(context).pop(); // プロフィールページに戻る
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新中にエラーが発生しました: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
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
        title: const Text('チームプロフィール編集'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (_profileImageUrl != null &&
                                    _profileImageUrl!.isNotEmpty
                                ? NetworkImage(
                                    _profileImageUrl!) // ✅ Firestore の画像を適用
                                : const AssetImage(
                                        'assets/default_team_avatar.png')
                                    as ImageProvider),
                      ),
                      const Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _teamNameController,
                  decoration: const InputDecoration(labelText: 'チーム名'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'チーム名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    _showCupertinoPrefecturePicker(context);
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: '都道府県',
                        border: UnderlineInputBorder(),
                        suffixIcon:
                            Icon(Icons.arrow_drop_down), // 🔽 右側に下矢印アイコン追加
                      ),
                      controller: TextEditingController(
                        text: _selectedPrefecture ?? '選択してください',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('実績',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _achievements.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: ListTile(
                        title: Text(_achievements[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _achievements.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
                TextFormField(
                  controller: _achievementController,
                  decoration: InputDecoration(
                    labelText: '実績を追加',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (_achievementController.text.isNotEmpty) {
                          setState(() {
                            _achievements.add(_achievementController.text);
                            _achievementController.clear();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _teamDescriptionController,
                  decoration: const InputDecoration(labelText: 'チーム紹介文'),
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _updateTeamProfile,
                        child: const Text('更新する'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamDescriptionController.dispose();
    _achievementController.dispose();
    super.dispose();
  }
}
