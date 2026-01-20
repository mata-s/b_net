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
                FocusScope.of(context).unfocus();
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
                  title: Text(
                    opponentName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isExpanded ? '閉じる' : 'もっと見る...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
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
                    child: Text(
                      '$totalGames試合',
                      style: const TextStyle(fontSize: 16),
                    ),
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: isExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _ExpandedDetailPanel(stat: stat),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }).toList(),
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
                  title: Text(
                    locationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isExpanded ? '閉じる' : 'もっと見る...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
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
                    child: Text(
                      '$totalGames試合',
                      style: const TextStyle(fontSize: 16),
                    ),
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: isExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _ExpandedDetailPanel(stat: stat),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            );
          }).toList(),
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
              final date = game['gameDate'] as DateTime;

return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  child: Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // TODO: 詳細へ遷移する場合はここに実装
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.06,
              ),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MiniPill(
                  icon: Icons.local_offer_outlined,
                  label: (game['game_type'] ?? '（種類不明）').toString(),
                ),
                const SizedBox(width: 8),
                _MiniPill(
                  icon: Icons.calendar_today_outlined,
                  label: '${date.year}/${date.month}/${date.day}',
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.grey.withOpacity(0.7)),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.sports_baseball, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'VS ${game['opponent'] ?? '不明'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (game['location'] ?? '場所不明').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.6),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Text(
                  '${game['score']?.toString() ?? '-'}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('ー', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                Text(
                  '${game['runs_allowed']?.toString() ?? '-'}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                _ResultChip(label: (game['result'] ?? '不明').toString()),
              ],
            ),
          ],
        ),
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

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;

  const _ResultChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;

    final v = label.trim();
    if (v.contains('勝')) {
      bg = cs.primary.withOpacity(isDark ? 0.25 : 0.12);
      fg = cs.primary;
    } else if (v.contains('負')) {
      bg = cs.error.withOpacity(isDark ? 0.25 : 0.12);
      fg = cs.error;
    } else if (v.contains('引') || v.contains('分')) {
      bg = cs.tertiary.withOpacity(isDark ? 0.25 : 0.12);
      fg = cs.tertiary;
    } else {
      bg = (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.10 : 0.06);
      fg = cs.onSurface.withOpacity(0.8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _ExpandedDetailPanel extends StatelessWidget {
  final Map<String, dynamic> stat;

  const _ExpandedDetailPanel({required this.stat});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final wins = (stat['totalWins'] ?? 0).toString();
    final losses = (stat['totalLosses'] ?? 0).toString();
    final draws = (stat['totalDraws'] ?? 0).toString();
    final score = (stat['totalScore'] ?? 0).toString();
    final runsAllowed = (stat['totalRunsAllowed'] ?? 0).toString();
    final winRate = formatPercentage(stat['winRate'] ?? 0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.03),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MiniPill(
                icon: Icons.emoji_events_outlined,
                label: '勝率 $winRate',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '勝 $wins / 負 $losses / 分 $draws',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: '総得点',
                  value: score,
                  icon: Icons.add_chart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: '総失点',
                  value: runsAllowed,
                  icon: Icons.remove_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: '勝利',
                  value: wins,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: '敗北',
                  value: losses,
                  icon: Icons.highlight_off,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: '引分',
                  value: draws,
                  icon: Icons.horizontal_rule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.035),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurface.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
