import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TeamPerformancePage extends StatelessWidget {
  final String teamId;
  final String selectedPeriodFilter; // '今月', '先月', '今年', '去年', '通算'
  final String selectedGameTypeFilter; // '全試合', '練習試合', '公式戦'
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const TeamPerformancePage({
    super.key,
    required this.teamId,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  Future<Map<String, dynamic>> getTeamStats() async {
    try {
      String year = startDate.year.toString();
      String month = startDate.month.toString();
      String gameType = selectedGameTypeFilter;

      // ドキュメントIDを期間と試合フィルタに基づいて生成
      String docId;

      if (yearOnly) {
        if (gameType != '全試合') {
          docId = 'results_stats_${year}_${gameType}_all';
        } else {
          docId = 'results_stats_${year}_all';
        }
      } else if (selectedPeriodFilter == '通算') {
        if (gameType == '全試合') {
          docId = 'results_stats_all'; // 通算、全試合
        } else {
          docId = 'results_stats_${gameType}_all'; // 通算、練習試合or公式戦
        }
      } else if (selectedPeriodFilter == '今月' || selectedPeriodFilter == '先月') {
        if (gameType != '全試合') {
          docId =
              'results_stats_${year}_${month}_$gameType'; // 今月or先月、練習試合or公式戦
        } else {
          docId = 'results_stats_${year}_$month'; // 今月or先月、全試合
        }
      } else if (selectedPeriodFilter == '今年' || selectedPeriodFilter == '去年') {
        if (gameType != '全試合') {
          docId = 'results_stats_${year}_${gameType}_all'; // 今年or去年、練習試合or公式戦
        } else {
          docId = 'results_stats_${year}_all'; // 今年or去年、全試合
        }
      } else {
        // その他の期間の場合
        docId = 'results_stats_${year}_$month'; // デフォルトで今月or先月
      }

      // Firestoreからデータを取得
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .collection('stats')
          .doc(docId)
          .get();

      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      } else {
        throw Exception("データが存在しません");
      }
    } catch (e) {
      throw Exception("データ取得エラー: $e");
    }
  }

  Future<Map<String, dynamic>> getTeamMeta() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teams')
          .doc(teamId)
          .get();
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      } else {
        throw Exception("チーム情報が存在しません");
      }
    } catch (e) {
      throw Exception("チーム情報取得エラー: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final double shortestSide = MediaQuery.of(context).size.shortestSide;
    final bool isTablet = shortestSide >= 600;
    final double horizontalPadding = 16.0 + (isTablet ? 60.0 : 0.0);
    final double maxContentWidth = isTablet ? 720.0 : double.infinity;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait([getTeamStats(), getTeamMeta()]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // データがない場合は "データがありません" を表示
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('データがありません'));
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

          final stats = snapshot.data![0];
          final meta = snapshot.data![1];
          final currentWinStreak = meta['currentWinStreak'] ?? 0;
          // gameDate が null の場合の対策
          DateTime? gameDate;
          if (stats.containsKey('gameDate') && stats['gameDate'] != null) {
            gameDate = (stats['gameDate'] as Timestamp).toDate();
          }

          if (gameDate == null) {
            return const Center(child: Text('試合データがありません'));
          }
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentWinStreak >= 2)
                    Text(
                      '$currentWinStreak 連勝中！',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  Text(
                    '初めて記録した日: ${DateFormat('yyyy/MM/dd').format(gameDate)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: Colors.white,
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '総試合 ${stats['totalGames']}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            color: Colors.white, // 内部カードの背景色
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border:
                                            Border.all(color: Colors.orange),
                                        color: Colors.orange,
                                      ),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        child: Text(
                                          '勝率',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${formatPercentage(stats['winRate'] ?? 0)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn(
                                  '勝利', '${stats['totalWins']}', 80),
                              _buildStatColumn(
                                  '敗北', '${stats['totalLosses']}', 80),
                              _buildStatColumn(
                                  '引き分け', '${stats['totalDraws']}', 80),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatColumn(
                                  '総得点', '${stats['totalScore']}', 80),
                              SizedBox(width: 20),
                              _buildStatColumn(
                                  '総失点', '${stats['totalRunsAllowed']}', 80),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // 外側のカード
                  if (stats.containsKey('totalBats') &&
                      stats['totalBats'] != null &&
                      stats['totalBats'] > 0) ...[
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: Colors.white,
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '総打席 ${stats['totalBats']}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              color: Colors.white, // 内部カードの背景色
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border:
                                              Border.all(color: Colors.orange),
                                          color: Colors.orange,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          child: Text(
                                            '打率',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  '${formatPercentage(stats['battingAverage'] ?? 0)} ',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  '(${stats['atBats']} - ${stats['hits']})',
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '打点', '${stats['totalRbis']}', 80),
                                _buildStatColumn('犠打',
                                    '${stats['totalAllBuntSuccess']}', 80),
                                _buildStatColumn(
                                    '犠飛', '${stats['totalSacrificeFly']}', 80),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '四球', '${stats['totalFourBalls']}', 80),
                                _buildStatColumn(
                                    '死球', '${stats['totalHitByAPitch']}', 80),
                                _buildStatColumn(
                                    '盗塁', '${stats['totalSteals']}', 80),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatColumn(
                                    '出塁率',
                                    formatPercentage(
                                        stats['onBasePercentage'] ?? 0),
                                    100),
                                SizedBox(width: 20),
                                _buildStatColumn(
                                    '長打率',
                                    formatPercentage(
                                        stats['sluggingPercentage'] ?? 0),
                                    100),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatColumn('ops',
                                    formatPercentage(stats['ops'] ?? 0), 100),
                                SizedBox(width: 20),
                                _buildStatColumn('rc',
                                    formatPercentage(stats['rc'] ?? 0), 100),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Card(
                          color: Colors.white,
                          elevation: 5,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _classification('安打', '${stats['hits']}', 60),
                                const SizedBox(height: 10),
                                Text(
                                  '内野安打: ${stats['totalInfieldHits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '単打: ${stats['total1hits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '二塁打: ${stats['total2hits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '三塁打: ${stats['total3hits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '本塁打: ${stats['totalHomeRuns']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          color: Colors.white,
                          elevation: 5,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _classification(
                                    '凡打', '${stats['totalOuts']}', 60),
                                const SizedBox(height: 10),
                                Text('ゴロ: ${stats['totalGrounders']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('ライナー: ${stats['totalLiners']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('フライ: ${stats['totalFlyBalls']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('併殺打: ${stats['totalDoublePlays']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('失策出塁: ${stats['totalErrorReaches']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('守備妨害: ${stats['totalInterferences']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('バント失敗: ${stats['totalBuntOuts']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Card(
                      color: Colors.white,
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '三振の詳細',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '空振り三振',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${stats['totalSwingingStrikeouts']}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '見逃し三振',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${stats['totalOverlookStrikeouts']}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '振り逃げ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${stats['totalSwingAwayStrikeouts']}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'スリーバント失敗',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${stats['totalThreeBuntFailures']}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Color(0xFF2C2C2C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (stats.containsKey('totalInningsPitched') &&
                      stats['totalInningsPitched'] != null &&
                      stats['totalInningsPitched'] > 0) ...[
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: Colors.white,
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '投球回 ${(stats['totalInningsPitched'] as num).toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              color: Colors.white, // 内部カードの背景色
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border:
                                              Border.all(color: Colors.orange),
                                          color: Colors.orange,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          child: Text(
                                            '防御率',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${formatPercentageEra(stats['era'] ?? 0)}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '奪三振', '${stats['totalPStrikeouts']}', 80),
                                _buildStatColumn(
                                    '与四球', '${stats['totalWalks']}', 80),
                                _buildStatColumn(
                                    '与死球', '${stats['totalHitByPitch']}', 80),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '被安打', '${stats['totalHitsAllowed']}', 80),
                                _buildStatColumn(
                                    '打者', '${stats['totalBattersFaced']}', 80),
                                _buildStatColumn(
                                    '自責点', '${stats['totalEarnedRuns']}', 80),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn('被本塁打',
                                    '${stats['totalHomeRunsAllowed']}', 80),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (stats.containsKey('fieldingPercentage') &&
                      stats['fieldingPercentage'] != null) ...[
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      color: Colors.white,
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              color: Colors.white, // 内部カードの背景色
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border:
                                              Border.all(color: Colors.orange),
                                          color: Colors.orange,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          child: Text(
                                            '守備率',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${formatPercentageEra(stats['fieldingPercentage'] ?? 0)}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '捕殺', '${stats['totalAssists']}', 80),
                                _buildStatColumn(
                                    '刺殺', '${stats['totalPutouts']}', 80),
                                _buildStatColumn(
                                    '失策', '${stats['totalErrors']}', 80),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '盗塁企図',
                                    '${stats['totalStolenBaseAttempts'] ?? 0}',
                                    60),
                                _buildStatColumn('盗塁刺',
                                    '${stats['totalCaughtStealing'] ?? 0}', 60),
                                _buildStatColumn(
                                    '阻止率',
                                    '${formatPercentage(stats['catcherStealingRate'] ?? 0)}',
                                    60),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
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

Widget _buildStatColumn(String label, String value, double underlineWidth) {
  return Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 18,
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
            width: underlineWidth, // 下線の長さを受け取った値に設定
            height: 1,
            color: Colors.black,
          ),
        ],
      ),
    ],
  );
}

Widget _classification(String label, String value, double underlineWidth) {
  return Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
        ),
      ),
      Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: underlineWidth, // 下線の長さを受け取った値に設定
            height: 1,
            color: Colors.black,
          ),
        ],
      ),
    ],
  );
}
