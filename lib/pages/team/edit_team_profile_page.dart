import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

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
    '沖縄県',
  ];

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    try {
      final teamSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();

      if (teamSnapshot.exists) {
        final teamData = teamSnapshot.data() as Map<String, dynamic>;

        setState(() {
          _teamNameController.text = teamData['teamName'] ?? '';
          _teamDescriptionController.text =
              teamData['teamDescription'] ?? '';
          _selectedPrefecture = teamData['prefecture'];
          _achievements = List<String>.from(
            teamData['achievements'] ?? <String>[],
          );
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
      final originalImage = File(pickedFile.path);
      final image = img.decodeImage(originalImage.readAsBytesSync());

      if (image != null) {
        final resizedImage = img.copyResize(image, width: 600);
        final compressedImage = File(pickedFile.path)
          ..writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));

        setState(() {
          _profileImage = compressedImage;
        });
      }
    }
  }

  Future<void> _updateTeamProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPrefecture == null || _selectedPrefecture!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('都道府県を選択してください')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      if (_profileImage != null) {
        final fileName =
            '${FirebaseAuth.instance.currentUser!.uid}_team_profile.jpg';
        final uploadTask = FirebaseStorage.instance
            .ref()
            .child('team_images/$fileName')
            .putFile(_profileImage!);

        final snapshot = await uploadTask;
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
        'profileImage': imageUrl ?? _profileImageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チームプロフィールが更新されました')),
      );

      Navigator.of(context).pop();
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

  void _showCupertinoPrefecturePicker(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());

    // 少し遅らせてからモーダルを開く
    Future.delayed(const Duration(milliseconds: 100), () {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        builder: (BuildContext context) {
          int tempIndex =
              _prefectures.indexOf(_selectedPrefecture ?? _prefectures[0]);

          return SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'キャンセル',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const Text(
                        '都道府県を選択',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedPrefecture = _prefectures[tempIndex];
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          '決定',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    backgroundColor: Colors.white,
                    itemExtent: 40.0,
                    scrollController: FixedExtentScrollController(
                      initialItem: tempIndex,
                    ),
                    onSelectedItemChanged: (int index) {
                      tempIndex = index;
                    },
                    children: _prefectures.map((p) {
                      return Center(
                        child: Text(
                          p,
                          style: const TextStyle(fontSize: 22),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
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
                                ? NetworkImage(_profileImageUrl!)
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
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_profileImage != null ||
                    (_profileImageUrl != null &&
                        _profileImageUrl!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _profileImage = null;
                          _profileImageUrl = '';
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.grey,
                      ),
                      label: const Text(
                        '写真を削除',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
                        suffixIcon: Icon(Icons.arrow_drop_down),
                      ),
                      controller: TextEditingController(
                        text: _selectedPrefecture ?? '選択してください',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '実績',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: 44,
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: const Text(
                        '完了',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
