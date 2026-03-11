import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manager_game_input_fielding.dart';
import 'manager_game_input_batting.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerGameInputHomePage extends StatefulWidget {
  final int matchIndex;
  final String userUid;
  final String teamId;
  final List<Map<String, dynamic>> members;
  final Map<String, dynamic> gameInfo;

  const ManagerGameInputHomePage({
    Key? key,
    required this.matchIndex,
    required this.userUid,
    required this.teamId,
    required this.members,
    required this.gameInfo,
  }) : super(key: key);

  @override
  _ManagerGameInputHomePageState createState() =>
      _ManagerGameInputHomePageState();
}

class _ManagerGameInputHomePageState extends State<ManagerGameInputHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _inningController = TextEditingController(text: '1');
  final TextEditingController _ourScoreController = TextEditingController(text: '0');
  final TextEditingController _opponentScoreController = TextEditingController(text: '0');
  bool _isTopInning = true;
  String? _gameResult;

  final ManagerGameInputBattingController _battingSaveController =
      ManagerGameInputBattingController();
  final ManagerGameInputFieldingController _fieldingSaveController =
      ManagerGameInputFieldingController();
  bool _isSaving = false;
  int _currentTabIndex = 0;
  String? _tentativeDocId;

  Future<void> _initializeTentativeDocId() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('tentative')
        .get();

    if (snapshot.docs.isEmpty) {
      _tentativeDocId = DateTime.now().microsecondsSinceEpoch.toString();
      return;
    }

    DateTime extractDate(Map<String, dynamic> data) {
      final candidates = [
        data['updatedAt'],
        data['savedAt'],
        data['createdAt'],
      ];

      for (final value in candidates) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final docs = [...snapshot.docs];
    docs.sort((a, b) {
      final aDate = extractDate(a.data());
      final bDate = extractDate(b.data());
      return bDate.compareTo(aDate);
    });

    _tentativeDocId = docs.first.id;
  }

  Future<void> _saveTeamMemberOnlyGames() async {
    final callable = FirebaseFunctions.instance.httpsCallable('addGameData');

    if (_tentativeDocId == null) return;

    final futures = <Future<void>>[];

    for (final member in widget.members) {
      final isTeamMemberOnly = member['isTeamMemberOnly'] == true;
      if (!isTeamMemberOnly) continue;

      final uid = member['uid']?.toString() ?? '';
      if (uid.isEmpty) continue;

      futures.add(() async {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('tentative')
            .doc(_tentativeDocId);

        final snapshot = await docRef.get();
        if (!snapshot.exists) return;

        final root = snapshot.data() ?? {};
        final data = root['data'];
        if (data is! Map) return;
        final games = data['games'];
        if (games is! List || games.length <= widget.matchIndex) return;
        if (games[widget.matchIndex] is! Map) return;

        final game = Map<String, dynamic>.from(games[widget.matchIndex] as Map);

        final rawGameDate = game['gameDate'];
        String gameDateIso;
        if (rawGameDate is Timestamp) {
          gameDateIso = rawGameDate.toDate().toIso8601String();
        } else if (rawGameDate is DateTime) {
          gameDateIso = rawGameDate.toIso8601String();
        } else if (rawGameDate is String && rawGameDate.isNotEmpty) {
          gameDateIso = rawGameDate;
        } else {
          gameDateIso = DateTime.now().toIso8601String();
        }

        await callable.call({
          'uid': uid,
          'matchIndex': widget.matchIndex,
          'gameDate': gameDateIso,
          'gameType': game['gameType'] ?? '',
          'location': game['location'] ?? '',
          'opponent': game['opponent'] ?? '',
          'steals': game['steals'] ?? 0,
          'rbis': game['rbis'] ?? 0,
          'runs': game['runs'] ?? 0,
          'memo': game['memo'] ?? '',
          'inningsThrow': game['inningsThrow'] ?? 0,
          'strikeouts': game['strikeouts'] ?? 0,
          'walks': game['walks'] ?? 0,
          'hitByPitch': game['hitByPitch'] ?? 0,
          'earnedRuns': game['earnedRuns'] ?? 0,
          'runsAllowed': game['runsAllowed'] ?? 0,
          'hitsAllowed': game['hitsAllowed'] ?? 0,
          'resultGame': game['resultGame'] ?? '',
          'outFraction': game['outFraction'] ?? 0,
          'putouts': game['putouts'] ?? 0,
          'assists': game['assists'] ?? 0,
          'errors': game['errors'] ?? 0,
          'atBats': game['atBats'] ?? [],
          'isCompleteGame': game['isCompleteGame'] ?? false,
          'isShutoutGame': game['isShutoutGame'] ?? false,
          'isSave': game['isSave'] ?? false,
          'isHold': game['isHold'] ?? false,
          'appearanceType': game['appearanceType'] ?? '',
          'battersFaced': game['battersFaced'] ?? 0,
          'positions': game['positions'] ?? [],
          'caughtStealingByRunner': game['caughtStealingByRunner'] ?? 0,
          'caughtStealing': game['caughtStealing'] ?? 0,
          'stolenBaseAttempts': game['stolenBaseAttempts'] ?? 0,
          'stealsAttempts': game['stealsAttempts'] ?? 0,
          'homeRunsAllowed': game['homeRunsAllowed'] ?? 0,
          'pitchCount': game['pitchCount'] ?? 0,
          'sourceTentativeId': _tentativeDocId,
        });
      }());
    }

    await Future.wait(futures);
  }

  Future<void> _saveTeamGameSummary() async {
    final ourScore = int.tryParse(_ourScoreController.text) ?? 0;
    final opponentScore = int.tryParse(_opponentScoreController.text) ?? 0;

    final callable = FirebaseFunctions.instance.httpsCallable('saveTeamGameData');

    await callable.call({
      'teamId': widget.teamId,
      'games': [
        {
          'game_date': DateTime.now().toIso8601String(),
          'game_type': widget.gameInfo['gameType'] ?? '',
          'location': widget.gameInfo['location'] ?? '',
          'opponent': widget.gameInfo['opponent'] ?? '',
          'result': _gameResult ?? '',
          'score': ourScore,
          'runs_allowed': opponentScore,
        },
      ],
    });
  }

  Future<void> _saveAllInputs() async {
    if (_isSaving) return;
    if (_tentativeDocId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _refreshAbsentAcrossTabs();

      // batting と fielding は同じ tentative ドキュメントを更新するため、
      // 並列保存すると後勝ちで片方の変更が消えることがある。
      await _battingSaveController.save(showSnackbar: false);
      await _fieldingSaveController.save(showSnackbar: false);

      await Future.wait([
        _saveTeamMemberOnlyGames(),
        _saveTeamGameSummary(),
      ]);

      await _cleanupTeamMemberOnlyTentative();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('打撃・守備の成績と試合結果を保存しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _cleanupTeamMemberOnlyTentative() async {
    if (_tentativeDocId == null) return;

    final futures = <Future<void>>[];

    for (final member in widget.members) {
      final isTeamMemberOnly = member['isTeamMemberOnly'] == true;
      if (!isTeamMemberOnly) continue;

      final uid = member['uid']?.toString() ?? '';
      if (uid.isEmpty) continue;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tentative')
          .doc(_tentativeDocId);

      futures.add(docRef.delete().catchError((_) {}));
    }

    await Future.wait(futures);
  }

  void _changeInning(int delta) {
    final current = int.tryParse(_inningController.text) ?? 1;
    final next = (current + delta).clamp(1, 99);
    setState(() {
      _inningController.text = next.toString();
    });
  }

  void _changeScore(TextEditingController controller, int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 999);
    setState(() {
      controller.text = next.toString();
    });
  }

  Future<void> _showMatchStatusEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '試合状況を編集',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '閉じる',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('イニング'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      modalSetState(() {
                        _changeInning(-1);
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _inningController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) {
                        modalSetState(() {});
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      modalSetState(() {
                        _changeInning(1);
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(_isTopInning ? '表' : '裏'),
                    selected: _isTopInning,
                    onSelected: (_) {
                      modalSetState(() {
                        _isTopInning = !_isTopInning;
                      });
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ourScoreController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              modalSetState(() {});
                              setState(() {});
                            },
                            decoration: const InputDecoration(
                              labelText: '自チーム',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            modalSetState(() {
                              _changeScore(_ourScoreController, 1);
                            });
                          },
                          icon: const Icon(Icons.exposure_plus_1),
                          tooltip: '自チーム +1',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '-',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _opponentScoreController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              modalSetState(() {});
                              setState(() {});
                            },
                            decoration: const InputDecoration(
                              labelText: '相手',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            modalSetState(() {
                              _changeScore(_opponentScoreController, 1);
                            });
                          },
                          icon: const Icon(Icons.exposure_plus_1),
                          tooltip: '相手 +1',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '勝敗',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('勝利'),
                    selected: _gameResult == '勝利',
                    onSelected: (_) {
                      modalSetState(() {
                        _gameResult = '勝利';
                      });
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('敗北'),
                    selected: _gameResult == '敗北',
                    onSelected: (_) {
                      modalSetState(() {
                        _gameResult = '敗北';
                      });
                      setState(() {});
                    },
                  ),
                  ChoiceChip(
                    label: const Text('引き分け'),
                    selected: _gameResult == '引き分け',
                    onSelected: (_) {
                      modalSetState(() {
                        _gameResult = '引き分け';
                      });
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
          },
        );
      },
    );
  }

  Future<void> _resetAllInputs() async {
    _battingSaveController.reset();
    _fieldingSaveController.reset();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('absent_members_${widget.teamId}', []);

    await _refreshAbsentAcrossTabs();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打撃・守備の入力をリセットしました')),
    );
  }

  Future<void> _refreshAbsentAcrossTabs() async {
  await _battingSaveController.refreshAbsent();
  await _fieldingSaveController.refreshAbsent();
}

  @override
  void initState() {
    super.initState();
    _initializeTentativeDocId().then((_) {
      if (mounted) setState(() {});
    });
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        _refreshAbsentAcrossTabs();
      }
    });
  }

  @override
  void dispose() {
    _inningController.dispose();
    _ourScoreController.dispose();
    _opponentScoreController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tentativeDocId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('試合入力'),
        actions: [
          TextButton(
            onPressed: _resetAllInputs,
            child: const Text('数値リセット'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '打撃'),
            Tab(text: '守備'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 1,
                child: InkWell(
                  onTap: _isSaving ? null : _showMatchStatusEditor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_inningController.text.isEmpty ? '1' : _inningController.text}回 ${_isTopInning ? '表' : '裏'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '自 ${_ourScoreController.text.isEmpty ? '0' : _ourScoreController.text} - ${_opponentScoreController.text.isEmpty ? '0' : _opponentScoreController.text} 相手',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              if (_gameResult != null)
                                Text(
                                  _gameResult!,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _isSaving ? null : _showMatchStatusEditor,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: '試合状況を編集',
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            FilledButton.tonal(
                              onPressed: _isSaving ? null : _saveAllInputs,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: _isSaving
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 8),
                                        Text('保存中...'),
                                      ],
                                    )
                                  : const Text('保存'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    ManagerGameInputBatting(
                      matchIndex: widget.matchIndex,
                      userUid: widget.userUid,
                      teamId: widget.teamId,
                      members: widget.members,
                      gameInfo: widget.gameInfo,
                      tentativeDocId: _tentativeDocId!,
                      controller: _battingSaveController,
                    ),
                    ManagerGameInputFielding(
                      matchIndex: widget.matchIndex,
                      userUid: widget.userUid,
                      teamId: widget.teamId,
                      members: widget.members,
                      gameInfo: widget.gameInfo,
                      tentativeDocId: _tentativeDocId!,
                      controller: _fieldingSaveController,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      '保存しています…',
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
