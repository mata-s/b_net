import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategorizedGameListPage extends StatefulWidget {
  final String teamId;
  final String categoryType;
  final String categoryValue;


  const CategorizedGameListPage({
    Key? key,
    required this.teamId,
    required this.categoryType,
    required this.categoryValue,
  }) : super(key: key);

  @override
  _CategorizedGameListPageState createState() =>
      _CategorizedGameListPageState();
}

class _CategorizedGameListPageState extends State<CategorizedGameListPage> {
  List<Map<String, dynamic>> games = [];
  bool isLoading = true;
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

  Future<void> _fetchGames() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('teams')
        .doc(widget.teamId)
        .collection('team_games')
        .orderBy('game_date', descending: _sortDescending)
        .get();

    print('Fetched ${snapshot.docs.length} documents from Firestore');
    print(
        'CategoryType: ${widget.categoryType}, CategoryValue: ${widget.categoryValue}');

    final List<Map<String, dynamic>> filtered = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final opponent = (data['opponent'] ?? '').toString().trim().toLowerCase();
      final location = (data['location'] ?? '').toString().trim().toLowerCase();
      final categoryValue = widget.categoryValue.trim().toLowerCase();
      print('Doc ID: ${doc.id}, opponent=$opponent, location=$location');
      print('Checking game: opponent=${opponent}, location=${location}');
      final matchTeam =
          widget.categoryType == 'opponent' && opponent == categoryValue;
      final matchLocation =
          widget.categoryType == 'location' && location == categoryValue;
      print('MatchTeam: $matchTeam, MatchLocation: $matchLocation');

      if (matchTeam || matchLocation) {
        print('Matched game added: ${doc.id}');
        filtered.add({
          ...data,
          'id': doc.id,
          'gameDate': (data['game_date'] as Timestamp).toDate(),
        });
      }
    }

    setState(() {
      games = filtered;
      isLoading = false;
    });

    print('Filtered games count: ${filtered.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryValue),
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.sort),
            onSelected: (bool value) {
              setState(() {
                _sortDescending = value;
                isLoading = true;
              });
              _fetchGames();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: true,
                child: Text('新しい順'),
              ),
              const PopupMenuItem(
                value: false,
                child: Text('古い順'),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : games.isEmpty
              ? const Center(child: Text('試合がありません'))
              : ListView.builder(
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    final date = game['gameDate'] as DateTime;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            // 将来：試合詳細へ遷移
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
                                // 上段：種別 / 日付 + 右端アイコン
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
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.withOpacity(0.7),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // VS 相手
                                Row(
                                  children: [
                                    const Icon(Icons.sports_baseball, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'VS ${game['opponent'] ?? '不明'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // 球場
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
                                Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.6)),
                                const SizedBox(height: 12),

                                // スコア + 結果（チップ）
                                Row(
                                  children: [
                                    Text(
                                      '${game['score'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        'ー',
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(
                                      '${game['runs_allowed'] ?? '-'}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
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
    );
  }
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
