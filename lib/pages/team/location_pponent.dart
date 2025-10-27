import 'package:b_net/pages/team/team_game_details/categorized_game_list_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LocationOpponentPage extends StatefulWidget {
  final String teamId;

  const LocationOpponentPage({super.key, required this.teamId});

  @override
  State<LocationOpponentPage> createState() => _LocationOpponentPageState();
}

class _LocationOpponentPageState extends State<LocationOpponentPage> {
  Set<String> _expandedOpponentIds = {};
  String selected = '球場、相手別';
  String selectedMonth = '';
  List<String> availableMonths = [];
  List<Map<String, dynamic>> allGames = [];
  List<Map<String, dynamic>> filteredGames = [];
  List<Map<String, dynamic>> teamLocationStats = [];
  bool showAllTeams = false;
  bool showAllLocations = false;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = '${now.year}年${now.month.toString().padLeft(2, '0')}月';
    _fetchGames();
  }

  void _showCupertinoPicker(BuildContext context) {
    int initialIndex = availableMonths.indexOf(selectedMonth);
    String tempSelected = selectedMonth;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上部ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                const Text('年・月を選択',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedMonth = tempSelected;
                      _filterGames();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('選択'),
                ),
              ],
            ),
            const Divider(height: 1),
            SizedBox(
              height: 250,
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: initialIndex),
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  tempSelected = availableMonths[index];
                },
                children:
                    availableMonths.map((m) => Center(child: Text(m))).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '球場、相手別', label: Text('球場、相手別')),
              ButtonSegment(value: '試合一覧', label: Text('試合一覧')),
            ],
            selected: {selected},
            onSelectionChanged: (newSelection) {
              setState(() {
                selected = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          if (selected == '球場、相手別') _builinMoreDetaildStats(),
          if (selected == '試合一覧') Expanded(child: _buildDetaildStats()),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, double underlineWidth) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: underlineWidth,
              height: 1,
              color: Colors.black,
            ),
          ],
        ),
      ],
    );
  }

  Widget _builinMoreDetaildStats() {
    final opponentStats = teamLocationStats
        .where((s) => s['id'].toString().startsWith('opponent_'))
        .where((s) => s['id']
            .toString()
            .replaceFirst('opponent_', '')
            .contains(searchQuery))
        .toList()
      ..sort((a, b) => (b['totalGames'] ?? 0).compareTo(a['totalGames'] ?? 0));

    final locationStats = teamLocationStats
        .where((s) => s['id'].toString().startsWith('location_'))
        .where((s) => s['id']
            .toString()
            .replaceFirst('location_', '')
            .contains(searchQuery))
        .toList()
      ..sort((a, b) => (b['totalGames'] ?? 0).compareTo(a['totalGames'] ?? 0));

    final opponentStatsToShow =
        showAllTeams ? opponentStats : opponentStats.take(5).toList();
    final locationStatsToShow =
        showAllLocations ? locationStats : locationStats.take(5).toList();

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              focusNode: _searchFocusNode,
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                FocusScope.of(context).unfocus(); // キーボードを閉じる
                setState(() {
                  searchQuery = value;
                });
              },
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '相手・球場を検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('相手別成績',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...opponentStatsToShow.map((stat) {
            final opponentName = stat['id'].replaceFirst('opponent_', '');
            final totalGames = stat['totalGames'] ?? 0;
            final statId = stat['id'];
            final isExpanded = _expandedOpponentIds.contains(statId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(opponentName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isExpanded ? '閉じる' : 'もっと見る...',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategorizedGameListPage(
                            teamId: widget.teamId,
                            categoryType: 'opponent',
                            categoryValue: opponentName,
                          ),
                        ),
                      );
                    },
                    child:
                        Text('$totalGames試合', style: TextStyle(fontSize: 16)),
                  ),
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedOpponentIds.remove(statId);
                      } else {
                        _expandedOpponentIds.add(statId);
                      }
                    });
                  },
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn(
                                '勝利', '${stat['totalWins'] ?? 0}', 24),
                            _buildStatColumn(
                                '敗北', '${stat['totalLosses'] ?? 0}', 24),
                            _buildStatColumn(
                                '引き分け', '${stat['totalDraws'] ?? 0}', 36),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn(
                                '総得点', '${stat['totalScore'] ?? 0}', 36),
                            _buildStatColumn(
                                '総失点', '${stat['totalRunsAllowed'] ?? 0}', 36),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '勝率 ${formatPercentage(stat['winRate'] ?? 0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
          if (opponentStats.length > 5)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showAllTeams && opponentStats.isNotEmpty)
                    _ExpandedStats(stat: opponentStats.first),
                ],
              ),
            ),
          if (opponentStats.length > 5)
            TextButton(
              onPressed: () {
                setState(() {
                  showAllTeams = !showAllTeams;
                });
              },
              child: Text(showAllTeams ? '閉じる' : 'もっと見る'),
            ),
          const SizedBox(height: 24),
          const Text('球場別成績',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...locationStatsToShow.map((stat) {
            final locationName = stat['id'].replaceFirst('location_', '');
            final totalGames = stat['totalGames'] ?? 0;
            final statId = stat['id'];
            final isExpanded = _expandedOpponentIds.contains(statId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(locationName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isExpanded ? '閉じる' : 'もっと見る...',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategorizedGameListPage(
                            teamId: widget.teamId,
                            categoryType: 'location',
                            categoryValue: locationName,
                          ),
                        ),
                      );
                    },
                    child:
                        Text('$totalGames試合', style: TextStyle(fontSize: 16)),
                  ),
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedOpponentIds.remove(statId);
                      } else {
                        _expandedOpponentIds.add(statId);
                      }
                    });
                  },
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn(
                                '勝利', '${stat['totalWins'] ?? 0}', 24),
                            _buildStatColumn(
                                '敗北', '${stat['totalLosses'] ?? 0}', 24),
                            _buildStatColumn(
                                '引き分け', '${stat['totalDraws'] ?? 0}', 36),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn(
                                '総得点', '${stat['totalScore'] ?? 0}', 36),
                            _buildStatColumn(
                                '総失点', '${stat['totalRunsAllowed'] ?? 0}', 36),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '勝率 ${formatPercentage(stat['winRate'] ?? 0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
          // Removed redundant _ExpandedStats for locations
          if (locationStats.length > 5)
            TextButton(
              onPressed: () {
                setState(() {
                  showAllLocations = !showAllLocations;
                });
              },
              child: Text(showAllLocations ? '閉じる' : 'もっと見る'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetaildStats() {
    return Column(
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _showCupertinoPicker(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedMonth,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down,
                              size: 26, color: Colors.black),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  '${filteredGames.length}試合',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 12),
              ],
            )),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: filteredGames.length,
            itemBuilder: (context, index) {
              final game = filteredGames[index];
              return GestureDetector(
                onTap: () {},
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1行目: gameType と日付
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              game['game_type'] ?? '（種類不明）',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                            Text(
                              '${game['gameDate'].month}月${game['gameDate'].day}日',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // 2行目: VS相手 @球場
                        Text(
                          'VS ${game['opponent'] ?? '不明'} @${game['location'] ?? '場所不明'}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('${game['score']?.toString() ?? '不明'} - ',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${game['runs_allowed']?.toString() ?? '不明'}',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('試合結果: ${game['result'] ?? '不明'}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _fetchGames() async {
    // Fetch games from the correct team_games path in Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('team_games')
        .orderBy('game_date', descending: true)
        .get();

    final List<Map<String, dynamic>> games = [];
    final Set<String> months = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['game_date'] as Timestamp).toDate();
      final yearMonth =
          '${date.year}年${date.month.toString().padLeft(2, '0')}月';
      months.add(yearMonth);
      games.add({
        'opponent': data['opponent'] ?? '不明',
        'location': data['location'] ?? '不明',
        'game_type': data['game_type'] ?? '（種類不明）',
        'gameDate': date,
        'month': yearMonth,
        'score': data['score'] ?? 0,
        'runs_allowed': data['runs_allowed'] ?? 0,
        'result': data['result'] ?? '不明',
      });
    }

    setState(() {
      allGames = games;
      _fetchTeamLocationStats();
      availableMonths = months.toList()..sort((a, b) => b.compareTo(a));
      if (!availableMonths.contains(selectedMonth)) {
        selectedMonth = availableMonths.isNotEmpty ? availableMonths.first : '';
      }
      _filterGames();
    });
  }

  Future<void> _fetchTeamLocationStats() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('summary_stats')
        .get();

    final stats = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    setState(() {
      teamLocationStats = stats;
    });
  }

  void _filterGames() {
    setState(() {
      filteredGames =
          allGames.where((game) => game['month'] == selectedMonth).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

String formatPercentage(num value) {
  // num型にすることでintとdouble両方を受け入れられる
  double doubleValue = value.toDouble(); // intをdoubleに変換
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted;
}

String formatPercentageEra(num value) {
  double doubleValue = value.toDouble(); // num を double に変換
  return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
}

class _ExpandedStats extends StatelessWidget {
  final Map<String, dynamic> stat;

  const _ExpandedStats({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('得点合計: ${stat['totalScore'] ?? 0}'),
        Text('失点合計: ${stat['totalRunsAllowed'] ?? 0}'),
        Text('勝利: ${stat['totalWins'] ?? 0}'),
        Text('敗北: ${stat['totalLosses'] ?? 0}'),
        Text('引き分け: ${stat['totalDraws'] ?? 0}'),
        Text('勝率: ${formatPercentage(stat['winRate'] ?? 0)}'),
        const SizedBox(height: 8),
      ],
    );
  }
}
