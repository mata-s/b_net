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
                    return GestureDetector(
                      onTap: () {},
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
                                    game['game_type'] ?? '（種類不明）',
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

                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                      '${game['score']?.toString() ?? '不明'} - ',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      '${game['runs_allowed']?.toString() ?? '不明'}',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text('試合結果: ${game['result'] ?? '不明'}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
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
