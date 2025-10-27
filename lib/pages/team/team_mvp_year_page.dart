import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TeamMvpYearPage extends StatefulWidget {
  final String teamId;

  const TeamMvpYearPage({Key? key, required this.teamId}) : super(key: key);

  @override
  State<TeamMvpYearPage> createState() => _TeamMvpYearPageState();
}

class _TeamMvpYearPageState extends State<TeamMvpYearPage>
    with SingleTickerProviderStateMixin {
  int _displayedMvpCount = 10;
  // ignore: unused_field
  String _resultText = '';
  // Use a map to track votes per tab (monthly/yearly)
  // Map<String, Set<String>> votedPlayerIds = {
  //   'monthly': <String>{},
  //   'yearly': <String>{},
  // };

  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoadingMembers = true;

  DateTime? _voteStartDate;
  DateTime? _voteEndDate;

  // Holds the currently selected MVP event ID
  String? _selectedMvpId;

  // ignore: unused_field
  bool _isTallied = false;

  // --- MVPテーマ絞り込み用 ---
  String? selectedTheme;
  List<String> _allThemes = [];

  // --- コメント展開管理用 ---
  Map<String, bool> _expandedComments = {};
  Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    final teamDoc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .get();

    final memberIds = List<String>.from(teamDoc['members'] ?? []);
    final memberSnapshots = await Future.wait(memberIds.map((uid) =>
        FirebaseFirestore.instance.collection('users').doc(uid).get()));

    setState(() {
      _teamMembers = memberSnapshots.where((doc) => doc.exists).map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return {
          'id': doc.id,
          'name': data['name'] ?? 'No Name',
        };
      }).toList();
      _isLoadingMembers = false;
    });
  }

  Future<void> voteForPlayer(
      String playerId, String period, String comment, bool isAnonymous) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final teamId = widget.teamId;

    if (userId == null) return;

    final voteDocRef = FirebaseFirestore.instance
        .collection('teams')
        .doc(teamId)
        .collection('mvp_year')
        .doc(period)
        .collection('votes')
        .doc(userId);

    await voteDocRef.set({
      'votedPlayerId': playerId,
      'comment': comment,
      'isAnonymous': isAnonymous,
      'votedAt': FieldValue.serverTimestamp(),
    });
  }

  String _getPlayerName(String playerId) {
    return _teamMembers.firstWhere((p) => p['id'] == playerId)['name'] ?? '';
  }

  // MVP作成用コントローラや状態
  final TextEditingController _themeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Move _showCreateMvpDialog inside the class and place at the end
  void _showCreateMvpDialog(int nextCount) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            _voteStartDate ??=
                DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
            _voteEndDate ??= _voteStartDate!.add(const Duration(days: 9));
            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.fromLTRB(5.0, 16.0, 5.0, 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('第${nextCount}回年間MVPを作成',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('対象年'),
                    TextButton(
                      onPressed: () {
                        _showYearPicker((picked) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        });
                      },
                      child: Text('${_selectedDate.year}年'),
                    ),
                    const SizedBox(height: 10),
                    const Text('投票期間'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _voteStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _voteStartDate = picked;
                              });
                            }
                          },
                          child: Text(
                            _voteStartDate != null
                                ? '開始: ${_voteStartDate!.month}月${_voteStartDate!.day}日'
                                : '開始日を選択',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _voteEndDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _voteEndDate = picked;
                              });
                            }
                          },
                          child: Text(
                            _voteEndDate != null
                                ? '終了: ${_voteEndDate!.month}月${_voteEndDate!.day}日'
                                : '終了日を選択',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('テーマ（任意）'),
                    TextField(
                      controller: _themeController,
                      decoration: const InputDecoration(
                        hintText: '例: 元気をくれた選手',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '※ テーマを空のままにすると「第◯回MVP」として保存されます',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('キャンセル'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (_voteStartDate == null ||
                                _voteEndDate == null) {
                              return;
                            }
                            try {
                              final inputTheme = _themeController.text.trim();
                              final theme = inputTheme.isEmpty
                                  ? '第${nextCount}回MVP'
                                  : '第${nextCount}回$inputTheme';

                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              String currentUserName = '';
                              if (currentUser != null) {
                                // Try to get user name from Firestore
                                final userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(currentUser.uid)
                                    .get();
                                currentUserName =
                                    (userDoc.data()?['name'] ?? '') as String;
                              }

                              final selectedEndDate = _voteEndDate!;
                              final mvpDoc = {
                                'teamId': widget.teamId,
                                'year': _selectedDate.year,
                                'month': _selectedDate.month,
                                'theme': theme,
                                'createdAt': DateTime.now(),
                                'voteDeadline': DateTime(_selectedDate.year,
                                        _selectedDate.month + 1, 1)
                                    .subtract(const Duration(days: 1)),
                                'voteStartDate': _voteStartDate,
                                // Set voteEndDate to user-selected date at 23:59:59
                                'voteEndDate': DateTime(
                                  selectedEndDate.year,
                                  selectedEndDate.month,
                                  selectedEndDate.day,
                                  23,
                                  59,
                                  59,
                                ),
                                'createdBy': {
                                  'uid': currentUser?.uid,
                                  'name': currentUserName,
                                },
                                'isTallied': false,
                              };

                              await FirebaseFirestore.instance
                                  .collection('teams')
                                  .doc(widget.teamId)
                                  .collection('mvp_year')
                                  .add(mvpDoc);
                            } catch (e) {
                              print('MVP保存エラー: $e');
                            }
                            Navigator.of(context).pop();
                            // MVPデータ保存処理などがあればここに追加
                          },
                          child: const Text('作成する'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showYearPicker(Function(DateTime) onSelected) {
    int tempYear = DateTime.now().year;

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
                  const Text('年を選択',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton(
                    onPressed: () {
                      onSelected(DateTime(tempYear));
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
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                    initialItem: DateTime.now().year - 2020),
                onSelectedItemChanged: (index) {
                  tempYear = 2020 + index;
                },
                children: List.generate(20, (i) => Text('${2020 + i}年')),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showVoteDialog({
    required String playerName,
    required void Function(String comment, bool isAnonymous) onVote,
  }) {
    final TextEditingController _commentController = TextEditingController();
    bool _isAnonymous = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('「$playerName」に投票',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'コメント（任意）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('匿名で投票'),
                        const Spacer(),
                        Switch(
                          value: _isAnonymous,
                          onChanged: (val) {
                            setState(() {
                              _isAnonymous = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('キャンセル'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onVote(_commentController.text, _isAnonymous);
                          },
                          child: const Text('投票する'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitVote(
      String votedPlayerId, String comment, bool isAnonymous) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _selectedMvpId == null) return;

    final voteData = {
      'votedPlayerId': votedPlayerId,
      'comment': comment,
      'isAnonymous': isAnonymous,
      'votedAt': Timestamp.now(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('mvp_year')
          .doc(_selectedMvpId)
          .collection('votes')
          .doc(currentUserId)
          .set(voteData);
      setState(() {
        // Optionally update UI state after vote
        // e.g., mark already voted player id
        // _alreadyVotedPlayerId = votedPlayerId;
      });
      Navigator.of(context).pop(); // close the dialog if not already closed
    } catch (e) {
      debugPrint('Error submitting vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投票の送信中にエラーが発生しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // MVP投票ロジック（年間）
          if (_isLoadingMembers)
            const Center(child: CircularProgressIndicator())
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('teams')
                  .doc(widget.teamId)
                  .collection('mvp_year')
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () {
                            FirebaseFirestore.instance
                                .collection('teams')
                                .doc(widget.teamId)
                                .collection('mvp_year')
                                .get()
                                .then((snapshot) {
                              final nextCount = snapshot.docs.length + 1;
                              _showCreateMvpDialog(nextCount);
                            });
                          },
                          child: const Text('年間MVPを作成'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('現在投票できるMVPはありません')),
                      ),
                    ],
                  );
                }
                // MVP投票ID取得
                final mvpDoc = snapshot.data!.docs.first;
                final mvpDocData = mvpDoc.data() as Map<String, dynamic>;
                final isTallied = mvpDocData.containsKey('isTallied')
                    ? mvpDocData['isTallied'] as bool
                    : false;
                if (isTallied) {
                  return ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () {
                            FirebaseFirestore.instance
                                .collection('teams')
                                .doc(widget.teamId)
                                .collection('mvp_year')
                                .get()
                                .then((snapshot) {
                              final nextCount = snapshot.docs.length + 1;
                              _showCreateMvpDialog(nextCount);
                            });
                          },
                          child: const Text('年間MVPを作成'),
                        ),
                      ),
                    ],
                  );
                }
                final currentVoteId = mvpDoc.id;
                final theme = mvpDoc['theme'];
                // 現在ユーザーID取得
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId == null) {
                  return const Center(child: Text('ユーザー情報が取得できません'));
                }
                // 投票期間や作成者判定
                final voteEndDate = mvpDoc['voteEndDate']?.toDate();
                final isCreator = mvpDoc['createdBy']?['uid'] ==
                    FirebaseAuth.instance.currentUser?.uid;
                final isVotingPeriod =
                    voteEndDate == null || DateTime.now().isBefore(voteEndDate);
                // Prepare mvpData for easier access in UI
                final mvpData = mvpDoc.data() as Map<String, dynamic>;
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('teams')
                      .doc(widget.teamId)
                      .collection('mvp_year')
                      .doc(currentVoteId)
                      .collection('votes')
                      .doc(currentUserId)
                      .get(),
                  builder: (context, voteSnapshot) {
                    String? alreadyVotedPlayerId;
                    if (voteSnapshot.connectionState == ConnectionState.done &&
                        voteSnapshot.data != null) {
                      final voteDoc = voteSnapshot.data!;
                      final voteData = voteDoc.data();
                      if (voteDoc.exists && voteData is Map<String, dynamic>) {
                        alreadyVotedPlayerId =
                            voteData['votedPlayerId'] as String?;
                      } else {
                        alreadyVotedPlayerId = null;
                      }
                    }
                    final docs = snapshot.data!.docs;
                    final hasUnTalliedMvp = docs.any((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['isTallied'] == false;
                    });
                    // すでに投票済みかどうかの分岐
                    String votedPlayerName = '';
                    if (alreadyVotedPlayerId != null) {
                      try {
                        votedPlayerName = _teamMembers.firstWhere((p) =>
                                p['id'] == alreadyVotedPlayerId)['name'] ??
                            '';
                      } catch (e) {
                        votedPlayerName = '';
                      }
                    }
                    return ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        if (!hasUnTalliedMvp)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection('teams')
                                    .doc(widget.teamId)
                                    .collection('mvp_year')
                                    .get()
                                    .then((snapshot) {
                                  final nextCount = snapshot.docs.length + 1;
                                  _showCreateMvpDialog(nextCount);
                                });
                              },
                              child: const Text('年間MVPを作成'),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$theme に投票',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              // --- 投票期間表示を追加 ---
                              if (mvpData['voteStartDate'] != null &&
                                  mvpData['voteEndDate'] != null) ...[
                                Text(
                                  '投票期間：${DateFormat('M月d日').format(mvpData['voteStartDate'].toDate())} 〜 ${DateFormat('M月d日').format(mvpData['voteEndDate'].toDate())}',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700]),
                                ),
                              ],
                              // 投票終了メッセージ
                              if (mvpData['voteEndDate'] != null &&
                                  DateTime.now().isAfter(
                                      mvpData['voteEndDate'].toDate())) ...[
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '投票期間は終了しました',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              // ------------------------
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '作成者：${mvpDoc['createdBy']?['name'] ?? '不明'}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (alreadyVotedPlayerId != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              'あなたは${votedPlayerName}に投票済みです',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          )
                        // 新規分岐: 投票期間終了かつ未投票の場合
                        else if (alreadyVotedPlayerId == null &&
                            mvpData['voteEndDate'] != null &&
                            DateTime.now()
                                .isAfter(mvpData['voteEndDate'].toDate())) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              'あなたは投票していません',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            ),
                          ),
                        ],
                        // ↓↓↓ 投票ボタン表示条件の分岐
                        if (isVotingPeriod && alreadyVotedPlayerId == null) ...[
                          ...List.generate(_teamMembers.length, (index) {
                            final player = _teamMembers[index];
                            return ListTile(
                              leading:
                                  const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(player['name'] ?? ''),
                              subtitle: Text('$theme 候補'),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  _showVoteDialog(
                                    playerName: player['name'],
                                    onVote: (String comment, bool isAnonymous) {
                                      voteForPlayer(player['id']!,
                                          currentVoteId, comment, isAnonymous);
                                      // Update local state to reflect immediate voting
                                      setState(() {
                                        alreadyVotedPlayerId = player['id'];
                                        votedPlayerName = player['name'] ?? '';
                                      });
                                    },
                                  );
                                },
                                child: const Text('投票する'),
                              ),
                            );
                          }),
                        ] else if (!isVotingPeriod && isCreator) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ElevatedButton(
                              onPressed: () async {
                                final voteSnapshot = await FirebaseFirestore
                                    .instance
                                    .collection('teams')
                                    .doc(widget.teamId)
                                    .collection('mvp_year')
                                    .doc(currentVoteId)
                                    .collection('votes')
                                    .get();

                                final Map<String, int> voteCounts = {};
                                final List<Map<String, dynamic>> allVotes = [];

                                for (var doc in voteSnapshot.docs) {
                                  final data = doc.data();
                                  final votedPlayerId = data['votedPlayerId'];
                                  final isAnonymous =
                                      data['isAnonymous'] ?? false;
                                  final comment = data['comment'] ?? '';
                                  if (votedPlayerId != null) {
                                    voteCounts[votedPlayerId] =
                                        (voteCounts[votedPlayerId] ?? 0) + 1;
                                    allVotes.add({
                                      'votedPlayerId': votedPlayerId,
                                      'comment': comment,
                                      'isAnonymous': isAnonymous,
                                    });
                                  }
                                }

                                final maxVotes = voteCounts.values
                                    .fold(0, (a, b) => a > b ? a : b);
                                final topPlayerIds = voteCounts.entries
                                    .where((e) => e.value == maxVotes)
                                    .map((e) => e.key)
                                    .toList();

                                final resultList = topPlayerIds.map((id) {
                                  final name = _teamMembers.firstWhere(
                                      (m) => m['id'] == id,
                                      orElse: () => {'name': '不明'})['name'];
                                  return {
                                    'id': id,
                                    'name': name,
                                    'votes': maxVotes,
                                  };
                                }).toList();

                                await FirebaseFirestore.instance
                                    .collection('teams')
                                    .doc(widget.teamId)
                                    .collection('mvp_year')
                                    .doc(currentVoteId)
                                    .update({
                                  'result': resultList,
                                  'resultCount': maxVotes,
                                  'isTallied': true,
                                });

                                setState(() {
                                  _isTallied = true;
                                  _resultText = 'MVP（$maxVotes票）:\n' +
                                      resultList
                                          .map((e) => e['name'])
                                          .join(', ');
                                });
                              },
                              child: const Text('集計'),
                            ),
                          ),
                        ]
                        // 非表示: 期間外かつ作成者でない場合はメンバーリストを表示しない
                      ],
                    );
                  },
                );
              },
            ),
          // MVP履歴表示
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teams')
                .doc(widget.teamId)
                .collection('mvp_year')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              // テーマリストを更新
              _allThemes = docs
                  .map((doc) =>
                      (doc.data() as Map<String, dynamic>)['theme']
                          ?.toString() ??
                      '')
                  .where((theme) => theme.isNotEmpty)
                  .toSet()
                  .toList();
              // MVP一覧の絞り込み
              final talliedDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isTallied = data['isTallied'] == true;
                final theme = data['theme']?.toString() ?? '';
                return isTallied &&
                    (selectedTheme == null || selectedTheme == theme);
              }).toList();
              final displayedDocs =
                  talliedDocs.take(_displayedMvpCount).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (talliedDocs.isNotEmpty) ...[
                    const Divider(),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Text(
                        '過去のMVP一覧',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    // テーマ絞り込みドロップダウン（CupertinoPicker形式）
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: InkWell(
                        onTap: () {
                          _showCupertinoPicker(
                            context,
                            ['すべて', ..._allThemes],
                            selectedTheme ?? 'すべて',
                            (String selected) {
                              setState(() {
                                selectedTheme =
                                    selected == 'すべて' ? null : selected;
                              });
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedTheme ?? 'すべて',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (talliedDocs.isEmpty)
                    const Center(child: Text('過去のMVPはまだありません'))
                  else
                    Column(
                      children: [
                        ...displayedDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final theme = data['theme'] ?? '';
                          final result = data['result'] as List<dynamic>? ?? [];
                          final resultNames =
                              result.map((e) => e['name']).join(', ');
                          final mvpDocId = doc.id;
                          // --- コメント情報取得 ---
                          // ただし votes サブコレクションから取得する必要があるため、下のようにする
                          // ここでは非同期取得はできないので、hasCommentsだけを先に判断
                          // 代わりに、コメント展開時にStreamBuilderを使うか、下でクエリ
                          // ここでは votes サブコレクションからコメントの有無だけを取得するためのダミー
                          // ただし、ここでは votes サブコレクションを直接参照できないので、コメント展開時に取得
                          // ここでは「コメントボタン」を常時表示する代わりに、hasCommentsフラグを後で取得
                          // しかし、Firestoreにアクセスしないと判定できないため、ここでは「コメントボタン」を常時表示し、展開時に取得
                          // --- コメント展開状態 ---
                          bool isExpanded = _expandedComments[mvpDocId] == true;
                          return FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('teams')
                                .doc(widget.teamId)
                                .collection('mvp_year')
                                .doc(mvpDocId)
                                .collection('votes')
                                .where('comment', isGreaterThan: '')
                                .get(),
                            builder: (context, voteSnapshot) {
                              final comments = voteSnapshot.data?.docs
                                      .map((voteDoc) {
                                        final d = voteDoc.data()
                                            as Map<String, dynamic>;
                                        return {
                                          ...d,
                                          'userId': voteDoc.id,
                                        };
                                      })
                                      .where((d) => (d['comment'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                      .toList() ??
                                  [];
                              final hasComments = comments.isNotEmpty;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${data['year']}年',
                                          style: TextStyle(
                                              fontSize: 14, color: Colors.grey),
                                        ),
                                        Text('$theme'),
                                      ],
                                    ),
                                    subtitle: Text('MVP: $resultNames'),
                                    trailing: hasComments
                                        ? TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _expandedComments[mvpDocId] =
                                                    !(isExpanded);
                                              });
                                            },
                                            child: Text('コメント'),
                                          )
                                        : null,
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16.0, bottom: 8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ...comments.map((commentData) {
                                            final isAnonymous =
                                                commentData['isAnonymous'] ??
                                                    false;
                                            final voterId =
                                                commentData['userId'];
                                            final voterName = isAnonymous
                                                ? '匿名'
                                                : (_userNameCache[voterId] ??
                                                    '不明');
                                            // キャッシュに名前がなければ取得してキャッシュ
                                            if (!isAnonymous &&
                                                !_userNameCache
                                                    .containsKey(voterId)) {
                                              FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(voterId)
                                                  .get()
                                                  .then((userDoc) {
                                                final name =
                                                    userDoc.data()?['name'] ??
                                                        'ユーザーID: $voterId';
                                                setState(() {
                                                  _userNameCache[voterId] =
                                                      name;
                                                });
                                              });
                                            }
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4.0),
                                              child: Text(
                                                  '$voterName: ${commentData['comment']}'),
                                            );
                                          }).toList(),
                                          const SizedBox(height: 8),
                                          Center(
                                            child: TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _expandedComments[mvpDocId] =
                                                      false;
                                                });
                                              },
                                              child: const Text('閉じる'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        }).toList(),
                        if (_displayedMvpCount < talliedDocs.length)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _displayedMvpCount += 10;
                              });
                            },
                            child: const Text('もっと見る'),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// CupertinoPickerを表示するヘルパー
void _showCupertinoPicker(
  BuildContext context,
  List<String> items,
  String selectedItem,
  void Function(String) onSelected,
) {
  int initialIndex = items.indexOf(selectedItem);
  int tempIndex = initialIndex >= 0 ? initialIndex : 0;
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
                const Text('テーマを選択',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () {
                    onSelected(items[tempIndex]);
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
              itemExtent: 32,
              scrollController:
                  FixedExtentScrollController(initialItem: tempIndex),
              onSelectedItemChanged: (index) {
                tempIndex = index;
              },
              children: items.map((e) => Text(e)).toList(),
            ),
          ),
        ],
      );
    },
  );
}
