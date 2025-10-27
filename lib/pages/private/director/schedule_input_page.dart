import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScheduleInputPage extends StatefulWidget {
  final DateTime selectedDate;
  final String userUid;
  final String teamId;
  final String? scheduleDocId;

  const ScheduleInputPage({
    super.key,
    required this.selectedDate,
    required this.userUid,
    required this.teamId,
    this.scheduleDocId,
  });

  @override
  State<ScheduleInputPage> createState() => _ScheduleInputPageState();
}

class _ScheduleInputPageState extends State<ScheduleInputPage> {
  bool _isLoading = true;
  bool _isSubscriptionActive = false;
  // 打撃成績順リスト
  List<Map<String, dynamic>> _playerStats = [];
  // 選手の表示カテゴリー
  String _selectedCategory = '打率';
  List<Map<String, String>> startingMembers =
      List.generate(9, (_) => {'position': '', 'name': '', 'number': ''});
  List<Map<String, String>> benchPlayers =
      List.generate(10, (_) => {'name': '', 'number': ''});

  List<Map<String, dynamic>> allPlayers = [];
  List<String> selectedPlayers = [];

  List<TextEditingController> startingPositionControllers = [];

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    startingPositionControllers =
        List.generate(9, (_) => TextEditingController());

    _checkSubscriptionStatus().then((_) {
      if (_isSubscriptionActive) {
        _fetchSortedPlayerStats().then((value) {
          setState(() {
            _playerStats = value;
            _playerStats.sort(_compareStats);
            _isLoading = false;
          });
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });

    _fetchTeamMembers();
    _loadScheduleIfExists();
  }

  Future<void> _checkSubscriptionStatus() async {
    final iosDoc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('subscription')
        .doc('iOS')
        .get();

    final androidDoc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('subscription')
        .doc('android')
        .get();

    final iosActive = iosDoc.exists && iosDoc.data()?['status'] == 'active';
    final androidActive =
        androidDoc.exists && androidDoc.data()?['status'] == 'active';

    setState(() {
      _isSubscriptionActive = iosActive || androidActive;
    });
  }

  int _compareStats(Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (_selectedCategory) {
      case '盗塁':
        return (b['totalSteals'] as num).compareTo(a['totalSteals'] as num);
      case 'バント':
        return (b['totalAllBuntSuccess'] as num)
            .compareTo(a['totalAllBuntSuccess'] as num);
      case '出塁率':
        return (b['onBasePercentage'] as num)
            .compareTo(a['onBasePercentage'] as num);
      case '長打率':
        return (b['sluggingPercentage'] as num)
            .compareTo(a['sluggingPercentage'] as num);
      case '打点':
        return (b['totalRbis'] as num).compareTo(a['totalRbis'] as num);
      case '守備率':
        return (b['fieldingPercentage'] as num)
            .compareTo(a['fieldingPercentage'] as num);
      case '投手成績':
        return (b['era'] as num).compareTo(a['era'] as num);
      default:
        return (b['average'] as num).compareTo(a['average'] as num);
    }
  }

  Future<void> _loadScheduleIfExists() async {
    if (widget.scheduleDocId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('schedules')
        .doc(widget.scheduleDocId);

    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        final List<dynamic> starting = data['startingMembers'] ?? [];
        final List<dynamic> bench = data['benchPlayers'] ?? [];

        for (int i = 0;
            i < starting.length && i < startingMembers.length;
            i++) {
          final item = Map<String, String>.from(starting[i]);
          startingMembers[i] = item;
          if (item['position'] != null) {
            startingPositionControllers[i].text = item['position']!;
          }
          if (item['name'] != null) {
            selectedPlayers.add(item['name']!);
          }
        }

        for (int i = 0; i < bench.length && i < benchPlayers.length; i++) {
          benchPlayers[i] = Map<String, String>.from(bench[i]);
          if (benchPlayers[i]['name'] != null) {
            selectedPlayers.add(benchPlayers[i]['name']!);
          }
        }
      });
    }
  }

  // カテゴリごとにフィルタしたリスト
  List<Map<String, dynamic>> get _filteredStats {
    switch (_selectedCategory) {
      case '盗塁':
        return _playerStats.where((p) => p['totalSteals'] != null).toList();
      case 'バント':
        return _playerStats
            .where((p) => p['totalBuntAttempts'] != null)
            .toList();
      case '出塁率':
        return _playerStats
            .where((p) => p['onBasePercentage'] != null)
            .toList();
      case '長打率':
        return _playerStats
            .where((p) => p['sluggingPercentage'] != null)
            .toList();
      case '打点':
        return _playerStats.where((p) => p['totalRbis'] != null).toList();
      case '守備率':
        return _playerStats
            .where((p) => p['fieldingPercentage'] != null)
            .toList();
      case '投手成績':
        return _playerStats
            .where((p) => (p['positions'] ?? []).contains('投手'))
            .toList();
      default:
        return _playerStats;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSortedPlayerStats() async {
    final teamDoc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .get();
    final data = teamDoc.data();
    final List<dynamic> memberUids = data?['members'] ?? [];

    List<Map<String, dynamic>> statsList = [];

    for (String uid in memberUids) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) continue;

      final userData = userDoc.data();
      final name = userData?['name'];
      final position = userData?['position'];
      if (position == 'マネージャー' || position == '監督') continue;

      final nowYear = DateTime.now().year;
      final statsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('stats')
          .doc('results_stats_${nowYear}_all')
          .get();

      final statsData = statsDoc.data();
      if (statsData == null) continue;

      final atBats = statsData['atBats'] ?? 0;
      final hits = statsData['hits'] ?? 0;
      final average = statsData['battingAverage'] ?? 0.0;
      final diff = atBats - hits;

      statsList.add({
        'name': name,
        'atBats': atBats,
        'hits': hits,
        'average': average,
        'diff': diff,
        'totalstealsAttempts': statsData['totalstealsAttempts'] ?? 0,
        'totalSteals': statsData['totalSteals'] ?? 0,
        'totalBuntAttempts': statsData['totalBuntAttempts'] ?? 0,
        'totalAllBuntSuccess': statsData['totalAllBuntSuccess'] ?? 0,
        'totalSqueezeSuccesses': statsData['totalSqueezeSuccesses'] ?? 0,
        'onBasePercentage': statsData['onBasePercentage'] ?? 0.0,
        'totalFourBalls': statsData['totalFourBalls'] ?? 0,
        'totalHitByPitch': statsData['totalHitByPitch'] ?? 0,
        'sluggingPercentage': statsData['sluggingPercentage'] ?? 0.0,
        'total1hits': statsData['total1hits'] ?? 0,
        'total2hits': statsData['total2hits'] ?? 0,
        'total3hits': statsData['total3hits'] ?? 0,
        'totalHomeRuns': statsData['totalHomeRuns'] ?? 0,
        'totalRbis': statsData['totalRbis'] ?? 0,
        // --- added for fielding and pitching ---
        'fieldingPercentage': statsData['fieldingPercentage'] ?? 0.0,
        'totalAssists': statsData['totalAssists'] ?? 0,
        'totalPutouts': statsData['totalPutouts'] ?? 0,
        'totalErrors': statsData['totalErrors'] ?? 0,
        'era': statsData['era'] ?? 0.0,
        'winRate': statsData['winRate'] ?? 0.0,
        'positions': userData?['positions'] ?? [],
      });
    }

    statsList.sort((a, b) {
      switch (_selectedCategory) {
        case '盗塁':
          return (b['totalSteals'] as num).compareTo(a['totalSteals'] as num);
        case 'バント':
          return (b['totalAllBuntSuccess'] as num)
              .compareTo(a['totalAllBuntSuccess'] as num);
        case '出塁率':
          return (b['onBasePercentage'] as num)
              .compareTo(a['onBasePercentage'] as num);
        case '長打率':
          return (b['sluggingPercentage'] as num)
              .compareTo(a['sluggingPercentage'] as num);
        case '打点':
          return (b['totalRbis'] as num).compareTo(a['totalRbis'] as num);
        case '守備率':
          return (b['fieldingPercentage'] as num)
              .compareTo(a['fieldingPercentage'] as num);
        case '投手成績':
          return (b['era'] as num).compareTo(a['era'] as num);
        default:
          return (b['average'] as num).compareTo(a['average'] as num);
      }
    });

    return statsList;
  }

  Future<void> _fetchTeamMembers() async {
    final teamDoc = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .get();
    final data = teamDoc.data();
    final List<dynamic> memberUids = data?['members'] ?? [];
    print('📣 members: $memberUids');

    List<Map<String, dynamic>> fetchedMembers = [];

    for (String uid in memberUids) {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final name = userData?['name'];
        final positions = userData?['positions'];
        if (name != null) {
          fetchedMembers.add({
            'name': name,
            'positions': positions ?? [],
          });
        }
      }
    }

    setState(() {
      allPlayers = fetchedMembers;
    });
  }

  Future<String?> _showPlayerSelector(String? currentName) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final availablePlayers = allPlayers
            .map((e) => e['name'] as String)
            .where((player) =>
                !selectedPlayers.contains(player) || player == currentName)
            .toList();

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8, // 画面の80%
          child: Column(
            children: [
              // 🔺 上部バー + バツ
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '選手を選択',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 🔹 一覧（Expandedで広く）
              Expanded(
                child: ListView.builder(
                  itemCount: availablePlayers.length,
                  itemBuilder: (context, index) {
                    final player = availablePlayers[index];
                    return ListTile(
                      title: Text(player),
                      onTap: () => Navigator.pop(context, player),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // 🔻 小さめの「クリア」ボタン
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text(
                    '選手をクリア',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerField({
    required String? currentName,
    required Function(String) onSelected,
    int? index,
  }) {
    return InkWell(
      onTap: () async {
        final selected = await _showPlayerSelector(currentName);
        if (selected != null && selected.isNotEmpty) {
          setState(() {
            selectedPlayers.remove(currentName);
            selectedPlayers.add(selected);
            onSelected(selected);
          });
          // 守備位置選択処理
          if (index != null) {
            final playerData = allPlayers.firstWhere(
              (player) => player['name'] == selected,
              orElse: () => {},
            );
            final positions = playerData['positions'];
            if (positions is List && positions.isNotEmpty) {
              if (positions.length == 1) {
                setState(() {
                  startingMembers[index]['position'] = positions.first;
                  startingPositionControllers[index].text = positions.first;
                });
              } else {
                showModalBottomSheet<String>(
                  context: context,
                  builder: (context) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '守備位置を選択',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 28),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView(
                              children: [
                                ...positions.map<Widget>((pos) {
                                  return ListTile(
                                    title: Text(pos),
                                    onTap: () {
                                      Navigator.pop(context, pos);
                                    },
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text('自分で入力する'),
                            leading: const Icon(Icons.edit),
                            onTap: () {
                              Navigator.pop(context);
                              // 入力モーダルを表示
                              showDialog<String>(
                                context: context,
                                builder: (context) {
                                  String manualInput = '';
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return AlertDialog(
                                        title: const Text('守備位置を入力'),
                                        content: TextField(
                                          autofocus: true,
                                          onChanged: (value) {
                                            manualInput = value;
                                            setState(() {});
                                          },
                                          decoration: const InputDecoration(
                                            hintText: '例: 遊',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('キャンセル'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                                context, manualInput),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ).then((customPos) {
                                if (customPos != null && customPos.isNotEmpty) {
                                  setState(() {
                                    startingMembers[index]['position'] =
                                        customPos;
                                    startingPositionControllers[index].text =
                                        customPos;
                                  });
                                }
                              });
                            },
                          ),
                          SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ).then((selectedPosition) {
                  if (selectedPosition != null) {
                    setState(() {
                      startingMembers[index]['position'] = selectedPosition;
                      startingPositionControllers[index].text =
                          selectedPosition;
                    });
                  }
                });
              }
            }
          }
        }
      },
      splashColor: Colors.blue.withOpacity(0.2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                currentName?.isNotEmpty == true ? currentName! : '選手名を選択',
                style: TextStyle(
                  fontSize: 14,
                  color: currentName?.isNotEmpty == true
                      ? Colors.black
                      : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis, // ← はみ出し防止
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Text _buildStatText(Map<String, dynamic> p) {
    switch (_selectedCategory) {
      case '盗塁':
        return Text(
            '${p['name']}：${p['totalSteals']}/${p['totalstealsAttempts']}（成功/企図）');
      case 'バント':
        return Text(
            '${p['name']}：${p['totalAllBuntSuccess']}/${p['totalBuntAttempts']}（成功/企図)');
      case '出塁率':
        return Text(
            '${p['name']}：${formatPercentage(p['onBasePercentage'])}（安打${p['hits']} 四球${p['totalFourBalls']} 死球${p['totalHitByPitch']}）');
      case '長打率':
        return Text(
            '${p['name']}：${formatPercentage(p['sluggingPercentage'])}（1B:${p['total1hits']} 2B:${p['total2hits']} 3B:${p['total3hits']} HR:${p['totalHomeRuns']}）');
      case '打点':
        return Text('${p['name']}： ${p['totalRbis']}点');
      case '守備率':
        return Text(
            '${p['name']}：${formatPercentage(p['fieldingPercentage'])}（捕殺${p['totalAssists']} 刺殺${p['totalPutouts']} 失策${p['totalErrors']}）');
      case '投手成績':
        if ((p['positions'] ?? []).contains('投手')) {
          return Text(
              '${p['name']}：防御率${formatPercentageEra(p['era'])} / 勝率${formatPercentage(p['winRate'])}');
        } else {
          return const Text('');
        }
      default:
        return Text(
            '${p['name']}：${formatPercentage(p['average'])}（${p['atBats']}-${p['hits']}）');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('オーダー表入力')),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('準備しています...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSubscriptionActive && _playerStats.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ▼ カテゴリ切替ドロップダウン
                        DropdownButton<String>(
                          value: _selectedCategory,
                          items: const [
                            '打率',
                            '盗塁',
                            'バント',
                            '出塁率',
                            '長打率',
                            '打点',
                            '守備率',
                            '投手成績',
                          ]
                              .map((label) => DropdownMenuItem(
                                    value: label,
                                    child: Text(label),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value!;
                              _playerStats.sort(_compareStats);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                final categories = [
                                  '打率',
                                  '盗塁',
                                  'バント',
                                  '出塁率',
                                  '長打率',
                                  '打点',
                                  '守備率',
                                  '投手成績'
                                ];
                                final currentIndex =
                                    categories.indexOf(_selectedCategory);
                                setState(() {
                                  _selectedCategory = categories[
                                      (currentIndex - 1 + categories.length) %
                                          categories.length];
                                  _playerStats.sort(_compareStats);
                                });
                              },
                            ),
                            Text(
                              '【$_selectedCategory】',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                final categories = [
                                  '打率',
                                  '盗塁',
                                  'バント',
                                  '出塁率',
                                  '長打率',
                                  '打点',
                                  '守備率',
                                  '投手成績'
                                ];
                                final currentIndex =
                                    categories.indexOf(_selectedCategory);
                                setState(() {
                                  _selectedCategory = categories[
                                      (currentIndex + 1) % categories.length];
                                  _playerStats.sort(_compareStats);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._filteredStats.map((p) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  _buildStatText(p),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  const Text('【スタメン】',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Table(
                    columnWidths: const {
                      0: FixedColumnWidth(40),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(3),
                      3: FlexColumnWidth(2),
                    },
                    border: TableBorder.all(color: Colors.grey),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('打順', textAlign: TextAlign.center)),
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('守備位置', textAlign: TextAlign.center)),
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('選手名', textAlign: TextAlign.center)),
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('背番号', textAlign: TextAlign.center)),
                        ],
                      ),
                      for (int i = 0; i < 9; i++)
                        TableRow(
                          children: [
                            Center(child: Text('${i + 1}')),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: TextField(
                                controller: startingPositionControllers[i],
                                decoration: const InputDecoration(
                                    border: InputBorder.none, hintText: '例：遊'),
                                onChanged: (v) =>
                                    startingMembers[i]['position'] = v,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: _buildPlayerField(
                                currentName: startingMembers[i]['name'],
                                onSelected: (value) {
                                  startingMembers[i]['name'] = value;
                                },
                                index: i,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: TextField(
                                decoration: const InputDecoration(
                                    border: InputBorder.none, hintText: '00'),
                                keyboardType: TextInputType.number,
                                onChanged: (v) =>
                                    startingMembers[i]['number'] = v,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('【控え選手】',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(3),
                      3: FlexColumnWidth(2),
                    },
                    border: TableBorder.all(color: Colors.grey),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFE0E0E0)),
                        children: [
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('選手名', textAlign: TextAlign.center)),
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('背番号', textAlign: TextAlign.center)),
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('選手名', textAlign: TextAlign.center)),
                          Padding(
                              padding: EdgeInsets.all(4),
                              child: Text('背番号', textAlign: TextAlign.center)),
                        ],
                      ),
                      for (int i = 0; i < 5; i++)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: _buildPlayerField(
                                currentName: benchPlayers[i * 2]['name'],
                                onSelected: (value) =>
                                    benchPlayers[i * 2]['name'] = value,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: TextField(
                                decoration: const InputDecoration(
                                    border: InputBorder.none, hintText: '00'),
                                keyboardType: TextInputType.number,
                                onChanged: (v) =>
                                    benchPlayers[i * 2]['number'] = v,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: _buildPlayerField(
                                currentName: benchPlayers[i * 2 + 1]['name'],
                                onSelected: (value) =>
                                    benchPlayers[i * 2 + 1]['name'] = value,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: TextField(
                                decoration: const InputDecoration(
                                    border: InputBorder.none, hintText: '00'),
                                keyboardType: TextInputType.number,
                                onChanged: (v) =>
                                    benchPlayers[i * 2 + 1]['number'] = v,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('保存'),
                      onPressed: () async {
                        final dateKey = DateFormat('yyyy-MM-dd')
                            .format(widget.selectedDate);
                        final scheduleDoc = FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userUid)
                            .collection('schedules')
                            .doc(dateKey);

                        await scheduleDoc.set({
                          'startingMembers': startingMembers,
                          'benchPlayers': benchPlayers,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('オーダーを仮保存しました')),
                        );
                      },
                    ),
                  ),
                ],
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
}

String formatPercentage(num value) {
  double doubleValue = value.toDouble(); // intをdoubleに変換
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted; // 先頭の0を削除
}

String formatPercentageEra(num value) {
  double doubleValue = value.toDouble(); // num を double に変換
  return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
}
