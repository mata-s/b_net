import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BattingTab extends StatelessWidget {
  final String userUid;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const BattingTab({
    super.key,
    required this.userUid,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  Future<Map<String, dynamic>> getUserStreaks() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userUid).get();
    if (!doc.exists) return {};
    final data = doc.data()!;
    return {
      'consecutiveHitCount': data['consecutiveHitCount'] ?? 0,
      'consecutiveNoStrikeoutCount': data['consecutiveNoStrikeoutCount'] ?? 0,
      'consecutiveOnBaseCount': data['consecutiveOnBaseCount'] ?? 0,
      'currentHitStreak': data['currentHitStreak'] ?? 0,
      'currentNoStrikeoutStreak': data['currentNoStrikeoutStreak'] ?? 0,
      'currentOnBaseStreak': data['currentOnBaseStreak'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> getBattingData() async {
    try {
      String year = startDate.year.toString();
      String month = startDate.month.toString(); // 月を1桁のまま保持
      String gameType = selectedGameTypeFilter; // ゲームタイプをそのまま使用

      // 適切なドキュメントIDを生成
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

      DocumentSnapshot statsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .collection('stats')
          .doc(docId) // 適切なドキュメントを取得
          .get();

      if (!statsSnapshot.exists) {
        return {}; // ドキュメントが存在しない場合は空のマップを返す
      }

      Map<String, dynamic> stats = statsSnapshot.data() as Map<String, dynamic>;

      return stats; // 取得した統計データを返す
    } catch (e) {
      throw Exception('データの取得に失敗しました: $e'); // エラーが発生した場合は例外を投げる
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final bool isTablet = shortestSide >= 600;
    final double horizontalPadding = 16.0 + (isTablet ? 60.0 : 0.0);
    final double maxContentWidth = isTablet ? 720.0 : double.infinity;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait([getBattingData(), getUserStreaks()]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.any((data) => data.isEmpty)) {
            return const Center(child: Text('データがありません'));
          }
          final stats = snapshot.data![0];
          final streaks = snapshot.data![1];
          DateTime gameDate = (stats['gameDate'] as Timestamp).toDate();

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if ((streaks['currentHitStreak'] ?? 0) >= 2 ||
                      (streaks['currentOnBaseStreak'] ?? 0) >= 2 ||
                      (streaks['currentNoStrikeoutStreak'] ?? 0) >= 2 ||
                      (streaks['consecutiveHitCount'] ?? 0) >= 2 ||
                      (streaks['consecutiveOnBaseCount'] ?? 0) >= 2 ||
                      (streaks['consecutiveNoStrikeoutCount'] ?? 0) >= 2) ...[
                    Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((streaks['currentHitStreak'] ?? 0) >= 2)
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text:
                                          '${streaks['currentHitStreak']}試合連続ヒット',
                                    ),
                                  ],
                                ),
                              ),
                            if ((streaks['currentOnBaseStreak'] ?? 0) >= 2)
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text:
                                          '${streaks['currentOnBaseStreak']}試合連続出塁',
                                    ),
                                  ],
                                ),
                              ),
                            if ((streaks['currentNoStrikeoutStreak'] ?? 0) >= 2)
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text:
                                          '${streaks['currentNoStrikeoutStreak']}試合連続三振なし！',
                                    ),
                                  ],
                                ),
                              ),
                            if ((streaks['consecutiveHitCount'] ?? 0) >= 2)
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text:
                                          '${streaks['consecutiveHitCount']}打席連続ヒット中！',
                                    ),
                                  ],
                                ),
                              ),
                            if ((streaks['consecutiveOnBaseCount'] ?? 0) >= 2)
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text:
                                          '${streaks['consecutiveOnBaseCount']}打席連続出塁中！',
                                    ),
                                  ],
                                ),
                              ),
                            if ((streaks['consecutiveNoStrikeoutCount'] ?? 0) >=
                                2)
                              RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text:
                                          '${streaks['consecutiveNoStrikeoutCount']}打席連続三振なし！',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '初めて記録した日: ${DateFormat('yyyy/MM/dd').format(gameDate)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stats['totalGames']}試合',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange),
                                      color: Colors.orange,
                                    ),
                                    child: const Text(
                                      '率',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text:
                                              '${formatPercentage(stats['battingAverage'])} ',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              '(${stats['atBats']} - ${stats['hits']})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange),
                                      color: Colors.orange,
                                    ),
                                    child: const Text(
                                      '打',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${stats['totalRbis']}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange),
                                      color: Colors.orange,
                                    ),
                                    child: const Text(
                                      '本',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${stats['totalHomeRuns']}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '打席: ${stats['totalBats']}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn('安打', '${stats['hits']}', 60),
                              _buildStatColumn(
                                  '凡打', '${stats['totalOuts']}', 60),
                              _buildStatColumn(
                                  '三振', '${stats['totalStrikeouts']}', 60),
                              _buildStatColumn(
                                  '犠打', '${stats['totalAllBuntSuccess']}', 60),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn(
                                  '犠飛', '${stats['totalSacrificeFly']}', 60),
                              _buildStatColumn(
                                  '四球', '${stats['totalFourBalls']}', 60),
                              _buildStatColumn(
                                  '死球', '${stats['totalHitByAPitch']}', 60),
                              _buildStatColumn(
                                  '盗塁', '${stats['totalSteals']}', 60),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn(
                                  '得点', '${stats['totalRuns']}', 60),
                              _buildStatColumn(
                                  '出塁率',
                                  formatPercentage(stats['onBasePercentage']),
                                  100),
                              _buildStatColumn(
                                  '長打率',
                                  formatPercentage(stats['sluggingPercentage']),
                                  100),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn(
                                  'OPS',
                                  formatPercentage(
                                      stats['ops']?.toDouble() ?? 0.0),
                                  100),
                              _buildStatColumn(
                                  'RC',
                                  formatPercentage(
                                      stats['rc']?.toDouble() ?? 0.0),
                                  100),
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
                              const Text(
                                '安打の内訳',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
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
                              const Text(
                                '凡打の内訳',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
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
            width: underlineWidth, // 下線の長さを受け取った値に設定
            height: 1,
            color: Colors.black,
          ),
        ],
      ),
    ],
  );
}

String formatPercentage(num value) {
  // num型にすることでintとdouble両方を受け入れられる
  double doubleValue = value.toDouble(); // intをdoubleに変換
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted;
}
