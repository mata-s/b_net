import 'package:b_net/pages/private/manager/manager_game_input_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerGemePage extends StatefulWidget {
  final String userUid;
  final String teamId;

  const ManagerGemePage({
    super.key,
    required this.userUid,
    required this.teamId,
  });

  @override
  State<ManagerGemePage> createState() => _ManagerGemePageState();
}

class _ManagerGemePageState extends State<ManagerGemePage> {
  // Map to store tentative document IDs for each user
  Map<String, String> tentativeDocIds = {};

  /// Save tentative game data for a user for today, for the given match index.
  Future<void> saveTentativeGameData(
      String uid, Map<String, dynamic> gameData, int matchIndex) async {
    final now = Timestamp.now();
    final todayStart =
        DateTime(now.toDate().year, now.toDate().month, now.toDate().day);
    final tentativeCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tentative');

    final snapshot = await tentativeCollection.get();

    Map<String, dynamic> data = {};
    bool foundTodayDoc = false;

    for (var doc in snapshot.docs) {
      final createdAt = (doc.data())['createdAt'];
      if (createdAt != null && createdAt is Timestamp) {
        final createdAtDate = createdAt.toDate();
        final createdStart = DateTime(
            createdAtDate.year, createdAtDate.month, createdAtDate.day);
        if (createdStart == todayStart) {
          data = doc.data();
          foundTodayDoc = true;
          break;
        }
      }
    }

    if (!foundTodayDoc) {
      final docRef = tentativeCollection.doc();
      List<Map<String, dynamic>> games = [];
      for (int i = 0; i < matchIndex; i++) {
        games.add({});
      }
      games.add(gameData);

      await docRef.set({
        'createdAt': Timestamp.fromDate(todayStart),
        'data': {
          'games': games,
        },
        'numberOfMatches': games.length,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final docRef = snapshot.docs.firstWhere((doc) {
        final createdAt = doc.data()['createdAt'];
        if (createdAt is Timestamp) {
          final createdAtDate = createdAt.toDate();
          final createdStart = DateTime(
              createdAtDate.year, createdAtDate.month, createdAtDate.day);
          return createdStart == todayStart;
        }
        return false;
      }).reference;
      final existingData = Map<String, dynamic>.from(data['data'] ?? {});
      final List<dynamic> rawGames = existingData['games'] is List
          ? List<dynamic>.from(existingData['games'])
          : [];

      while (rawGames.length <= matchIndex) {
        rawGames.add({});
      }
      // Merge-based update: preserve existing values, overwrite only passed fields
      Map<String, dynamic> mergedGame = {};
      if (rawGames[matchIndex] is Map<String, dynamic>) {
        mergedGame = Map<String, dynamic>.from(rawGames[matchIndex]);
      }
      mergedGame.addAll(gameData);
      rawGames[matchIndex] = mergedGame;

      await docRef.update({
        'data': {'games': rawGames},
        'numberOfMatches': rawGames.length,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  final List<TextEditingController> _opponentControllers = [];
  final List<TextEditingController> _locationControllers = [];
  final List<String> _matchTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTentativeData();
    _addMatchForm(); // 初期フォーム1件
  }

  Future<void> _loadTentativeData() async {
    final now = Timestamp.now();
    final todayStart =
        DateTime(now.toDate().year, now.toDate().month, now.toDate().day);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('tentative')
        .get();

    for (var doc in snapshot.docs) {
      final createdAt = doc.data()['createdAt'];
      if (createdAt != null && createdAt is Timestamp) {
        final createdAtDate = createdAt.toDate();
        final createdStart = DateTime(
            createdAtDate.year, createdAtDate.month, createdAtDate.day);
        if (createdStart == todayStart) {
          final data = doc.data();
          final games = data['data']?['games'];
          if (games is List) {
            setState(() {
              _opponentControllers.clear();
              _locationControllers.clear();
              _matchTypes.clear();

              for (final game in games) {
                _opponentControllers
                    .add(TextEditingController(text: game['opponent'] ?? ''));
                _locationControllers
                    .add(TextEditingController(text: game['location'] ?? ''));
                _matchTypes.add(game['gameType'] ?? '練習試合');
              }
            });
          }
          break;
        }
      }
    }
  }

  void _addMatchForm() {
    setState(() {
      _opponentControllers.add(TextEditingController());
      _locationControllers.add(TextEditingController());
      _matchTypes.add('練習試合');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('試合情報入力'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        for (int i = 0; i < _opponentControllers.length; i++)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('試合 ${i + 1}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _opponentControllers.removeAt(i);
                                        _locationControllers.removeAt(i);
                                        _matchTypes.removeAt(i);
                                        if (_opponentControllers.isEmpty) {
                                          _addMatchForm();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text('対戦相手'),
                              TextField(
                                controller: _opponentControllers[i],
                                decoration: const InputDecoration(),
                              ),
                              const SizedBox(height: 8),
                              const Text('場所'),
                              TextField(
                                controller: _locationControllers[i],
                                decoration: const InputDecoration(),
                              ),
                              const SizedBox(height: 8),
                              const Text('試合タイプ'),
                              InkWell(
                                onTap: () {
                                  _showCupertinoPicker(
                                    context,
                                    ['練習試合', '公式戦'],
                                    _matchTypes[i],
                                    (selected) {
                                      setState(() {
                                        _matchTypes[i] = selected;
                                      });
                                    },
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_matchTypes[i]),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 32),
                              // 1試合のみ保存ボタン
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    setState(() {
                                      _isLoading = true;
                                    });

                                    // チームID が空の場合は即ダイアログを出して終了（doc('') でのクラッシュ防止）
                                    if (widget.teamId.isEmpty) {
                                      await showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('チームが設定されていません'),
                                          content: const Text('チームに加入してから試合を登録できます。'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      return;
                                    }

                                    // チームメンバー取得（安全な null チェック付き）
                                    final teamDoc = await FirebaseFirestore.instance
                                        .collection('teams')
                                        .doc(widget.teamId)
                                        .get();

                                    List<String> memberUids = [];

                                    if (teamDoc.exists && teamDoc.data() != null) {
                                      final data = teamDoc.data()!;
                                      if (data['members'] is List) {
                                        memberUids = List<String>.from(data['members']);
                                      }
                                    }

                                    // チーム未所属時の防御処理（クラッシュ防止）
                                    if (memberUids.isEmpty) {
                                      await showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('チームに未所属です'),
                                          content: const Text('チームに加入してから試合を登録できます。'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      return;
                                    }

                                    final List<Map<String, dynamic>> members =
                                        [];
                                    for (final uid in memberUids) {
                                      final userDoc = await FirebaseFirestore
                                          .instance
                                          .collection('users')
                                          .doc(uid)
                                          .get();
                                      members.add({
                                        'uid': uid,
                                        'name': userDoc['name'] ?? '',
                                        'positions': userDoc['positions'] ?? [],
                                      });

                                      // 最新のmatchIndexを取得
                                      int matchIndex = i;
                                      final docSnapshot =
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(uid)
                                              .collection('tentative')
                                              .orderBy('createdAt',
                                                  descending: true)
                                              .limit(1)
                                              .get();
                                      if (docSnapshot.docs.isNotEmpty) {
                                        final data =
                                            docSnapshot.docs.first.data();
                                        if (data['data']?['games'] is Map) {
                                          matchIndex =
                                              (data['data']['games'] as Map)
                                                  .length;
                                        }
                                      }

                                      // Build gameData before saving
                                      final gameData = {
                                        'gameType': _matchTypes[i],
                                        'location':
                                            _locationControllers[i].text,
                                        'opponent':
                                            _opponentControllers[i].text,
                                      };

                                      await saveTentativeGameData(
                                          uid, gameData, matchIndex);
                                    }

                                    if (!mounted) return;
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ManagerGameInputHomePage(
                                          matchIndex: i,
                                          userUid: widget.userUid,
                                          teamId: widget.teamId,
                                          members: members,
                                        ),
                                      ),
                                    );
                                    if (!mounted) return;
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  },
                                  child: Text('試合を始める'),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ElevatedButton(
                          onPressed: _addMatchForm,
                          child: const Text('＋ 試合を追加'),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '試合を準備しています...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _showCupertinoPicker(
  BuildContext context,
  List<String> options,
  String selectedValue,
  Function(String) onSelected,
) {
  int selectedIndex = options.indexOf(selectedValue);
  if (selectedIndex == -1) selectedIndex = 0;
  String tempSelected = options[selectedIndex];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
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
                const Text('選択してください',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () {
                    onSelected(tempSelected);
                    Navigator.pop(context);
                  },
                  child: const Text('決定',
                      style: TextStyle(fontSize: 16, color: Colors.blue)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 250,
            child: CupertinoPicker(
              scrollController:
                  FixedExtentScrollController(initialItem: selectedIndex),
              itemExtent: 40.0,
              onSelectedItemChanged: (int index) {
                tempSelected = options[index];
              },
              children: options.map((option) {
                return Center(
                  child: Text(option, style: const TextStyle(fontSize: 22)),
                );
              }).toList(),
            ),
          ),
        ],
      );
    },
  );
}
