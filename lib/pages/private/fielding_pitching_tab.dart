import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FieldingPitchingTab extends StatelessWidget {
  final String userUid;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const FieldingPitchingTab({
    super.key,
    required this.userUid,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  Future<Map<String, dynamic>> getFieldingPitchingData() async {
    try {
      // Firestoreからユーザーの情報を取得
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .get();

      if (!userSnapshot.exists) {
        throw Exception('ユーザーが見つかりません');
      }

      // ユーザーのデータを取得
      Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;

      // 適切なドキュメントIDを生成
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

      // Firestoreから結果統計を取得
      DocumentSnapshot statsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .collection('stats')
          .doc(docId) // 適切なドキュメントを取得
          .get();

      if (!statsSnapshot.exists) {
        return {};
      }

      Map<String, dynamic> stats = statsSnapshot.data() as Map<String, dynamic>;

      // ユーザーのポジションから投手かどうかを判定
      bool isPitcher = (userData['positions'] as List).contains('投手');
      bool isCatcher = (userData['positions'] as List).contains('捕手');

      // 統計データに投手・捕手かどうかを追加
      stats['isPitcher'] = isPitcher;
      stats['isCatcher'] = isCatcher;

      return stats;
    } catch (e) {
      throw Exception('データの取得に失敗しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: FutureBuilder<Map<String, dynamic>>(
        future: getFieldingPitchingData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('データがありません'));
          }

          final stats = snapshot.data!;
          DateTime gameDate = (stats['gameDate'] as Timestamp).toDate();
          bool isPitcher = stats['isPitcher'];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '初めて記録した日: ${DateFormat('yyyy/MM/dd').format(gameDate)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
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
                                '${stats['totalGames']} 試合',
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
                                '${stats['totalAppearances']}',
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
                                '${stats['totalInningsPitched'].toStringAsFixed(1)}',
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
                                              '${formatPercentageEra(stats['era'])}',
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
                                    '${stats['totalEarnedRuns']}',
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
                                    '${stats['totalPStrikeouts']}',
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
                                  '被安打', '${stats['totalHitsAllowed']}', 60),
                              buildStatColumn('被本塁打',
                                  '${stats['totalHomeRunsAllowed']}', 60),
                              buildStatColumn(
                                  '与四球', '${stats['totalWalks']}', 60),
                              buildStatColumn(
                                  '与死球', '${stats['totalHitByPitch']}', 60),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              buildStatColumn(
                                  '失点', '${stats['totalRunsAllowed']}', 60),
                              buildStatColumn(
                                  '打者', '${stats['totalBattersFaced']}', 60),
                              buildStatColumn(
                                  '先発', '${stats['totalStarts']}', 60),
                              buildStatColumn(
                                  '中継ぎ', '${stats['totalReliefs']}', 60),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              buildStatColumn(
                                  '抑え', '${stats['totalClosures']}', 60),
                              buildStatColumn(
                                  '完投', '${stats['totalCompleteGames']}', 60),
                              buildStatColumn(
                                  '完封', '${stats['totalShutouts']}', 60),
                              buildStatColumn(
                                  'ホールド', '${stats['totalHolds']}', 60),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildStatColumn(
                                  'セーブ', '${stats['totalSaves']}', 60),
                              SizedBox(width: 30),
                              buildStatColumn(
                                  '救援勝利', '${stats['totalReliefWins']}', 60),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              buildStatColumn(
                                  '勝利', '${stats['totalWins']}', 60),
                              buildStatColumn(
                                  '敗北', '${stats['totalLosses']}', 60),
                              buildStatColumn('勝率',
                                  '${formatPercentage(stats['winRate'])}', 60),
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
                              '${stats['totalGames']} 試合',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Text(
                          '守備率',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${formatPercentage(stats['fieldingPercentage'])}',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildStatColumn(
                                '刺殺', '${stats['totalPutouts']}', 60),
                            buildStatColumn(
                                '捕殺', '${stats['totalAssists']}', 60),
                            buildStatColumn(
                                '失策', '${stats['totalErrors']}', 60),
                          ],
                        ),
                        if (stats['isCatcher'] == true) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              buildStatColumn('盗塁企図',
                                  '${stats['totalStolenBaseAttempts']}', 60),
                              buildStatColumn(
                                  '盗塁刺', '${stats['totalCaughtStealing']}', 60),
                              buildStatColumn(
                                  '阻止率',
                                  '${formatPercentage(stats['catcherStealingRate'])}',
                                  60),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
