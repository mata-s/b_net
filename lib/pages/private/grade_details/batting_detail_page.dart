import 'package:b_net/pages/private/grade_details/sacrifice_fly_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_net/pages/private/grade_details/bunt_detail_page.dart';

class BattingDetailPage extends StatefulWidget {
  final String userUid;
  final String selectedPeriodFilter;
  final String selectedGameTypeFilter;
  final DateTime startDate;
  final DateTime endDate;
  final bool yearOnly;

  const BattingDetailPage({
    super.key,
    required this.userUid,
    required this.selectedPeriodFilter,
    required this.selectedGameTypeFilter,
    required this.startDate,
    required this.endDate,
    required this.yearOnly,
  });

  @override
  State<BattingDetailPage> createState() => _BattingDetailPageState();
}

class _BattingDetailPageState extends State<BattingDetailPage> {
  Future<Map<String, dynamic>?>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = getFullStats();
  }

  Future<Map<String, dynamic>?> getFullStats() async {
    String year = widget.startDate.year.toString();
    String month = widget.startDate.month.toString();
    String gameType = widget.selectedGameTypeFilter;

    String docId;
    if (widget.yearOnly) {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_all'
          : 'results_stats_${year}_${gameType}_all';
    } else if (widget.selectedPeriodFilter == '通算') {
      docId = gameType == '全試合'
          ? 'results_stats_all'
          : 'results_stats_${gameType}_all';
    } else if (widget.selectedPeriodFilter == '今年' ||
        widget.selectedPeriodFilter == '去年') {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_all'
          : 'results_stats_${year}_${gameType}_all';
    } else {
      docId = gameType == '全試合'
          ? 'results_stats_${year}_$month'
          : 'results_stats_${year}_${month}_$gameType';
    }

    final statsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .collection('stats')
        .doc(docId)
        .get();

    return statsSnapshot.data();
  }

  String formatPercentage(dynamic value) {
    if (value == null) return '0%';
    if (value is num) {
      double percent = value * 100;
      return percent % 1 == 0
          ? '${percent.toInt()}%'
          : '${percent.toStringAsFixed(1)}%';
    }
    return value.toString();
  }

  Widget _buildStatItem(String label, dynamic value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${value != null ? (value is num ? value.toStringAsFixed(3) : value.toString()) : '0.000'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, dynamic value,
      [double underlineWidth = 40]) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value != null
              ? (value is num ? value.toStringAsFixed(3) : value.toString())
              : '0.000',
          style: const TextStyle(
            fontSize: 20,
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: underlineWidth,
              height: 1,
              color: Colors.black,
            ),
          ],
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant BattingDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriodFilter != oldWidget.selectedPeriodFilter ||
        widget.selectedGameTypeFilter != oldWidget.selectedGameTypeFilter ||
        widget.startDate != oldWidget.startDate ||
        widget.endDate != oldWidget.endDate) {
      setState(() {
        _statsFuture = getFullStats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 251, 252),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('データがありません'));
          }
          final stats = snapshot.data!;
          final adv = stats['advancedStats'] ?? {};
          final firstPitchSwingCount = stats['firstPitchSwingCount'] ?? 0;
          final firstPitchSwingHits = stats['firstPitchSwingHits'] ?? 0;
          final firstPitchSwingRate = adv['firstPitchSwingRate'];
          final firstPitchSwingSuccessRate = adv['firstPitchSwingSuccessRate'];
          final firstPitchHitRate = adv['firstPitchHitRate'];
          final swingCount = stats['swingCount'] ?? 0;
          final missSwingCount = stats['missSwingCount'] ?? 0;
          final batterPitchCount = stats['batterPitchCount'] ?? 0;
          final swingRate = adv['swingRate'];
          final missSwingRate = adv['missSwingRate'];
          final avgPitchesPerAtBat = adv['avgPitchesPerAtBat'];
          final totalBats = stats['totalBats'] ?? 0;
          final atBats = stats['atBats'] ?? 0;
          final totalBuntAttempts = stats['totalBuntAttempts'] ?? 0;
          final totalAllBuntSuccess = stats['totalAllBuntSuccess'] ?? 0;
          final totalstealsAttempts = stats['totalstealsAttempts'] ?? 0;
          final totalSteals = stats['totalSteals'] ?? 0;
          final totalSacrificeFly = stats['totalSacrificeFly'] ?? 0;

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    top: 60), // make space for the fixed header
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '打撃傾向',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn(
                                      'ISO', formatAverage(adv['iso']), 80),
                                  _buildStatColumn(
                                      'BABI', formatAverage(adv['babip']), 80),
                                  _buildStatColumn('BB/K',
                                      formatAverage(adv['bbPerK'] ?? 0), 80),
                                ],
                              ),
                              SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '球数',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn('球数',
                                            batterPitchCount.toString(), 100),
                                        _buildStatColumn(
                                            '平均球数',
                                            avgPitchesPerAtBat
                                                .toStringAsFixed(1),
                                            100),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '選球眼',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '四球割合',
                                            formatPercentage(
                                                adv['walkHitByPitchRate']
                                                        ?['fourBallsRate'] ??
                                                    0),
                                            100),
                                        _buildStatColumn(
                                            '死球割合',
                                            formatPercentage(
                                                adv['walkHitByPitchRate']
                                                        ?['hitByPitchRate'] ??
                                                    0),
                                            100),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'アプローチ傾向',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '初球',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '初球スイング数',
                                            firstPitchSwingCount.toString(),
                                            60),
                                        _buildStatColumn('初球安打数',
                                            firstPitchSwingHits.toString(), 60),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '初球スイング率',
                                            formatPercentage(
                                                firstPitchSwingRate),
                                            100),
                                        _buildStatColumn(
                                            '初球打率',
                                            formatAverage(firstPitchHitRate),
                                            100),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '初球スイングが安打になる率',
                                            formatPercentage(
                                                firstPitchSwingSuccessRate),
                                            100),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'スイング傾向',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            'スイング数', swingCount.toString(), 60),
                                        _buildStatColumn('空振り数',
                                            missSwingCount.toString(), 60),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn('スイング率',
                                            formatPercentage(swingRate), 100),
                                        _buildStatColumn(
                                            '空振り率',
                                            formatPercentage(missSwingRate),
                                            100),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'チャンスメイク',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              // 犠打ブロック
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'バント',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            'バント企図数',
                                            totalBuntAttempts?.toString() ??
                                                '0',
                                            100),
                                        _buildStatColumn(
                                            'バント成功数',
                                            totalAllBuntSuccess?.toString(),
                                            100),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            'バント成功率',
                                            formatPercentage(
                                                adv['buntSuccessRate']),
                                            100),
                                      ],
                                    ),
                                    // さらに詳しくボタン
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BuntDetailPage(
                                              userUid: widget.userUid,
                                              selectedPeriodFilter:
                                                  widget.selectedPeriodFilter,
                                              selectedGameTypeFilter:
                                                  widget.selectedGameTypeFilter,
                                              startDate: widget.startDate,
                                              endDate: widget.endDate,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'さらに詳しく',
                                        style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 盗塁・進塁ブロック
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '盗塁',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '盗塁企図数',
                                            totalstealsAttempts?.toString() ??
                                                '0',
                                            100),
                                        _buildStatColumn(
                                            '盗塁成功数',
                                            totalSteals?.toString() ?? '0',
                                            100),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '盗塁成功率',
                                            formatAverage(
                                                adv['stealSuccessRate'] ?? 0),
                                            100),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.only(bottom: 30),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '得点貢献度',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 20, thickness: 1.5),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '生還率',
                                            formatPercentage(
                                                adv['runAfterOnBaseRate']),
                                            100),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '犠飛',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatColumn(
                                            '犠飛',
                                            totalSacrificeFly?.toString() ??
                                                '0',
                                            100),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                SacrificeFlyDetailPage(
                                              userUid: widget.userUid,
                                              selectedPeriodFilter:
                                                  widget.selectedPeriodFilter,
                                              selectedGameTypeFilter:
                                                  widget.selectedGameTypeFilter,
                                              startDate: widget.startDate,
                                              endDate: widget.endDate,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'さらに詳しく',
                                        style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 240, 251, 252),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text('打席: $totalBats',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      SizedBox(width: 20),
                      Row(
                        children: [
                          Text('打数: $atBats',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String formatAverage(num value) {
  // num型にすることでintとdouble両方を受け入れられる
  double doubleValue = value.toDouble(); // intをdoubleに変換
  String formatted = doubleValue.toStringAsFixed(3);
  return formatted.startsWith("0")
      ? formatted.replaceFirst("0", "")
      : formatted;
}
