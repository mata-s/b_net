import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TeamRankingPage extends StatefulWidget {
  final String teamId;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const TeamRankingPage({
    super.key,
    required this.teamId,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  @override
  _TeamRankingPageState createState() => _TeamRankingPageState();
}

class _TeamRankingPageState extends State<TeamRankingPage> {
  late Future<List<Map<String, dynamic>>> _battingAverageRanking;
  late Future<List<Map<String, dynamic>>> _homeRunRanking;
  late Future<List<Map<String, dynamic>>> _onBasePercentageRanking;
  late Future<List<Map<String, dynamic>>> _rbisRanking;
  late Future<List<Map<String, dynamic>>> _sluggingPercentageRanking;
  late Future<List<Map<String, dynamic>>> _stealsRanking;
  late Future<List<Map<String, dynamic>>> _eraRanking;
  late Future<List<Map<String, dynamic>>> _strikeoutsRanking;
  late Future<List<Map<String, dynamic>>> _winRateRanking;
  late Future<List<Map<String, dynamic>>> _holdsRanking;
  late Future<List<Map<String, dynamic>>> _savesRanking;
  late String selectedPeriodFilter;

  @override
  void initState() {
    super.initState();
    selectedPeriodFilter = widget.selectedPeriodFilter.isEmpty
        ? '今年'
        : widget.selectedPeriodFilter;
    _battingAverageRanking = _fetchRankingData('battingAverage', 'batting');
    _homeRunRanking = _fetchRankingData('homeRuns', 'batting');
    _onBasePercentageRanking = _fetchRankingData('onBasePercentage', 'batting');
    _rbisRanking = _fetchRankingData('rbis', 'batting');
    _sluggingPercentageRanking =
        _fetchRankingData('sluggingPercentage', 'batting');
    _stealsRanking = _fetchRankingData('steals', 'batting');

    _eraRanking = _fetchRankingData('era', 'pitching');
    _strikeoutsRanking = _fetchRankingData('strikeouts', 'pitching');
    _winRateRanking = _fetchRankingData('winRate', 'pitching');
    _holdsRanking = _fetchRankingData('holds', 'pitching');
    _savesRanking = _fetchRankingData('saves', 'pitching');
  }

  @override
  void didUpdateWidget(covariant TeamRankingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriodFilter != oldWidget.selectedPeriodFilter ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      setState(() {
        selectedPeriodFilter = widget.selectedPeriodFilter;
        _battingAverageRanking = _fetchRankingData('battingAverage', 'batting');
        _homeRunRanking = _fetchRankingData('homeRuns', 'batting');
        _onBasePercentageRanking =
            _fetchRankingData('onBasePercentage', 'batting');
        _rbisRanking = _fetchRankingData('rbis', 'batting');
        _sluggingPercentageRanking =
            _fetchRankingData('sluggingPercentage', 'batting');
        _stealsRanking = _fetchRankingData('steals', 'batting');

        _eraRanking = _fetchRankingData('era', 'pitching');
        _strikeoutsRanking = _fetchRankingData('strikeouts', 'pitching');
        _winRateRanking = _fetchRankingData('winRate', 'pitching');
        _holdsRanking = _fetchRankingData('holds', 'pitching');
        _savesRanking = _fetchRankingData('saves', 'pitching');
      });
    }
  }

  /// **Firestoreからデータを取得**
  Future<List<Map<String, dynamic>>> _fetchRankingData(
      String rankingType, String category) async {
    try {
      String documentId = _getDocumentId();
      final docSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('rankings')
          .doc(documentId)
          .get();

      if (!docSnapshot.exists) {
        print("⚠️ Firestoreにドキュメントが存在しません: $documentId");
        return [];
      }

      final data = docSnapshot.data();

      if (data == null) {
        print("⚠️ データが `null` です: $documentId");
        return [];
      }

      if (!data.containsKey('rankings')) {
        print("⚠️ 'rankings' キーが存在しません: $documentId");
        return [];
      }

      final rankingsCategory = data['rankings'][category];
      if (rankingsCategory == null ||
          !rankingsCategory.containsKey(rankingType)) {
        print("⚠️ 'rankings.$category.$rankingType' のデータが見つかりません");
        return [];
      }

      List<dynamic> rankings = rankingsCategory[rankingType];
      List<Map<String, dynamic>> rankingList =
          rankings.cast<Map<String, dynamic>>();

      rankingList.sort((a, b) {
        final rankA = a['rank'];
        final rankB = b['rank'];

        if (rankA == null && rankB == null) return 0;
        if (rankA == null) return 1;
        if (rankB == null) return -1;
        return rankA.compareTo(rankB);
      });

      return rankingList;
    } catch (e) {
      print('🔥Firestoreデータ取得エラー ($rankingType - $category): $e');
      return [];
    }
  }

  /// **FirestoreのドキュメントIDを取得**
  String _getDocumentId() {
    String year = widget.startDate.year.toString();
    String month = widget.startDate.month.toString();
    String gameType = widget.selectedGameTypeFilter;
    String docId;

    if (selectedPeriodFilter == '通算') {
      docId = gameType == '全試合'
          ? 'results_stats_all'
          : 'results_stats_${gameType}_all';
    } else if (selectedPeriodFilter == '今月' || selectedPeriodFilter == '先月') {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_$month'
          : 'results_stats_${year}_${month}_$gameType';
    } else if (selectedPeriodFilter == '今年' ||
        selectedPeriodFilter == '去年' ||
        selectedPeriodFilter == '年を選択') {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_all'
          : 'results_stats_${year}_${gameType}_all';
    } else if (selectedPeriodFilter == '年を選択' || widget.yearOnly) {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_all'
          : 'results_stats_${year}_${gameType}_all';
    } else {
      docId = 'results_stats_${year}_$month';
    }

    print("📌 取得するFirestoreドキュメントID: $docId");
    return docId;
  }

  String formatBattingAverage(double value) {
    String formatted = value.toStringAsFixed(3);
    return formatted.startsWith("0")
        ? formatted.replaceFirst("0", "")
        : formatted;
  }

  String formatPercentageEra(num value) {
    double doubleValue = value.toDouble(); // num を double に変換
    return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildRankingSection("打率", _battingAverageRanking, (player) {
              final atBats = player['atBats'] ?? 0;
              final hits = player['hits'] ?? 0;
              final battingAverage =
                  formatBattingAverage(player['battingAverage'] ?? 0.0);
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '打率 $battingAverage ($atBats - $hits) ',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            _buildRankingSection("ホームラン", _homeRunRanking, (player) {
              final homeRuns = player['totalHomeRuns'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: 'ホームラン数: $homeRuns',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            _buildRankingSection("出塁率", _onBasePercentageRanking, (player) {
              final onBasePercentage =
                  formatBattingAverage(player['onBasePercentage'] ?? 0.0);
              final totalBats = player['totalBats'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '出塁率 $onBasePercentage\n',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: '打席: $totalBats',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
            _buildRankingSection("打点", _rbisRanking, (player) {
              final totalRbis = player['totalRbis'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '打点: $totalRbis点',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            _buildRankingSection("長打率", _sluggingPercentageRanking, (player) {
              final sluggingPercentage =
                  formatBattingAverage(player['sluggingPercentage'] ?? 0.0);
              final total1hits = player['total1hits'] ?? 0;
              final total2hits = player['total2hits'] ?? 0;
              final total3hits = player['total3hits'] ?? 0;
              final totalHomeRuns = player['totalHomeRuns'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '長打率 $sluggingPercentage\n',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                        text:
                            '単打:$total1hits 二塁打:$total2hits 三塁打:$total3hits 本塁打:$totalHomeRuns',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              );
            }),
            _buildRankingSection("盗塁", _stealsRanking, (player) {
              final totalSteals = player['totalSteals'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '盗塁: $totalSteals',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            _buildRankingSection("防御率", _eraRanking, (player) {
              final era = formatPercentageEra(player['era'] ?? 0.0);
              final totalInningsPitched =
                  (player['totalInningsPitched'] ?? 0.0).toStringAsFixed(1);
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '防御率 $era\n',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: '投球回: $totalInningsPitched',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
            _buildRankingSection("奪三振", _strikeoutsRanking, (player) {
              final totalPStrikeouts = player['totalPStrikeouts'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '奪三振: $totalPStrikeouts',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
            _buildRankingSection("勝率", _winRateRanking, (player) {
              final winRate = formatBattingAverage(player['winRate'] ?? 0.0);
              final totalAppearances = player['totalAppearances'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: '勝率 $winRate\n',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: '登板数: $totalAppearances',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
            _buildRankingSection("ホールドポイント", _holdsRanking, (player) {
              final totalHoldPoints = player['totalHoldPoints'] ?? 0;
              final totalAppearances = player['totalAppearances'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: 'ホールドポイント: $totalHoldPoints\n',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: '登板数: $totalAppearances',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
            _buildRankingSection("セーブ", _savesRanking, (player) {
              final totalSaves = player['totalSaves'] ?? 0;
              final totalAppearances = player['totalAppearances'] ?? 0;
              return RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style, // ✅ 基本のスタイルを適用
                  children: [
                    TextSpan(
                        text: 'セーブ: $totalSaves\n',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: '登板数: $totalAppearances',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// **ランキングセクションを作成**
  Widget _buildRankingSection(
    String title,
    Future<List<Map<String, dynamic>>> rankingFuture,
    Widget Function(Map<String, dynamic>)
        statFormatter, // ✅ String → Widget に変更
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: rankingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('データが見つかりません'));
        }

        final rankings = snapshot.data!;
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ExpansionTile(
            title: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rankings.length,
                itemBuilder: (context, index) {
                  final player = rankings[index];
                  final rank = player['rank'];
                  return Card(
                    elevation: 2,
                    margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                    child: ListTile(
                      leading: _buildRankIcon(rank),
                      title: Text(
                        '${player['name'] ?? '不明'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          statFormatter(player), // ✅ `Text` ではなく `Widget` に変更
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// **順位アイコン**
  Widget _buildRankIcon(int? rank) {
    if (rank == null) {
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Text('-',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    IconData crownIcon = FontAwesomeIcons.crown;
    Color crownColor;

    switch (rank) {
      case 1:
        crownColor = Colors.yellow;
        break;
      case 2:
        crownColor = Colors.grey;
        break;
      case 3:
        crownColor = Colors.brown;
        break;
      default:
        return CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Text('$rank',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        FaIcon(crownIcon, color: crownColor, size: 36),
        Positioned(
          top: 10,
          child: Text(
            '$rank',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
