import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'game_detail_page.dart';

class CategorizedGameListPage extends StatefulWidget {
  final String userUid;
  final String categoryType; // 'team' or 'location'
  final String categoryValue;
  final List<String> userPositions;

  const CategorizedGameListPage({
    super.key,
    required this.userUid,
    required this.categoryType,
    required this.categoryValue,
    required this.userPositions,
  });

  @override
  State<CategorizedGameListPage> createState() =>
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
        .collection('users')
        .doc(widget.userUid)
        .collection('games')
        .orderBy('gameDate', descending: _sortDescending)
        .get();

    final List<Map<String, dynamic>> filtered = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final opponent = data['opponent'];
      final location = data['location'];
      final matchTeam = widget.categoryType == 'team' &&
          opponent != null &&
          opponent == widget.categoryValue;
      final matchLocation = widget.categoryType == 'location' &&
          location != null &&
          location == widget.categoryValue;

      if (matchTeam || matchLocation) {
        filtered.add({
          ...data,
          'id': doc.id,
          'gameDate': (data['gameDate'] as Timestamp).toDate(),
          'positions': data['positions'] ?? [],
        });
      }
    }

    setState(() {
      games = filtered;
      isLoading = false;
    });
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
                    return GestureDetector(
                      onTap: () {
                        final isPitcher = widget.userPositions.contains('投手');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GameDetailPage(
                              gameData: game,
                              isPitcher: isPitcher,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    game['gameType'] ?? '（種類不明）',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                  Text(
                                    '${date.year}年${date.month}月${date.day}日',
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
                              if (game['atBats'] != null &&
                                  game['atBats'] is List)
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: (game['atBats'] as List)
                                      .map<Widget>((atBat) {
                                    final pos = atBat['position'] ?? '';
                                    final res = atBat['result'] ?? '';
                                    return Text(
                                      '$posー$res',
                                      style: const TextStyle(fontSize: 14),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
