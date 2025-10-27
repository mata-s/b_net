import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategorizedBattingTab extends StatefulWidget {
  final String userUid;
  final String statId;
  final List<String> userPositions;

  const CategorizedBattingTab({
    super.key,
    required this.userUid,
    required this.statId,
    required this.userPositions,
  });

  @override
  State<CategorizedBattingTab> createState() => _CategorizedBattingTabState();
}

class _CategorizedBattingTabState extends State<CategorizedBattingTab> {
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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // ← return 削除
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // テキストを左揃えにする
                  children: [
                    Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${stats?['totalGames']}試合',
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
                                        border:
                                            Border.all(color: Colors.orange),
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
                                                '${formatPercentage(stats?['battingAverage'])} ',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                '(${stats?['atBats']} - ${stats?['hits']})',
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
                                        border:
                                            Border.all(color: Colors.orange),
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
                                      '${stats?['totalRbis']}',
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
                                        border:
                                            Border.all(color: Colors.orange),
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
                                      '${stats?['totalHomeRuns']}',
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
                              '打席: ${stats?['totalBats']}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn('安打', '${stats?['hits']}', 60),
                                _buildStatColumn(
                                    '凡打', '${stats?['totalOuts']}', 60),
                                _buildStatColumn(
                                    '三振', '${stats?['totalStrikeouts']}', 60),
                                _buildStatColumn('犠打',
                                    '${stats?['totalAllBuntSuccess']}', 60),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '犠飛', '${stats?['totalSacrificeFly']}', 60),
                                _buildStatColumn(
                                    '四球', '${stats?['totalFourBalls']}', 60),
                                _buildStatColumn(
                                    '死球', '${stats?['totalHitByAPitch']}', 60),
                                _buildStatColumn(
                                    '盗塁', '${stats?['totalSteals']}', 60),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn(
                                    '得点', '${stats?['totalRuns']}', 60),
                                _buildStatColumn(
                                    '出塁率',
                                    formatPercentage(
                                        stats?['onBasePercentage']),
                                    100),
                                _buildStatColumn(
                                    '長打率',
                                    formatPercentage(
                                        stats?['sluggingPercentage']),
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
                                        stats?['ops']?.toDouble() ?? 0.0),
                                    100),
                                _buildStatColumn(
                                    'RC',
                                    formatPercentage(
                                        stats?['rc']?.toDouble() ?? 0.0),
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
                                  '内野安打: ${stats?['totalInfieldHits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '単打: ${stats?['total1hits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '二塁打: ${stats?['total2hits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '三塁打: ${stats?['total3hits']}',
                                  style: const TextStyle(
                                    color: Color(0xFF2C2C2C),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '本塁打: ${stats?['totalHomeRuns']}',
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
                                Text('ゴロ: ${stats?['totalGrounders']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('ライナー: ${stats?['totalLiners']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('フライ: ${stats?['totalFlyBalls']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('併殺打: ${stats?['totalDoublePlays']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('失策出塁: ${stats?['totalErrorReaches']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                const SizedBox(height: 5),
                                Text('守備妨害: ${stats?['totalInterferences']}',
                                    style: const TextStyle(
                                      color: Color(0xFF2C2C2C),
                                      fontSize: 18,
                                    )),
                                Text('バント失敗: ${stats?['totalBuntOuts']}',
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
                                            '${stats?['totalSwingingStrikeouts']}',
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
                                            '${stats?['totalOverlookStrikeouts']}',
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
                                            '${stats?['totalSwingAwayStrikeouts']}',
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
                                            '${stats?['totalThreeBuntFailures']}',
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
