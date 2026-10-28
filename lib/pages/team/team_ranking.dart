import 'package:b_net/pages/team/team_subscription_guard.dart';
import 'package:flutter/material.dart';
import 'package:b_net/widgets/b_net_floating_tab_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TeamRankingPage extends StatefulWidget {
  final String teamId;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;
  final bool hasActiveTeamSubscription;

  const TeamRankingPage(
      {super.key,
      required this.teamId,
      required this.selectedPeriodFilter,
      required this.selectedGameTypeFilter,
      required this.startDate,
      required this.endDate,
      required this.yearOnly,
      required this.hasActiveTeamSubscription});

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
  late Future<Map<String, dynamic>?> _latestMonthlyMvp;
  late Future<List<Map<String, dynamic>>> _recentFiveStats;
  late String selectedPeriodFilter;
  bool _showRecentFive = false;

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
    _latestMonthlyMvp = _fetchLatestMonthlyMvp();
    _recentFiveStats = _fetchRecentFiveStats();
  }

  @override
  void didUpdateWidget(covariant TeamRankingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.teamId != oldWidget.teamId) {
      setState(() {
        _latestMonthlyMvp = _fetchLatestMonthlyMvp();
        _recentFiveStats = _fetchRecentFiveStats();
      });
    }
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

  Future<Map<String, dynamic>?> _fetchLatestMonthlyMvp() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .collection('mvp_month')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final results = List<Map<String, dynamic>>.from(data['result'] ?? []);
        if (data['isTallied'] == true && results.isNotEmpty) {
          results.sort((a, b) =>
              ((b['votes'] as num?) ?? 0).compareTo((a['votes'] as num?) ?? 0));
          return {...data, 'id': doc.id, 'result': results};
        }
      }
    } catch (e) {
      debugPrint('月間MVP取得エラー: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchRecentFiveStats() async {
    try {
      final teamDoc = await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .get();
      final memberIds = List<String>.from(teamDoc.data()?['members'] ?? []);
      return Future.wait(memberIds.map((uid) async {
        final results = await Future.wait([
          FirebaseFirestore.instance.collection('users').doc(uid).get(),
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('games')
              .orderBy('gameDate', descending: true)
              .limit(5)
              .get(),
        ]);
        final user = results[0] as DocumentSnapshot<Map<String, dynamic>>;
        final games = results[1] as QuerySnapshot<Map<String, dynamic>>;
        var atBats = 0;
        var hits = 0;
        var rbis = 0;
        var strikeouts = 0;
        var earnedRuns = 0;
        var innings = 0.0;
        const hitResults = {'内野安打', '単打', '二塁打', '三塁打', '本塁打'};
        const excludedAtBats = {'四球', '死球', '犠打', '犠飛', '打撃妨害'};

        for (final gameDoc in games.docs) {
          final game = gameDoc.data();
          for (final raw in List<dynamic>.from(game['atBats'] ?? [])) {
            final result = raw is Map ? raw['result']?.toString() ?? '' : '';
            if (result.isNotEmpty && !excludedAtBats.contains(result)) atBats++;
            if (hitResults.contains(result)) hits++;
          }
          rbis += ((game['rbis'] as num?) ?? 0).toInt();
          strikeouts += ((game['strikeouts'] as num?) ?? 0).toInt();
          earnedRuns += ((game['earnedRuns'] as num?) ?? 0).toInt();
          final inningsValue = game['inningsThrow'];
          innings += inningsValue is num
              ? inningsValue.toDouble()
              : double.tryParse(inningsValue?.toString() ?? '') ?? 0;
          final fraction = game['outFraction']?.toString() ?? '';
          if (fraction == '1/3') innings += 1 / 3;
          if (fraction == '2/3') innings += 2 / 3;
        }
        return {
          'id': uid,
          'name': user.data()?['name'] ?? '名前未設定',
          'games': games.docs.length,
          'atBats': atBats,
          'hits': hits,
          'rbis': rbis,
          'strikeouts': strikeouts,
          'earnedRuns': earnedRuns,
          'innings': innings,
          'battingAverage': atBats > 0 ? hits / atBats : null,
          'era': innings > 0 ? earnedRuns * 7 / innings : null,
        };
      }));
    } catch (e) {
      debugPrint('直近5試合集計エラー: $e');
      return [];
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
    if (!widget.hasActiveTeamSubscription) {
      return TeamSubscriptionGuard(
        isLocked: true,
        initialPage: 5,
        teamId: widget.teamId,
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: BNetFloatingTabBar.bodyClearance(context),
        ),
        child: Column(
          children: [
            _buildLatestMvpCard(),
            _buildViewSelector(),
            if (_showRecentFive)
              _buildRecentFiveView()
            else ...[
              _buildRankingSection("打率", _battingAverageRanking, (player) {
                final atBats = player['atBats'] ?? 0;
                final hits = player['hits'] ?? 0;
                final battingAverage = formatBattingAverage(
                  (player['battingAverage'] as num?)?.toDouble() ?? 0.0,
                );
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
                final onBasePercentage = formatBattingAverage(
                  (player['onBasePercentage'] as num?)?.toDouble() ?? 0.0,
                );
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
                final sluggingPercentage = formatBattingAverage(
                  (player['sluggingPercentage'] as num?)?.toDouble() ?? 0.0,
                );
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
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
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
                final era = formatPercentageEra(player['era'] ?? 0);
                final innings =
                    (player['totalInningsPitched'] as num?)?.toDouble() ?? 0.0;
                final totalInningsPitched = innings.toStringAsFixed(1);
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
                final winRate = formatBattingAverage(
                  (player['winRate'] as num?)?.toDouble() ?? 0.0,
                );
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
          ],
        ),
      ),
    );
  }

  Widget _buildLatestMvpCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _latestMonthlyMvp,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting ||
            data == null) {
          return const SizedBox.shrink();
        }
        final results = List<Map<String, dynamic>>.from(data['result'] ?? []);
        if (results.isEmpty) return const SizedBox.shrink();
        final winner = results.first;
        final year = data['year'];
        final month = data['month'];
        final period = year != null && month != null ? '$year年$month月' : '最新';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF5D6), Color(0xFFFFE5A3)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                child: FaIcon(FontAwesomeIcons.crown,
                    color: Color(0xFFE2A900), size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$period 月間MVP',
                        style: TextStyle(
                            color: Colors.brown.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(winner['name']?.toString() ?? '名前未設定',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if ((data['theme']?.toString() ?? '').isNotEmpty)
                      Text(data['theme'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.brown.shade600)),
                  ],
                ),
              ),
              Text('${winner['votes'] ?? 0}票',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('期間ランキング')),
          ButtonSegment(value: true, label: Text('最近5試合')),
        ],
        selected: {_showRecentFive},
        showSelectedIcon: false,
        onSelectionChanged: (value) {
          setState(() => _showRecentFive = value.first);
        },
      ),
    );
  }

  Widget _buildRecentFiveView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recentFiveStats,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          );
        }
        final players = snapshot.data ?? [];
        if (players.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Text('直近の試合データがありません'),
          );
        }
        final average = players
            .where((p) => p['battingAverage'] != null)
            .toList()
          ..sort((a, b) => (b['battingAverage'] as num)
              .compareTo(a['battingAverage'] as num));
        final hits = players.where((p) => (p['atBats'] as int) > 0).toList()
          ..sort((a, b) => (b['hits'] as int).compareTo(a['hits'] as int));
        final rbis = players.where((p) => (p['games'] as int) > 0).toList()
          ..sort((a, b) => (b['rbis'] as int).compareTo(a['rbis'] as int));
        final era = players.where((p) => p['era'] != null).toList()
          ..sort((a, b) => (a['era'] as num).compareTo(b['era'] as num));
        final strikeouts = players
            .where((p) => (p['innings'] as double) > 0)
            .toList()
          ..sort((a, b) =>
              (b['strikeouts'] as int).compareTo(a['strikeouts'] as int));

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('選手ごとの最新5試合を集計',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
            _buildRecentSection(
                '打率',
                average,
                (p) =>
                    '${formatBattingAverage((p['battingAverage'] as num).toDouble())}  (${p['atBats']}-${p['hits']})'),
            _buildRecentSection('安打', hits, (p) => '${p['hits']}安打'),
            _buildRecentSection('打点', rbis, (p) => '${p['rbis']}打点'),
            _buildRecentSection(
                '防御率',
                era,
                (p) =>
                    '${formatPercentageEra(p['era'] as num)}  ${_formatInnings(p['innings'] as double)}回'),
            _buildRecentSection(
                '奪三振', strikeouts, (p) => '${p['strikeouts']}奪三振'),
          ],
        );
      },
    );
  }

  String _formatInnings(double innings) {
    final full = innings.floor();
    final fraction = innings - full;
    if (fraction > 0.6) return '$full 2/3';
    if (fraction > 0.2) return '$full 1/3';
    return '$full';
  }

  Widget _buildRecentSection(String title, List<Map<String, dynamic>> players,
      String Function(Map<String, dynamic>) valueBuilder) {
    if (players.isEmpty) return const SizedBox.shrink();
    final visible = players.take(5).toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: title == '打率',
        title: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        children: List.generate(visible.length, (index) {
          final player = visible[index];
          return ListTile(
            dense: true,
            leading: _buildRankIcon(index + 1),
            title: Text(player['name']?.toString() ?? '名前未設定',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${player['games']}試合'),
            trailing: Text(valueBuilder(player),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }),
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
