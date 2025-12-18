import 'package:b_net/common/subscription_guard.dart';
import 'package:b_net/pages/private/game_dateile/Categorized_game_page.dart';
import 'package:b_net/pages/private/game_dateile/categorized_game_list_page.dart';
import 'package:b_net/pages/private/game_dateile/game_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivateGameDetail extends StatefulWidget {
  final String userUid;
  final bool hasActiveSubscription;
  const PrivateGameDetail({super.key, required this.userUid, required this.hasActiveSubscription});

  @override
  State<PrivateGameDetail> createState() => _PrivateGameDetailState();
}

class _PrivateGameDetailState extends State<PrivateGameDetail> {
  String selected = '球場、相手別';
  String selectedMonth = '';
  List<String> availableMonths = [];
  List<Map<String, dynamic>> allGames = [];
  List<Map<String, dynamic>> filteredGames = [];
  List<String> userPositions = [];
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
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .get();
    final data = doc.data();
    if (data != null && data.containsKey('positions')) {
      setState(() {
        userPositions = List<String>.from(data['positions']);
      });
    }
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
    if (!widget.hasActiveSubscription) {
      return const SubscriptionGuard(isLocked: true, initialPage: 4);
    }
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

  Widget _builinMoreDetaildStats() {
    final teamStats = teamLocationStats
        .where((s) => s['id'].toString().startsWith('team_'))
        .where((s) =>
            s['id'].toString().replaceFirst('team_', '').contains(searchQuery))
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

    final teamStatsToShow =
        showAllTeams ? teamStats : teamStats.take(5).toList();
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
                hintText: 'チーム・球場を検索',
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
          const Text('チーム別成績',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...teamStatsToShow.map((stat) {
            final teamName = stat['id'].replaceFirst('team_', '');
            final totalGames = stat['totalGames'] ?? 0;
            return ListTile(
              title: Text(teamName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '打率 ${formatPercentage(stat['battingAverage'] ?? 0)}'
                  '${userPositions.contains("投手") ? ' / 防御率 ${formatPercentageEra(stat['era'] ?? 0)}' : ''}'),
              trailing: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategorizedGameListPage(
                        userUid: widget.userUid,
                        categoryType: 'team',
                        categoryValue: teamName,
                        userPositions: userPositions,
                      ),
                    ),
                  );
                },
                child: Text(
                  '$totalGames試合',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategorizedGamePage(
                      userUid: widget.userUid,
                      statId: stat['id'],
                      userPositions: userPositions,
                    ),
                  ),
                );
              },
            );
          }),
          if (teamStats.length > 5)
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
            return ListTile(
              title: Text(locationName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '打率 ${formatPercentage(stat['battingAverage'] ?? 0)}'
                  '${userPositions.contains("投手") ? ' / 防御率 ${formatPercentageEra(stat['era'] ?? 0)}' : ''}'),
              trailing: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategorizedGameListPage(
                        userUid: widget.userUid,
                        categoryType: 'location',
                        categoryValue: locationName,
                        userPositions: userPositions,
                      ),
                    ),
                  );
                },
                child: Text(
                  '$totalGames試合',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategorizedGamePage(
                      userUid: widget.userUid,
                      statId: stat['id'],
                      userPositions: userPositions,
                    ),
                  ),
                );
              },
            );
          }),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameDetailPage(
                        gameData: game,
                        isPitcher: userPositions.contains('投手'),
                      ),
                    ),
                  );
                },
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
                              game['gameType'] ?? '（種類不明）',
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
                        const SizedBox(height: 4),

                        // 3行目: 打席結果（position - result）
                        if (game['atBats'] != null && game['atBats'] is List)
                          Wrap(
                            spacing: 8.0, // アイテム間の間隔
                            runSpacing: 4.0, // 折り返したときの縦の間隔
                            children:
                                (game['atBats'] as List).map<Widget>((atBat) {
                              final pos = atBat['position'] ?? '';
                              final res = atBat['result'] ?? '';
                              return Text(
                                '$posー$res',
                                style: const TextStyle(fontSize: 14),
                              );
                            }).toList(),
                          ),
                        // 投手なら投球回を表示
                        if (userPositions.contains('投手') &&
                            ((game['inningsThrow'] ?? 0) > 0 ||
                                (game['outFraction'] ?? '') != '')) ...[
                          const SizedBox(height: 8),
                          Text(
                            '投球回: ${game['inningsThrow']}${(game['outFraction'] != null && game['outFraction'] != '0' && game['outFraction'].toString().isNotEmpty) ? 'と${game['outFraction']}' : ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
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
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('games')
        .orderBy('gameDate', descending: true)
        .get();

    final List<Map<String, dynamic>> games = [];
    final Set<String> months = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['gameDate'] as Timestamp).toDate();
      final yearMonth =
          '${date.year}年${date.month.toString().padLeft(2, '0')}月';
      months.add(yearMonth);
      games.add({
        'opponent': data['opponent'] ?? '不明',
        'location': data['location'] ?? '不明',
        'gameType': data['gameType'] ?? '（種類不明）',
        'gameDate': date,
        'month': yearMonth,
        'atBats': data['atBats'] ?? [],
        'memo': data['memo'] ?? '',
        'steals': data['steals'] ?? 0,
        'rbis': data['rbis'] ?? 0,
        'runs': data['runs'] ?? 0,
        'putouts': data['putouts'] ?? 0,
        'assists': data['assists'] ?? 0,
        'errors': data['errors'] ?? 0,
        'inningsThrow': data['inningsThrow'] ?? 0,
        'outFraction': data['outFraction'] ?? '',
        'resultGame': data['resultGame'] ?? '',
        'isCompleteGame': data['isCompleteGame'] ?? false,
        'isShutoutGame': data['isShutoutGame'] ?? false,
        'isSave': data['isSave'] ?? false,
        'isHold': data['isHold'] ?? false,
        'appearanceType': data['appearanceType'] ?? '',
        'battersFaced': data['battersFaced'] ?? 0,
        'walks': data['walks'] ?? 0,
        'hitByPitch': data['hitByPitch'] ?? 0,
        'runsAllowed': data['runsAllowed'] ?? 0,
        'earnedRuns': data['earnedRuns'] ?? 0,
        'hitsAllowed': data['hitsAllowed'] ?? 0,
        'strikeouts': data['strikeouts'] ?? 0,
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
        .collection('users')
        .doc(widget.userUid)
        .collection('teamLocationStats')
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
