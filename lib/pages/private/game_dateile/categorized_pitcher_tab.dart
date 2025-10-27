import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategorizedPitcherTab extends StatefulWidget {
  final String userUid;
  final String statId;
  final List<String> userPositions;

  const CategorizedPitcherTab({
    Key? key,
    required this.userUid,
    required this.statId,
    required this.userPositions,
  }) : super(key: key);

  @override
  State<CategorizedPitcherTab> createState() => _CategorizedPitcherTabState();
}

class _CategorizedPitcherTabState extends State<CategorizedPitcherTab> {
  Map<String, dynamic>? stats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('teamLocationStats')
        .doc(widget.statId)
        .get();

    if (doc.exists) {
      setState(() {
        stats = doc.data();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stats == null) {
      return const Center(child: Text('データがありません'));
    }

    bool isPitcher = widget.userPositions.contains("投手");
    bool isCatcher = widget.userPositions.contains("捕手");

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPitcher) // もし投手なら
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${stats?['totalGames']} 試合',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '登板:',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${stats?['totalAppearances']}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '投球回:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${stats?['totalInningsPitched'].toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                                          '${formatPercentageEra(stats?['era'])}',
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
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange),
                                  color: Colors.orange,
                                ),
                                child: const Text(
                                  '自',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${stats?['totalEarnedRuns']}',
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
                                  '奪',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${stats?['totalPStrikeouts']}',
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
            if (isPitcher)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildStatColumn(
                              '被安打', '${stats?['totalHitsAllowed']}', 60),
                          buildStatColumn('与四球', '${stats?['totalWalks']}', 60),
                          buildStatColumn(
                              '与死球', '${stats?['totalHitByPitch']}', 60),
                          buildStatColumn(
                              '失点', '${stats?['totalRunsAllowed']}', 60),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildStatColumn(
                              '打者', '${stats?['totalBattersFaced']}', 60),
                          buildStatColumn('先発', '${stats?['totalStarts']}', 60),
                          buildStatColumn(
                              '中継ぎ', '${stats?['totalReliefs']}', 60),
                          buildStatColumn(
                              '抑え', '${stats?['totalClosures']}', 60),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildStatColumn(
                              '完投', '${stats?['totalCompleteGames']}', 60),
                          buildStatColumn(
                              '完封', '${stats?['totalShutouts']}', 60),
                          buildStatColumn(
                              'ホールド', '${stats?['totalHolds']}', 60),
                          buildStatColumn('セーブ', '${stats?['totalSaves']}', 60),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildStatColumn(
                              '救援勝利', '${stats?['totalReliefWins']}', 60),
                          buildStatColumn('勝利', '${stats?['totalWins']}', 60),
                          buildStatColumn('敗北', '${stats?['totalLosses']}', 60),
                          buildStatColumn('勝率',
                              '${formatPercentage(stats?['winRate'])}', 60),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (isPitcher)
              const Text(
                '守備',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0), // 引数を修正
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${stats?['totalGames']} 試合',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Text(
                      '守備率',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${formatPercentage(stats?['fieldingPercentage'])}',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        buildStatColumn('刺殺', '${stats?['totalPutouts']}', 60),
                        buildStatColumn('捕殺', '${stats?['totalAssists']}', 60),
                        buildStatColumn('失策', '${stats?['totalErrors']}', 60),
                      ],
                    ),
                    if (isCatcher) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildStatColumn('盗塁企図',
                              '${stats?['totalStolenBaseAttempts']}', 60),
                          buildStatColumn(
                              '盗塁刺', '${stats?['totalCaughtStealing']}', 60),
                          buildStatColumn(
                              '阻止率',
                              '${formatPercentage(stats?['catcherStealingRate'])}',
                              60),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget buildStatColumn(String label, String value, double underlineWidth) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(value, style: const TextStyle(fontSize: 20)),
        Container(
          width: underlineWidth,
          height: 1,
          color: Colors.black,
        ),
      ],
    );
  }
}

String formatPercentage(num value) {
  double doubleValue = value.toDouble(); // intをdoubleに変換
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted; // 先頭の0を削除
}

String formatPercentageEra(num value) {
  double doubleValue = value.toDouble(); // num を double に変換
  return doubleValue.toStringAsFixed(2); // 小数点第2位までフォーマット
}
