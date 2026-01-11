import 'package:b_net/home_page.dart';
import 'package:b_net/login/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // 日付フォーマット用
import 'package:image/image.dart' as img;
import 'package:flutter/cupertino.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _passwordVisible = false; // パスワード表示/非表示切り替え用
  DateTime? _selectedDate; // 生年月日（任意）
  File? _profileImage;
  bool _isLoading = false;
  final List<String> _positions = [
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
  final List<String> _selectedPositions = [];
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

    Future<void> _setupFcmForNewUser(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // iOS向けの通知権限リクエスト（Androidは基本的に不要だが呼んでも問題なし）
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
        print('✅ FCM token saved for user $uid: $token');
      } else {
        print('⚠️ FCM token is null or empty for user $uid');
      }
    } catch (e) {
      print('⚠️ Error setting up FCM for new user $uid: $e');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // 画像を読み込んで圧縮
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ja'), // カレンダーを日本語に設定
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate() && _selectedPositions.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Firebase Authでユーザーを作成
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        String? downloadUrl;
        if (_profileImage != null) {
          try {
            String fileName = '${userCredential.user!.uid}_profile.jpg';
            print('Uploading to: profile_images/$fileName');

            UploadTask uploadTask = FirebaseStorage.instance
                .ref()
                .child('profile_images/$fileName')
                .putFile(_profileImage!);

            TaskSnapshot snapshot = await uploadTask;
            downloadUrl = await snapshot.ref.getDownloadURL();
            print('Download URL: $downloadUrl');
          } catch (e) {
            print('Upload error: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('画像のアップロード中にエラーが発生しました: $e')),
            );
          }
        }

        // Firestore にユーザー情報を保存
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': _nameController.text,
          'positions': _selectedPositions,
          'profileImage': downloadUrl ?? '', // 画像がない場合は空文字を保存
          'birthday': _selectedDate, // 生年月日が選択されている場合のみ保存
          'prefecture': _selectedPrefecture,
          'createdAt': Timestamp.now(),
        });

        await _setupFcmForNewUser(userCredential.user!.uid);

        try {
  // ✅ Firebase UID を RevenueCat の appUserID として固定（user: プレフィックスを付ける）
  await Purchases.logIn('user:${userCredential.user!.uid}');
  print('✅ RevenueCat: logIn 完了 (user:${userCredential.user!.uid})');
} catch (e) {
  print('⚠️ RevenueCat logIn failed: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アカウント作成に成功しました')),
        );

        if (mounted) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final positions = List<String>.from(data['positions'] ?? []);
          final teams = List<String>.from(data['teams'] ?? []);
          final prefecture = data['prefecture'] ?? '未設定';

          return HomePage(
            userUid: userCredential.user!.uid,
            isTeamAccount: false,
            accountId: userCredential.user!.uid,
            accountName: userCredential.user!.displayName ?? '匿名',
            userPrefecture: prefecture,
            userPosition: positions,
            userTeamId: teams.isNotEmpty ? teams.first : null,
          );
        },
      ),
    ),
    (route) => false,
  );
}
      } on FirebaseAuthException catch (e) {
        String message = '';
        if (e.code == 'weak-password') {
          message = 'パスワードが短すぎます';
        } else if (e.code == 'email-already-in-use') {
          message = 'このメールアドレスは既に使用されています';
        } else {
          message = 'エラーが発生しました: ${e.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全ての必須項目を入力してください')),
      );
    }
  }

  void _showCupertinoPrefecturePicker(BuildContext context) {
    FocusScope.of(context).requestFocus(FocusNode());

    final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // 少し遅らせてからモーダルを開く
    Future.delayed(const Duration(milliseconds: 100), () {
      int tempIndex =
          _prefectures.indexOf(_selectedPrefecture ?? _prefectures[0]);

      if (isTablet) {
        // ✅ iPad: ボトムシートではなく中央ダイアログで表示（見やすい）
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext dialogContext) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('キャンセル',
                                style: TextStyle(fontSize: 16)),
                          ),
                          const Text(
                            '都道府県を選択',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedPrefecture = _prefectures[tempIndex];
                              });
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('決定',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.blue)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 320,
                      child: CupertinoPicker(
                        backgroundColor: Colors.white,
                        itemExtent: 44.0,
                        scrollController:
                            FixedExtentScrollController(initialItem: tempIndex),
                        onSelectedItemChanged: (int index) {
                          tempIndex = index;
                        },
                        children: _prefectures.map((p) {
                          return Center(
                            child:
                                Text(p, style: const TextStyle(fontSize: 22)),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }

      // ✅ SP: いままで通りボトムシート
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        builder: (BuildContext context) {
          return SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('キャンセル', style: TextStyle(fontSize: 16)),
                      ),
                      const Text('都道府県を選択',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        title: const Text('アカウント作成'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          final horizontalPadding = isTablet ? 24.0 : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // iPad などで横に広がりすぎないように制限
                maxWidth: isTablet ? 560 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16.0,
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                // ログインページへの遷移ボタン
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: const Text('アカウントをお持ちならこちら'),
                ),
                // プロフィール画像
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: isTablet ? 64 : 50,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : const AssetImage('assets/default_avatar.png')
                                as ImageProvider,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 名前フィールド + 都道府県（iPadは2カラム、SPは縦並び）
                if (isTablet)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: '名前'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '名前を入力してください';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _showCupertinoPrefecturePicker(context);
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: '都道府県',
                                border: UnderlineInputBorder(),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.black54,
                                ),
                              ),
                              controller: TextEditingController(
                                text: _selectedPrefecture ?? '選択してください',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '名前'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '名前を入力してください';
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
                              Icon(Icons.arrow_drop_down, color: Colors.black54),
                        ),
                        controller: TextEditingController(
                          text: _selectedPrefecture ?? '選択してください',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // 生年月日選択（任意）
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? '生年月日を選択してください'
                            : '生年月日: ${DateFormat('yyyy年MM月dd日').format(_selectedDate!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('生年月日選択'),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                // ポジション選択
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ポジションを選択(複数選択可)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5.0, // チップ間の幅を追加
                  runSpacing: 5.0, // チップ間の縦幅を追加
                  children: _positions.map((String position) {
                    return ChoiceChip(
                      label: Text(position),
                      selected: _selectedPositions.contains(position),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (position == '監督' || position == 'マネージャー') {
                              // 監督またはマネージャーを選んだ場合、それ以外をすべて除外
                              _selectedPositions
                                ..clear()
                                ..add(position);
                            } else {
                              // 監督またはマネージャーが既に選ばれていたら無視
                              if (_selectedPositions.contains('監督') ||
                                  _selectedPositions.contains('マネージャー')) {
                                return;
                              }
                              _selectedPositions.add(position);
                            }
                          } else {
                            _selectedPositions.remove(position);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // 選択されたポジションを表示
                if (_selectedPositions.isNotEmpty)
                  Text(
                    '選択されたポジション: ${_selectedPositions.join(', ')}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                const Divider(),
                const SizedBox(height: 16),
                // メールアドレスフィールド
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'メールアドレスを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // パスワードフィールド
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    helperText: '6文字以上',
                    suffixIcon: IconButton(
                      icon: Icon(_passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) {
                      return 'パスワードを入力してください';
                    }
                    if (v.length < 6) {
                      return 'パスワードは6文字以上にしてください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _signUp,
                        child: const Text('アカウント作成'),
                      ),
                      const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
