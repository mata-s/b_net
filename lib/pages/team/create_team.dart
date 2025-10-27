import 'package:b_net/pages/team/team_home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:purchases_flutter/purchases_flutter.dart';

class CreateTeamAccountPage extends StatefulWidget {
  final String userUid;
  final String accountName;
  final String userPrefecture;
  final List<String> userPosition;
  final String? userTeamId;

  const CreateTeamAccountPage({
    super.key,
    required this.userUid,
    required this.accountName,
    required this.userPrefecture,
    required this.userPosition,
    this.userTeamId,
  });

  @override
  _CreateTeamAccountPageState createState() => _CreateTeamAccountPageState();
}

class _CreateTeamAccountPageState extends State<CreateTeamAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _teamDescriptionController =
      TextEditingController();
  final TextEditingController _startYearController = TextEditingController();
  final TextEditingController _achievementController = TextEditingController();
  final TextEditingController _prefectureController = TextEditingController();

  final List<String> _achievements = []; // 実績のリスト
  File? _profileImage;
  bool _isLoading = false;

  String? _selectedPrefecture;

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

          return Container(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child:
                            const Text('キャンセル', style: TextStyle(fontSize: 16)),
                      ),
                      const Text('都道府県を選択',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedPrefecture = _prefectures[tempIndex];
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('決定',
                            style: TextStyle(fontSize: 16, color: Colors.blue)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: CupertinoPicker(
                    backgroundColor: Colors.white,
                    itemExtent: 40.0,
                    scrollController:
                        FixedExtentScrollController(initialItem: tempIndex),
                    onSelectedItemChanged: (int index) {
                      tempIndex = index;
                    },
                    children: _prefectures.map((p) {
                      return Center(
                        child: Text(p, style: const TextStyle(fontSize: 22)),
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
        title: const Text('チームアカウントを作成'),
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
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : const AssetImage('assets/default_team_avatar.png')
                            as ImageProvider,
                    child: _profileImage == null
                        ? const Icon(Icons.camera_alt, size: 50)
                        : null,
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
                    FocusScope.of(context).unfocus();
                    _showCupertinoPrefecturePicker(context);
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: '都道府県', // ラベル
                        border: const UnderlineInputBorder(), // 下線のみ
                        suffixIcon: const Icon(Icons.arrow_drop_down,
                            color: Colors.black54), // 🔹 右に下矢印アイコン
                      ),
                      controller: TextEditingController(
                        text: _selectedPrefecture ?? '選択してください',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _startYearController,
                  decoration: const InputDecoration(labelText: '活動開始'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '活動開始を入力してください';
                    }
                    return null;
                  },
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
                    suffixIcon: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        backgroundColor: Colors.blue,
                        minimumSize: Size(10, 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        if (_achievementController.text.isNotEmpty) {
                          setState(() {
                            _achievements.add(_achievementController.text);
                            _achievementController.clear();
                          });
                        }
                      },
                      child: const Text(
                        '追加',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _teamDescriptionController,
                  decoration: const InputDecoration(labelText: 'チーム紹介文'),
                  maxLines: 5,
                  // 紹介文のバリデーションは不要なので削除
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _createTeamAccount,
                        child: const Text('作成する'),
                      ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
          ? Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
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

  Future<void> _createTeamAccount() async {
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

        DocumentReference teamRef =
            await FirebaseFirestore.instance.collection('teams').add({
          'teamName': _teamNameController.text,
          'teamDescription': _teamDescriptionController.text.isNotEmpty
              ? _teamDescriptionController.text
              : '', // 紹介文が空の場合は空文字を設定
          'prefecture': _selectedPrefecture ?? '',
          'startYear': int.parse(_startYearController.text),
          'achievements':
              _achievements.isNotEmpty ? _achievements : [], // 実績がない場合は空のリスト
          'profileImage': imageUrl,
          'createdAt': Timestamp.now(),
          'createdBy': FirebaseAuth.instance.currentUser!.uid,
          'members': [FirebaseAuth.instance.currentUser!.uid],
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'teams': FieldValue.arrayUnion([teamRef.id]),
        });

        try {
          await Purchases.logOut();
          await Purchases.logIn(teamRef.id);
          print('✅ RevenueCat: チームIDでログイン完了 (${teamRef.id})');
        } catch (e) {
          print('⚠️ RevenueCatログインに失敗: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チームアカウントが作成されました')),
        );

        final createdTeam = {
          'teamId': teamRef.id,
          'teamName': _teamNameController.text,
          'profileImage': imageUrl,
          'prefecture': _selectedPrefecture,
          'startYear': int.parse(_startYearController.text),
          'achievements': _achievements,
          'teamDescription': _teamDescriptionController.text,
        };

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TeamHomePage(
              team: createdTeam, // ✅ ここが追加
              isTeamAccount: true,
              accountId: teamRef.id,
              accountName: _teamNameController.text,
              userUid: widget.userUid,
              userPrefecture: widget.userPrefecture,
              userPosition: widget.userPosition,
              userTeamId: widget.userTeamId,
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamDescriptionController.dispose();
    _startYearController.dispose();
    _achievementController.dispose();
    _prefectureController.dispose();
    super.dispose();
  }
}
